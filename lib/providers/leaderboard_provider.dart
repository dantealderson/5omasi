import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/leaderboard_model.dart';
import '../services/leaderboard_service.dart';

class LeaderboardProvider extends ChangeNotifier {
  final LeaderboardService _leaderboardService = LeaderboardService();

  // ==========================================
  // STATE
  // ==========================================

  bool _isLoading = false;
  String? _errorMessage;

  // Current selections
  LeaderboardPeriod _selectedPeriod = LeaderboardPeriod.week;
  LeaderboardType _selectedType = LeaderboardType.goals;

  // Leaderboard data
  List<LeaderboardEntry> _leaderboard = [];
  List<LeaderboardEntry> _topThree = [];

  // User's rank
  int? _userRank;
  LeaderboardEntry? _userEntry;

  // Stream subscriptions
  StreamSubscription? _leaderboardSubscription;

  // ==========================================
  // GETTERS
  // ==========================================

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  LeaderboardPeriod get selectedPeriod => _selectedPeriod;
  LeaderboardType get selectedType => _selectedType;

  List<LeaderboardEntry> get leaderboard => _leaderboard;
  List<LeaderboardEntry> get topThree => _topThree;

  int? get userRank => _userRank;
  LeaderboardEntry? get userEntry => _userEntry;

  // ==========================================
  // INITIALIZATION & CLEANUP
  // ==========================================

  void init({String? currentUserId}) {
    loadLeaderboard();
    if (currentUserId != null) {
      _loadUserRank(currentUserId);
    }
  }

  @override
  void dispose() {
    _leaderboardSubscription?.cancel();
    super.dispose();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ==========================================
  // FILTER METHODS
  // ==========================================

  /// Change period filter (week, month, all)
  void setPeriod(LeaderboardPeriod period) {
    if (_selectedPeriod == period) return;
    _selectedPeriod = period;
    notifyListeners();
    loadLeaderboard();
  }

  /// Change type filter (goals, assists)
  void setType(LeaderboardType type) {
    if (_selectedType == type) return;
    _selectedType = type;
    notifyListeners();
    loadLeaderboard();
  }

  /// Set period from string (for UI compatibility)
  void setPeriodFromString(String period) {
    switch (period) {
      case 'week':
        setPeriod(LeaderboardPeriod.week);
        break;
      case 'month':
        setPeriod(LeaderboardPeriod.month);
        break;
      case 'year':
        setPeriod(LeaderboardPeriod.year);
        break;
      case 'all':
        setPeriod(LeaderboardPeriod.all);
        break;
    }
  }

  /// Set type from string (for UI compatibility)
  void setTypeFromString(String type) {
    switch (type) {
      case 'goals':
        setType(LeaderboardType.goals);
        break;
      case 'assists':
        setType(LeaderboardType.assists);
        break;
    }
  }

  // ==========================================
  // LOAD METHODS
  // ==========================================

  /// Load leaderboard based on current filters
  Future<void> loadLeaderboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_selectedType == LeaderboardType.goals) {
        _leaderboard = await _leaderboardService.getGoalsLeaderboard(
          period: _selectedPeriod,
        );
        _topThree = await _leaderboardService.getTopGoalScorers(
          period: _selectedPeriod,
        );
      } else {
        _leaderboard = await _leaderboardService.getAssistsLeaderboard(
          period: _selectedPeriod,
        );
        _topThree = await _leaderboardService.getTopAssistMakers(
          period: _selectedPeriod,
        );
      }
    } catch (e) {
      _errorMessage = 'خطأ في تحميل لوحة الصدارة';
      debugPrint('Error loading leaderboard: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh leaderboard
  Future<void> refresh() async {
    await loadLeaderboard();
  }

  /// Load user's rank
  Future<void> _loadUserRank(String oderId) async {
    try {
      if (_selectedType == LeaderboardType.goals) {
        _userRank = await _leaderboardService.getUserGoalsRank(
          oderId,
          period: _selectedPeriod,
        );
      } else {
        _userRank = await _leaderboardService.getUserAssistsRank(
          oderId,
          period: _selectedPeriod,
        );
      }
      
      _userEntry = await _leaderboardService.getUserEntry(oderId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user rank: $e');
    }
  }

  /// Start streaming leaderboard updates
  void startStreaming() {
    _leaderboardSubscription?.cancel();
    
    if (_selectedType == LeaderboardType.goals) {
      _leaderboardSubscription = _leaderboardService
          .streamGoalsLeaderboard(period: _selectedPeriod)
          .listen((entries) {
            _leaderboard = entries;
            _topThree = entries.take(3).toList();
            notifyListeners();
          });
    } else {
      _leaderboardSubscription = _leaderboardService
          .streamAssistsLeaderboard(period: _selectedPeriod)
          .listen((entries) {
            _leaderboard = entries;
            _topThree = entries.take(3).toList();
            notifyListeners();
          });
    }
  }

  /// Stop streaming
  void stopStreaming() {
    _leaderboardSubscription?.cancel();
    _leaderboardSubscription = null;
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  /// Get player at specific rank
  LeaderboardEntry? getPlayerAtRank(int rank) {
    if (rank < 1 || rank > _leaderboard.length) return null;
    return _leaderboard[rank - 1];
  }

  /// Check if user is in top 3
  bool isUserInTopThree(String oderId) {
    return _topThree.any((e) => e.oderId == oderId);
  }

  /// Get sorted leaderboard (already sorted, but this can apply additional sorting)
  List<LeaderboardEntry> get sortedLeaderboard {
    final sorted = List<LeaderboardEntry>.from(_leaderboard);
    if (_selectedType == LeaderboardType.goals) {
      sorted.sort((a, b) => b.goals.compareTo(a.goals));
    } else {
      sorted.sort((a, b) => b.assists.compareTo(a.assists));
    }
    return sorted;
  }
}