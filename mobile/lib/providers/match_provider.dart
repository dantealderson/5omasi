import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_model.dart';
import '../services/match_service.dart';
import '../services/push_notification_sender.dart';
import '../services/waiting_list_service.dart';

class MatchProvider extends ChangeNotifier {
  final MatchService _matchService = MatchService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================
  // STATE
  // ==========================================

  // Loading states
  bool _isLoading = false;
  bool _isJoining = false;
  bool _isRefreshing = false;

  // Error handling
  String? _errorMessage;

  // Match lists
  List<MatchModel> _availableMatches = [];
  List<MatchModel> _userMatches = [];
  List<MatchModel> _matchesNeedingReferee = [];

  // Active/Live match (for referee)
  MatchModel? _activeMatch;
  
  // Selected match (for viewing details)
  MatchModel? _selectedMatch;

  // Stream subscriptions
  StreamSubscription? _availableMatchesSubscription;
  StreamSubscription? _activeMatchSubscription;
  StreamSubscription? _needingRefereeSubscription;

  // Filter state
  String _currentFilter = 'all'; // 'all', 'today', 'tomorrow', 'week'
  String _searchQuery = '';
  bool _showFullMatches = false;

  // ==========================================
  // GETTERS
  // ==========================================

  bool get isLoading => _isLoading;
  bool get isJoining => _isJoining;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;

  List<MatchModel> get availableMatches => _availableMatches;
  List<MatchModel> get userMatches => _userMatches;
  List<MatchModel> get matchesNeedingReferee => _matchesNeedingReferee;

  MatchModel? get activeMatch => _activeMatch;
  MatchModel? get selectedMatch => _selectedMatch;

  String get currentFilter => _currentFilter;
  String get searchQuery => _searchQuery;
  bool get showFullMatches => _showFullMatches;

  bool get hasActiveMatch => _activeMatch != null;
  bool get isMatchLive => _activeMatch?.status == MatchStatus.inProgress;

  // Current user ID for filtering
  String _currentUserId = '';
  
  void setCurrentUserId(String oderId) {
    _currentUserId = oderId;
  }

  // Filtered matches based on current filter and search
  // Full/scheduled matches only shown to users who are booked in them
  List<MatchModel> get filteredMatches {
    var matches = _availableMatches;
    
    // Filter out full/scheduled matches unless user is booked or showFullMatches is on
    matches = matches.where((m) {
      // Always show open matches
      if (m.status == MatchStatus.open) return true;

      // Show full matches if toggle is on
      if (_showFullMatches && m.status == MatchStatus.full) return true;

      // For full/scheduled matches, only show if user is booked
      if (_currentUserId.isNotEmpty) {
        return m.isUserBooked(_currentUserId);
      }

      return false;
    }).toList();

    // Apply date filter
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(const Duration(days: 7));

    switch (_currentFilter) {
      case 'today':
        matches = matches.where((m) {
          return m.dateTime.year == today.year &&
                 m.dateTime.month == today.month &&
                 m.dateTime.day == today.day;
        }).toList();
        break;
      case 'tomorrow':
        matches = matches.where((m) {
          return m.dateTime.year == tomorrow.year &&
                 m.dateTime.month == tomorrow.month &&
                 m.dateTime.day == tomorrow.day;
        }).toList();
        break;
      case 'week':
        matches = matches.where((m) {
          return m.dateTime.isAfter(today.subtract(const Duration(days: 1))) &&
                 m.dateTime.isBefore(weekEnd);
        }).toList();
        break;
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      matches = matches.where((m) {
        return m.stadiumName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               (m.stadiumAddress?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    return matches;
  }

  // ==========================================
  // INITIALIZATION & CLEANUP
  // ==========================================

  /// Initialize provider for a player
  void initForPlayer(String oderId) {
    _currentUserId = oderId;
    loadAvailableMatches();
    _loadUserMatches(oderId);
  }

  /// Initialize provider for a referee
  void initForReferee(String refereeId) {
    _currentUserId = refereeId;
    _startNeedingRefereeStream();
    _startActiveMatchStream(refereeId);
  }

  @override
  void dispose() {
    _availableMatchesSubscription?.cancel();
    _activeMatchSubscription?.cancel();
    _needingRefereeSubscription?.cancel();
    super.dispose();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ==========================================
  // STREAM MANAGEMENT
  // ==========================================

  void _startNeedingRefereeStream() {
    _needingRefereeSubscription?.cancel();
    _needingRefereeSubscription = _matchService.streamMatchesNeedingReferee().listen(
      (matches) {
        _matchesNeedingReferee = matches;
        notifyListeners();
      },
    );
  }

  void _startActiveMatchStream(String refereeId) {
    _activeMatchSubscription?.cancel();
    _activeMatchSubscription = _matchService.streamRefereeActiveMatch(refereeId).listen(
      (match) {
        _activeMatch = match;
        notifyListeners();
      },
    );
  }

  // ==========================================
  // PLAYER METHODS
  // ==========================================

  /// Load available matches
  Future<void> loadAvailableMatches() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _availableMatches = await _matchService.getAvailableMatches();
    } catch (e) {
      _errorMessage = 'خطأ في تحميل المباريات';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh matches (pull to refresh)
  Future<void> refreshMatches() async {
    _isRefreshing = true;
    // Don't call notifyListeners here - avoid triggering a rebuild mid-refresh

    // Fetch fresh data in one shot (stream stays active for live updates)
    try {
      _availableMatches = await _matchService.getAvailableMatches();
    } catch (e) {
      _errorMessage = 'خطأ في تحديث المباريات';
    }

    _isRefreshing = false;
    notifyListeners();
  }

  /// Load user's matches
  Future<void> _loadUserMatches(String oderId) async {
    try {
      _userMatches = await _matchService.getUserMatches(oderId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user matches: $e');
    }
  }

  /// Set filter
  void setFilter(String filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  void toggleShowFullMatches() {
    _showFullMatches = !_showFullMatches;
    notifyListeners();
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Select a match for viewing details
  Future<void> selectMatch(String matchId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedMatch = await _matchService.getMatchById(matchId);
    } catch (e) {
      _errorMessage = 'خطأ في تحميل تفاصيل المباراة';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Clear selected match
  void clearSelectedMatch() {
    _selectedMatch = null;
    notifyListeners();
  }

  /// Join a match (supports booking multiple spots)
  /// Returns false if user already has a booking in another match
  /// Allows adding more spots if user is already in THIS match
  Future<bool> joinMatch({
    required String matchId,
    required String oderId,
    required String playerName,
    required String team,
    int count = 1,
  }) async {
    _isJoining = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check if user already has a booking in another upcoming match (not this one)
      final existingBooking = _availableMatches.where((m) => 
        m.id != matchId && 
        m.isUserBooked(oderId) &&
        m.status != MatchStatus.completed &&
        m.status != MatchStatus.cancelled &&
        m.dateTime.isAfter(DateTime.now().subtract(const Duration(hours: 2)))
      ).toList();
      
      if (existingBooking.isNotEmpty) {
        _errorMessage = 'لديك حجز مسبق في مباراة أخرى';
        _isJoining = false;
        notifyListeners();
        return false;
      }

      // Check if user is already in this match - if so, add guests only
      final currentMatch = _availableMatches.firstWhere(
        (m) => m.id == matchId,
        orElse: () => throw Exception('Match not found'),
      );
      
      final isAlreadyBooked = currentMatch.isUserBooked(oderId);
      
      bool success;
      if (isAlreadyBooked) {
        // User already booked - add guests to their team
        success = await _matchService.addGuestsToMatch(
          matchId: matchId,
          bookedByUserId: oderId,
          playerName: playerName,
          team: team,
          count: count,
        );
      } else {
        // New booking
        success = await _matchService.joinMatchMultiple(
          matchId: matchId,
          oderId: oderId,
          playerName: playerName,
          team: team,
          count: count,
        );
      }

      if (success) {
        // Remove user from all waiting lists since they now have a booking
        await WaitingListService.removeUserFromAllWaitingLists(oderId);

        // Refresh only the changed match, not the whole list (avoids isLoading flicker)
        final updatedMatch = await _matchService.getMatchById(matchId);
        if (updatedMatch != null) {
          final idx = _availableMatches.indexWhere((m) => m.id == matchId);
          if (idx != -1) {
            _availableMatches[idx] = updatedMatch;
          }

          // If match is now full, notify all players
          if (updatedMatch.currentPlayers >= updatedMatch.maxPlayers) {
            PushNotificationSender.notifyMatchPlayers(
              matchId: matchId,
              excludeUserId: '',
              title: '🔥 المباراة اكتملت!',
              body: 'اكتملت المباراة في ${updatedMatch.stadiumName} - استعدوا!',
            );
          }
        }
        await _loadUserMatches(oderId);
      } else {
        _errorMessage = 'فشل الانضمام للمباراة';
      }

      _isJoining = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'خطأ في الانضمام للمباراة';
      _isJoining = false;
      notifyListeners();
      return false;
    }
  }

  /// Join a match with token deduction
  /// Deducts tokens first, then joins match
  /// If join fails, tokens are NOT refunded (manual admin action needed)
  Future<bool> joinMatchWithTokens({
    required String matchId,
    required String oderId,
    required String playerName,
    required String team,
    int count = 1,
  }) async {
    _isJoining = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Import token service
      final tokenService = await _deductTokensForBooking(oderId, count, matchId);
      if (!tokenService) {
        _errorMessage = 'فشل خصم التوكنات';
        _isJoining = false;
        notifyListeners();
        return false;
      }

      // Now join the match
      final success = await joinMatch(
        matchId: matchId,
        oderId: oderId,
        playerName: playerName,
        team: team,
        count: count,
      );

      if (!success) {
        // Join failed - refund tokens
        await _refundTokensForBooking(oderId, count, matchId, 'فشل الحجز - استرداد');
      }

      return success;
    } catch (e) {
      _errorMessage = 'خطأ في الحجز';
      _isJoining = false;
      notifyListeners();
      return false;
    }
  }

  /// Helper to deduct tokens
  Future<bool> _deductTokensForBooking(String oderId, int amount, String matchId) async {
    try {
      // Using Firestore transaction for atomic operation
      final userRef = _firestore.collection('users').doc(oderId);
      
      return await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return false;
        
        final currentTokens = (userDoc.data()?['matchTokens'] ?? 0) as int;
        if (currentTokens < amount) return false;
        
        final newBalance = currentTokens - amount;
        final totalUsed = (userDoc.data()?['totalTokensUsed'] ?? 0) as int;
        
        transaction.update(userRef, {
          'matchTokens': newBalance,
          'totalTokensUsed': totalUsed + amount,
        });
        
        // Create transaction record
        final transactionRef = _firestore.collection('tokenTransactions').doc();
        transaction.set(transactionRef, {
          'oderId': oderId,
          'type': 'matchBooking',
          'amount': -amount,
          'balanceAfter': newBalance,
          'matchId': matchId,
          'description': 'حجز مباراة',
          'createdAt': Timestamp.now(),
        });
        
        return true;
      });
    } catch (e) {
      debugPrint('Error deducting tokens: $e');
      return false;
    }
  }

  /// Helper to refund tokens
  Future<bool> _refundTokensForBooking(String oderId, int amount, String matchId, String reason) async {
    try {
      final userRef = _firestore.collection('users').doc(oderId);
      
      return await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return false;
        
        final currentTokens = (userDoc.data()?['matchTokens'] ?? 0) as int;
        final newBalance = currentTokens + amount;
        
        transaction.update(userRef, {
          'matchTokens': newBalance,
        });
        
        // Create transaction record
        final transactionRef = _firestore.collection('tokenTransactions').doc();
        transaction.set(transactionRef, {
          'oderId': oderId,
          'type': 'matchRefund',
          'amount': amount,
          'balanceAfter': newBalance,
          'matchId': matchId,
          'description': reason,
          'createdAt': Timestamp.now(),
        });
        
        return true;
      });
    } catch (e) {
      debugPrint('Error refunding tokens: $e');
      return false;
    }
  }

  /// Leave a match (with token refund)
  Future<bool> leaveMatch({
    required String matchId,
    required String oderId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // First, count how many spots this user has booked (including guests)
      final match = _availableMatches.firstWhere(
        (m) => m.id == matchId,
        orElse: () => throw Exception('Match not found'),
      );
      
      int spotsToRefund = 0;
      for (final player in [...match.teamAPlayers, ...match.teamBPlayers]) {
        // Count spots booked by this user (their own + guests)
        if (player.oderId == oderId || player.bookedByUserId == oderId) {
          spotsToRefund++;
        }
      }
      
      final success = await _matchService.leaveMatch(
        matchId: matchId,
        oderId: oderId,
      );

      if (success && spotsToRefund > 0) {
        // Refund tokens for all spots
        await _refundTokensForBooking(
          oderId,
          spotsToRefund,
          matchId,
          'استرداد - إلغاء الحجز',
        );

        // Auto-promote from waiting list
        await _promoteFromWaitingList(matchId, match);

        // Refresh only the changed match
        final updatedMatch = await _matchService.getMatchById(matchId);
        if (updatedMatch != null) {
          final idx = _availableMatches.indexWhere((m) => m.id == matchId);
          if (idx != -1) {
            _availableMatches[idx] = updatedMatch;
          }
        }
        await _loadUserMatches(oderId);
      } else if (!success) {
        _errorMessage = 'فشل مغادرة المباراة';
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'خطأ في مغادرة المباراة';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // WAITING LIST AUTO-PROMOTE
  // ==========================================

  Future<void> _promoteFromWaitingList(String matchId, MatchModel match) async {
    // Keep promoting users from the waiting list until the match is full
    // or the waiting list is empty
    for (int attempt = 0; attempt < match.maxPlayers; attempt++) {
      try {
        // Re-check available spots from Firestore
        final freshMatch = await _matchService.getMatchById(matchId);
        if (freshMatch == null || freshMatch.isFull) break;

        final nextUser = await WaitingListService.getNextInLine(matchId);
        if (nextUser == null) break;

        final userId = nextUser['userId'] as String;
        final userName = nextUser['userName'] as String;
        final preferredTeam = nextUser['preferredTeam'] as String? ?? 'A';
        final playerCount = (nextUser['playerCount'] as int?) ?? 1;

        // Check if requested spots exceed available spots
        if (playerCount > freshMatch.spotsLeft) {
          // Skip this user — they want more spots than available
          // Don't remove them; they might get in later if more people leave
          continue;
        }

        // Determine which team to join — use preferred team if it has space,
        // otherwise fall back to the other team
        final maxPerTeam = freshMatch.maxPlayers ~/ 2;
        String teamToJoin;
        if (preferredTeam == 'A' && freshMatch.teamAPlayers.length + playerCount <= maxPerTeam) {
          teamToJoin = 'A';
        } else if (preferredTeam == 'B' && freshMatch.teamBPlayers.length + playerCount <= maxPerTeam) {
          teamToJoin = 'B';
        } else if (freshMatch.teamAPlayers.length + playerCount <= maxPerTeam) {
          teamToJoin = 'A';
        } else if (freshMatch.teamBPlayers.length + playerCount <= maxPerTeam) {
          teamToJoin = 'B';
        } else {
          // Neither team has enough space for this user's playerCount
          continue;
        }

        // Deduct tokens first - skip user if they don't have enough
        final deducted = await _deductTokensForBooking(userId, playerCount, matchId);
        if (!deducted) {
          // Remove from waiting list since they can't pay
          await WaitingListService.leaveWaitingList(matchId: matchId, userId: userId);
          continue;
        }

        // Try to join them into the match
        final joined = await _matchService.joinMatchMultiple(
          matchId: matchId,
          oderId: userId,
          playerName: userName,
          team: teamToJoin,
          count: playerCount,
        );

        if (joined) {
          // Remove from waiting list
          await WaitingListService.leaveWaitingList(
            matchId: matchId,
            userId: userId,
          );

          // Notify the promoted user
          await PushNotificationSender.sendToUsers(
            userIds: [userId],
            title: '🎉 تم تأكيد مكانك!',
            body: 'تم إضافتك تلقائياً من قائمة الانتظار في المباراة',
            data: {'matchId': matchId, 'type': 'waiting_list_promoted'},
          );
        } else {
          // Join failed — refund tokens
          await _refundTokensForBooking(userId, playerCount, matchId, 'فشل الترقية من قائمة الانتظار');
        }
      } catch (e) {
        debugPrint('Error promoting from waiting list: $e');
        break;
      }
    }
  }

  // ==========================================
  // REFEREE METHODS
  // ==========================================

  /// Load matches needing referee
  Future<void> loadMatchesNeedingReferee() async {
    _isLoading = true;
    notifyListeners();

    try {
      _matchesNeedingReferee = await _matchService.getMatchesNeedingReferee();
    } catch (e) {
      _errorMessage = 'خطأ في تحميل المباريات';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Assign referee to match
  Future<bool> assignToMatch({
    required String matchId,
    required String refereeId,
    required String refereeName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _matchService.assignReferee(
        matchId: matchId,
        refereeId: refereeId,
        refereeName: refereeName,
      );

      if (success) {
        // The match should now appear in activeMatch via stream
        await loadMatchesNeedingReferee();
      } else {
        _errorMessage = 'فشل تعيين الحكم';
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'خطأ في تعيين الحكم';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Unassign referee from match
  Future<bool> unassignFromMatch({
    required String matchId,
    required String refereeId,
  }) async {
    try {
      final success = await _matchService.unassignReferee(
        matchId: matchId,
        refereeId: refereeId,
      );

      if (success) {
        _activeMatch = null;
        await loadMatchesNeedingReferee();
      }

      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'خطأ في إلغاء التعيين';
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // LIVE MATCH CONTROLS (Referee)
  // ==========================================

  /// Start the match
  Future<bool> startMatch() async {
    if (_activeMatch == null) return false;

    try {
      final success = await _matchService.startMatch(_activeMatch!.id);
      return success;
    } catch (e) {
      _errorMessage = 'خطأ في بدء المباراة';
      notifyListeners();
      return false;
    }
  }

  /// End the match
  Future<bool> endMatch(int durationSeconds) async {
    if (_activeMatch == null) return false;

    try {
      final success = await _matchService.endMatch(
        matchId: _activeMatch!.id,
        matchDurationSeconds: durationSeconds,
      );

      if (success) {
        _activeMatch = null;
      }

      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'خطأ في إنهاء المباراة';
      notifyListeners();
      return false;
    }
  }

  /// Record a goal
  Future<bool> recordGoal({
    required String oderId,
    required String team,
  }) async {
    if (_activeMatch == null) return false;

    try {
      return await _matchService.recordGoal(
        matchId: _activeMatch!.id,
        oderId: oderId,
        team: team,
      );
    } catch (e) {
      _errorMessage = 'خطأ في تسجيل الهدف';
      notifyListeners();
      return false;
    }
  }

  /// Record an assist
  Future<bool> recordAssist(String oderId) async {
    if (_activeMatch == null) return false;

    try {
      return await _matchService.recordAssist(
        matchId: _activeMatch!.id,
        oderId: oderId,
      );
    } catch (e) {
      _errorMessage = 'خطأ في تسجيل التمريرة';
      notifyListeners();
      return false;
    }
  }

  /// Give yellow card
  Future<bool> giveYellowCard(String oderId) async {
    if (_activeMatch == null) return false;

    try {
      return await _matchService.giveYellowCard(
        matchId: _activeMatch!.id,
        oderId: oderId,
      );
    } catch (e) {
      _errorMessage = 'خطأ في إعطاء البطاقة';
      notifyListeners();
      return false;
    }
  }

  /// Give red card
  Future<bool> giveRedCard(String oderId) async {
    if (_activeMatch == null) return false;

    try {
      return await _matchService.giveRedCard(
        matchId: _activeMatch!.id,
        oderId: oderId,
      );
    } catch (e) {
      _errorMessage = 'خطأ في إعطاء البطاقة';
      notifyListeners();
      return false;
    }
  }

  /// Remove red card (after timeout)
  Future<bool> removeRedCard(String oderId) async {
    if (_activeMatch == null) return false;

    try {
      return await _matchService.removeRedCard(
        matchId: _activeMatch!.id,
        oderId: oderId,
      );
    } catch (e) {
      return false;
    }
  }

  // ==========================================
  // HELPER GETTERS FOR ACTIVE MATCH
  // ==========================================

  int get teamAScore => _activeMatch?.teamAScore ?? 0;
  int get teamBScore => _activeMatch?.teamBScore ?? 0;
  String get teamAName => _activeMatch?.teamAName ?? 'الفريق الأزرق';
  String get teamBName => _activeMatch?.teamBName ?? 'الفريق الأحمر';
  List<MatchPlayer> get teamAPlayers => _activeMatch?.teamAPlayers ?? [];
  List<MatchPlayer> get teamBPlayers => _activeMatch?.teamBPlayers ?? [];
  int get totalYellowCards => _activeMatch?.totalYellowCards ?? 0;
  int get totalRedCards => _activeMatch?.totalRedCards ?? 0;
}