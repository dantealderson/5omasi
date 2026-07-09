import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign Up with Email & Password
  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
    required UserRole role,
  }) async {
    try {
      print('🔵 AuthService: Starting signup...');
      
      // Create user in Firebase Auth
      print('📝 Creating Firebase Auth user...');
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print('✅ Firebase Auth user created!');

      User? user = result.user;
      if (user == null) {
        print('❌ User is null after creation');
        return null;
      }
      
      print('👤 User UID: ${user.uid}');

      // Create user document in Firestore
      print('📄 Creating UserModel...');
      UserModel newUser = UserModel(
        uid: user.uid,
        email: email,
        name: name,
        phoneNumber: phoneNumber,
        role: role,
        createdAt: DateTime.now(),
        settings: UserSettings(),
        // Initialize player stats and profile if player
        playerStats: role == UserRole.player ? PlayerStats() : null,
        playerProfile: role == UserRole.player
            ? PlayerProfile(
                memberSince: DateTime.now(),
              )
            : null,
        // Initialize referee stats and profile if referee
        refereeStats: role == UserRole.referee ? RefereeStats() : null,
        refereeProfile: role == UserRole.referee
            ? RefereeProfile(
                weeklyAvailability: {
                  'saturday': RefereeAvailability(
                    isAvailable: true,
                    startTime: '18:00',
                    endTime: '23:00',
                  ),
                  'sunday': RefereeAvailability(
                    isAvailable: true,
                    startTime: '18:00',
                    endTime: '23:00',
                  ),
                  'monday': RefereeAvailability(isAvailable: false),
                  'tuesday': RefereeAvailability(
                    isAvailable: true,
                    startTime: '19:00',
                    endTime: '22:00',
                  ),
                  'wednesday': RefereeAvailability(
                    isAvailable: true,
                    startTime: '18:00',
                    endTime: '23:00',
                  ),
                  'thursday': RefereeAvailability(
                    isAvailable: true,
                    startTime: '18:00',
                    endTime: '23:00',
                  ),
                  'friday': RefereeAvailability(
                    isAvailable: true,
                    startTime: '14:00',
                    endTime: '23:00',
                  ),
                },
              )
            : null,
      );
      
      print('✅ UserModel created successfully');

      // Save to Firestore
      print('💾 Saving to Firestore...');
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(newUser.toFirestore());
      
      print('✅ Saved to Firestore successfully!');
      print('🎉 Signup complete!');

      return newUser;
    } catch (e, stackTrace) {
      print('❌ Sign up error in AuthService: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Sign In with Email & Password
  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Sign in with Firebase Auth
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user == null) return null;

      // Get user document from Firestore
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) return null;

      return UserModel.fromFirestore(doc);
    } catch (e) {
      print('Sign in error: $e');
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
      rethrow;
    }
  }

  // Get User Data
  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      
      if (!doc.exists) return null;
      
      return UserModel.fromFirestore(doc);
    } catch (e) {
      print('Get user data error: $e');
      return null;
    }
  }

  // Update User Data
  Future<void> updateUserData(UserModel user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update(user.copyWith(updatedAt: DateTime.now()).toFirestore());
    } catch (e) {
      print('Update user data error: $e');
      rethrow;
    }
  }

  // Update Player Stats
  Future<void> updatePlayerStats(String uid, PlayerStats stats) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'playerStats': stats.toMap(),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Update player stats error: $e');
      rethrow;
    }
  }

  // Update Referee Stats
  Future<void> updateRefereeStats(String uid, RefereeStats stats) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'refereeStats': stats.toMap(),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Update referee stats error: $e');
      rethrow;
    }
  }

  // Stream of user data
  Stream<UserModel?> streamUserData(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  // Check if email exists (for validation)
  // NOTE: fetchSignInMethodsForEmail was removed in Firebase Auth 5.x for security reasons
  // This method now checks Firestore instead
  Future<bool> isEmailRegistered(String email) async {
    try {
      // Query Firestore to check if email exists
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase().trim())
          .limit(1)
          .get();
      
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Check email error: $e');
      return false;
    }
  }

  // Update Profile Image
  Future<void> updateProfileImage(String uid, String imageUrl) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'profileImageUrl': imageUrl,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Update profile image error: $e');
      rethrow;
    }
  }

  // Delete Account
  Future<void> deleteAccount() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      // Delete user document from Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete user from Firebase Auth
      await user.delete();
    } catch (e) {
      print('Delete account error: $e');
      rethrow;
    }
  }

  // Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Password reset error: $e');
      rethrow;
    }
  }

  // Re-authenticate user (needed before sensitive operations)
  Future<bool> reauthenticateUser(String password) async {
    try {
      User? user = _auth.currentUser;
      if (user == null || user.email == null) return false;

      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      print('Reauthentication error: $e');
      return false;
    }
  }

  // Update Email
  Future<void> updateEmail(String newEmail) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      await user.verifyBeforeUpdateEmail(newEmail);
      
      // Update in Firestore after verification
      await _firestore.collection('users').doc(user.uid).update({
        'email': newEmail,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Update email error: $e');
      rethrow;
    }
  }

  // Update Password
  Future<void> updatePassword(String newPassword) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      await user.updatePassword(newPassword);
    } catch (e) {
      print('Update password error: $e');
      rethrow;
    }
  }
}