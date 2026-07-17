import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khomasi/models/match_model.dart';

class TeamBalanceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Balance teams in a match by redistributing players so both teams
  /// have roughly equal total ratings.
  /// Returns true if rebalanced successfully.
  static Future<bool> balanceTeams(String matchId) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final matchRef = _firestore.collection('matches').doc(matchId);
        final matchDoc = await transaction.get(matchRef);

        if (!matchDoc.exists) return false;

        final match = MatchModel.fromFirestore(matchDoc);
        final allPlayers = [...match.teamAPlayers, ...match.teamBPlayers];

        if (allPlayers.length < 2) return false;

        // Fetch ratings for all non-guest players
        final ratings = <String, double>{};
        for (final player in allPlayers) {
          if (player.isGuest) {
            ratings[player.oderId] = 0.0;
            continue;
          }
          final userDoc = await transaction.get(
            _firestore.collection('users').doc(player.oderId),
          );
          if (userDoc.exists) {
            final stats = userDoc.data()?['playerStats'] as Map<String, dynamic>?;
            ratings[player.oderId] = (stats?['averageRating'] ?? 0.0).toDouble();
          } else {
            ratings[player.oderId] = 0.0;
          }
        }

        // Group: real players with their guests
        final groups = _buildPlayerGroups(allPlayers);

        // Sort groups by total rating descending
        groups.sort((a, b) {
          final ratingA = a.fold<double>(0, (sum, p) => sum + (ratings[p.oderId] ?? 0));
          final ratingB = b.fold<double>(0, (sum, p) => sum + (ratings[p.oderId] ?? 0));
          return ratingB.compareTo(ratingA);
        });

        // Greedy assignment: put each group into the team with lower total rating
        final maxPerTeam = match.maxPlayers ~/ 2;
        final teamA = <MatchPlayer>[];
        final teamB = <MatchPlayer>[];
        double sumA = 0, sumB = 0;

        for (final group in groups) {
          final groupRating = group.fold<double>(0, (sum, p) => sum + (ratings[p.oderId] ?? 0));
          final groupSize = group.length;

          // Pick team with lower rating, but respect capacity
          final aHasRoom = teamA.length + groupSize <= maxPerTeam;
          final bHasRoom = teamB.length + groupSize <= maxPerTeam;

          if (!aHasRoom && !bHasRoom) continue; // shouldn't happen
          if (!aHasRoom) {
            teamB.addAll(group);
            sumB += groupRating;
          } else if (!bHasRoom) {
            teamA.addAll(group);
            sumA += groupRating;
          } else if (sumA <= sumB) {
            teamA.addAll(group);
            sumA += groupRating;
          } else {
            teamB.addAll(group);
            sumB += groupRating;
          }
        }

        // Reassign team labels and player numbers
        for (int i = 0; i < teamA.length; i++) {
          teamA[i] = teamA[i].copyWith(team: 'A', playerNumber: i + 1);
        }
        for (int i = 0; i < teamB.length; i++) {
          teamB[i] = teamB[i].copyWith(team: 'B', playerNumber: maxPerTeam + i + 1);
        }

        transaction.update(matchRef, {
          'teamAPlayers': teamA.map((p) => p.toMap()).toList(),
          'teamBPlayers': teamB.map((p) => p.toMap()).toList(),
        });

        return true;
      });
    } catch (e) {
      print('Error balancing teams: $e');
      return false;
    }
  }

  /// Group players: each real player + their guests stay together.
  static List<List<MatchPlayer>> _buildPlayerGroups(List<MatchPlayer> allPlayers) {
    final groups = <String, List<MatchPlayer>>{};

    // First pass: add real players as group keys
    for (final p in allPlayers) {
      if (!p.isGuest) {
        groups[p.oderId] = [p];
      }
    }

    // Second pass: attach guests to their booker
    for (final p in allPlayers) {
      if (p.isGuest && p.bookedByUserId != null) {
        if (groups.containsKey(p.bookedByUserId)) {
          groups[p.bookedByUserId]!.add(p);
        } else {
          // Orphan guest - make their own group
          groups[p.oderId] = [p];
        }
      }
    }

    return groups.values.toList();
  }
}
