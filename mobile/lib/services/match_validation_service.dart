import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khomasi/services/token_service.dart';
import 'package:khomasi/services/push_notification_sender.dart';

/// Service to handle match validation and auto-cancellation
/// 
/// Rules:
/// - 1 hour before match: Check if match is 100% full AND has referee
/// - If not valid: Auto-cancel match and refund all players
class MatchValidationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================
  // CHECK AND CANCEL INVALID MATCHES
  // ============================================
  
  /// Call this periodically (e.g., every 5-10 minutes via Cloud Function)
  /// Or on app open - checks all open matches starting within 1 hour
  static Future<void> checkAndCancelInvalidMatches() async {
    final now = DateTime.now();
    final oneHourFromNow = now.add(const Duration(hours: 1));
    
    try {
      // Get ALL open matches starting within the next hour
      // These should be cancelled if not valid (not full or no referee)
      final matchesSnapshot = await _firestore
          .collection('matches')
          .where('status', isEqualTo: 'open')
          .where('dateTime', isGreaterThan: Timestamp.fromDate(now))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(oneHourFromNow))
          .get();
      
      print('🔍 Checking ${matchesSnapshot.docs.length} matches starting within 1 hour...');
      
      for (final doc in matchesSnapshot.docs) {
        await _validateAndProcessMatch(doc.id, doc.data());
      }
    } catch (e) {
      print('Error checking matches: $e');
    }
  }

  // ============================================
  // VALIDATE SINGLE MATCH
  // ============================================
  
  static Future<MatchValidationResult> validateMatch(String matchId) async {
    try {
      final doc = await _firestore.collection('matches').doc(matchId).get();
      if (!doc.exists) {
        return MatchValidationResult(
          isValid: false,
          reason: 'Match not found',
        );
      }
      
      final data = doc.data()!;
      return _checkMatchValidity(data);
    } catch (e) {
      return MatchValidationResult(
        isValid: false,
        reason: 'Error: $e',
      );
    }
  }

  static MatchValidationResult _checkMatchValidity(Map<String, dynamic> data) {
    final currentPlayers = (data['currentPlayers'] ?? 0) as int;
    final maxPlayers = (data['maxPlayers'] ?? 10) as int;
    final refereeId = data['refereeId'] as String?;
    
    final isFull = currentPlayers >= maxPlayers;
    final hasReferee = refereeId != null && refereeId.isNotEmpty;
    
    if (!isFull && !hasReferee) {
      return MatchValidationResult(
        isValid: false,
        reason: 'لم يكتمل عدد اللاعبين ولا يوجد حكم',
        missingPlayers: maxPlayers - currentPlayers,
        hasReferee: false,
      );
    } else if (!isFull) {
      return MatchValidationResult(
        isValid: false,
        reason: 'لم يكتمل عدد اللاعبين',
        missingPlayers: maxPlayers - currentPlayers,
        hasReferee: true,
      );
    } else if (!hasReferee) {
      return MatchValidationResult(
        isValid: false,
        reason: 'لا يوجد حكم للمباراة',
        missingPlayers: 0,
        hasReferee: false,
      );
    }
    
    return MatchValidationResult(
      isValid: true,
      reason: 'المباراة جاهزة',
      missingPlayers: 0,
      hasReferee: true,
    );
  }

  // ============================================
  // PROCESS MATCH (VALIDATE & CANCEL IF NEEDED)
  // ============================================
  
  static Future<void> _validateAndProcessMatch(String matchId, Map<String, dynamic> data) async {
    final result = _checkMatchValidity(data);
    
    if (!result.isValid) {
      await cancelMatchWithRefund(matchId, data, result.reason);
    }
  }

  // ============================================
  // CANCEL MATCH WITH REFUND
  // ============================================
  
  static Future<bool> cancelMatchWithRefund(
    String matchId,
    Map<String, dynamic> matchData,
    String reason,
  ) async {
    try {
      // Get all players from both teams
      final teamAPlayers = (matchData['teamAPlayers'] as List<dynamic>?) ?? [];
      final teamBPlayers = (matchData['teamBPlayers'] as List<dynamic>?) ?? [];
      final allPlayers = [...teamAPlayers, ...teamBPlayers];
      
      // Refund all players
      final refundReason = 'استرداد - إلغاء المباراة: $reason';
      
      for (final player in allPlayers) {
        if (player is Map<String, dynamic>) {
          final oderId = player['oderId'] as String?;
          final bookedByUserId = player['bookedByUserId'] as String?;
          
          // Refund to the person who booked (could be different from player for guests)
          final refundTo = bookedByUserId ?? oderId;
          
          if (refundTo != null && refundTo.isNotEmpty) {
            await TokenService.refundTokens(
              oderId: refundTo,
              amount: 1,
              matchId: matchId,
              description: refundReason,
            );
          }
        }
      }
      
      // Update match status
      await _firestore.collection('matches').doc(matchId).update({
        'status': 'cancelled',
        'cancelledAt': Timestamp.now(),
        'cancellationReason': reason,
        'autoCancel': true,
      });

      // Notify all players about cancellation
      final playerIds = <String>[];
      for (final player in allPlayers) {
        if (player is Map<String, dynamic>) {
          final oderId = player['oderId'] as String?;
          if (oderId != null && oderId.isNotEmpty) {
            playerIds.add(oderId);
          }
        }
      }
      if (playerIds.isNotEmpty) {
        final stadiumName = matchData['stadiumName'] ?? 'ملعب';
        PushNotificationSender.sendToUsers(
          userIds: playerIds,
          title: '❌ تم إلغاء المباراة',
          body: 'تم إلغاء المباراة في $stadiumName - $reason. تم استرداد التوكنات.',
          data: {'matchId': matchId, 'type': 'match_cancelled'},
        );
      }

      print('Match $matchId cancelled: $reason');
      return true;
    } catch (e) {
      print('Error cancelling match $matchId: $e');
      return false;
    }
  }

  // ============================================
  // MANUAL CANCEL (by admin)
  // ============================================
  
  static Future<bool> adminCancelMatch(String matchId, String reason) async {
    try {
      final doc = await _firestore.collection('matches').doc(matchId).get();
      if (!doc.exists) return false;
      
      final data = doc.data()!;
      return await cancelMatchWithRefund(matchId, data, reason);
    } catch (e) {
      print('Error in admin cancel: $e');
      return false;
    }
  }

  // ============================================
  // GET MATCHES NEEDING VALIDATION
  // ============================================
  
  /// Returns matches that will be checked in the next hour
  static Future<List<MatchToValidate>> getMatchesNeedingValidation() async {
    final now = DateTime.now();
    final twoHoursFromNow = now.add(const Duration(hours: 2));
    
    try {
      final snapshot = await _firestore
          .collection('matches')
          .where('status', isEqualTo: 'open')
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(twoHoursFromNow))
          .where('dateTime', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('dateTime')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final dateTime = (data['dateTime'] as Timestamp).toDate();
        final validationTime = dateTime.subtract(const Duration(hours: 1));
        final result = _checkMatchValidity(data);
        
        return MatchToValidate(
          matchId: doc.id,
          stadiumName: data['stadiumName'] ?? 'ملعب',
          matchTime: dateTime,
          validationTime: validationTime,
          currentPlayers: data['currentPlayers'] ?? 0,
          maxPlayers: data['maxPlayers'] ?? 10,
          hasReferee: data['refereeId'] != null,
          isCurrentlyValid: result.isValid,
          validationResult: result,
        );
      }).toList();
    } catch (e) {
      print('Error getting matches for validation: $e');
      return [];
    }
  }
}

// ============================================
// HELPER CLASSES
// ============================================

class MatchValidationResult {
  final bool isValid;
  final String reason;
  final int missingPlayers;
  final bool hasReferee;

  MatchValidationResult({
    required this.isValid,
    required this.reason,
    this.missingPlayers = 0,
    this.hasReferee = true,
  });
}

class MatchToValidate {
  final String matchId;
  final String stadiumName;
  final DateTime matchTime;
  final DateTime validationTime;
  final int currentPlayers;
  final int maxPlayers;
  final bool hasReferee;
  final bool isCurrentlyValid;
  final MatchValidationResult validationResult;

  MatchToValidate({
    required this.matchId,
    required this.stadiumName,
    required this.matchTime,
    required this.validationTime,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.hasReferee,
    required this.isCurrentlyValid,
    required this.validationResult,
  });

  Duration get timeUntilValidation => validationTime.difference(DateTime.now());
  Duration get timeUntilMatch => matchTime.difference(DateTime.now());
  
  bool get willBeCancelledIfNoChange => !isCurrentlyValid;
}