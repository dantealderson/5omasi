import 'package:flutter/material.dart';
import 'package:khomasi/theme/app_colors.dart';
import 'package:khomasi/theme/app_text.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khomasi/providers/auth_provider.dart';
import 'package:khomasi/providers/user_provider.dart';
import 'package:khomasi/pages/login_page.dart';
import 'package:khomasi/pages/signup_page.dart';
import 'package:khomasi/pages/settings_page.dart';
import 'package:khomasi/pages/edit_profile_page.dart';
import 'package:khomasi/pages/match_history_page.dart';
import 'package:khomasi/pages/contact_us_page.dart';
import 'package:khomasi/pages/faq_page.dart';
import 'package:khomasi/l10n/app_localizations.dart';
import 'package:khomasi/services/player_rating_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final double coverHeight = 250;
  final double profileHeight = 120;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _logout() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    userProvider.clear();
    await authProvider.signOut();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              ),
            );
          },
        ),
        (route) => false,
      );
    }
  }

  // TEST FUNCTION - Add 1 token for testing
  Future<void> _addTestToken(UserProvider userProvider) async {
    if (userProvider.userId.isEmpty) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userProvider.userId)
          .update({
        'matchTokens': FieldValue.increment(1),
        'totalTokensPurchased': FieldValue.increment(1),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, 'testTokenAdded')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, 'tokenAddFailed')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Widget _buildGuestProfile(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.brand.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline,
                  size: 80,
                  color: AppColors.brand.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 32),

              // Welcome text
              Text(
                tr(context, 'guestWelcome'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                tr(context, 'guestProfileMessage'),
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Create Account button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpPage()),
                    );
                  },
                  icon: const Icon(Icons.person_add, size: 22),
                  label: Text(
                    tr(context, 'guestCreateAccount'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Login row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tr(context, 'guestLoginPrompt'),
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: Text(
                      tr(context, 'login'),
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Guest mode — show login/signup prompt
    if (userProvider.isGuest) {
      return _buildGuestProfile(context, isDark);
    }

    // Get user data from provider using convenience getters
    final userName = userProvider.userName.isNotEmpty ? userProvider.userName : tr(context, 'user');
    final userPhotoUrl = userProvider.userPhotoUrl;
    final playerStats = userProvider.playerStats;
    final user = userProvider.user;
    final matchTokens = userProvider.matchTokens;

    // Calculate stats
    final totalGoals = playerStats?.totalGoals ?? 0;
    final totalAssists = playerStats?.totalAssists ?? 0;
    final totalMatches = playerStats?.totalMatches ?? 0;
    final wins = playerStats?.wins ?? 0;
    final winRate = totalMatches > 0 ? (wins / totalMatches * 100) : 0.0;
    final averageRating = playerStats?.averageRating ?? 0.0;
    final totalRatings = playerStats?.totalRatings ?? 0;

    // Format join date
    final joinDate = user?.createdAt;
    final memberSince = joinDate != null
        ? '${tr(context, 'memberSince')} ${joinDate.year}'
        : tr(context, 'newMember');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: userProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : RefreshIndicator(
              onRefresh: () => userProvider.refresh(),
              color: AppColors.brand,
              child: CustomScrollView(
              slivers: [
                // Custom App Bar with Cover Image
                SliverAppBar(
                  expandedHeight: coverHeight,
                  floating: false,
                  pinned: true,
                  backgroundColor: AppColors.brand,
                  flexibleSpace: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final bool isCollapsed = constraints.biggest.height <=
                          MediaQuery.of(context).padding.top +
                              kToolbarHeight +
                              profileHeight / 2;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Background image
                          FlexibleSpaceBar(
                            background: ClipRect(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    'https://ichef.bbci.co.uk/images/ic/1008x567/p09rht22.jpg',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                      color: AppColors.brand,
                                      child: const Icon(
                                        Icons.sports_soccer,
                                        size: 100,
                                        color: Colors.white24,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.4),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Profile picture
                          Positioned(
                            bottom: -profileHeight / 2,
                            left: MediaQuery.of(context).size.width / 2 -
                                profileHeight / 2,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isCollapsed ? 0.0 : 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).cardColor,
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: profileHeight / 2,
                                  backgroundColor: AppColors.brandTint,
                                  backgroundImage: userPhotoUrl != null
                                      ? NetworkImage(userPhotoUrl)
                                      : null,
                                  child: userPhotoUrl == null
                                      ? Text(
                                          _getInitials(userName),
                                          style: const TextStyle(
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.brand,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Profile Content
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        // Space for overlapping profile picture
                        SizedBox(height: profileHeight / 2 + 16),

                        // Name and member since
                        Text(
                          userName,
                          style: AppText.kufi(
                              size: 26, weight: 700, color: context.palette.textHi),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          memberSince,
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Stats Section
                        Column(
                          children: [
                            // Primary Stats Cards
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withOpacity(isDark ? 0.3 : 0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItem(
                                    icon: Icons.sports_soccer,
                                    value: totalGoals.toString(),
                                    label: tr(context, 'goals'),
                                    color: Colors.green,
                                    isDark: isDark,
                                  ),
                                  Container(
                                    height: 50,
                                    width: 1,
                                    color: Theme.of(context).dividerColor,
                                  ),
                                  _buildStatItem(
                                    icon: Icons.sports,
                                    value: totalAssists.toString(),
                                    label: tr(context, 'assists'),
                                    color: Colors.blue,
                                    isDark: isDark,
                                  ),
                                  Container(
                                    height: 50,
                                    width: 1,
                                    color: Theme.of(context).dividerColor,
                                  ),
                                  _buildStatItem(
                                    icon: Icons.calendar_today,
                                    value: totalMatches.toString(),
                                    label: tr(context, 'matches'),
                                    color: Colors.orange,
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                            ),

                            // Player Rating Card
                            if (totalRatings > 0) ...[
                              const SizedBox(height: 16),
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 20),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
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
                                    Row(
                                      children: List.generate(5, (index) {
                                        final starValue = index + 1;
                                        if (averageRating >= starValue) {
                                          return const Icon(Icons.star_rounded, color: Colors.amber, size: 28);
                                        } else if (averageRating >= starValue - 0.5) {
                                          return const Icon(Icons.star_half_rounded, color: Colors.amber, size: 28);
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
                                              color: context.palette.textHi),
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
                            ],

                            // Player Traits
                            FutureBuilder<Map<String, int>>(
                              future: PlayerRatingService.getPlayerTraits(userProvider.userId),
                              builder: (context, traitSnapshot) {
                                if (!traitSnapshot.hasData || traitSnapshot.data!.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final traits = traitSnapshot.data!;
                                return Column(
                                  children: [
                                    const SizedBox(height: 16),
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 20),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
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
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 20),

                            // Win Rate Card
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.brand,
                                    AppColors.brandPressed,
                                  ],
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
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${winRate.toStringAsFixed(1)}%',
                                        style: AppText.mono(
                                            size: 30,
                                            weight: FontWeight.w700,
                                            color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.emoji_events,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Token Balance Card
                            GestureDetector(
                              onTap: () => _addTestToken(userProvider),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 20),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber.shade600,
                                      Colors.orange.shade700,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.3),
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
                                          tr(context, 'tokenBalance'),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '$matchTokens',
                                              style: AppText.mono(
                                                  size: 30,
                                                  weight: FontWeight.w700,
                                                  color: Colors.white),
                                            ),
                                            const SizedBox(width: 8),
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Text(
                                                tr(context, 'token'),
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.add, color: Colors.white, size: 20),
                                          const SizedBox(width: 4),
                                          Text(
                                            tr(context, 'charge'),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Recent Achievements
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr(context, 'recentAchievements'),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _buildAchievementBadge(
                                          icon: Icons.local_fire_department,
                                          title: tr(context, 'winningStreak'),
                                          subtitle: '$wins ${tr(context, 'win')}',
                                          color: Colors.red,
                                          isDark: isDark,
                                        ),
                                        _buildAchievementBadge(
                                          icon: Icons.star,
                                          title: tr(context, 'playerOfWeek'),
                                          subtitle:
                                              '${playerStats?.mvpAwards ?? 0} ${tr(context, 'times')}',
                                          color: Colors.amber,
                                          isDark: isDark,
                                        ),
                                        _buildAchievementBadge(
                                          icon: Icons.sports_score,
                                          title: tr(context, 'hatTrick'),
                                          subtitle: '${playerStats?.hatTricks ?? 0} ${tr(context, 'times')}',
                                          color: Colors.green,
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 30),

                            // Menu Options
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(30),
                                  topRight: Radius.circular(30),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withOpacity(isDark ? 0.3 : 0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, -5),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(height: 20),

                                  // Settings
                                  _buildMenuItem(
                                    icon: Icons.settings_outlined,
                                    text: tr(context, 'settings'),
                                    isDark: isDark,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const SettingsPage(),
                                        ),
                                      );
                                    },
                                  ),

                                  // Edit Profile
                                  _buildMenuItem(
                                    icon: Icons.edit_outlined,
                                    text: tr(context, 'editProfile'),
                                    isDark: isDark,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const EditProfilePage(),
                                        ),
                                      );
                                    },
                                  ),

                                  // Match History
                                  _buildMenuItem(
                                    icon: Icons.history,
                                    text: tr(context, 'matchHistory'),
                                    isDark: isDark,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const MatchHistoryPage(),
                                        ),
                                      );
                                    },
                                  ),

                                  // Contact Us
                                  _buildMenuItem(
                                    icon: Icons.support_agent_outlined,
                                    text: tr(context, 'contactUs'),
                                    isDark: isDark,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ContactUsPage(),
                                        ),
                                      );
                                    },
                                  ),

                                  // FAQ
                                  _buildMenuItem(
                                    icon: Icons.help_outline_rounded,
                                    text: tr(context, 'faq'),
                                    isDark: isDark,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const FAQPage(),
                                        ),
                                      );
                                    },
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    child: Divider(
                                      color:
                                          isDark ? Colors.grey[700] : Colors.grey[300],
                                    ),
                                  ),

                                  // Logout
                                  _buildMenuItem(
                                    icon: Icons.logout_rounded,
                                    text: tr(context, 'logout'),
                                    textColor: Colors.red,
                                    isDark: isDark,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      _showLogoutDialog();
                                    },
                                  ),

                                  const SizedBox(height: 30),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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

  void _showLogoutDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.dSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr(context, 'logout'),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          tr(context, 'logoutConfirm'),
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'cancel'), style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(tr(context, 'exit'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
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
              size: 20, weight: FontWeight.w700, color: context.palette.textHi),
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

  Widget _buildAchievementBadge({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String text,
    Color? textColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: textColor ?? (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor ?? (isDark ? Colors.white70 : Colors.grey[800]),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}