import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/match_history_model.dart';
import 'package:khomasi/l10n/app_localizations.dart';
import 'package:khomasi/pages/rate_players_page.dart';

class MatchHistoryPage extends StatefulWidget {
  const MatchHistoryPage({super.key});

  @override
  State<MatchHistoryPage> createState() => _MatchHistoryPageState();
}

class _MatchHistoryPageState extends State<MatchHistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all'; // all, upcoming, won, lost, draw
  
  // Player data
  List<PlayerMatchHistory> _playerMatches = [];
  List<PlayerMatchHistory> _upcomingMatches = [];
  
  // Referee data
  List<RefereeMatchHistory> _refereeMatches = [];
  
  bool _isLoading = true;
  bool _isReferee = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMatchHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMatchHistory() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    _isReferee = userProvider.isReferee;
    
    print('🔍 Loading match history for userId: $userId, isReferee: $_isReferee');
    
    if (userId.isEmpty) {
      print('❌ userId is empty!');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      if (_isReferee) {
        await _loadRefereeHistory(userId);
        print('📊 Loaded ${_refereeMatches.length} referee matches');
      } else {
        await _loadPlayerHistory(userId);
        await _loadUpcomingMatches(userId);
        print('📊 Loaded ${_playerMatches.length} completed + ${_upcomingMatches.length} upcoming matches');
      }
    } catch (e) {
      print('❌ Error loading match history: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadPlayerHistory(String userId) async {
    final matches = <PlayerMatchHistory>[];
    
    print('🔍 _loadPlayerHistory called for userId: $userId');
    
    // Query playerMatchRecords (this has all the data we need including result)
    try {
      print('📡 Querying playerMatchRecords...');
      
      // Simple query without orderBy to avoid index requirement
      final snapshot = await FirebaseFirestore.instance
          .collection('playerMatchRecords')
          .where('oderId', isEqualTo: userId)
          .get();
      
      print('📦 playerMatchRecords returned ${snapshot.docs.length} docs');
      
      final seenMatchIds = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();

        final matchId = data['matchId'] as String?;

        // Skip duplicates (same match shown multiple times)
        if (matchId == null || seenMatchIds.contains(matchId)) continue;
        seenMatchIds.add(matchId);
        
        // Get stadium name from matches collection
        String stadiumName = 'ملعب غير معروف';
        int myTeamScore = 0;
        int opponentScore = 0;
        
        try {
          final matchDoc = await FirebaseFirestore.instance
              .collection('matches')
              .doc(matchId)
              .get();

          if (matchDoc.exists) {
            final matchData = matchDoc.data()!;
            stadiumName = matchData['stadiumName'] ?? 'ملعب غير معروف';
            final teamAScore = matchData['teamAScore'] ?? 0;
            final teamBScore = matchData['teamBScore'] ?? 0;

            // Determine scores based on result
            final result = data['result'] ?? 'draw';
            if (result == 'win') {
              myTeamScore = teamAScore > teamBScore ? teamAScore : teamBScore;
              opponentScore = teamAScore > teamBScore ? teamBScore : teamAScore;
            } else if (result == 'loss') {
              myTeamScore = teamAScore < teamBScore ? teamAScore : teamBScore;
              opponentScore = teamAScore < teamBScore ? teamBScore : teamAScore;
            } else {
              myTeamScore = teamAScore;
              opponentScore = teamBScore;
            }
          }
        } catch (e) {
          print('⚠️ Error fetching match $matchId: $e');
        }

        matches.add(PlayerMatchHistory(
          matchId: matchId,
          matchDate: (data['matchDate'] as Timestamp).toDate(),
          stadiumName: stadiumName,
          result: data['result'] ?? 'draw',
          myTeamScore: myTeamScore,
          opponentScore: opponentScore,
          myGoals: data['goals'] ?? 0,
          myAssists: data['assists'] ?? 0,
          yellowCards: data['yellowCards'] ?? 0,
          redCards: data['redCards'] ?? 0,
        ));
      }
    } catch (e) {
      print('❌ Error querying playerMatchRecords: $e');
    }
    
    // Sort by date in memory (since we removed orderBy from query)
    matches.sort((a, b) => b.matchDate.compareTo(a.matchDate));
    
    print('✅ Final matches count: ${matches.length}');
    _playerMatches = matches;
  }

  Future<void> _loadUpcomingMatches(String userId) async {
    final upcoming = <PlayerMatchHistory>[];
    
    try {
      // Query matches that are not completed
      final snapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('status', whereIn: ['open', 'full', 'scheduled'])
          .get();
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final teamAPlayers = data['teamAPlayers'] as List<dynamic>? ?? [];
        final teamBPlayers = data['teamBPlayers'] as List<dynamic>? ?? [];
        
        // Check if user is in this match
        bool isInMatch = false;
        for (final p in teamAPlayers) {
          if (p['oderId'] == userId && (p['isGuest'] != true)) {
            isInMatch = true;
            break;
          }
        }
        if (!isInMatch) {
          for (final p in teamBPlayers) {
            if (p['oderId'] == userId && (p['isGuest'] != true)) {
              isInMatch = true;
              break;
            }
          }
        }
        
        if (isInMatch) {
          upcoming.add(PlayerMatchHistory(
            matchId: doc.id,
            matchDate: (data['dateTime'] as Timestamp).toDate(),
            stadiumName: data['stadiumName'] ?? 'ملعب غير معروف',
            result: 'upcoming',
            myTeamScore: 0,
            opponentScore: 0,
            myGoals: 0,
            myAssists: 0,
            status: data['status'],
          ));
        }
      }
      
      // Sort by date (earliest first)
      upcoming.sort((a, b) => a.matchDate.compareTo(b.matchDate));
      
    } catch (e) {
      print('❌ Error loading upcoming matches: $e');
    }
    
    _upcomingMatches = upcoming;
  }

  Future<void> _loadRefereeHistory(String userId) async {
    try {
      // Query completed matches where this user was referee
      final snapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('refereeId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .orderBy('endedAt', descending: true)
          .limit(50)
          .get();
      
      _refereeMatches = snapshot.docs
          .map((doc) => RefereeMatchHistory.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error loading referee history: $e');
      
      // Fallback: query without orderBy (in case index doesn't exist)
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('matches')
            .where('refereeId', isEqualTo: userId)
            .where('status', isEqualTo: 'completed')
            .get();
        
        final matches = snapshot.docs
            .map((doc) => RefereeMatchHistory.fromFirestore(doc))
            .toList();
        
        // Sort in memory
        matches.sort((a, b) => b.matchDate.compareTo(a.matchDate));
        
        _refereeMatches = matches.take(50).toList();
      } catch (e2) {
        print('Error in fallback referee history: $e2');
        _refereeMatches = [];
      }
    }
  }

  // Player filtered matches
  List<PlayerMatchHistory> get filteredPlayerMatches {
    if (_selectedFilter == 'all') {
      // Combine upcoming and completed, with upcoming first
      return [..._upcomingMatches, ..._playerMatches];
    }
    if (_selectedFilter == 'upcoming') {
      return _upcomingMatches;
    }
    return _playerMatches.where((match) {
      switch (_selectedFilter) {
        case 'won':
          return match.isWin;
        case 'lost':
          return match.isLoss;
        case 'draw':
          return match.isDraw;
        default:
          return true;
      }
    }).toList();
  }

  // All matches for stats (completed only)
  List<PlayerMatchHistory> get _completedMatches => _playerMatches;

  // Player stats (only from completed matches)
  int get _totalGoals => _completedMatches.fold(0, (sum, m) => sum + m.myGoals);
  int get _totalAssists => _completedMatches.fold(0, (sum, m) => sum + m.myAssists);
  int get _wonMatches => _completedMatches.where((m) => m.isWin).length;
  int get _lostMatches => _completedMatches.where((m) => m.isLoss).length;
  int get _drawMatches => _completedMatches.where((m) => m.isDraw).length;
  int get _upcomingCount => _upcomingMatches.length;
  String get _winRate => _completedMatches.isEmpty 
      ? '0.0' 
      : (_wonMatches / _completedMatches.length * 100).toStringAsFixed(1);

  // Referee stats
  int get _refTotalGoals => _refereeMatches.fold(0, (sum, m) => sum + m.totalGoals);
  int get _refTotalYellowCards => _refereeMatches.fold(0, (sum, m) => sum + m.yellowCards);
  int get _refTotalRedCards => _refereeMatches.fold(0, (sum, m) => sum + m.redCards);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isReferee ? tr(context, 'refereeMatches') : tr(context, 'matchHistory')),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: tr(context, 'completedMatches')),
            const Tab(text: 'الإحصائيات'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : RefreshIndicator(
              onRefresh: _loadMatchHistory,
              color: Colors.deepPurple,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _isReferee ? _buildRefereeMatchesTab() : _buildPlayerMatchesTab(),
                  _isReferee ? _buildRefereeStatisticsTab() : _buildPlayerStatisticsTab(),
                ],
              ),
            ),
    );
  }

  // ==========================================
  // PLAYER MATCHES TAB
  // ==========================================

  Widget _buildPlayerMatchesTab() {
    final allMatches = [..._upcomingMatches, ..._playerMatches];
    
    if (allMatches.isEmpty) {
      return _buildEmptyState(tr(context, 'noCompletedMatches'));
    }
    
    return Column(
      children: [
        // Filter Buttons
        Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('الكل', 'all', allMatches.length),
                const SizedBox(width: 8),
                if (_upcomingCount > 0) ...[
                  _buildFilterChip('قادمة', 'upcoming', _upcomingCount),
                  const SizedBox(width: 8),
                ],
                _buildFilterChip('الفوز', 'won', _wonMatches),
                const SizedBox(width: 8),
                _buildFilterChip('التعادل', 'draw', _drawMatches),
                const SizedBox(width: 8),
                _buildFilterChip('الخسارة', 'lost', _lostMatches),
              ],
            ),
          ),
        ),
        
        // Matches List
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredPlayerMatches.length,
            itemBuilder: (context, index) {
              final match = filteredPlayerMatches[index];
              // Show rate button only on the most recent completed match
              final isLatestCompleted = !match.isUpcoming &&
                  _playerMatches.isNotEmpty &&
                  match.matchId == _playerMatches.first.matchId;
              return _buildPlayerMatchCard(match, isLatestCompleted: isLatestCompleted);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _selectedFilter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.deepPurple 
              : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? Colors.deepPurple 
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected 
                    ? Colors.white 
                    : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Colors.white 
                    : (isDark 
                        ? Colors.deepPurple.withOpacity(0.2) 
                        : Colors.deepPurple.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected 
                      ? Colors.deepPurple 
                      : (isDark ? Colors.deepPurple[300] : Colors.deepPurple),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerMatchCard(PlayerMatchHistory match, {bool isLatestCompleted = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color resultColor;
    String resultText;
    IconData resultIcon;
    
    if (match.isUpcoming) {
      resultColor = Colors.blue;
      resultText = tr(context, 'upcomingMatches');
      resultIcon = Icons.schedule;
    } else if (match.isWin) {
      resultColor = Colors.green;
      resultText = tr(context, 'wonMatch');
      resultIcon = Icons.emoji_events;
    } else if (match.isLoss) {
      resultColor = Colors.red;
      resultText = tr(context, 'lostMatch');
      resultIcon = Icons.sentiment_dissatisfied;
    } else {
      resultColor = Colors.orange;
      resultText = tr(context, 'drawMatch');
      resultIcon = Icons.handshake;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
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
          // Match Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: resultColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(resultIcon, color: resultColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  resultText,
                  style: TextStyle(
                    color: resultColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  match.isUpcoming 
                      ? _formatUpcomingDate(match.matchDate)
                      : _formatDate(match.matchDate),
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Match Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Stadium and Score
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            match.stadiumName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (match.isUpcoming) ...[
                            const SizedBox(height: 4),
                            Text(
                              _formatMatchTime(match.matchDate),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!match.isUpcoming) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.grey[700]! : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              match.myTeamScore.toString(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: match.isWin 
                                    ? Colors.green 
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '-',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ),
                            Text(
                              match.opponentScore.toString(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: match.isLoss 
                                    ? Colors.red 
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Upcoming match - show status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Text(
                          match.status == 'full' ? 'مكتملة' : 'متاحة',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                
                // Player Stats (only for completed matches)
                if (!match.isUpcoming) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        icon: Icons.sports_soccer,
                        value: match.myGoals.toString(),
                        label: tr(context, 'goalsLower'),
                      ),
                      _buildStatItem(
                        icon: Icons.sports,
                        value: match.myAssists.toString(),
                        label: tr(context, 'assistsLower'),
                      ),
                      if (match.yellowCards > 0 || match.redCards > 0)
                        _buildStatItem(
                          icon: Icons.square,
                          iconColor: match.redCards > 0 ? Colors.red : Colors.amber,
                          value: match.redCards > 0
                              ? match.redCards.toString()
                              : match.yellowCards.toString(),
                          label: match.redCards > 0 ? tr(context, 'redAction') : tr(context, 'yellowAction'),
                        ),
                      if (match.hasHatTrick)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.amber),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'هاتريك',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  // Rate Players button - only on latest completed match
                  if (isLatestCompleted) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openRatePlayers(match.matchId),
                        icon: const Icon(Icons.star_outline_rounded, size: 20),
                        label: Text(tr(context, 'ratePlayers')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                          side: const BorderSide(color: Colors.deepPurple),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRatePlayers(String matchId) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;

    // Fetch match data
    final matchDoc = await FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .get();

    if (!matchDoc.exists || !mounted) return;

    final matchData = matchDoc.data()!;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RatePlayersPage(
          matchId: matchId,
          currentUserId: userId,
          matchData: matchData,
        ),
      ),
    );
  }

  String _formatUpcomingDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final matchDay = DateTime(date.year, date.month, date.day);
    
    if (matchDay == today) return 'اليوم';
    if (matchDay == tomorrow) return 'غداً';
    
    final difference = matchDay.difference(today).inDays;
    if (difference < 7) return 'بعد $difference أيام';
    
    return '${date.day}/${date.month}';
  }

  String _formatMatchTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  // ==========================================
  // REFEREE MATCHES TAB
  // ==========================================

  Widget _buildRefereeMatchesTab() {
    if (_refereeMatches.isEmpty) {
      return _buildEmptyState(tr(context, 'noRefereeMatches'));
    }
    
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _refereeMatches.length,
      itemBuilder: (context, index) {
        final match = _refereeMatches[index];
        return _buildRefereeMatchCard(match);
      },
    );
  }

  Widget _buildRefereeMatchCard(RefereeMatchHistory match) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
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
          // Match Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.sports, color: Colors.deepPurple, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    match.stadiumName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatDate(match.matchDate),
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Match Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Score
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Text(
                          tr(context, 'blueTeam'),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          match.teamAScore.toString(),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: match.teamAScore > match.teamBScore
                                ? Colors.green
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '-',
                        style: TextStyle(
                          fontSize: 28,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          tr(context, 'redTeam'),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          match.teamBScore.toString(),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: match.teamBScore > match.teamAScore 
                                ? Colors.green 
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                
                // Match Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Icons.sports_soccer,
                      value: match.totalGoals.toString(),
                      label: tr(context, 'totalGoalsRecorded'),
                    ),
                    _buildStatItem(
                      icon: Icons.square,
                      iconColor: Colors.amber,
                      value: match.yellowCards.toString(),
                      label: tr(context, 'yellowAction'),
                    ),
                    _buildStatItem(
                      icon: Icons.square,
                      iconColor: Colors.red,
                      value: match.redCards.toString(),
                      label: tr(context, 'redAction'),
                    ),
                    _buildStatItem(
                      icon: Icons.groups,
                      value: match.totalPlayers.toString(),
                      label: 'لاعبين',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PLAYER STATISTICS TAB
  // ==========================================

  Widget _buildPlayerStatisticsTab() {
    if (_playerMatches.isEmpty) {
      return _buildEmptyState(tr(context, 'noCompletedMatches'));
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Overall Stats Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.deepPurple.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'إحصائيات عامة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildOverallStatItem('المباريات', _playerMatches.length.toString()),
                    _buildOverallStatItem('الأهداف', _totalGoals.toString()),
                    _buildOverallStatItem('الصناعات', _totalAssists.toString()),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Win Rate Card
          _buildWinRateCard(),

          const SizedBox(height: 20),

          // Performance Trends
          _buildPerformanceTrends(),
        ],
      ),
    );
  }

  Widget _buildWinRateCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'نسبة الفوز',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '$_winRate%',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _buildResultRow(tr(context, 'wonMatch'), _wonMatches, Colors.green),
                    const SizedBox(height: 8),
                    _buildResultRow(tr(context, 'drawMatch'), _drawMatches, Colors.orange),
                    const SizedBox(height: 8),
                    _buildResultRow(tr(context, 'lostMatch'), _lostMatches, Colors.red),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTrends() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recentMatches = _playerMatches.take(5).toList();
    
    if (recentMatches.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الأداء الأخير',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: recentMatches.map((match) {
              Color color;
              String letter;
              
              if (match.isWin) {
                color = Colors.green;
                letter = 'W';
              } else if (match.isLoss) {
                color = Colors.red;
                letter = 'L';
              } else {
                color = Colors.orange;
                letter = 'D';
              }
              
              return Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // REFEREE STATISTICS TAB
  // ==========================================

  Widget _buildRefereeStatisticsTab() {
    if (_refereeMatches.isEmpty) {
      return _buildEmptyState(tr(context, 'noRefereeMatches'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Overall Stats Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.deepPurple.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'إحصائيات التحكيم',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildOverallStatItem('المباريات', _refereeMatches.length.toString()),
                    _buildOverallStatItem('الأهداف', _refTotalGoals.toString()),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Cards Stats
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, 'cardsGiven'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 60,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _refTotalYellowCards.toString(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(tr(context, 'yellowAction')),
                      ],
                    ),
                    Column(
                      children: [
                        Container(
                          width: 60,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _refTotalRedCards.toString(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(tr(context, 'redAction')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Average Stats
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'المتوسطات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildAverageRow(
                  'أهداف / مباراة',
                  (_refTotalGoals / _refereeMatches.length).toStringAsFixed(1),
                  Icons.sports_soccer,
                ),
                const SizedBox(height: 12),
                _buildAverageRow(
                  'بطاقات صفراء / مباراة',
                  (_refTotalYellowCards / _refereeMatches.length).toStringAsFixed(1),
                  Icons.square,
                  iconColor: Colors.amber,
                ),
                const SizedBox(height: 12),
                _buildAverageRow(
                  'بطاقات حمراء / مباراة',
                  (_refTotalRedCards / _refereeMatches.length).toStringAsFixed(1),
                  Icons.square,
                  iconColor: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAverageRow(String label, String value, IconData icon, {Color? iconColor}) {
    return Row(
      children: [
        Icon(icon, color: iconColor ?? Colors.deepPurple, size: 20),
        const SizedBox(width: 12),
        Text(label),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    Color? iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        Icon(icon, color: iconColor ?? Colors.deepPurple, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildOverallStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildResultRow(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 80,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'اسحب للأسفل للتحديث',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) return 'اليوم';
    if (difference == 1) return 'أمس';
    if (difference < 7) return 'منذ $difference أيام';
    if (difference < 30) return 'منذ ${(difference / 7).floor()} أسابيع';
    return 'منذ ${(difference / 30).floor()} شهر';
  }
}