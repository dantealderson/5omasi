import 'package:flutter/material.dart';
import 'package:khomasi/theme/app_colors.dart';
import 'package:khomasi/theme/app_text.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khomasi/models/user_model.dart';
import 'package:khomasi/l10n/app_localizations.dart';
import 'package:khomasi/services/player_rating_service.dart';

class PlayerProfilePage extends StatelessWidget {
  final String oderId;
  final String? playerName; // Optional - shown while loading

  const PlayerProfilePage({
    super.key,
    required this.oderId,
    this.playerName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(oderId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState(context, isDark);
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildErrorState(context, isDark);
          }

          final user = UserModel.fromFirestore(snapshot.data!);
          return _buildProfileContent(context, user, isDark);
        },
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppColors.brand,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            title: Text(playerName ?? tr(context, 'loading')),
            centerTitle: true,
          ),
        ),
        const SliverFillRemaining(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.brand,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(tr(context, 'error')),
          centerTitle: true,
        ),
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_off,
                  size: 80,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  tr(context, 'playerNotFound'),
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileContent(BuildContext context, UserModel user, bool isDark) {
    final playerStats = user.playerStats;
    final totalGoals = playerStats?.totalGoals ?? 0;
    final totalAssists = playerStats?.totalAssists ?? 0;
    final totalMatches = playerStats?.totalMatches ?? 0;
    final wins = playerStats?.wins ?? 0;
    final losses = playerStats?.losses ?? 0;
    final draws = playerStats?.draws ?? 0;
    final winRate = totalMatches > 0 ? (wins / totalMatches * 100) : 0.0;
    final yellowCards = playerStats?.yellowCards ?? 0;
    final redCards = playerStats?.redCards ?? 0;
    final mvpAwards = playerStats?.mvpAwards ?? 0;
    final hatTricks = playerStats?.hatTricks ?? 0;

    final averageRating = playerStats?.averageRating ?? 0.0;
    final totalRatings = playerStats?.totalRatings ?? 0;

    final memberSince = user.createdAt;
    final memberSinceText = '${tr(context, 'memberSince')} ${memberSince.year}';

    return CustomScrollView(
      slivers: [
        // App Bar with profile picture
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          backgroundColor: AppColors.brand,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Gradient background
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.brand,
                        AppColors.brandPressed,
                      ],
                    ),
                  ),
                ),
                // Profile content
                SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Profile picture
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.brandTint,
                          backgroundImage: user.profileImageUrl != null
                              ? NetworkImage(user.profileImageUrl!)
                              : null,
                          child: user.profileImageUrl == null
                              ? Text(
                                  _getInitials(user.name),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.brand,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Name
                      Text(
                        user.name,
                        style: AppText.kufi(
                            size: 26, weight: 700, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // At-a-glance standing — read the player instantly.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (totalRatings > 0) ...[
                            _headerChip(Icons.star_rounded,
                                averageRating.toStringAsFixed(1), AppColors.gold),
                            const SizedBox(width: 8),
                          ],
                          _headerChip(Icons.sports_soccer, '$totalMatches',
                              Colors.white),
                          const SizedBox(width: 8),
                          _headerChip(Icons.emoji_events,
                              '${winRate.toStringAsFixed(0)}%', Colors.white),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        memberSinceText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Stats content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Player Rating
                if (totalRatings > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.dSurface : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Stars
                        Row(
                          children: List.generate(5, (index) {
                            final starValue = index + 1;
                            if (averageRating >= starValue) {
                              return const Icon(Icons.star_rounded, color: AppColors.gold, size: 28);
                            } else if (averageRating >= starValue - 0.5) {
                              return const Icon(Icons.star_half_rounded, color: AppColors.gold, size: 28);
                            } else {
                              return Icon(Icons.star_outline_rounded,
                                  color: isDark ? Colors.grey[600] : Colors.grey[400], size: 28);
                            }
                          }),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              averageRating.toStringAsFixed(1),
                              style: AppText.mono(
                                  size: 22,
                                  weight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87),
                            ),
                            Text(
                              '($totalRatings ${tr(context, 'ratingsCount')})',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Player Traits
                FutureBuilder<Map<String, int>>(
                  future: PlayerRatingService.getPlayerTraits(oderId),
                  builder: (context, traitSnapshot) {
                    if (!traitSnapshot.hasData || traitSnapshot.data!.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final traits = traitSnapshot.data!;
                    return Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.dSurface : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr(context, 'topTraits'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: traits.entries.take(6).map((entry) {
                                  final isPositive = [
                                    'fast', 'goodPasser', 'strongShot',
                                    'teamPlayer', 'goodDefense', 'skilled',
                                  ].contains(entry.key);
                                  final color = isPositive ? Colors.green : Colors.red;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: color.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          tr(context, entry.key),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: color,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${entry.value}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: color.withOpacity(0.7),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),

                // Main stats card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.dSurface : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        context: context,
                        icon: Icons.sports_soccer,
                        value: totalGoals.toString(),
                        label: tr(context, 'goals'),
                        color: Colors.green,
                        isDark: isDark,
                      ),
                      Container(height: 50, width: 1, color: Theme.of(context).dividerColor),
                      _buildStatItem(
                        context: context,
                        icon: Icons.sports,
                        value: totalAssists.toString(),
                        label: tr(context, 'assists'),
                        color: Colors.blue,
                        isDark: isDark,
                      ),
                      Container(height: 50, width: 1, color: Theme.of(context).dividerColor),
                      _buildStatItem(
                        context: context,
                        icon: Icons.calendar_today,
                        value: totalMatches.toString(),
                        label: tr(context, 'matches'),
                        color: Colors.orange,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Win rate card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.brand, AppColors.brandPressed],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brand.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(context, 'winRate'),
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${winRate.toStringAsFixed(1)}%',
                            style: AppText.mono(
                                size: 30,
                                color: Colors.white,
                                weight: FontWeight.w700),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emoji_events, color: Colors.white, size: 32),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Match results
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.dSurface : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, 'matchResults'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildResultItem(
                              label: tr(context, 'wonMatch'),
                              value: wins,
                              color: Colors.green,
                              isDark: isDark,
                            ),
                          ),
                          Expanded(
                            child: _buildResultItem(
                              label: tr(context, 'drawMatch'),
                              value: draws,
                              color: Colors.orange,
                              isDark: isDark,
                            ),
                          ),
                          Expanded(
                            child: _buildResultItem(
                              label: tr(context, 'lostMatch'),
                              value: losses,
                              color: Colors.red,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Cards & Awards - Using flexible layout to prevent overflow
                Row(
                  children: [
                    // Cards box
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.dSurface : Colors.white,
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildCardIcon(Colors.yellow.shade700, yellowCards),
                                const SizedBox(width: 8),
                                _buildCardIcon(Colors.red, redCards),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr(context, 'cards'),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // MVP box
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.dSurface : Colors.white,
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: AppColors.gold, size: 24),
                                const SizedBox(width: 4),
                                Text(
                                  '$mvpAwards',
                                  style: AppText.mono(
                                      size: 18,
                                      weight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr(context, 'playerOfWeek'),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Hat-trick box
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.dSurface : Colors.white,
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sports_score, color: Colors.green, size: 24),
                                const SizedBox(width: 4),
                                Text(
                                  '$hatTricks',
                                  style: AppText.mono(
                                      size: 18,
                                      weight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr(context, 'hatTrick'),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerChip(IconData icon, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 5),
          Text(
            value,
            style: AppText.mono(
                size: 13, color: Colors.white, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppText.mono(
              size: 20,
              weight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87),
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

  Widget _buildResultItem({
    required String label,
    required int value,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$value',
            style: AppText.mono(size: 24, color: color, weight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
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

  Widget _buildCardIcon(Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}';
    }
    return name[0];
  }
}
