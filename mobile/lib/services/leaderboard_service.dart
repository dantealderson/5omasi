import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khomasi/models/leaderboard_model.dart';

class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================
  // MAIN LEADERBOARD METHODS
  // ==========================================

  /// Get leaderboard by period (goals)
  Future<List<LeaderboardEntry>> getGoalsLeaderboard({
    LeaderboardPeriod period = LeaderboardPeriod.all,
    int limit = 50,
  }) async {
    if (period == LeaderboardPeriod.all) {
      // All-time: use aggregated stats from users collection
      return _computeAllTimeLeaderboard(LeaderboardType.goals, limit);
    } else {
      // Time-based: aggregate from playerMatchRecords
      return _computeTimedLeaderboard(LeaderboardType.goals, period, limit);
    }
  }

  /// Get leaderboard by period (assists)
  Future<List<LeaderboardEntry>> getAssistsLeaderboard({
    LeaderboardPeriod period = LeaderboardPeriod.all,
    int limit = 50,
  }) async {
    if (period == LeaderboardPeriod.all) {
      return _computeAllTimeLeaderboard(LeaderboardType.assists, limit);
    } else {
      return _computeTimedLeaderboard(LeaderboardType.assists, period, limit);
    }
  }

  /// Compute time-based leaderboard from playerMatchRecords
  Future<List<LeaderboardEntry>> _computeTimedLeaderboard(
    LeaderboardType type,
    LeaderboardPeriod period,
    int limit,
  ) async {
    // Calculate date range
    final now = DateTime.now();
    DateTime startDate;
    
    switch (period) {
      case LeaderboardPeriod.week:
        startDate = now.subtract(const Duration(days: 7));
        break;
      case LeaderboardPeriod.month:
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case LeaderboardPeriod.year:
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      case LeaderboardPeriod.all:
        startDate = DateTime(2020); // Far in the past
        break;
    }
    
    // Query match records within date range
    final snapshot = await _firestore
        .collection('playerMatchRecords')
        .where('matchDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .get();
    
    // Aggregate stats per player
    final Map<String, Map<String, dynamic>> playerStats = {};
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final oderId = data['oderId'] as String;

      // Skip guest records that may have leaked in
      if (oderId.contains('_guest_')) continue;

      if (!playerStats.containsKey(oderId)) {
        playerStats[oderId] = {
          'oderId': oderId,
          'playerName': data['playerName'] ?? '',
          'goals': 0,
          'assists': 0,
          'totalMatches': 0,
          'wins': 0,
        };
      }
      
      playerStats[oderId]!['goals'] += data['goals'] ?? 0;
      playerStats[oderId]!['assists'] += data['assists'] ?? 0;
      playerStats[oderId]!['totalMatches'] += 1;
      if (data['result'] == 'win') {
        playerStats[oderId]!['wins'] += 1;
      }
    }
    
    // Fetch current names and photos from users collection
    final userIds = playerStats.keys.toList();
    if (userIds.isNotEmpty) {
      // Batch fetch user data for current names
      final usersSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: userIds.take(10).toList())
          .get();
      
      // If more than 10 users, fetch in batches
      final List<QueryDocumentSnapshot> allUserDocs = [...usersSnapshot.docs];
      if (userIds.length > 10) {
        for (int i = 10; i < userIds.length; i += 10) {
          final batch = userIds.skip(i).take(10).toList();
          if (batch.isNotEmpty) {
            final batchSnapshot = await _firestore
                .collection('users')
                .where(FieldPath.documentId, whereIn: batch)
                .get();
            allUserDocs.addAll(batchSnapshot.docs);
          }
        }
      }
      
      // Update player names with current names from users collection
      for (final userDoc in allUserDocs) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (playerStats.containsKey(userDoc.id)) {
          playerStats[userDoc.id]!['playerName'] = userData['name'] ?? playerStats[userDoc.id]!['playerName'];
          playerStats[userDoc.id]!['photoUrl'] = userData['profileImageUrl'] ?? userData['photoUrl'];
        }
      }
    }
    
    // Convert to list and sort
    final entries = playerStats.values.map((stats) => LeaderboardEntry(
      oderId: stats['oderId'],
      playerName: stats['playerName'],
      photoUrl: stats['photoUrl'],
      goals: stats['goals'],
      assists: stats['assists'],
      totalMatches: stats['totalMatches'],
      wins: stats['wins'],
    )).toList();
    
    // Sort by the appropriate stat
    if (type == LeaderboardType.goals) {
      entries.sort((a, b) => b.goals.compareTo(a.goals));
    } else {
      entries.sort((a, b) => b.assists.compareTo(a.assists));
    }
    
    // Filter out zero values and assign ranks
    final filtered = entries
        .where((e) => type == LeaderboardType.goals ? e.goals > 0 : e.assists > 0)
        .take(limit)
        .toList();
    
    return filtered.asMap().entries.map((e) => LeaderboardEntry(
      oderId: e.value.oderId,
      playerName: e.value.playerName,
      photoUrl: e.value.photoUrl,
      goals: e.value.goals,
      assists: e.value.assists,
      totalMatches: e.value.totalMatches,
      wins: e.value.wins,
      rank: e.key + 1,
    )).toList();
  }

  /// Stream leaderboard updates (goals)
  Stream<List<LeaderboardEntry>> streamGoalsLeaderboard({
    LeaderboardPeriod period = LeaderboardPeriod.all,
    int limit = 50,
  }) {
    // Stream directly from users collection for real-time updates
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'player')
        .snapshots()
        .map((snapshot) {
          final entries = snapshot.docs
              .where((doc) {
                final data = doc.data();
                final stats = data['playerStats'] as Map<String, dynamic>?;
                return stats != null && (stats['totalGoals'] ?? 0) > 0;
              })
              .map((doc) => LeaderboardEntry.fromUserDoc(doc, rank: 0))
              .toList();
          
          // Sort by goals
          entries.sort((a, b) => b.goals.compareTo(a.goals));
          
          // Assign ranks
          for (int i = 0; i < entries.length; i++) {
            entries[i] = LeaderboardEntry(
              oderId: entries[i].oderId,
              playerName: entries[i].playerName,
              photoUrl: entries[i].photoUrl,
              goals: entries[i].goals,
              assists: entries[i].assists,
              totalMatches: entries[i].totalMatches,
              wins: entries[i].wins,
              rank: i + 1,
            );
          }
          
          return entries.take(limit).toList();
        });
  }

  /// Stream leaderboard updates (assists)
  Stream<List<LeaderboardEntry>> streamAssistsLeaderboard({
    LeaderboardPeriod period = LeaderboardPeriod.all,
    int limit = 50,
  }) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'player')
        .snapshots()
        .map((snapshot) {
          final entries = snapshot.docs
              .where((doc) {
                final data = doc.data();
                final stats = data['playerStats'] as Map<String, dynamic>?;
                return stats != null && (stats['totalAssists'] ?? 0) > 0;
              })
              .map((doc) => LeaderboardEntry.fromUserDoc(doc, rank: 0))
              .toList();
          
          // Sort by assists
          entries.sort((a, b) => b.assists.compareTo(a.assists));
          
          // Assign ranks
          for (int i = 0; i < entries.length; i++) {
            entries[i] = LeaderboardEntry(
              oderId: entries[i].oderId,
              playerName: entries[i].playerName,
              photoUrl: entries[i].photoUrl,
              goals: entries[i].goals,
              assists: entries[i].assists,
              totalMatches: entries[i].totalMatches,
              wins: entries[i].wins,
              rank: i + 1,
            );
          }
          
          return entries.take(limit).toList();
        });
  }

  // ==========================================
  // USER RANKING METHODS
  // ==========================================

  /// Get user's rank in goals leaderboard
  Future<int?> getUserGoalsRank(String oderId, {LeaderboardPeriod period = LeaderboardPeriod.all}) async {
    final leaderboard = await getGoalsLeaderboard(period: period);
    final index = leaderboard.indexWhere((e) => e.oderId == oderId);
    return index >= 0 ? index + 1 : null;
  }

  /// Get user's rank in assists leaderboard
  Future<int?> getUserAssistsRank(String oderId, {LeaderboardPeriod period = LeaderboardPeriod.all}) async {
    final leaderboard = await getAssistsLeaderboard(period: period);
    final index = leaderboard.indexWhere((e) => e.oderId == oderId);
    return index >= 0 ? index + 1 : null;
  }

  /// Get user's leaderboard entry
  Future<LeaderboardEntry?> getUserEntry(String oderId) async {
    final doc = await _firestore.collection('users').doc(oderId).get();
    if (!doc.exists) return null;
    
    // Get ranks
    final goalsRank = await getUserGoalsRank(oderId);
    
    return LeaderboardEntry.fromUserDoc(doc, rank: goalsRank ?? 0);
  }

  /// Get users around a specific user (for context)
  Future<List<LeaderboardEntry>> getUsersAroundPlayer({
    required String oderId,
    required LeaderboardType type,
    LeaderboardPeriod period = LeaderboardPeriod.all,
    int range = 2,
  }) async {
    final leaderboard = type == LeaderboardType.goals 
        ? await getGoalsLeaderboard(period: period)
        : await getAssistsLeaderboard(period: period);
    
    final userIndex = leaderboard.indexWhere((e) => e.oderId == oderId);
    if (userIndex < 0) return [];
    
    final start = (userIndex - range).clamp(0, leaderboard.length);
    final end = (userIndex + range + 1).clamp(0, leaderboard.length);
    
    return leaderboard.sublist(start, end);
  }

  // ==========================================
  // TOP PLAYERS METHODS
  // ==========================================

  /// Get top 3 goal scorers (for podium display)
  Future<List<LeaderboardEntry>> getTopGoalScorers({
    LeaderboardPeriod period = LeaderboardPeriod.all,
  }) async {
    final leaderboard = await getGoalsLeaderboard(period: period, limit: 3);
    return leaderboard.take(3).toList();
  }

  /// Get top 3 assist makers (for podium display)
  Future<List<LeaderboardEntry>> getTopAssistMakers({
    LeaderboardPeriod period = LeaderboardPeriod.all,
  }) async {
    final leaderboard = await getAssistsLeaderboard(period: period, limit: 3);
    return leaderboard.take(3).toList();
  }

  // ==========================================
  // PRIVATE HELPER METHODS
  // ==========================================

  Future<List<LeaderboardEntry>> _computeAllTimeLeaderboard(
    LeaderboardType type,
    int limit,
  ) async {
    final field = type == LeaderboardType.goals 
        ? 'playerStats.totalGoals' 
        : 'playerStats.totalAssists';
    
    // Query ALL players (both 'player' string and for safety)
    final snapshot = await _firestore
        .collection('users')
        .orderBy(field, descending: true)
        .limit(limit)
        .get();
    
    // Filter to only include players with stats > 0
    final filteredDocs = snapshot.docs.where((doc) {
      final data = doc.data();
      final role = data['role'];
      // Accept both 'player' and enum format
      if (role != 'player' && role != 'UserRole.player') return false;
      
      final stats = data['playerStats'] as Map<String, dynamic>?;
      if (stats == null) return false;
      
      final value = type == LeaderboardType.goals 
          ? stats['totalGoals'] ?? 0 
          : stats['totalAssists'] ?? 0;
      return value > 0;
    }).toList();
    
    return filteredDocs
        .asMap()
        .entries
        .map((e) => LeaderboardEntry.fromUserDoc(e.value, rank: e.key + 1))
        .toList();
  }
}