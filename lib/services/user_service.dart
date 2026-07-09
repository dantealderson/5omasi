import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  // Get user by ID
  Future<UserModel?> getUserById(String uid) async {
    final doc = await _firestore.collection(_collection).doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  // Stream user document
  Stream<UserModel?> streamUser(String uid) {
    return _firestore
        .collection(_collection)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  // Create new user document
  Future<void> createUser({
    required String uid,
    required String email,
    required String name,
    String? phoneNumber,
    String role = 'player',
  }) async {
    final userRole = role == 'referee' ? UserRole.referee : UserRole.player;
    
    final user = UserModel(
      uid: uid,
      email: email,
      name: name,
      phoneNumber: phoneNumber,
      role: userRole,
      createdAt: DateTime.now(),
      settings: UserSettings(),
      playerStats: userRole == UserRole.player ? PlayerStats() : null,
      playerProfile: userRole == UserRole.player 
          ? PlayerProfile(memberSince: DateTime.now()) 
          : null,
      refereeStats: userRole == UserRole.referee ? RefereeStats() : null,
      refereeProfile: userRole == UserRole.referee ? RefereeProfile() : null,
    );

    await _firestore.collection(_collection).doc(uid).set(user.toFirestore());
  }

  // Update user basic info
  Future<void> updateUser({
    required String uid,
    String? name,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) updates['name'] = name;
    if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
    if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;

    await _firestore.collection(_collection).doc(uid).update(updates);
  }

  // Update player profile
  Future<void> updatePlayerProfile({
    required String uid,
    int? age,
    String? bio,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (age != null) updates['playerProfile.age'] = age;
    if (bio != null) updates['playerProfile.bio'] = bio;

    await _firestore.collection(_collection).doc(uid).update(updates);
  }

  // Update referee profile
  Future<void> updateRefereeProfile({
    required String uid,
    bool? availableForMatches,
    bool? instantBooking,
    int? experienceYears,
    double? pricePerMatch,
    int? maxDistanceKm,
    List<String>? preferredMatchTypes,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (availableForMatches != null) {
      updates['refereeProfile.availableForMatches'] = availableForMatches;
    }
    if (instantBooking != null) {
      updates['refereeProfile.instantBooking'] = instantBooking;
    }
    if (experienceYears != null) {
      updates['refereeProfile.experienceYears'] = experienceYears;
    }
    if (pricePerMatch != null) {
      updates['refereeProfile.pricePerMatch'] = pricePerMatch;
    }
    if (maxDistanceKm != null) {
      updates['refereeProfile.maxDistanceKm'] = maxDistanceKm;
    }
    if (preferredMatchTypes != null) {
      updates['refereeProfile.preferredMatchTypes'] = preferredMatchTypes;
    }

    await _firestore.collection(_collection).doc(uid).update(updates);
  }

  // Update settings
  Future<void> updateSettings({
    required String uid,
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? locationEnabled,
    String? language,
    bool? darkModeEnabled,
    bool? autoJoinEnabled,
    bool? showProfilePublicly,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (notificationsEnabled != null) {
      updates['settings.notificationsEnabled'] = notificationsEnabled;
    }
    if (soundEnabled != null) {
      updates['settings.soundEnabled'] = soundEnabled;
    }
    if (locationEnabled != null) {
      updates['settings.locationEnabled'] = locationEnabled;
    }
    if (language != null) {
      updates['settings.language'] = language;
    }
    if (darkModeEnabled != null) {
      updates['settings.darkModeEnabled'] = darkModeEnabled;
    }
    if (autoJoinEnabled != null) {
      updates['settings.autoJoinEnabled'] = autoJoinEnabled;
    }
    if (showProfilePublicly != null) {
      updates['settings.showProfilePublicly'] = showProfilePublicly;
    }

    await _firestore.collection(_collection).doc(uid).update(updates);
  }

  // Upload profile image - TODO: Add firebase_storage package
  Future<String?> uploadProfileImage({
    required String uid,
    required String imagePath,
  }) async {
    // TODO: Implement when firebase_storage is added
    // For now, return null
    return null;
  }

  // Add favorite venue
  Future<void> addFavoriteVenue({
    required String uid,
    required String venueId,
  }) async {
    await _firestore.collection(_collection).doc(uid).update({
      'favoriteVenues': FieldValue.arrayUnion([venueId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Remove favorite venue
  Future<void> removeFavoriteVenue({
    required String uid,
    required String venueId,
  }) async {
    await _firestore.collection(_collection).doc(uid).update({
      'favoriteVenues': FieldValue.arrayRemove([venueId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Block user
  Future<void> blockUser({
    required String uid,
    required String blockedUserId,
  }) async {
    await _firestore.collection(_collection).doc(uid).update({
      'blockedUsers': FieldValue.arrayUnion([blockedUserId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Unblock user
  Future<void> unblockUser({
    required String uid,
    required String blockedUserId,
  }) async {
    await _firestore.collection(_collection).doc(uid).update({
      'blockedUsers': FieldValue.arrayRemove([blockedUserId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update player stats (called after match ends)
  Future<void> updatePlayerStats({
    required String uid,
    int? goalsToAdd,
    int? assistsToAdd,
    int? yellowCardsToAdd,
    int? redCardsToAdd,
    bool? won,
    bool? lost,
    bool? draw,
  }) async {
    final updates = <String, dynamic>{
      'playerStats.totalMatches': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (goalsToAdd != null && goalsToAdd > 0) {
      updates['playerStats.totalGoals'] = FieldValue.increment(goalsToAdd);
    }
    if (assistsToAdd != null && assistsToAdd > 0) {
      updates['playerStats.totalAssists'] = FieldValue.increment(assistsToAdd);
    }
    if (yellowCardsToAdd != null && yellowCardsToAdd > 0) {
      updates['playerStats.yellowCards'] = FieldValue.increment(yellowCardsToAdd);
    }
    if (redCardsToAdd != null && redCardsToAdd > 0) {
      updates['playerStats.redCards'] = FieldValue.increment(redCardsToAdd);
    }
    if (won == true) {
      updates['playerStats.wins'] = FieldValue.increment(1);
    }
    if (lost == true) {
      updates['playerStats.losses'] = FieldValue.increment(1);
    }
    if (draw == true) {
      updates['playerStats.draws'] = FieldValue.increment(1);
    }

    await _firestore.collection(_collection).doc(uid).update(updates);
  }

  // Update referee stats (called after match ends)
  Future<void> updateRefereeStats({
    required String uid,
    int? goalsRecorded,
    int? yellowCardsGiven,
    int? redCardsGiven,
    double? earnings,
  }) async {
    final updates = <String, dynamic>{
      'refereeStats.totalMatchesRefereed': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (goalsRecorded != null && goalsRecorded > 0) {
      updates['refereeStats.totalGoalsRecorded'] = FieldValue.increment(goalsRecorded);
    }
    if (yellowCardsGiven != null && yellowCardsGiven > 0) {
      updates['refereeStats.yellowCardsGiven'] = FieldValue.increment(yellowCardsGiven);
      updates['refereeStats.totalCardsGiven'] = FieldValue.increment(yellowCardsGiven);
    }
    if (redCardsGiven != null && redCardsGiven > 0) {
      updates['refereeStats.redCardsGiven'] = FieldValue.increment(redCardsGiven);
      updates['refereeStats.totalCardsGiven'] = FieldValue.increment(redCardsGiven);
    }
    if (earnings != null && earnings > 0) {
      updates['refereeStats.totalEarnings'] = FieldValue.increment(earnings);
    }

    await _firestore.collection(_collection).doc(uid).update(updates);
  }

  // Delete user
  Future<void> deleteUser(String uid) async {
    await _firestore.collection(_collection).doc(uid).delete();
  }

  // Search users by name
  Future<List<UserModel>> searchUsers(String query) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();

    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  // Get users by role
  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('role', isEqualTo: role.toString().split('.').last)
        .get();

    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }
}