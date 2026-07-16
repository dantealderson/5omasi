import 'dart:async';
import 'package:flutter/material.dart';
import 'package:khomasi/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:khomasi/providers/user_provider.dart';
import 'package:khomasi/models/match_model.dart';
import 'package:khomasi/components/score_board.dart';
import 'package:khomasi/components/match_timer.dart';
import 'package:khomasi/l10n/app_localizations.dart';

class ActiveMatchPage extends StatefulWidget {
  final String matchId;
  final String venue;
  final String teamAName;
  final String teamBName;

  const ActiveMatchPage({
    super.key,
    required this.matchId,
    required this.venue,
    this.teamAName = '',
    this.teamBName = '',
  });

  @override
  State<ActiveMatchPage> createState() => _ActiveMatchPageState();
}

class _ActiveMatchPageState extends State<ActiveMatchPage> with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Local state for match (loaded from Firestore)
  MatchModel? _match;
  bool _isLoading = true;
  String? _error;
  
  // Local tracking for this session (for live updates)
  int _teamAScore = 0;
  int _teamBScore = 0;
  List<MatchPlayer> _teamAPlayers = [];
  List<MatchPlayer> _teamBPlayers = [];
  int _currentMatchYellowCards = 0;
  int _currentMatchRedCards = 0;
  bool _isEndingMatch = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMatchData();
  }
  
  Future<void> _loadMatchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .get();
      
      if (!doc.exists) {
        setState(() {
          _error = tr(context, 'matchNotFound');
          _isLoading = false;
        });
        return;
      }
      
      final match = MatchModel.fromFirestore(doc);
      
      // Assign this referee to the match if not already assigned
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (match.refereeId == null || match.refereeId!.isEmpty) {
        await FirebaseFirestore.instance
            .collection('matches')
            .doc(widget.matchId)
            .update({
          'refereeId': userProvider.userId,
          'refereeName': userProvider.userName,
        });
      }
      
      setState(() {
        _match = match;
        _teamAScore = match.teamAScore;
        _teamBScore = match.teamBScore;
        _teamAPlayers = List.from(match.teamAPlayers);
        _teamBPlayers = List.from(match.teamBPlayers);
        _currentMatchYellowCards = match.totalYellowCards;
        _currentMatchRedCards = match.totalRedCards;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = tr(context, 'matchLoadError');
        _isLoading = false;
      });
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _recordGoal(String team, int playerIndex) {
    HapticFeedback.lightImpact();
    setState(() {
      if (team == 'A') {
        _teamAScore++;
        _teamAPlayers[playerIndex].goals++;
      } else {
        _teamBScore++;
        _teamBPlayers[playerIndex].goals++;
      }
    });
    
    // Update Firestore
    _updateMatchInFirestore();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(context, 'goalScored')),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
  
  void _recordAssist(String team, int playerIndex) {
    HapticFeedback.lightImpact();
    setState(() {
      if (team == 'A') {
        _teamAPlayers[playerIndex].assists++;
      } else {
        _teamBPlayers[playerIndex].assists++;
      }
    });
    
    // Update Firestore
    _updateMatchInFirestore();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(context, 'assistRecorded')),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
  
  void _giveYellowCard(String team, int playerIndex) {
    HapticFeedback.mediumImpact();
    setState(() {
      final players = team == 'A' ? _teamAPlayers : _teamBPlayers;
      players[playerIndex].yellowCards++;
      _currentMatchYellowCards++;
      
      // Auto red card for second yellow
      if (players[playerIndex].yellowCards >= 2 && !players[playerIndex].hasRedCard) {
        players[playerIndex].hasRedCard = true;
        players[playerIndex].redCardTime = DateTime.now();
        _currentMatchRedCards++;
      }
    });
    
    // Update Firestore
    _updateMatchInFirestore();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(context, 'yellowCard')),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
  
  void _giveRedCard(String team, int playerIndex) {
    HapticFeedback.heavyImpact();
    setState(() {
      final players = team == 'A' ? _teamAPlayers : _teamBPlayers;
      if (!players[playerIndex].hasRedCard) {
        players[playerIndex].hasRedCard = true;
        players[playerIndex].redCardTime = DateTime.now();
        _currentMatchRedCards++;
      }
    });
    
    // Update Firestore
    _updateMatchInFirestore();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(context, 'redCard')),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _updateMatchInFirestore() async {
    try {
      await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .update({
        'teamAScore': _teamAScore,
        'teamBScore': _teamBScore,
        'teamAPlayers': _teamAPlayers.map((p) => p.toMap()).toList(),
        'teamBPlayers': _teamBPlayers.map((p) => p.toMap()).toList(),
        'totalYellowCards': _currentMatchYellowCards,
        'totalRedCards': _currentMatchRedCards,
      });
    } catch (e) {
      print('Error updating match: $e');
    }
  }

  void _endMatch() {
    HapticFeedback.heavyImpact();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.dSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.stop_circle, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              tr(context, 'endMatch'),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(context, 'endMatchConfirm'),
              style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr(context, 'finalScore'),
                        style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
                      ),
                      Text(
                        '$_teamAScore - $_teamBScore',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr(context, 'goalsScored'),
                        style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
                      ),
                      Text(
                        '${_teamAScore + _teamBScore}',
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr(context, 'cards'),
                        style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
                      ),
                      Text(
                        '🟨 $_currentMatchYellowCards  🟥 $_currentMatchRedCards',
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Note about guest stats
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr(context, 'onlyRegisteredStats'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              tr(context, 'cancel'),
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: _isEndingMatch ? null : () async {
              // Prevent double press
              _isEndingMatch = true;

              Navigator.pop(dialogContext);

              final matchDate = DateTime.now();

              try {
                // Update match status to completed
                await FirebaseFirestore.instance
                    .collection('matches')
                    .doc(widget.matchId)
                    .update({
                  'status': 'completed',
                  'endedAt': Timestamp.fromDate(matchDate),
                  'teamAScore': _teamAScore,
                  'teamBScore': _teamBScore,
                  'teamAPlayers': _teamAPlayers.map((p) => p.toMap()).toList(),
                  'teamBPlayers': _teamBPlayers.map((p) => p.toMap()).toList(),
                  'totalYellowCards': _currentMatchYellowCards,
                  'totalRedCards': _currentMatchRedCards,
                });

                // Update referee stats
                await userProvider.updateRefereeStats(
                  matchesIncrement: 1,
                  goalsIncrement: _teamAScore + _teamBScore,
                  yellowCardsIncrement: _currentMatchYellowCards,
                  redCardsIncrement: _currentMatchRedCards,
                );

                // Update player stats (only for non-guest players)
                await _updatePlayerStats();

                // Save match records for time-based leaderboard
                await _savePlayerMatchRecords(matchDate);
              } catch (e) {
                print('Error ending match: $e');
              }

              if (!mounted) {
                print('❌ NOT MOUNTED - cannot pop');
                return;
              }

              print('✅ MOUNTED - popping active match page');
              Navigator.of(context).pop();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tr(context, 'matchEndedSuccess')),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(tr(context, 'endMatch'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Update player stats in Firestore (only for non-guest players)
  Future<void> _updatePlayerStats() async {
    // Determine match result for each team
    final String teamAResult;
    final String teamBResult;
    
    if (_teamAScore > _teamBScore) {
      teamAResult = 'win';
      teamBResult = 'loss';
    } else if (_teamBScore > _teamAScore) {
      teamAResult = 'loss';
      teamBResult = 'win';
    } else {
      teamAResult = 'draw';
      teamBResult = 'draw';
    }
    
    // Track which oderIds we've already updated to prevent double-counting
    final updatedOderIds = <String>{};

    // Update Team A players
    for (final player in _teamAPlayers) {
      if (updatedOderIds.contains(player.oderId)) continue;
      if (player.oderId.contains('_guest_')) continue;
      updatedOderIds.add(player.oderId);
      await _updateSinglePlayerStats(player, teamAResult);
    }

    // Update Team B players
    for (final player in _teamBPlayers) {
      if (updatedOderIds.contains(player.oderId)) continue;
      if (player.oderId.contains('_guest_')) continue;
      updatedOderIds.add(player.oderId);
      await _updateSinglePlayerStats(player, teamBResult);
    }
  }
  
  /// Update stats for a single player
  Future<void> _updateSinglePlayerStats(MatchPlayer player, String result) async {
    // Skip guest players - their stats don't get saved
    if (player.isGuest) {
      print('⏭️ Skipping guest player: ${player.playerName}');
      return;
    }
    
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(player.oderId);
      
      // First check if user exists
      final userDoc = await userRef.get();
      if (!userDoc.exists) {
        print('⚠️ User not found: ${player.oderId}');
        return;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      
      // Check if playerStats exists, if not create it
      if (userData['playerStats'] == null) {
        print('📝 Creating playerStats for user: ${player.playerName}');
        await userRef.update({
          'playerStats': {
            'totalMatches': 1,
            'totalGoals': player.goals,
            'totalAssists': player.assists,
            'yellowCards': player.yellowCards,
            'redCards': player.hasRedCard ? 1 : 0,
            'wins': result == 'win' ? 1 : 0,
            'losses': result == 'loss' ? 1 : 0,
            'draws': result == 'draw' ? 1 : 0,
            'playerOfMatchAwards': 0,
            'hatTricks': player.goals >= 3 ? 1 : 0,
          }
        });
      } else {
        // Use FieldValue.increment for existing stats
        final updates = <String, dynamic>{
          'playerStats.totalMatches': FieldValue.increment(1),
          'playerStats.totalGoals': FieldValue.increment(player.goals),
          'playerStats.totalAssists': FieldValue.increment(player.assists),
          'playerStats.yellowCards': FieldValue.increment(player.yellowCards),
          'playerStats.redCards': FieldValue.increment(player.hasRedCard ? 1 : 0),
        };
        
        // Add win/loss/draw increment
        if (result == 'win') {
          updates['playerStats.wins'] = FieldValue.increment(1);
        } else if (result == 'loss') {
          updates['playerStats.losses'] = FieldValue.increment(1);
        } else {
          updates['playerStats.draws'] = FieldValue.increment(1);
        }
        
        // Check for hat trick
        if (player.goals >= 3) {
          updates['playerStats.hatTricks'] = FieldValue.increment(1);
        }
        
        await userRef.update(updates);
      }
      
      print('✅ Updated stats for ${player.playerName}: Goals=${player.goals}, Result=$result');
    } catch (e) {
      print('❌ Error updating stats for ${player.playerName}: $e');
    }
  }

  /// Save individual match records for time-based leaderboard filtering
  Future<void> _savePlayerMatchRecords(DateTime matchDate) async {
    // Determine match result for each team
    final String teamAResult;
    final String teamBResult;
    
    if (_teamAScore > _teamBScore) {
      teamAResult = 'win';
      teamBResult = 'loss';
    } else if (_teamBScore > _teamAScore) {
      teamAResult = 'loss';
      teamBResult = 'win';
    } else {
      teamAResult = 'draw';
      teamBResult = 'draw';
    }
    
    final batch = FirebaseFirestore.instance.batch();
    final collection = FirebaseFirestore.instance.collection('playerMatchRecords');
    
    // Track which oderIds we've already saved to prevent duplicates
    final savedOderIds = <String>{};

    // Save Team A players
    for (final player in _teamAPlayers) {
      if (player.isGuest) continue; // Skip guests
      if (player.oderId.contains('_guest_')) continue; // Extra safety
      if (savedOderIds.contains(player.oderId)) continue; // Prevent duplicates
      savedOderIds.add(player.oderId);

      // Use deterministic ID: matchId_oderId to prevent duplicate records
      final docRef = collection.doc('${widget.matchId}_${player.oderId}');
      batch.set(docRef, {
        'oderId': player.oderId,
        'matchId': widget.matchId,
        'playerName': player.playerName,
        'goals': player.goals,
        'assists': player.assists,
        'yellowCards': player.yellowCards,
        'redCards': player.hasRedCard ? 1 : 0,
        'result': teamAResult,
        'matchDate': Timestamp.fromDate(matchDate),
      });
    }

    // Save Team B players
    for (final player in _teamBPlayers) {
      if (player.isGuest) continue; // Skip guests
      if (player.oderId.contains('_guest_')) continue; // Extra safety
      if (savedOderIds.contains(player.oderId)) continue; // Prevent duplicates
      savedOderIds.add(player.oderId);

      final docRef = collection.doc('${widget.matchId}_${player.oderId}');
      batch.set(docRef, {
        'oderId': player.oderId,
        'matchId': widget.matchId,
        'playerName': player.playerName,
        'goals': player.goals,
        'assists': player.assists,
        'yellowCards': player.yellowCards,
        'redCards': player.hasRedCard ? 1 : 0,
        'result': teamBResult,
        'matchDate': Timestamp.fromDate(matchDate),
      });
    }
    
    try {
      await batch.commit();
      print('✅ Saved ${_teamAPlayers.length + _teamBPlayers.length} match records');
    } catch (e) {
      print('❌ Error saving match records: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_error != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('خطأ'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Colors.red[400])),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('رجوع'),
              ),
            ],
          ),
        ),
      );
    }
    
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // Header with gradient background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [AppColors.dRaised, AppColors.dSurface]
                        : [AppColors.brand, AppColors.brandPressed],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        widget.venue,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    ScoreBoard(
                      teamAName: _match?.teamAName ?? (widget.teamAName.isNotEmpty ? widget.teamAName : tr(context, 'blueTeam')),
                      teamBName: _match?.teamBName ?? (widget.teamBName.isNotEmpty ? widget.teamBName : tr(context, 'redTeam')),
                      teamAScore: _teamAScore,
                      teamBScore: _teamBScore,
                    ),
                    
                    const MatchTimer(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.brand,
                  indicatorWeight: 3,
                  labelColor: AppColors.brand,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.circle, size: 12, color: Colors.blue),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _match?.teamAName ?? (widget.teamAName.isNotEmpty ? widget.teamAName : tr(context, 'blueTeam')),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.circle, size: 12, color: Colors.red),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _match?.teamBName ?? (widget.teamBName.isNotEmpty ? widget.teamBName : tr(context, 'redTeam')),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Players List
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTeamPlayers('A', _teamAPlayers),
                    _buildTeamPlayers('B', _teamBPlayers),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _endMatch,
          backgroundColor: Colors.red,
          icon: const Icon(Icons.stop, color: Colors.white),
          label: Text(tr(context, 'endMatch'), style: const TextStyle(color: Colors.white)),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
  
  Widget _buildTeamPlayers(String team, List<MatchPlayer> players) {
    if (players.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              tr(context, 'noPlayers'),
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        return _PlayerActionCard(
          player: player,
          onGoal: () => _recordGoal(team, index),
          onAssist: () => _recordAssist(team, index),
          onYellowCard: () => _giveYellowCard(team, index),
          onRedCard: () => _giveRedCard(team, index),
          onRedCardExpired: () => _clearRedCard(team, index),
        );
      },
    );
  }
  
  void _clearRedCard(String team, int playerIndex) {
    HapticFeedback.mediumImpact();
    setState(() {
      final players = team == 'A' ? _teamAPlayers : _teamBPlayers;
      players[playerIndex].hasRedCard = false;
      players[playerIndex].redCardTime = null;
    });
    
    // Show snackbar
    final playerName = (team == 'A' ? _teamAPlayers : _teamBPlayers)[playerIndex].playerName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$playerName ${tr(context, 'returnedToPlay')}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ============================================
// PLAYER ACTION CARD (with guest indicator)
// ============================================

class _PlayerActionCard extends StatefulWidget {
  final MatchPlayer player;
  final VoidCallback onGoal;
  final VoidCallback onAssist;
  final VoidCallback onYellowCard;
  final VoidCallback onRedCard;
  final VoidCallback? onRedCardExpired;

  const _PlayerActionCard({
    required this.player,
    required this.onGoal,
    required this.onAssist,
    required this.onYellowCard,
    required this.onRedCard,
    this.onRedCardExpired,
  });

  @override
  State<_PlayerActionCard> createState() => _PlayerActionCardState();
}

class _PlayerActionCardState extends State<_PlayerActionCard> {
  Timer? _timer;
  int _remainingSeconds = 0;
  
  static const int redCardDurationSeconds = 5 * 60; // 5 minutes

  @override
  void initState() {
    super.initState();
    _calculateAndStartTimer();
  }

  @override
  void didUpdateWidget(_PlayerActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always recalculate when player data changes
    _calculateAndStartTimer();
  }

  void _calculateAndStartTimer() {
    _timer?.cancel();
    _timer = null;
    
    if (widget.player.hasRedCard) {
      // Calculate remaining time from redCardTime
      if (widget.player.redCardTime != null) {
        final elapsed = DateTime.now().difference(widget.player.redCardTime!).inSeconds;
        _remainingSeconds = (redCardDurationSeconds - elapsed).clamp(0, redCardDurationSeconds);
      } else {
        _remainingSeconds = redCardDurationSeconds;
      }
      
      // Start timer if time remaining
      if (_remainingSeconds > 0) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() {
              _remainingSeconds--;
            });
            if (_remainingSeconds <= 0) {
              _timer?.cancel();
              widget.onRedCardExpired?.call();
            }
          }
        });
      } else {
        // Time already expired
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onRedCardExpired?.call();
        });
      }
    } else {
      _remainingSeconds = 0;
    }
    
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get _isSuspended => widget.player.hasRedCard && _remainingSeconds > 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final player = widget.player;
    final isGuest = player.isGuest;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.dSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isSuspended
              ? Colors.red.withOpacity(0.5)
              : (isGuest
                  ? Colors.orange.withOpacity(0.3)
                  : (isDark ? Colors.grey[800]! : Colors.grey[200]!)),
          width: _isSuspended ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Player info row
          Row(
            children: [
              // Player number
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isSuspended
                      ? Colors.red.withOpacity(0.15)
                      : (isGuest
                          ? Colors.orange.withOpacity(0.2)
                          : AppColors.brand.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${player.playerNumber}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isSuspended
                          ? Colors.red
                          : (isGuest ? Colors.orange : AppColors.brand),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Player name and stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            player.playerName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _isSuspended
                                  ? Colors.red[700]
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isGuest) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tr(context, 'guest'),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        // Simple red card timer badge
                        if (_isSuspended) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTime(_remainingSeconds),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Stats row
                    Row(
                      children: [
                        if (player.goals > 0) ...[
                          _StatBadge(icon: '⚽', value: player.goals.toString()),
                          const SizedBox(width: 8),
                        ],
                        if (player.assists > 0) ...[
                          _StatBadge(icon: '🅰️', value: player.assists.toString()),
                          const SizedBox(width: 8),
                        ],
                        ...List.generate(
                          player.yellowCards,
                          (_) => Container(
                            width: 12,
                            height: 16,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: Colors.yellow[700],
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(color: Colors.orange, width: 1),
                            ),
                          ),
                        ),
                        if (player.hasRedCard)
                          Container(
                            width: 12,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(color: Colors.red[900]!, width: 1),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Action buttons (hidden when suspended)
          if (!_isSuspended) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.sports_soccer,
                    label: tr(context, 'goalAction'),
                    color: Colors.green,
                    onTap: widget.onGoal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.assistant,
                    label: tr(context, 'passAction'),
                    color: Colors.blue,
                    onTap: widget.onAssist,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.square,
                    label: tr(context, 'yellowAction'),
                    color: Colors.amber,
                    onTap: widget.onYellowCard,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.square,
                    label: tr(context, 'redAction'),
                    color: Colors.red,
                    onTap: widget.onRedCard,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String icon;
  final String value;

  const _StatBadge({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.brand.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}