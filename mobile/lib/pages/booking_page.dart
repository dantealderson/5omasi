import 'package:flutter/material.dart';
import 'package:khomasi/theme/app_colors.dart';
import 'package:khomasi/theme/app_text.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:khomasi/providers/match_provider.dart';
import 'package:khomasi/providers/user_provider.dart';
import 'package:khomasi/models/match_model.dart';
import 'package:khomasi/pages/player_profile_page.dart';
import 'package:khomasi/pages/root_page.dart';
import 'package:khomasi/pages/match_chat_page.dart';
import 'package:khomasi/l10n/app_localizations.dart';
import 'package:khomasi/providers/locale_provider.dart';
import 'package:khomasi/services/waiting_list_service.dart';
import 'package:khomasi/services/team_balance_service.dart';
import 'package:khomasi/pages/login_page.dart';
import 'package:khomasi/pages/signup_page.dart';

class BookingPage extends StatefulWidget {
  final MatchModel match;
  
  const BookingPage({super.key, required this.match});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  bool _isBooking = false;
  int _selectedPlayers = 1;
  String _selectedTeam = 'A';
  MatchModel? _currentMatch;
  bool _isOnWaitingList = false;
  bool _isJoiningWaitingList = false;
  
  @override
  void initState() {
    super.initState();
    _currentMatch = widget.match;
    _selectDefaultTeam();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _animationController.forward();
    _refreshMatchData();
    _checkWaitingListStatus();
  }

  /// Select the first team that has available spots.
  /// Defaults to 'A', but picks 'B' if 'A' is full.
  void _selectDefaultTeam() {
    final match = _currentMatch ?? widget.match;
    final maxPerTeam = match.maxPlayers ~/ 2;
    if (match.teamAPlayers.length >= maxPerTeam && match.teamBPlayers.length < maxPerTeam) {
      _selectedTeam = 'B';
    } else {
      _selectedTeam = 'A';
    }
  }

  void _showGuestLoginDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.dSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.lock_outline, size: 48, color: AppColors.brand.withOpacity(0.7)),
        title: Text(
          tr(context, 'guestLoginRequired'),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          tr(context, 'guestBookingMessage'),
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
                    foregroundColor: AppColors.brand,
                    side: const BorderSide(color: AppColors.brand),
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
                    backgroundColor: AppColors.brand,
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

  Future<void> _checkWaitingListStatus() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.isGuest) return;
    final onList = await WaitingListService.isOnWaitingList(
      matchId: widget.match.id,
      userId: userProvider.userId,
    );
    if (mounted) setState(() => _isOnWaitingList = onList);
  }

  Future<void> _handleJoinWaitingList() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.isGuest) {
      _showGuestLoginDialog();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);

    // Check if user has at least 1 token before joining waiting list
    if (userProvider.matchTokens < 1) {
      _showInsufficientTokensDialog(userProvider.matchTokens, 1);
      return;
    }

    setState(() => _isJoiningWaitingList = true);

    try {
      final success = await WaitingListService.joinWaitingList(
        matchId: _match.id,
        userId: userProvider.userId,
        userName: userProvider.userName,
        preferredTeam: _selectedTeam,
        playerCount: 1,
      );

      if (mounted) {
        setState(() {
          _isJoiningWaitingList = false;
          if (success) _isOnWaitingList = true;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(success ? tr(context, 'joinedWaitingList') : tr(context, 'error')),
            backgroundColor: success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 80, left: 16, right: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error joining waiting list: $e');
      if (mounted) {
        setState(() => _isJoiningWaitingList = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text(tr(context, 'error')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 80, left: 16, right: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _handleLeaveWaitingList() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final success = await WaitingListService.leaveWaitingList(
      matchId: _match.id,
      userId: userProvider.userId,
    );
    if (mounted && success) {
      setState(() => _isOnWaitingList = false);
    }
  }

  Future<void> _handleBalanceTeams() async {
    final messenger = ScaffoldMessenger.of(context);
    final successMsg = tr(context, 'teamsBalanced');
    final errorMsg = tr(context, 'error');

    final success = await TeamBalanceService.balanceTeams(_match.id);

    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(success ? successMsg : errorMsg),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      if (success) _refreshMatchData();
    }
  }
  
  Future<void> _refreshMatchData() async {
    final matchProvider = Provider.of<MatchProvider>(context, listen: false);
    final updatedMatch = matchProvider.availableMatches.firstWhere(
      (m) => m.id == widget.match.id,
      orElse: () => widget.match,
    );
    if (mounted) setState(() => _currentMatch = updatedMatch);
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  MatchModel get _match => _currentMatch ?? widget.match;
  int get _availableSpots => _match.spotsLeft;
  bool get _isFull => _match.isFull;
  
  bool _isUserBooked(String oderId) => _match.isUserBooked(oderId);
  
  int _getUserBookedSpots(String oderId) {
    return _match.allPlayers.where((p) => p.oderId == oderId || p.bookedByUserId == oderId).length;
  }
  
  String? _getUserTeam(String oderId) {
    final player = _match.allPlayers.firstWhere(
      (p) => p.oderId == oderId,
      orElse: () => MatchPlayer(oderId: '', playerName: '', playerNumber: 0, team: '', joinedAt: DateTime.now()),
    );
    return player.team.isNotEmpty ? player.team : null;
  }

  Future<void> _openMapsLocation(MatchModel match) async {
    String? url = match.googleMapsUrl;
    
    // If no Google Maps URL, try to create one from location coordinates
    if ((url == null || url.isEmpty) && match.location != null) {
      url = 'https://www.google.com/maps/search/?api=1&query=${match.location!.latitude},${match.location!.longitude}';
    }
    
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr(context, 'openInMaps')),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, 'location')),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
  
  String get _surfaceTypeText {
    switch (_match.surfaceType) {
      case SurfaceType.natural: return 'عشب طبيعي';
      case SurfaceType.artificial: return 'عشب صناعي';
      case SurfaceType.indoor: return 'ملعب داخلي';
    }
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final matchDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (matchDate == today) return 'اليوم';
    if (matchDate == tomorrow) return 'غداً';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    return trTime(context, dateTime);
  }

  void _shareMatch() {
    final match = _match;
    final date = '${match.dateTime.day}/${match.dateTime.month}/${match.dateTime.year}';
    final time = _formatTime(match.dateTime);
    final spots = match.maxPlayers - match.currentPlayers;
    final price = match.pricePerPlayer.toInt();
    final isArabic = Provider.of<LocaleProvider>(context, listen: false).isArabic;
    final link = 'https://khomasi-177f3.web.app/match/${match.id}';

    final text = isArabic
        ? '⚽ تعال العب معي خماسي!\n\n'
          '🏟️ ${match.stadiumName}\n'
          '📅 $date\n'
          '⏰ $time\n'
          '👥 $spots ${spots == 1 ? "مكان متبقي" : "أماكن متبقية"}\n'
          '💰 $price د.ع\n\n'
          '$link'
        : '⚽ Come play 5-a-side with me!\n\n'
          '🏟️ ${match.stadiumName}\n'
          '📅 $date\n'
          '⏰ $time\n'
          '👥 $spots spot${spots == 1 ? "" : "s"} left\n'
          '💰 ${price}IQD\n\n'
          '$link';

    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(isArabic ? 'تم نسخ رابط المباراة!' : 'Match link copied!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleBooking() async {
    HapticFeedback.mediumImpact();

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.isGuest) {
      _showGuestLoginDialog();
      return;
    }
    final matchProvider = Provider.of<MatchProvider>(context, listen: false);

    if (userProvider.userId.isEmpty) {
      _showErrorSnackbar(tr(context, 'bookingFailed'));
      return;
    }
    
    // Check if user has enough tokens
    final userTokens = userProvider.matchTokens;
    if (userTokens < _selectedPlayers) {
      _showInsufficientTokensDialog(userTokens, _selectedPlayers);
      return;
    }
    
    final existingTeam = _getUserTeam(userProvider.userId);
    final teamToUse = existingTeam ?? _selectedTeam;
    
    setState(() => _isBooking = true);
    
    final success = await matchProvider.joinMatchWithTokens(
      matchId: _match.id,
      oderId: userProvider.userId,
      playerName: userProvider.userName,
      team: teamToUse,
      count: _selectedPlayers,
    );
    
    if (!mounted) return;
    setState(() => _isBooking = false);
    
    if (success) {
      // Refresh user data to update token balance
      userProvider.refreshUserData();
      await _refreshMatchData();
      _showBookingSuccessDialog();
    } else {
      _showErrorSnackbar(matchProvider.errorMessage ?? tr(context, 'bookingFailed'));
    }
  }

  void _showInsufficientTokensDialog(int current, int needed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.dSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.token, color: Colors.orange, size: 32),
        ),
        title: Text(
          tr(context, 'notEnoughTokens'),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${tr(context, 'costTokens')} $needed ${tr(context, 'tokensUnit')}\n${tr(context, 'costTokens')}: $current ${tr(context, 'tokensUnit')}',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brand.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, color: AppColors.brand, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    tr(context, 'notEnoughTokens'),
                    style: TextStyle(color: AppColors.brandPressed, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr(context, 'cancel'), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
              ),
            ),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Navigate to buy tokens page
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tr(context, 'notEnoughTokens')),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(tr(context, 'tokensUnit'), style: const TextStyle(color: Colors.white)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  void _handleCancelBooking() async {
    // Check if within 2 hours of match start - lockout cancellation
    final now = DateTime.now();
    final matchTime = _match.dateTime;
    final hoursUntilMatch = matchTime.difference(now).inHours;
    final minutesUntilMatch = matchTime.difference(now).inMinutes;
    
    if (minutesUntilMatch <= 120 && minutesUntilMatch > 0) {
      // Within 2 hours - can't cancel
      _showLockoutDialog(hoursUntilMatch, minutesUntilMatch);
      return;
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.dSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr(context, 'cancelBooking'), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        content: Text(tr(context, 'cancelBooking'), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]), textAlign: TextAlign.center),
        actions: [
          Row(children: [
            Expanded(child: TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr(context, 'cancel'), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])))),
            Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text(tr(context, 'cancelBooking'), style: const TextStyle(color: Colors.white)))),
          ]),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    HapticFeedback.mediumImpact();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final matchProvider = Provider.of<MatchProvider>(context, listen: false);
    
    setState(() => _isBooking = true);
    final success = await matchProvider.leaveMatch(matchId: _match.id, oderId: userProvider.userId);
    if (!mounted) return;
    setState(() => _isBooking = false);
    
    if (success) {
      await _refreshMatchData();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'cancelSuccess')), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    } else {
      _showErrorSnackbar(matchProvider.errorMessage ?? tr(context, 'cancelFailed'));
    }
  }

  void _showLockoutDialog(int hours, int minutes) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.dSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_clock, color: Colors.orange, size: 32),
        ),
        title: Text(
          tr(context, 'cancelFailed'),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '${tr(context, 'cancelFailed')}\n\n${hours > 0 ? "$hours " : ""}${minutes % 60} ${tr(context, 'minutesSuffix')}',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(tr(context, 'confirm'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }
  
  void _showBookingSuccessDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.dSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.check_circle, color: Colors.green, size: 48)),
            const SizedBox(height: 16),
            Text(tr(context, 'bookingSuccess'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text(_selectedPlayers > 1 ? '${tr(context, 'bookingSuccess')} $_selectedPlayers' : tr(context, 'bookingSuccess'), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                _buildSummaryRow(tr(context, 'stadium'), widget.match.stadiumName),
                const SizedBox(height: 8),
                _buildSummaryRow(tr(context, 'dateAndTime'), _formatDate(widget.match.dateTime)),
                const SizedBox(height: 8),
                _buildSummaryRow(tr(context, 'dateAndTime'), _formatTime(widget.match.dateTime)),
                const SizedBox(height: 8),
                _buildSummaryRow(tr(context, 'teams'), _selectedTeam == 'A' ? widget.match.teamAName : widget.match.teamBName),
                if (_selectedPlayers > 1) ...[const SizedBox(height: 8), _buildSummaryRow(tr(context, 'numberOfPlayers'), '$_selectedPlayers')],
              ]),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () { Navigator.pop(dialogContext); Navigator.pop(context); },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(tr(context, 'confirm'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
      Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
    ]);
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: AppColors.brand,
      child: Center(child: Icon(Icons.stadium, size: 80, color: Colors.white.withOpacity(0.3))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final match = _match;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: isDark ? AppColors.dSurface : AppColors.brand,
            leading: IconButton(
              icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle), child: const Icon(Icons.arrow_back, color: Colors.white)),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // Chat button
              Consumer<UserProvider>(
                builder: (context, userProvider, _) {
                  if (!_isUserBooked(userProvider.userId)) return const SizedBox.shrink();
                  return IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                      child: const Icon(Icons.chat, color: Colors.white, size: 20),
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => MatchChatPage(
                          matchId: _match.id,
                          userId: userProvider.userId,
                          userName: userProvider.userName,
                          userPhotoUrl: userProvider.userPhotoUrl,
                        ),
                      ));
                    },
                  );
                },
              ),
              // Share button
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                  child: const Icon(Icons.share, color: Colors.white, size: 20),
                ),
                onPressed: _shareMatch,
              ),
              // Token balance indicator
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.token, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Consumer<UserProvider>(
                      builder: (context, userProvider, _) => Text(
                        '${userProvider.matchTokens}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(tr(context, 'matchDetails'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              centerTitle: true,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // USE PITCH IMAGE FROM MATCH
                  match.pitchImageUrl != null && match.pitchImageUrl!.isNotEmpty
                      ? Image.network(match.pitchImageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholderImage())
                      : _buildPlaceholderImage(),
                  Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)]))),
                  Positioned(
                    bottom: 60, left: 16, right: 16,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)), child: Text('${match.maxPlayers ~/ 2}v${match.maxPlayers ~/ 2}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                          const SizedBox(height: 8),
                          Text(match.stadiumName, style: AppText.kufi(size: 24, weight: 700, color: Colors.white)),
                          const SizedBox(height: 4),
                          // Address
                          if (match.stadiumAddress != null) 
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.white70, size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    match.stadiumAddress!,
                                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          // Location text (detailed directions)
                          if (match.locationText != null && match.locationText!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.near_me, color: Colors.white70, size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    match.locationText!,
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // Google Maps button
                          if (match.googleMapsUrl != null && match.googleMapsUrl!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _openMapsLocation(match),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.map, color: Colors.white, size: 16),
                                    const SizedBox(width: 6),
                                    Text(tr(context, 'openInMaps'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: _isFull ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: _isFull ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3))),
                    child: Row(children: [
                      Icon(_isFull ? Icons.block : Icons.check_circle, color: _isFull ? Colors.red : Colors.green),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_isFull ? tr(context, 'matchFull') : tr(context, 'playersCount'), style: TextStyle(fontWeight: FontWeight.bold, color: _isFull ? Colors.red : Colors.green)),
                        Text('${match.currentPlayers}/${match.maxPlayers} ${tr(context, 'playersCount')}', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
                      ])),
                      SizedBox(width: 60, height: 60, child: Stack(children: [
                        CircularProgressIndicator(value: match.currentPlayers / match.maxPlayers, strokeWidth: 6, backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300], valueColor: AlwaysStoppedAnimation(_isFull ? Colors.red : Colors.green)),
                        Center(child: Text('$_availableSpots', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87))),
                      ])),
                    ]),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Info cards
                  Row(children: [
                    Expanded(child: _buildInfoCard(Icons.calendar_today, tr(context, 'dateAndTime'), _formatDate(match.dateTime), Colors.blue, isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInfoCard(Icons.access_time, tr(context, 'dateAndTime'), _formatTime(match.dateTime), Colors.orange, isDark)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _buildInfoCard(Icons.timer, tr(context, 'duration'), '${match.durationMinutes} ${tr(context, 'minutesSuffix')}', AppColors.gold, isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInfoCard(Icons.grass, tr(context, 'surfaceType'), _surfaceTypeText, Colors.green, isDark)),
                  ]),
                  
                  const SizedBox(height: 24),
                  
                  // Booked Players Section (only for players, not referees)
                  if (match.currentPlayers > 0) ...[
                    _buildBookedPlayersSection(match, isDark),
                    const SizedBox(height: 24),
                  ],
                  
                  // Team selection
                  if (!_isFull) ...[
                    Text(tr(context, 'selectTeam'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _buildTeamOption('A', match.teamAName, match.teamAPlayers.length, match.maxPlayers ~/ 2, Colors.blue, isDark)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTeamOption('B', match.teamBName, match.teamBPlayers.length, match.maxPlayers ~/ 2, Colors.red, isDark)),
                    ]),
                    const SizedBox(height: 24),
                  ],
                  
                  // Price section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: isDark ? AppColors.dSurface : Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 2))]),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr(context, 'pricePerPlayer'), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                          Text('${match.pricePerPlayer.toInt()}', style: AppText.mono(size: 24, color: AppColors.brand, weight: FontWeight.w700)),
                          const SizedBox(width: 5),
                          Text(tr(context, 'currency'), style: TextStyle(color: context.palette.textMid, fontSize: 13, fontWeight: FontWeight.w600)),
                        ]),
                      ]),
                      if (!_isFull) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(tr(context, 'costTokens'), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                          Text('${(match.pricePerPlayer * _selectedPlayers).toInt()}', style: AppText.mono(size: 20, color: context.palette.textHi, weight: FontWeight.w700)),
                          const SizedBox(width: 5),
                          Text(tr(context, 'currency'), style: TextStyle(color: context.palette.textMid, fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ]),
                    ]),
                  ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      
      bottomNavigationBar: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final isBooked = _isUserBooked(userProvider.userId);
          final bookedSpots = _getUserBookedSpots(userProvider.userId);
          final userTeam = _getUserTeam(userProvider.userId);
          
          return Container(
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(color: isDark ? AppColors.dSurface : Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.1), blurRadius: 20, offset: const Offset(0, -5))]),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isBooked) ...[
                    Container(
                      width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.3))),
                      child: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${tr(context, 'bookingConfirm')}: $bookedSpots ${tr(context, 'numberOfPlayers')} - ${userTeam == "A" ? _match.teamAName : _match.teamBName}', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w600, fontSize: 13))),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _isBooking ? null : _handleCancelBooking,
                          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.3))), child: Text(tr(context, 'cancel'), style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600, fontSize: 12))),
                        ),
                      ]),
                    ),
                    if (_isFull)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _handleBalanceTeams,
                            icon: const Icon(Icons.balance, size: 20),
                            label: Text(tr(context, 'balanceTeams')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.brand,
                              side: const BorderSide(color: AppColors.brand),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                  ],
                  Row(children: [
                    if (!_isFull && _availableSpots > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          IconButton(onPressed: _selectedPlayers > 1 ? () { HapticFeedback.selectionClick(); setState(() => _selectedPlayers--); } : null, icon: const Icon(Icons.remove), iconSize: 20),
                          Text(_selectedPlayers.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(onPressed: _selectedPlayers < _availableSpots ? () { HapticFeedback.selectionClick(); setState(() => _selectedPlayers++); } : null, icon: const Icon(Icons.add), iconSize: 20),
                        ]),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (_isFull && !isBooked) ...[
                      Expanded(
                        child: _isOnWaitingList
                            ? ElevatedButton.icon(
                                onPressed: _handleLeaveWaitingList,
                                icon: const Icon(Icons.check_circle, size: 20),
                                label: Text(tr(context, 'onWaitingList'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                              )
                            : ElevatedButton.icon(
                                onPressed: _isJoiningWaitingList ? null : _handleJoinWaitingList,
                                icon: _isJoiningWaitingList
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                    : const Icon(Icons.hourglass_top, size: 20),
                                label: Text(tr(context, 'joinWaitingList'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                              ),
                      ),
                    ] else ...[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: !_isFull && !_isBooking ? _handleBooking : null,
                          style: ElevatedButton.styleFrom(backgroundColor: _isFull ? context.palette.surfaceRaised : (isBooked ? AppColors.gold : AppColors.brand), foregroundColor: _isFull ? context.palette.textLow : AppColors.onBrand, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                          child: _isBooking
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                              : Text(_isFull ? tr(context, 'matchFull') : isBooked ? '${tr(context, 'bookMatch')} $_selectedPlayers' : '${tr(context, 'bookMatch')} $_selectedPlayers', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTeamOption(String team, String teamName, int currentPlayers, int maxPlayers, Color color, bool isDark) {
    final isSelected = _selectedTeam == team;
    final isFull = currentPlayers >= maxPlayers;
    
    return GestureDetector(
      onTap: isFull ? null : () { HapticFeedback.selectionClick(); setState(() => _selectedTeam = team); },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: isSelected ? color.withOpacity(0.1) : (isDark ? AppColors.dSurface : Colors.white), borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? color : (isDark ? Colors.grey[700]! : Colors.grey[300]!), width: isSelected ? 2 : 1)),
        child: Column(children: [
          Icon(Icons.shield, color: isFull ? Colors.grey : color, size: 32),
          const SizedBox(height: 8),
          Text(teamName, style: TextStyle(fontWeight: FontWeight.bold, color: isFull ? Colors.grey : (isDark ? Colors.white : Colors.black87))),
          const SizedBox(height: 4),
          Text('$currentPlayers/$maxPlayers', style: TextStyle(fontSize: 12, color: isFull ? Colors.grey : (isDark ? Colors.grey[400] : Colors.grey[600]))),
          if (isFull) Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(tr(context, 'matchFull'), style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold))),
        ]),
      ),
    );
  }
  
  Widget _buildInfoCard(IconData icon, String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? AppColors.dSurface : Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(height: 12),
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
      ]),
    );
  }

  Widget _buildBookedPlayersSection(MatchModel match, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, 'playersCount'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        
        // Team A Players
        if (match.teamAPlayers.isNotEmpty) ...[
          _buildTeamPlayersCard(
            teamName: match.teamAName,
            players: match.teamAPlayers,
            color: Colors.blue,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
        ],
        
        // Team B Players
        if (match.teamBPlayers.isNotEmpty)
          _buildTeamPlayersCard(
            teamName: match.teamBName,
            players: match.teamBPlayers,
            color: Colors.red,
            isDark: isDark,
          ),
      ],
    );
  }

  Widget _buildTeamPlayersCard({
    required String teamName,
    required List<MatchPlayer> players,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.dSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
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
          // Team header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.shield, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                teamName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${players.length} ${tr(context, 'playersCount')}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Players list
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: players.map((player) => _buildPlayerChip(player, isDark)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerChip(MatchPlayer player, bool isDark) {
    // For guests, show a different style
    final isGuest = player.isGuest;
    
    return FutureBuilder<DocumentSnapshot>(
      future: !isGuest && player.oderId.isNotEmpty 
          ? FirebaseFirestore.instance.collection('users').doc(player.oderId).get()
          : null,
      builder: (context, snapshot) {
        String? profileImageUrl;
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          profileImageUrl = userData?['profileImageUrl'];
        }
        
        return GestureDetector(
          onTap: isGuest ? null : () {
            HapticFeedback.lightImpact();
            final currentUserId = Provider.of<UserProvider>(context, listen: false).userId;
            
            if (player.oderId == currentUserId) {
              // Navigate to own profile via RootPage
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const RootPage(initialIndex: 2)),
                (route) => false,
              );
            } else {
              // Navigate to other player's profile
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerProfilePage(
                    oderId: player.oderId,
                    playerName: player.playerName,
                  ),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark 
                  ? (isGuest ? Colors.grey[800] : Colors.grey[850]) 
                  : (isGuest ? Colors.grey[100] : Colors.grey[50]),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile picture or guest icon
                if (isGuest)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                  )
                else
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.brandTint,
                    backgroundImage: profileImageUrl != null 
                        ? NetworkImage(profileImageUrl) 
                        : null,
                    child: profileImageUrl == null
                        ? Text(
                            player.playerName.isNotEmpty 
                                ? player.playerName[0].toUpperCase() 
                                : '?',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brand,
                            ),
                          )
                        : null,
                  ),
                const SizedBox(width: 8),
                // Player name
                Text(
                  player.playerName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                // Guest badge
                if (isGuest) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tr(context, 'guestPlayer'),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}