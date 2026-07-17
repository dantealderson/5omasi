import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerRatingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit a rating for a player from a specific match.
  /// Returns true if successful.
  /// - One rating per (rater, rated player, match) combo
  /// - Can update existing rating
  /// - Cannot rate yourself
  static Future<bool> ratePlayer({
    required String raterUserId,
    required String ratedPlayerId,
    required String matchId,
    required double rating,
    List<String> traits = const [],
  }) async {
    if (raterUserId == ratedPlayerId) return false;
    if (rating < 1 || rating > 5) return false;

    try {
      // Use deterministic doc ID to prevent duplicates
      final ratingDocId = '${matchId}_${raterUserId}_$ratedPlayerId';

      return await _firestore.runTransaction((transaction) async {
        final ratingRef = _firestore.collection('playerRatings').doc(ratingDocId);
        final ratingDoc = await transaction.get(ratingRef);

        final userRef = _firestore.collection('users').doc(ratedPlayerId);
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) return false;

        final userData = userDoc.data()!;
        final playerStats = userData['playerStats'] as Map<String, dynamic>? ?? {};
        final currentAvg = (playerStats['averageRating'] ?? 0.0).toDouble();
        final currentCount = (playerStats['totalRatings'] ?? 0) as int;

        double newAvg;
        int newCount;

        if (ratingDoc.exists) {
          // Update existing rating - recalculate average
          final oldRating = (ratingDoc.data()!['rating'] as num).toDouble();
          newCount = currentCount; // count stays same
          if (newCount > 0) {
            final totalSum = currentAvg * currentCount - oldRating + rating;
            newAvg = totalSum / newCount;
          } else {
            newAvg = rating;
            newCount = 1;
          }
        } else {
          // New rating
          newCount = currentCount + 1;
          newAvg = ((currentAvg * currentCount) + rating) / newCount;
        }

        // Clamp average to valid range
        newAvg = newAvg.clamp(0.0, 5.0);

        // Save/update the rating document
        transaction.set(ratingRef, {
          'raterUserId': raterUserId,
          'ratedPlayerId': ratedPlayerId,
          'matchId': matchId,
          'rating': rating,
          'traits': traits,
          'createdAt': ratingDoc.exists
              ? ratingDoc.data()!['createdAt']
              : Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });

        // Update player's average rating
        transaction.update(userRef, {
          'playerStats.averageRating': newAvg,
          'playerStats.totalRatings': newCount,
        });

        return true;
      });
    } catch (e) {
      print('Error rating player: $e');
      return false;
    }
  }

  /// Get the user's last completed match (most recent).
  /// Returns null if no completed matches found.
  static Future<Map<String, dynamic>?> getLastCompletedMatch(String userId) async {
    try {
      // Query playerMatchRecords for this user's matches
      final records = await _firestore
          .collection('playerMatchRecords')
          .where('oderId', isEqualTo: userId)
          .get();

      if (records.docs.isEmpty) return null;

      // Sort by matchDate descending to get the latest
      final sorted = records.docs.toList()
        ..sort((a, b) {
          final dateA = (a.data()['matchDate'] as Timestamp).toDate();
          final dateB = (b.data()['matchDate'] as Timestamp).toDate();
          return dateB.compareTo(dateA);
        });

      final latestRecord = sorted.first.data();
      final matchId = latestRecord['matchId'] as String?;
      if (matchId == null) return null;

      // Get the full match document
      final matchDoc = await _firestore.collection('matches').doc(matchId).get();
      if (!matchDoc.exists) return null;

      final matchData = matchDoc.data()!;
      if (matchData['status'] != 'completed') return null;

      return {
        'matchId': matchId,
        ...matchData,
      };
    } catch (e) {
      print('Error getting last completed match: $e');
      return null;
    }
  }

  /// Get all players from a match (both teams), excluding the given user.
  static List<Map<String, dynamic>> getMatchPlayers(
    Map<String, dynamic> matchData,
    String excludeUserId,
  ) {
    final players = <Map<String, dynamic>>[];

    final teamA = (matchData['teamAPlayers'] as List<dynamic>?) ?? [];
    final teamB = (matchData['teamBPlayers'] as List<dynamic>?) ?? [];

    for (final player in [...teamA, ...teamB]) {
      if (player is Map<String, dynamic>) {
        final oderId = player['oderId'] as String?;
        final isGuest = player['isGuest'] == true;
        if (oderId != null && oderId != excludeUserId && !isGuest) {
          players.add(player);
        }
      }
    }

    return players;
  }

  /// Get existing ratings the user has given for a specific match.
  /// Returns a map of ratedPlayerId -> {rating, traits}.
  static Future<Map<String, Map<String, dynamic>>> getMyRatingsForMatch(
    String raterUserId,
    String matchId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('playerRatings')
          .where('raterUserId', isEqualTo: raterUserId)
          .where('matchId', isEqualTo: matchId)
          .get();

      final ratings = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final ratedId = data['ratedPlayerId'] as String?;
        final rating = (data['rating'] as num?)?.toDouble();
        if (ratedId != null && rating != null) {
          ratings[ratedId] = {
            'rating': rating,
            'traits': (data['traits'] as List<dynamic>?)?.cast<String>() ?? <String>[],
          };
        }
      }
      return ratings;
    } catch (e) {
      print('Error getting ratings for match: $e');
      return {};
    }
  }

  /// Get aggregated trait counts for a player across all ratings.
  /// Returns a map of traitKey -> count, sorted by most frequent.
  static Future<Map<String, int>> getPlayerTraits(String playerId) async {
    try {
      final snapshot = await _firestore
          .collection('playerRatings')
          .where('ratedPlayerId', isEqualTo: playerId)
          .get();

      final traitCounts = <String, int>{};
      for (final doc in snapshot.docs) {
        final traits = (doc.data()['traits'] as List<dynamic>?)?.cast<String>() ?? [];
        for (final trait in traits) {
          traitCounts[trait] = (traitCounts[trait] ?? 0) + 1;
        }
      }

      // Sort by count descending
      final sorted = traitCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return Map.fromEntries(sorted);
    } catch (e) {
      print('Error getting player traits: $e');
      return {};
    }
  }

  /// Check if a user has already rated all players in a match.
  static Future<bool> hasRatedAllPlayers(
    String userId,
    String matchId,
    int totalPlayers,
  ) async {
    final ratings = await getMyRatingsForMatch(userId, matchId);
    return ratings.length >= totalPlayers;
  }
}
