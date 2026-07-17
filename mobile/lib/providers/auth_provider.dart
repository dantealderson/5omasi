import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:khomasi/services/auth_service.dart';
import 'package:khomasi/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  firebase_auth.User? _user;
  bool _isInitializing = true;  // For initial auth state check only
  bool _isLoading = false;      // For login/signup operations
  String? _errorMessage;

  // Getters
  firebase_auth.User? get user => _user;
  bool get isInitializing => _isInitializing;  // Use this in AuthWrapper
  bool get isLoading => _isLoading;            // Use this in LoginPage button
  bool get isAuthenticated => _user != null;
  String? get errorMessage => _errorMessage;
  String? get userId => _user?.uid;

  AuthProvider() {
    _init();
  }

  void _init() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((firebase_auth.User? user) {
      _user = user;
      _isInitializing = false;  // Initial check done
      notifyListeners();
    });
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Sign in with email and password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      
      if (result != null) {
        _user = _auth.currentUser;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _errorMessage = 'loginFailed';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('wrong-password') ||
          errorStr.contains('invalid-credential') ||
          errorStr.contains('invalid-login-credentials')) {
        _errorMessage = 'authInvalidCredential';
      } else if (errorStr.contains('user-not-found')) {
        _errorMessage = 'authUserNotFound';
      } else if (errorStr.contains('too-many-requests')) {
        _errorMessage = 'authTooManyRequests';
      } else if (errorStr.contains('network') || errorStr.contains('connection')) {
        _errorMessage = 'authNetworkError';
      } else if (errorStr.contains('invalid-email')) {
        _errorMessage = 'authInvalidEmail';
      } else if (errorStr.contains('user-disabled')) {
        _errorMessage = 'authAccountDisabled';
      } else {
        _errorMessage = 'loginFailed';
      }
      
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign up with email and password
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    String role = 'player',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Convert string role to UserRole enum
      final userRole = role == 'referee' ? UserRole.referee : UserRole.player;
      
      final result = await _authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
        phoneNumber: phone,
        role: userRole,
      );
      
      if (result != null) {
        _user = _auth.currentUser;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _errorMessage = 'accountCreationFailed';
      _isLoading = false;
      notifyListeners();
      return false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _errorMessage = _getErrorKey(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'authDefaultError';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Trigger the Google Sign In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        _errorMessage = 'authLoginCancelled';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        // Check if user document exists in Firestore
        final existingUser = await _authService.getUserData(userCredential.user!.uid);
        
        if (existingUser == null) {
          // Create new user document for Google sign-in using set() not update()
          final newUser = UserModel(
            uid: userCredential.user!.uid,
            email: userCredential.user!.email ?? '',
            name: userCredential.user!.displayName ?? 'User',
            phoneNumber: userCredential.user!.phoneNumber,
            profileImageUrl: userCredential.user!.photoURL,
            role: UserRole.player,
            createdAt: DateTime.now(),
            settings: UserSettings(),
            playerStats: PlayerStats(),
            playerProfile: PlayerProfile(memberSince: DateTime.now()),
          );
          
          // Use Firestore set() directly to create the document
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set(newUser.toFirestore());
        }
        
        _user = userCredential.user;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _errorMessage = 'googleLoginFailed';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'googleLoginFailed';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Sign out from Google if signed in with Google
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      await _authService.signOut();
      _user = null;
    } catch (e) {
      _errorMessage = 'authLogoutFailed';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      
      if (errorStr.contains('user-not-found')) {
        _errorMessage = 'authUserNotFound';
      } else if (errorStr.contains('invalid-email')) {
        _errorMessage = 'authInvalidEmail';
      } else if (errorStr.contains('too-many-requests')) {
        _errorMessage = 'authTooManyRequests';
      } else if (errorStr.contains('network') || errorStr.contains('connection')) {
        _errorMessage = 'authNetworkError';
      } else {
        _errorMessage = 'resetLinkFailed';
      }
      
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update password
  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // First reauthenticate
      final reauthSuccess = await _authService.reauthenticateUser(currentPassword);
      if (!reauthSuccess) {
        _errorMessage = 'authWrongPassword';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Then update password
      await _authService.updatePassword(newPassword);
      _isLoading = false;
      notifyListeners();
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _errorMessage = _getErrorKey(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'authDefaultError';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update email
  Future<bool> updateEmail({
    required String newEmail,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // First reauthenticate
      final reauthSuccess = await _authService.reauthenticateUser(password);
      if (!reauthSuccess) {
        _errorMessage = 'authWrongPassword';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Then update email
      await _authService.updateEmail(newEmail);
      _isLoading = false;
      notifyListeners();
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _errorMessage = _getErrorKey(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'authDefaultError';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete account
  Future<bool> deleteAccount(String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // First reauthenticate
      final reauthSuccess = await _authService.reauthenticateUser(password);
      if (!reauthSuccess) {
        _errorMessage = 'authWrongPassword';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Then delete account
      await _authService.deleteAccount();
      _user = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _errorMessage = _getErrorKey(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'authDefaultError';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Returns a translation key for the given Firebase error code
  String _getErrorKey(String code) {
    switch (code) {
      case 'user-not-found':
        return 'authUserNotFound';
      case 'wrong-password':
        return 'authWrongPassword';
      case 'invalid-credential':
        return 'authInvalidCredential';
      case 'email-already-in-use':
        return 'authEmailInUse';
      case 'weak-password':
        return 'authWeakPassword';
      case 'invalid-email':
        return 'authInvalidEmail';
      case 'too-many-requests':
        return 'authTooManyRequests';
      case 'network-request-failed':
        return 'authNetworkError';
      case 'requires-recent-login':
        return 'authRequiresRecentLogin';
      default:
        return 'authDefaultError';
    }
  }
}