import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khomasi/providers/auth_provider.dart';
import 'package:khomasi/providers/user_provider.dart';
import 'package:khomasi/pages/root_page.dart';
import 'package:khomasi/pages/referee_page.dart';
import 'package:khomasi/services/notification_services.dart';

/// AuthWrapper listens to authentication state and routes accordingly:
/// - If user is authenticated → Check role and show appropriate page
/// - If user is not authenticated → Show LoginPage
/// - While checking initial auth state → Show loading spinner
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _lastInitializedUserId;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    // Show loading ONLY during initial auth check (app startup)
    if (authProvider.isInitializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.deepPurple),
              SizedBox(height: 16),
              Text(
                'جاري التحميل...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Not authenticated - go to home as guest (skip login screen)
    if (!authProvider.isAuthenticated || authProvider.userId == null) {
      _lastInitializedUserId = null;
      return const RootPage();
    }

    // Authenticated - check if we need to initialize UserProvider
    final currentAuthUserId = authProvider.userId!;
    
    // Initialize if: never initialized OR user changed
    if (_lastInitializedUserId != currentAuthUserId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Clear old data if switching users
        if (_lastInitializedUserId != null) {
          userProvider.clear();
        }
        _lastInitializedUserId = currentAuthUserId;
        userProvider.init(currentAuthUserId);
        
        // Save FCM token now that user is logged in
        NotificationService.refreshToken();
      });
      
      // Show loading while we trigger init
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.deepPurple),
              SizedBox(height: 16),
              Text(
                'جاري تحميل بياناتك...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Wait for user data to load
    if (userProvider.isInitializing || userProvider.user == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.deepPurple),
              SizedBox(height: 16),
              Text(
                'جاري تحميل بياناتك...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Route based on user role
    if (userProvider.isReferee) {
      return const RefereePage();
    }

    return const RootPage();
  }
}