// lib/root_page.dart - With Player Lockout for Active Matches
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khomasi/providers/user_provider.dart';
import 'package:khomasi/pages/login_page.dart';
import 'package:khomasi/pages/signup_page.dart';
import 'package:khomasi/pages/home_page.dart';
import 'package:khomasi/pages/leaderboard_page.dart';
import 'package:khomasi/pages/profile_page.dart';
import 'package:khomasi/pages/test_create_match.dart';
import 'package:khomasi/pages/player_lockout_screen.dart';
import 'package:khomasi/services/match_validation_service.dart';
import 'package:khomasi/l10n/app_localizations.dart';

class RootPage extends StatefulWidget {
  final int initialIndex;
  
  const RootPage({super.key, this.initialIndex = 1});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  late int _currentIndex;
  bool _hasCheckedMatches = false;

  final List<Widget> _pages = [
    const LeaderboardPage(),
    const HomePage(),
    const TestCreateMatchPage(), // Test page - remove later
    const ProfilePage(),
  ];

  List<String> _titles(BuildContext context) => [
    '',
    tr(context, 'welcomeStadiums'),
    tr(context, 'createMatch'),
    tr(context, 'personalAccount'),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // Run match validation check when app opens
    _runMatchValidationCheck();
  }

  /// Check and cancel invalid matches (runs once when app opens)
  Future<void> _runMatchValidationCheck() async {
    if (_hasCheckedMatches) return;
    _hasCheckedMatches = true;
    
    try {
      await MatchValidationService.checkAndCancelInvalidMatches();
      debugPrint('✅ Match validation check completed');
    } catch (e) {
      debugPrint('❌ Match validation check failed: $e');
    }
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) return;

    // Block "Create Match" tab for guests
    if (index == 2) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.isGuest) {
        _showGuestLoginDialog();
        return;
      }
    }

    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = index;
    });
  }

  void _showGuestLoginDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.lock_outline, size: 48, color: Colors.deepPurple.withOpacity(0.7)),
        title: Text(
          tr(context, 'guestLoginRequired'),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          tr(context, 'guestCreateMatchMessage'),
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(color: Colors.deepPurple),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(tr(context, 'login')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpPage()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(tr(context, 'guestCreateAccount')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userId = userProvider.userId;

    // Skip lockout check for guests
    if (userProvider.isGuest) return _buildNormalUI();

    // Check if user is a player (not referee)
    if (userId.isNotEmpty && userProvider.userRole == 'player') {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('matches')
            .where('status', isEqualTo: 'inProgress')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            // Check if user is playing in any active match
            for (final doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              
              // Check teamAPlayers
              final teamAPlayers = data['teamAPlayers'] as List<dynamic>? ?? [];
              final teamBPlayers = data['teamBPlayers'] as List<dynamic>? ?? [];
              
              bool isInTeamA = false;
              bool isInTeamB = false;
              
              for (final player in teamAPlayers) {
                if (player is Map && player['oderId'] == userId) {
                  isInTeamA = true;
                  break;
                }
              }
              
              if (!isInTeamA) {
                for (final player in teamBPlayers) {
                  if (player is Map && player['oderId'] == userId) {
                    isInTeamB = true;
                    break;
                  }
                }
              }
              
              if (isInTeamA || isInTeamB) {
                // User is in an active match - show lockout screen
                final matchTime = (data['dateTime'] as Timestamp).toDate();
                final durationMinutes = (data['durationMinutes'] ?? 60) as int;
                final stadiumName = data['stadiumName'] ?? tr(context, 'stadium');
                final teamName = isInTeamA
                    ? (data['teamAName'] ?? tr(context, 'blueTeam'))
                    : (data['teamBName'] ?? tr(context, 'redTeam'));
                
                return PlayerLockoutScreen(
                  stadiumName: stadiumName,
                  teamName: teamName,
                  matchStartTime: matchTime,
                  durationMinutes: durationMinutes,
                );
              }
            }
          }
          
          // No active match - show normal UI
          return _buildNormalUI();
        },
      );
    }
    
    // Referee or no user - show normal UI
    return _buildNormalUI();
  }

  Widget _buildNormalUI() {
    final bool showAppBar = _currentIndex != 0;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: Colors.deepPurple,
              centerTitle: true,
              title: Text(
                _titles(context)[_currentIndex],
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              elevation: 0,
            )
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        margin: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding > 0 ? bottomPadding + 10 : 20),
        height: 60,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(
              icon: Icons.emoji_events_outlined,
              activeIcon: Icons.emoji_events,
              label: tr(context, 'ranking'),
              index: 0,
            ),
            _buildNavItem(
              icon: Icons.sports_soccer_outlined,
              activeIcon: Icons.sports_soccer,
              label: tr(context, 'home'),
              index: 1,
            ),
            _buildNavItem(
              icon: Icons.add_circle_outline,
              activeIcon: Icons.add_circle,
              label: tr(context, 'create'),
              index: 2,
            ),
            _buildNavItem(
              icon: Icons.account_circle_outlined,
              activeIcon: Icons.account_circle,
              label: tr(context, 'account'),
              index: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final bool isSelected = _currentIndex == index;
    final color = isSelected ? Colors.deepPurple : Colors.grey;
    
    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        borderRadius: BorderRadius.circular(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}