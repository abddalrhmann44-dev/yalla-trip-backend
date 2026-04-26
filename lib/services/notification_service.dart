// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Notification Service
//  Firebase Cloud Messaging + Local Notifications
//  Handles: token management, foreground/background, local display
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'device_service.dart';

// ── Top-level background handler (must be top-level function) ──
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are handled automatically by the system tray.
  // If you need custom processing, do it here.
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  /// Global navigator key — wire this into `MaterialApp(navigatorKey: ...)`
  /// so notification taps can push routes from outside the widget tree.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  bool _initialized = false;

  // ── Android notification channel ──────────────────────────
  static const _androidChannel = AndroidNotificationChannel(
    'talaa_channel',
    'Talaa Notifications',
    description: 'Notifications for bookings, approvals, and updates',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  // ══════════════════════════════════════════════════════════
  //  INITIALIZE
  // ══════════════════════════════════════════════════════════
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Request permissions
    await _requestPermission();

    // 2. Initialize local notifications
    await _initLocalNotifications();

    // 3. Create Android notification channel
    if (Platform.isAndroid) {
      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }

    // 4. Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 5. Listen for foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 6. Handle notification taps (app opened from notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 7. Check if app was opened from a terminated state notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // 8. Save FCM token
    await saveTokenToFirestore();

    // 9. Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      _saveToken(newToken);
    });
  }

  // ══════════════════════════════════════════════════════════
  //  PERMISSIONS
  // ══════════════════════════════════════════════════════════
  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
  }

  // ══════════════════════════════════════════════════════════
  //  LOCAL NOTIFICATIONS SETUP
  // ══════════════════════════════════════════════════════════
  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TOKEN MANAGEMENT
  // ══════════════════════════════════════════════════════════

  /// Fetch the current FCM token from Firebase and hand it to the
  /// backend.  Call after a successful sign-in so the server knows
  /// which device to push to.
  Future<void> registerToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _saveToken(token);
      }
    } catch (e) {
      debugPrint('[FCM] Error getting token: $e');
    }
  }

  /// Backwards-compat alias kept so older call sites don't break.
  Future<void> saveTokenToFirestore() => registerToken();

  /// Remove every push target registered by this user – call on
  /// sign-out so the next user on the same device isn't spammed.
  Future<void> unregisterAll() => DeviceService.unregisterAll();

  Future<void> _saveToken(String token) async {
    try {
      await DeviceService.register(token);
      debugPrint('[FCM] Token registered via /devices');
    } catch (e) {
      debugPrint('[FCM] Error registering device: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  //  FOREGROUND MESSAGE HANDLER
  // ══════════════════════════════════════════════════════════
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    // Show local notification
    _showLocalNotification(
      title: notification.title ?? '',
      body: notification.body ?? '',
      payload: jsonEncode(message.data),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  NOTIFICATION TAP HANDLER
  // ══════════════════════════════════════════════════════════
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Notification tapped: ${message.data}');
    _routeFromPayload(message.data);
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[Local] Notification tapped: ${response.payload}');
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _routeFromPayload(data);
    } catch (e) {
      debugPrint('[Local] Bad payload: $e');
    }
  }

  /// Route an FCM/local notification to the appropriate page based on
  /// its ``type`` field.  Payload keys follow the backend contract in
  /// ``app/services/notification_service.py`` and ``push_service.py``.
  void _routeFromPayload(Map<String, dynamic> data) {
    final nav = navigatorKey.currentState;
    if (nav == null) {
      debugPrint('[FCM] Navigator not ready, skipping route');
      return;
    }
    final type = (data['type'] ?? '').toString();
    debugPrint('[FCM] Routing notification type=$type data=$data');

    switch (type) {
      case 'booking_created':
      case 'booking_confirmed':
      case 'booking_cancelled':
      case 'booking_completed':
      case 'payment_received':
      case 'review_received':
        nav.pushNamed('/bookings');
        break;

      case 'property_approved':
      case 'property_rejected':
        // Owner-facing – deep-link to the host dashboard.
        nav.pushNamed('/host');
        break;

      case 'chat_message':
      case 'chat_offer':
      case 'chat_accept':
      case 'message':
      case 'chat':
        final convId = _parseInt(data['conversation_id']);
        if (convId != null) {
          nav.pushNamed('/chat', arguments: {'conversationId': convId});
        } else {
          nav.pushNamed('/home');
        }
        break;

      default:
        nav.pushNamed('/home');
    }
  }

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  // ══════════════════════════════════════════════════════════
  //  SHOW LOCAL NOTIFICATION
  // ══════════════════════════════════════════════════════════
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(body),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // ══════════════════════════════════════════════════════════
  //  PUBLIC: SEND LOCAL NOTIFICATION (for testing / manual)
  // ══════════════════════════════════════════════════════════
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _showLocalNotification(
      title: title,
      body: body,
      payload: data != null ? jsonEncode(data) : null,
    );
  }
}
