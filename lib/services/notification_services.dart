import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  static String? _fcmToken;
  
  /// Initialize notification service
  /// Call this in main.dart after Firebase.initializeApp()
  static Future<void> initialize() async {
    // Request permission
    await _requestPermission();
    
    // Initialize local notifications (for foreground)
    await _initLocalNotifications();
    
    // Get FCM token and save to Firestore
    await _getAndSaveToken();
    
    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _saveTokenToFirestore(newToken);
    });
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background/terminated message taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
    
    // Check if app was opened from notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }
  }
  
  /// Request notification permission
  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    print('Notification permission: ${settings.authorizationStatus}');
  }
  
  /// Initialize local notifications for foreground display
  static Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        // Handle notification tap when app is in foreground
        print('Notification tapped: ${response.payload}');
      },
    );
    
    // Create notification channel for Android
    const channel = AndroidNotificationChannel(
      'khomasi_matches', // id
      'المباريات', // name
      description: 'إشعارات المباريات والتذكيرات',
      importance: Importance.high,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
  
  /// Get FCM token and save to Firestore
  static Future<void> _getAndSaveToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        print('FCM Token: $_fcmToken');
        await _saveTokenToFirestore(_fcmToken!);
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }
  
  /// Save FCM token to user's Firestore document
  static Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      print('FCM token saved to Firestore');
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }
  
  /// Handle foreground messages - show local notification
  static void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message: ${message.notification?.title}');
    
    final notification = message.notification;
    if (notification == null) return;
    
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'khomasi_matches',
          'المباريات',
          channelDescription: 'إشعارات المباريات والتذكيرات',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['matchId'],
    );
  }
  
  /// Handle notification tap (background/terminated)
  static void _handleMessageTap(RemoteMessage message) {
    print('Message tap: ${message.data}');
    // TODO: Navigate to match details page
    // You can use a GlobalKey<NavigatorState> or a navigation service
  }
  
  /// Get current FCM token
  static String? get fcmToken => _fcmToken;
  
  /// Manually refresh and save token (call after login)
  static Future<void> refreshToken() async {
    await _getAndSaveToken();
  }
  
  /// Clear token on logout
  static Future<void> clearToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': FieldValue.delete(),
        });
      } catch (e) {
        print('Error clearing FCM token: $e');
      }
    }
    await _messaging.deleteToken();
    _fcmToken = null;
  }
  
  /// Subscribe to a topic (e.g., 'all_users', 'referees')
  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }
  
  /// Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }
}

/// Handle background messages (must be top-level function)
/// Add this to main.dart: FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message: ${message.notification?.title}');
  // Don't need to show notification - FCM does it automatically in background
}