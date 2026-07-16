import 'dart:async';
import 'package:flutter/material.dart';
import 'package:khomasi/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:khomasi/models/match_model.dart';
import 'package:khomasi/services/match_service.dart';
import 'package:khomasi/pages/booking_page.dart';
import 'package:provider/provider.dart';
import 'package:khomasi/providers/locale_provider.dart';

class DeepLinkService {
  final GlobalKey<NavigatorState> navigatorKey;
  static const _channel = MethodChannel('app.khomasi/deeplink');
  StreamSubscription? _sub;

  DeepLinkService(this.navigatorKey);

  void init() {
    // Handle link when app is opened from terminated state
    _handleInitialLink();

    // Handle links when app is already running
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        _handleLink(call.arguments as String);
      }
    });
  }

  Future<void> _handleInitialLink() async {
    try {
      final initialLink = await _channel.invokeMethod<String>('getInitialLink');
      if (initialLink != null) {
        // Small delay to let the app finish building
        await Future.delayed(const Duration(seconds: 1));
        _handleLink(initialLink);
      }
    } catch (_) {
      // No initial link or channel not ready
    }
  }

  void _handleLink(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) return;

    String? matchId;

    if (uri.scheme == 'khomasi' && uri.host == 'match' && uri.pathSegments.isNotEmpty) {
      // khomasi://match/{matchId}
      matchId = uri.pathSegments.first;
    } else if (uri.scheme == 'https' && uri.path.contains('/match/')) {
      // https://khomasi-177f3.web.app/match/{matchId}
      final segments = uri.pathSegments;
      final matchIndex = segments.indexOf('match');
      if (matchIndex != -1 && matchIndex + 1 < segments.length) {
        matchId = segments[matchIndex + 1];
      }
    }

    if (matchId != null && matchId.isNotEmpty) {
      _openMatch(matchId);
    }
  }

  Future<void> _openMatch(String matchId) async {
    if (navigatorKey.currentState == null) return;

    final match = await MatchService().getMatchById(matchId);

    _handleMatchResult(match);
  }

  void _handleMatchResult(MatchModel? match) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    if (match == null) {
      _showMatchUnavailableDialog(nav.context);
      return;
    }

    final isExpired = match.status == MatchStatus.completed ||
        match.status == MatchStatus.cancelled ||
        match.dateTime.isBefore(DateTime.now().subtract(const Duration(hours: 2)));

    if (isExpired) {
      _showMatchUnavailableDialog(nav.context);
      return;
    }

    nav.push(
      MaterialPageRoute(builder: (_) => BookingPage(match: match)),
    );
  }

  void _showMatchUnavailableDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Provider.of<LocaleProvider>(context, listen: false).locale;
    final isArabic = locale == 'ar';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.dSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.event_busy, size: 48, color: Colors.orange[700]),
        title: Text(
          isArabic ? 'المباراة غير متاحة' : 'Match Unavailable',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          isArabic
              ? 'هذه المباراة انتهت أو تم إلغاؤها ولم تعد متاحة.'
              : 'This match has ended or been cancelled and is no longer available.',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(isArabic ? 'حسنًا' : 'OK'),
            ),
          ),
        ],
      ),
    );
  }

  void dispose() {
    _sub?.cancel();
  }
}
