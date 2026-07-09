import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/image_upload_service.dart';

class UserProvider extends ChangeNotifier {
  final UserService _userService = UserService();

  UserModel? _user;
  bool _isInitializing = true;  // For initial user data load only
  bool _isLoading = false;      // For operations (upload, update, etc.)
  bool _hasInitialized = false; // Whether init() was ever called
  String? _errorMessage;
  StreamSubscription? _userSubscription;

  // Getters
  UserModel? get user => _user;
  bool get isInitializing => _isInitializing;  // Use this in AuthWrapper
  bool get isLoading => _isLoading;            // Use this for button states
  String? get errorMessage => _errorMessage;

  // Guest mode - true when no user is logged in (init was never called, or user is null after loading)
  bool get isGuest => !_hasInitialized || (_user == null && !_isInitializing);

  // Convenience getters
  String get userId => _user?.uid ?? '';
  String get userName => _user?.name ?? '';
  String get userEmail => _user?.email ?? '';
  String? get userPhone => _user?.phoneNumber;
  String? get userPhotoUrl => _user?.profileImageUrl;
  UserRole get userRole => _user?.role ?? UserRole.player;
  bool get isPlayer => _user?.role == UserRole.player;
  bool get isReferee => _user?.role == UserRole.referee;
  
  // Token getters
  int get matchTokens => _user?.matchTokens ?? 0;
  int get totalTokensPurchased => _user?.totalTokensPurchased ?? 0;
  int get totalTokensUsed => _user?.totalTokensUsed ?? 0;
  bool hasEnoughTokens(int count) => matchTokens >= count;
  
  // Stats getters
  PlayerStats? get playerStats => _user?.playerStats;
  RefereeStats? get refereeStats => _user?.refereeStats;
  PlayerProfile? get playerProfile => _user?.playerProfile;
  RefereeProfile? get refereeProfile => _user?.refereeProfile;
  UserSettings get settings => _user?.settings ?? UserSettings();

  // Initialize with user ID
  void init(String uid) {
    _hasInitialized = true;
    _startUserStream(uid);
  }

  // Start listening to user document changes
  void _startUserStream(String uid) {
    _userSubscription?.cancel();
    _isInitializing = true;
    notifyListeners();

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
      (doc) {
        if (doc.exists) {
          _user = UserModel.fromFirestore(doc);
        } else {
          _user = null;
        }
        _isInitializing = false;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = 'فشل تحميل بيانات المستخدم';
        _isInitializing = false;
        notifyListeners();
      },
    );
  }

  // Clear user data (on logout)
  void clear() {
    _userSubscription?.cancel();
    _user = null;
    _isInitializing = true;  // Reset for next login
    _hasInitialized = false;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  // ==========================================
  // UPDATE METHODS
  // ==========================================

  // Update profile info
  Future<bool> updateProfile({
    String? name,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    if (_user == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _userService.updateUser(
        uid: _user!.uid,
        name: name,
        phoneNumber: phoneNumber,
        profileImageUrl: profileImageUrl,
      );
      
      // Stream will automatically update _user when Firestore changes
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'فشل تحديث الملف الشخصي';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update player profile
  Future<bool> updatePlayerProfile({
    int? age,
    String? bio,
  }) async {
    if (_user == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _userService.updatePlayerProfile(
        uid: _user!.uid,
        age: age,
        bio: bio,
      );
      
      // Stream will automatically update _user when Firestore changes
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'فشل تحديث الملف الشخصي';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update referee profile
  Future<bool> updateRefereeProfile({
    bool? availableForMatches,
    bool? instantBooking,
    int? experienceYears,
    double? pricePerMatch,
    int? maxDistanceKm,
    List<String>? preferredMatchTypes,
  }) async {
    if (_user == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _userService.updateRefereeProfile(
        uid: _user!.uid,
        availableForMatches: availableForMatches,
        instantBooking: instantBooking,
        experienceYears: experienceYears,
        pricePerMatch: pricePerMatch,
        maxDistanceKm: maxDistanceKm,
        preferredMatchTypes: preferredMatchTypes,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'فشل تحديث الملف الشخصي';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update settings
  Future<bool> updateSettings({
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? locationEnabled,
    String? language,
    bool? darkModeEnabled,
    bool? autoJoinEnabled,
    bool? showProfilePublicly,
  }) async {
    if (_user == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _userService.updateSettings(
        uid: _user!.uid,
        notificationsEnabled: notificationsEnabled,
        soundEnabled: soundEnabled,
        locationEnabled: locationEnabled,
        language: language,
        darkModeEnabled: darkModeEnabled,
        autoJoinEnabled: autoJoinEnabled,
        showProfilePublicly: showProfilePublicly,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'فشل تحديث الإعدادات';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Upload profile image
  Future<bool> uploadProfileImage(String imagePath) async {
    if (_user == null) {
      print('DEBUG: User is null, cannot upload');
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('DEBUG: Starting upload for path: $imagePath');
      
      // Upload to ImgBB
      final imageUrl = await ImageUploadService.uploadImageFromPath(imagePath);
      
      print('DEBUG: ImgBB returned URL: $imageUrl');
      
      if (imageUrl != null) {
        print('DEBUG: Saving to Firestore for user: ${_user!.uid}');
        
        // Update Firestore with new image URL
        await _userService.updateUser(
          uid: _user!.uid,
          profileImageUrl: imageUrl,
        );
        
        print('DEBUG: Firestore update complete');
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      print('DEBUG: imageUrl was null');
      _errorMessage = 'فشل رفع الصورة';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('DEBUG: Upload error: $e');
      _errorMessage = 'فشل رفع الصورة';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // FAVORITES
  // ==========================================

  Future<bool> addFavoriteVenue(String venueId) async {
    if (_user == null) return false;

    try {
      await _userService.addFavoriteVenue(
        uid: _user!.uid,
        venueId: venueId,
      );
      return true;
    } catch (e) {
      _errorMessage = 'فشل إضافة الملعب للمفضلة';
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeFavoriteVenue(String venueId) async {
    if (_user == null) return false;

    try {
      await _userService.removeFavoriteVenue(
        uid: _user!.uid,
        venueId: venueId,
      );
      return true;
    } catch (e) {
      _errorMessage = 'فشل إزالة الملعب من المفضلة';
      notifyListeners();
      return false;
    }
  }

  bool isVenueFavorite(String venueId) {
    return _user?.favoriteVenues.contains(venueId) ?? false;
  }

  // ==========================================
  // BLOCKING
  // ==========================================

  Future<bool> blockUser(String blockedUserId) async {
    if (_user == null) return false;

    try {
      await _userService.blockUser(
        uid: _user!.uid,
        blockedUserId: blockedUserId,
      );
      return true;
    } catch (e) {
      _errorMessage = 'فشل حظر المستخدم';
      notifyListeners();
      return false;
    }
  }

  Future<bool> unblockUser(String blockedUserId) async {
    if (_user == null) return false;

    try {
      await _userService.unblockUser(
        uid: _user!.uid,
        blockedUserId: blockedUserId,
      );
      return true;
    } catch (e) {
      _errorMessage = 'فشل إلغاء حظر المستخدم';
      notifyListeners();
      return false;
    }
  }

  bool isUserBlocked(String oderId) {
    return _user?.blockedUsers.contains(oderId) ?? false;
  }

  // ==========================================
  // REFEREE STATS
  // ==========================================

  /// Update referee stats after a match
  Future<bool> updateRefereeStats({
    int matchesIncrement = 0,
    int goalsIncrement = 0,
    int yellowCardsIncrement = 0,
    int redCardsIncrement = 0,
    double? newRating,
  }) async {
    if (_user == null || !isReferee) return false;

    _errorMessage = null;

    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (matchesIncrement > 0) {
        updates['refereeStats.totalMatchesRefereed'] = FieldValue.increment(matchesIncrement);
        updates['refereeStats.todayMatches'] = FieldValue.increment(matchesIncrement);
        updates['refereeStats.thisWeekMatches'] = FieldValue.increment(matchesIncrement);
        updates['refereeStats.thisMonthMatches'] = FieldValue.increment(matchesIncrement);
      }

      if (goalsIncrement > 0) {
        updates['refereeStats.totalGoalsRecorded'] = FieldValue.increment(goalsIncrement);
      }

      if (yellowCardsIncrement > 0 || redCardsIncrement > 0) {
        final totalCards = yellowCardsIncrement + redCardsIncrement;
        updates['refereeStats.totalCardsGiven'] = FieldValue.increment(totalCards);
        updates['refereeStats.yellowCardsGiven'] = FieldValue.increment(yellowCardsIncrement);
        updates['refereeStats.redCardsGiven'] = FieldValue.increment(redCardsIncrement);
      }

      // Calculate earnings based on price per match
      if (matchesIncrement > 0) {
        final pricePerMatch = _user!.refereeProfile?.pricePerMatch ?? 25000.0;
        updates['refereeStats.totalEarnings'] = FieldValue.increment(pricePerMatch * matchesIncrement);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .update(updates);

      return true;
    } catch (e) {
      _errorMessage = 'فشل تحديث إحصائيات الحكم';
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // REFRESH
  // ==========================================

  Future<void> refresh() async {
    if (_user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();

      if (doc.exists) {
        _user = UserModel.fromFirestore(doc);
      }
    } catch (e) {
      _errorMessage = 'فشل تحديث البيانات';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Alias for refresh - used after token transactions
  Future<void> refreshUserData() => refresh();
}