import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:khomasi/l10n/app_localizations.dart';
import '../models/leaderboard_model.dart';
import '../providers/leaderboard_provider.dart';
import '../providers/user_provider.dart';
import 'player_profile_page.dart';
import 'root_page.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  @override
  void initState() {
    super.initState();
    // Load leaderboard on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LeaderboardProvider>(context, listen: false).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  
                  Text(
                    tr(context, 'leaderboard'),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      color: Colors.amber,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Period Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Consumer<LeaderboardProvider>(
                builder: (context, provider, _) {
                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F1F1F) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildPeriodTab(
                          "week",
                          tr(context, 'week'),
                          provider.selectedPeriod == LeaderboardPeriod.week,
                          () => provider.setPeriodFromString("week"),
                        ),
                        _buildPeriodTab(
                          "month",
                          tr(context, 'month'),
                          provider.selectedPeriod == LeaderboardPeriod.month,
                          () => provider.setPeriodFromString("month"),
                        ),
                        _buildPeriodTab(
                          "year",
                          tr(context, 'year'),
                          provider.selectedPeriod == LeaderboardPeriod.year,
                          () => provider.setPeriodFromString("year"),
                        ),
                        _buildPeriodTab(
                          "all",
                          tr(context, 'all'),
                          provider.selectedPeriod == LeaderboardPeriod.all,
                          () => provider.setPeriodFromString("all"),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Type Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Consumer<LeaderboardProvider>(
                builder: (context, provider, _) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildTypeButton(
                          "goals",
                          tr(context, 'goalsLabel'),
                          "⚽",
                          provider.selectedType == LeaderboardType.goals,
                          () => provider.setTypeFromString("goals"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTypeButton(
                          "assists",
                          tr(context, 'assistsLabel'),
                          "🎯",
                          provider.selectedType == LeaderboardType.assists,
                          () => provider.setTypeFromString("assists"),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Leaderboard List
            Expanded(
              child: Consumer<LeaderboardProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.deepPurple,
                      ),
                    );
                  }

                  if (provider.errorMessage != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            provider.errorMessage!,
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => provider.refresh(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                            ),
                            child: Text(tr(context, 'retry')),
                          ),
                        ],
                      ),
                    );
                  }

                  if (provider.leaderboard.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.leaderboard_outlined,
                            size: 64,
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            tr(context, 'noData'),
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr(context, 'startPlayingToAppear'),
                            style: TextStyle(
                              color: isDark ? Colors.grey[600] : Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => provider.refresh(),
                    color: Colors.deepPurple,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: provider.leaderboard.length,
                      itemBuilder: (context, index) {
                        final entry = provider.leaderboard[index];
                        final rank = index + 1;
                        return _buildPlayerCard(entry, rank, isDark, provider.selectedType);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodTab(String value, String label, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.deepPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String value, String label, String emoji, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepPurple.withOpacity(0.1)
              : (isDark ? const Color(0xFF1F1F1F) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.deepPurple
                : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.deepPurple
                    : (isDark ? Colors.white : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard(LeaderboardEntry entry, int rank, bool isDark, LeaderboardType type) {
    final stat = type == LeaderboardType.goals ? entry.goals : entry.assists;
    final secondaryStat = type == LeaderboardType.goals ? entry.assists : entry.goals;
    final secondaryLabel = type == LeaderboardType.goals ? tr(context, 'assist') : tr(context, 'goal');
    final isTopThree = rank <= 3;

    Color? getMedalColor() {
      switch (rank) {
        case 1:
          return Colors.amber;
        case 2:
          return Colors.grey[400];
        case 3:
          return Colors.brown[400];
        default:
          return null;
      }
    }

    return GestureDetector(
      onTap: () {
        if (entry.oderId.isNotEmpty) {
          HapticFeedback.lightImpact();
          final currentUserId = Provider.of<UserProvider>(context, listen: false).userId;
          
          if (entry.oderId == currentUserId) {
            // Navigate to own profile via RootPage
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const RootPage(initialIndex: 3)),
              (route) => false,
            );
          } else {
            // Navigate to other player's profile
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlayerProfilePage(
                  oderId: entry.oderId,
                  playerName: entry.playerName,
                ),
              ),
            );
          }
        }
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isTopThree
            ? Border.all(color: getMedalColor()!.withOpacity(0.5), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: isTopThree
                ? getMedalColor()!.withOpacity(0.15)
                : Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: isTopThree ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isTopThree
                  ? getMedalColor()!.withOpacity(0.15)
                  : (isDark ? Colors.grey[800] : Colors.grey[100]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: isTopThree
                  ? Icon(
                      Icons.emoji_events,
                      color: getMedalColor(),
                      size: 18,
                    )
                  : Text(
                      rank.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 12),

          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isTopThree
                  ? Border.all(color: getMedalColor()!, width: 2)
                  : null,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isTopThree ? 10 : 12),
              child: entry.photoUrl != null && entry.photoUrl!.isNotEmpty
                  ? Image.network(
                      entry.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultAvatar(entry.playerName, isDark);
                      },
                    )
                  : _buildDefaultAvatar(entry.playerName, isDark),
            ),
          ),

          const SizedBox(width: 12),

          // Name & subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.playerName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$secondaryStat $secondaryLabel',
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Stat
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isTopThree
                  ? getMedalColor()!.withOpacity(0.15)
                  : Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              stat.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isTopThree ? getMedalColor() : Colors.deepPurple,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String name, bool isDark) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: isDark ? Colors.grey[700] : Colors.grey[300],
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }
}