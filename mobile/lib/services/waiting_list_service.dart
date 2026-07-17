import 'package:cloud_firestore/cloud_firestore.dart';

class WaitingListService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add a user to the waiting list for a match.
  /// Returns true if added successfully.
  static Future<bool> joinWaitingList({
    required String matchId,
    required String userId,
    required String userName,
    required String preferredTeam,
    int playerCount = 1,
  }) async {
    try {
      final docId = '${matchId}_$userId';
      final ref = _firestore.collection('waitingList').doc(docId);

      final existing = await ref.get();
      if (existing.exists) return false; // Already in waiting list

      await ref.set({
        'matchId': matchId,
        'userId': userId,
        'userName': userName,
        'preferredTeam': preferredTeam,
        'playerCount': playerCount,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error joining waiting list: $e');
      return false;
    }
  }

  /// Remove a user from the waiting list.
  static Future<bool> leaveWaitingList({
    required String matchId,
    required String userId,
  }) async {
    try {
      final docId = '${matchId}_$userId';
      await _firestore.collection('waitingList').doc(docId).delete();
      return true;
    } catch (e) {
      print('Error leaving waiting list: $e');
      return false;
    }
  }

  /// Check if a user is on the waiting list for a match.
  static Future<bool> isOnWaitingList({
    required String matchId,
    required String userId,
  }) async {
    try {
      final docId = '${matchId}_$userId';
      final doc = await _firestore.collection('waitingList').doc(docId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Get the waiting list for a match, ordered by join time.
  static Future<List<Map<String, dynamic>>> getWaitingList(String matchId) async {
    try {
      final snapshot = await _firestore
          .collection('waitingList')
          .where('matchId', isEqualTo: matchId)
          .get();

      final list = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      // Sort client-side to avoid needing a composite Firestore index
      list.sort((a, b) {
        final aTime = a['joinedAt'] as Timestamp?;
        final bTime = b['joinedAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });
      return list;
    } catch (e) {
      print('Error getting waiting list: $e');
      return [];
    }
  }

  /// Get the number of users waiting for a match.
  static Future<int> getWaitingCount(String matchId) async {
    try {
      final snapshot = await _firestore
          .collection('waitingList')
          .where('matchId', isEqualTo: matchId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get the next person in the waiting list (first in queue).
  /// Returns null if the waiting list is empty.
  static Future<Map<String, dynamic>?> getNextInLine(String matchId) async {
    try {
      // Query without orderBy to avoid needing a composite Firestore index
      final snapshot = await _firestore
          .collection('waitingList')
          .where('matchId', isEqualTo: matchId)
          .get();

      if (snapshot.docs.isEmpty) return null;

      // Sort client-side by joinedAt to get the first in queue
      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final aTime = a.data()['joinedAt'] as Timestamp?;
        final bTime = b.data()['joinedAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });

      final doc = docs.first;
      return {'id': doc.id, ...doc.data()};
    } catch (e) {
      print('Error getting next in line: $e');
      return null;
    }
  }

  /// Remove a user from ALL waiting lists (all matches).
  /// Called when a user books a different match.
  static Future<void> removeUserFromAllWaitingLists(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('waitingList')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error removing user from all waiting lists: $e');
    }
  }

  /// Check if a user has at least the required tokens.
  static Future<bool> userHasEnoughTokens(String userId, int minTokens) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;
      final tokens = (doc.data()?['matchTokens'] ?? 0) as int;
      return tokens >= minTokens;
    } catch (e) {
      return false;
    }
  }

  /// Stream the waiting list count for real-time UI updates.
  static Stream<int> streamWaitingCount(String matchId) {
    return _firestore
        .collection('waitingList')
        .where('matchId', isEqualTo: matchId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
