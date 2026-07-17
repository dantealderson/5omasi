import 'package:flutter/material.dart';
import 'package:khomasi/theme/app_colors.dart';
import 'package:khomasi/theme/app_text.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LeaderboardProvider>(context, listen: false).init();
    });
  }

  // Medal metals for the top three.
  static const Color _silver = Color(0xFFB8C0C2);
  static const Color _bronze = Color(0xFFB87333);

  Color _medalColor(AppPalette p, int rank) {
    switch (rank) {
      case 1:
        return p.gold;
      case 2:
        return _silver;
      case 3:
        return _bronze;
      default:
        return p.textMid;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr(context, 'leaderboard'),
                    style: AppText.kufi(size: 28, weight: 700, color: p.textHi),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.gold.withOpacity(0.4)),
                    ),
                    child: Icon(Icons.emoji_events, color: p.gold, size: 24),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Period filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Consumer<LeaderboardProvider>(
                builder: (context, provider, _) {
                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: p.surfaceRaised,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.line),
                    ),
                    child: Row(
                      children: [
                        _buildPeriodTab("week", tr(context, 'week'),
                            provider.selectedPeriod == LeaderboardPeriod.week,
                            () => provider.setPeriodFromString("week")),
                        _buildPeriodTab("month", tr(context, 'month'),
                            provider.selectedPeriod == LeaderboardPeriod.month,
                            () => provider.setPeriodFromString("month")),
                        _buildPeriodTab("year", tr(context, 'year'),
                            provider.selectedPeriod == LeaderboardPeriod.year,
                            () => provider.setPeriodFromString("year")),
                        _buildPeriodTab("all", tr(context, 'all'),
                            provider.selectedPeriod == LeaderboardPeriod.all,
                            () => provider.setPeriodFromString("all")),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Type toggle
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

            Expanded(
              child: Consumer<LeaderboardProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return Center(
                      child: CircularProgressIndicator(color: p.emerald),
                    );
                  }

                  if (provider.errorMessage != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: p.textLow),
                          const SizedBox(height: 16),
                          Text(provider.errorMessage!,
                              style: TextStyle(color: p.textMid, fontSize: 16)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => provider.refresh(),
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
                          Icon(Icons.leaderboard_outlined,
                              size: 64, color: p.textLow),
                          const SizedBox(height: 16),
                          Text(tr(context, 'noData'),
                              style: TextStyle(
                                  color: p.textMid,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(tr(context, 'startPlayingToAppear'),
                              style: TextStyle(color: p.textLow, fontSize: 14)),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => provider.refresh(),
                    color: p.emerald,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: provider.leaderboard.length,
                      itemBuilder: (context, index) {
                        final entry = provider.leaderboard[index];
                        return _buildPlayerCard(
                            entry, index + 1, provider.selectedType);
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

  Widget _buildPeriodTab(
      String value, String label, bool isSelected, VoidCallback onTap) {
    final p = context.palette;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? p.emerald : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? p.onEmerald : p.textMid,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String value, String label, String emoji,
      bool isSelected, VoidCallback onTap) {
    final p = context.palette;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? p.emeraldSoft : p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? p.emerald : p.line,
            width: isSelected ? 1.5 : 1,
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
                color: isSelected ? p.emerald : p.textHi,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard(
      LeaderboardEntry entry, int rank, LeaderboardType type) {
    final p = context.palette;
    final stat = type == LeaderboardType.goals ? entry.goals : entry.assists;
    final secondaryStat =
        type == LeaderboardType.goals ? entry.assists : entry.goals;
    final secondaryLabel = type == LeaderboardType.goals
        ? tr(context, 'assist')
        : tr(context, 'goal');
    final isTopThree = rank <= 3;
    final medal = _medalColor(p, rank);

    return GestureDetector(
      onTap: () {
        if (entry.oderId.isNotEmpty) {
          HapticFeedback.lightImpact();
          final currentUserId =
              Provider.of<UserProvider>(context, listen: false).userId;

          if (entry.oderId == currentUserId) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                  builder: (context) => const RootPage(initialIndex: 2)),
              (route) => false,
            );
          } else {
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
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isTopThree ? medal.withOpacity(0.55) : p.line,
            width: isTopThree ? 1.4 : 1,
          ),
          boxShadow: [
            if (isTopThree)
              BoxShadow(
                color: medal.withOpacity(0.14),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            // Rank / medal
            SizedBox(
              width: 34,
              child: Center(
                child: isTopThree
                    ? Icon(Icons.emoji_events, color: medal, size: 22)
                    : Text(
                        rank.toString(),
                        style: AppText.mono(
                            size: 15,
                            color: p.textLow,
                            weight: FontWeight.w600),
                      ),
              ),
            ),

            const SizedBox(width: 10),

            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border:
                    isTopThree ? Border.all(color: medal, width: 2) : null,
                color: p.surfaceRaised,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isTopThree ? 10 : 12),
                child: entry.photoUrl != null && entry.photoUrl!.isNotEmpty
                    ? Image.network(
                        entry.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildDefaultAvatar(entry.playerName),
                      )
                    : _buildDefaultAvatar(entry.playerName),
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
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: p.textHi),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text('$secondaryStat $secondaryLabel',
                      style: TextStyle(color: p.textLow, fontSize: 12)),
                ],
              ),
            ),

            // Stat — headline number in mono.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isTopThree ? medal.withOpacity(0.14) : p.emeraldSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                stat.toString(),
                style: AppText.mono(
                  size: 18,
                  color: isTopThree ? medal : p.emerald,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String name) {
    final p = context.palette;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: p.surfaceRaised,
      child: Center(
        child: Text(
          initial,
          style: AppText.kufi(size: 20, weight: 700, color: p.textMid),
        ),
      ),
    );
  }
}
