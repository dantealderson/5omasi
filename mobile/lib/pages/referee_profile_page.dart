import 'package:flutter/material.dart';
import 'package:khomasi/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:khomasi/providers/auth_provider.dart';
import 'package:khomasi/providers/user_provider.dart';
import 'package:khomasi/pages/settings_page.dart';
import 'package:khomasi/pages/login_page.dart';
import 'package:khomasi/l10n/app_localizations.dart';

class RefereeProfilePage extends StatefulWidget {
  const RefereeProfilePage({super.key});

  @override
  State<RefereeProfilePage> createState() => _RefereeProfilePageState();
}

class _RefereeProfilePageState extends State<RefereeProfilePage> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M ${tr(context, 'currency')}';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K ${tr(context, 'currency')}';
    }
    return '${amount.toStringAsFixed(0)} ${tr(context, 'currency')}';
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    
    final userProvider = Provider.of<UserProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Get referee data from provider
    final refereeName = userProvider.userName.isNotEmpty ? userProvider.userName : tr(context, 'referee');
    final refereePhotoUrl = userProvider.userPhotoUrl;
    final refereeStats = userProvider.refereeStats;
    final refereeProfile = userProvider.refereeProfile;
    final user = userProvider.user;
    
    // Stats
    final totalMatches = refereeStats?.totalMatchesRefereed ?? 0;
    final thisMonthMatches = refereeStats?.thisMonthMatches ?? 0;
    final totalGoals = refereeStats?.totalGoalsRecorded ?? 0;
    final totalCards = refereeStats?.totalCardsGiven ?? 0;
    final yellowCards = refereeStats?.yellowCardsGiven ?? 0;
    final redCards = refereeStats?.redCardsGiven ?? 0;
    final rating = refereeStats?.averageRating ?? 0.0;
    final totalRatings = refereeStats?.totalRatings ?? 0;
    final earnings = refereeStats?.totalEarnings ?? 0.0;
    
    // Profile
    final experience = refereeProfile?.experienceYears ?? 0;
    final pricePerMatch = refereeProfile?.pricePerMatch ?? 25000.0;
    final certifications = refereeProfile?.certifications ?? [];
    final preferredMatchTypes = refereeProfile?.preferredMatchTypes ?? ['5v5'];
    
    // Member since
    final memberSince = user?.createdAt.year ?? DateTime.now().year;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar with Profile Header
          SliverAppBar(
            expandedHeight: 280 + topPadding,
            pinned: true,
            backgroundColor: isDark ? AppColors.dSurface : AppColors.brand,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.settings, color: Colors.white, size: 20),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                      ? [AppColors.dRaised, AppColors.dSurface]
                      : [AppColors.brand, AppColors.brandPressed],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Background pattern
                    Positioned(
                      right: -80,
                      top: -80,
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    
                    // Profile content
                    Positioned(
                      top: topPadding + 50,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Profile picture
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.brandTint,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: refereePhotoUrl != null
                                  ? Image.network(
                                      refereePhotoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(
                                          _getInitials(refereeName),
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.brand,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        _getInitials(refereeName),
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.brand,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Name
                          Text(
                            refereeName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          
                          // Role badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.gavel, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  tr(context, 'certifiedReferee'),
                                  style: TextStyle(
                                    color: Colors.amber.shade100,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Rating
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ...List.generate(5, (index) {
                                return Icon(
                                  index < rating.floor() 
                                      ? Icons.star 
                                      : (index < rating ? Icons.star_half : Icons.star_border),
                                  color: Colors.amber,
                                  size: 20,
                                );
                              }),
                              const SizedBox(width: 8),
                              Text(
                                '${rating.toStringAsFixed(1)} ($totalRatings)',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Stats Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Main stats row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.sports_score,
                          label: tr(context, 'matches'),
                          value: _formatNumber(totalMatches),
                          subValue: '+$thisMonthMatches ${tr(context, 'thisMonth')}',
                          color: Colors.blue,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.sports_soccer,
                          label: tr(context, 'totalGoalsRecorded'),
                          value: _formatNumber(totalGoals),
                          subValue: '${(totalMatches > 0 ? totalGoals / totalMatches : 0).toStringAsFixed(1)} ${tr(context, 'avgPerMatch')}',
                          color: Colors.green,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.style,
                          label: tr(context, 'cards'),
                          value: _formatNumber(totalCards),
                          subValue: '🟨 $yellowCards  🟥 $redCards',
                          color: Colors.orange,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.account_balance_wallet,
                          label: tr(context, 'earnings'),
                          value: _formatCurrency(earnings),
                          subValue: '${_formatCurrency(pricePerMatch)}/${tr(context, 'match')}',
                          color: AppColors.brand,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Experience & Info Section
                  Container(
                    padding: const EdgeInsets.all(16),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(context, 'refereeInfo'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          icon: Icons.calendar_today,
                          label: tr(context, 'experienceYears'),
                          value: '$experience ${tr(context, 'yearsUnit')}',
                          isDark: isDark,
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          icon: Icons.date_range,
                          label: tr(context, 'memberSince'),
                          value: '$memberSince',
                          isDark: isDark,
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          icon: Icons.sports,
                          label: tr(context, 'preferredMatchType'),
                          value: preferredMatchTypes.join(', '),
                          isDark: isDark,
                        ),
                        if (certifications.isNotEmpty) ...[
                          const Divider(height: 24),
                          _buildInfoRow(
                            icon: Icons.verified,
                            label: tr(context, 'certifications'),
                            value: certifications.join(', '),
                            isDark: isDark,
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showLogoutDialog(authProvider, userProvider),
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: Text(
                        tr(context, 'logout'),
                        style: const TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
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
  
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String subValue,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subValue,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.brand.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.brand, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog(AuthProvider authProvider, UserProvider userProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout, color: Colors.red),
            const SizedBox(width: 8),
            Text(tr(context, 'logout')),
          ],
        ),
        content: Text(tr(context, 'logoutConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              userProvider.clear();
              await authProvider.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr(context, 'logout'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}