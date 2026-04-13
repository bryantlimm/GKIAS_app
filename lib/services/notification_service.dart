// lib/services/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Background handler ────────────────────────────────────────────────────────
// Must be a top-level function (not inside a class).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message received: ${message.messageId}');
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notifikasi Penting',
    description: 'Notifikasi jadwal pelayanan GKI Alsut',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    // 1. Request permission
    final settings = await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    print('FCM permission: ${settings.authorizationStatus}');

    // 2. Set up flutter_local_notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(initSettings);

    // ── THE FIX ──────────────────────────────────────────────────────────────
    // Assigning resolvePlatformSpecificImplementation to a typed local variable
    // first. Calling it inline returns dynamic in some Flutter SDK versions,
    // which is why 'createNotificationChannel' wasn't found.
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_androidChannel);

    // 3. Save FCM token
    // await saveToken();

    // 4. Token refresh listener
    _messaging.onTokenRefresh.listen(_saveTokenToFirestore);

    // 5. Foreground messages — show as local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
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
      );
    });

    // 6. App was in background, user tapped notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 7. App was terminated, user tapped notification to open it
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  // Call this after every successful login
  static Future<void> saveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await _messaging.getToken();
    if (token != null) await _saveTokenToFirestore(token);
  }

  // Call this in your logout handler
  static Future<void> removeToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
    } catch (_) {
      // Doc may already be deleted — ignore
    }
    await _messaging.deleteToken();
  }

  static Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
    print('FCM token saved.');
  }

  // message.data payload sent from Cloud Functions:
  //   { 'screen': 'notifications' }      → NotificationsScreen
  //   { 'screen': 'schedules' }          → StaffVolunteerScreen
  //   { 'screen': 'adminNotifications' } → AdminNotificationScreen
  static void _handleNotificationTap(RemoteMessage message) {
    final screen = message.data['screen'];
    print('Notification tapped → $screen');
    // Wire up to your global NavigatorKey here once you have one set up.
  }
}