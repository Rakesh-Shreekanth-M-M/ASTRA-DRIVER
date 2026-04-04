import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Top-level FCM background handler (required by Firebase)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Message handled in background — notification shown by system
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static const _channelId = 'astra_corridor';
  static const _channelName = 'ASTRA Green Corridor';
  static const _geofenceChannelId = 'astra_geofence';
  static const _geofenceChannelName = 'ASTRA Geofence Alerts';

  // ── Initialise ────────────────────────────────────

  Future<void> initialize() async {
    // Local notifications setup
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotif.initialize(initSettings);

    // Create high-importance channel for heads-up
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Green corridor proximity alerts',
      importance: Importance.max,
      playSound: true,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Create geofence alert channel
    const geofenceChannel = AndroidNotificationChannel(
      _geofenceChannelId,
      _geofenceChannelName,
      description: 'Signal geofence entry alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(geofenceChannel);

    // FCM permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground FCM handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showHeadsUpNotification(
        title: message.notification?.title ?? '🚨 ASTRA',
        body: message.notification?.body ?? 'Green Corridor update',
      );
    });

    // Background FCM handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // ── FCM Token ─────────────────────────────────────

  Future<String?> getFcmToken() async {
    try {
      return await _fcm.getToken();
    } catch (_) {
      return null;
    }
  }

  // ── Show Notification ─────────────────────────────

  Future<void> showHeadsUpNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Green corridor proximity alerts',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      ticker: 'ASTRA Alert',
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  // ── Geofence Notifications ────────────────────────

  Future<void> showProximityAlert(String signalName) async {
    final androidDetails = AndroidNotificationDetails(
      _geofenceChannelId,
      _geofenceChannelName,
      channelDescription: 'Signal geofence entry alerts',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      ticker: '🚨 Green Signal',
    );
    final details = NotificationDetails(android: androidDetails);

    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '🚨 ASTRA — Signal Ahead',
      'Green corridor active — $signalName cleared',
      details,
    );
  }

  Future<void> showCorridorActive(String hospital) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Green corridor status',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '✅ ASTRA — Corridor Active',
      'Green signals cleared to $hospital',
      details,
    );
  }

  Future<void> showCorridorCleared() async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Green corridor status',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'ASTRA — Corridor Ended',
      'Signal corridor has been deactivated',
      details,
    );
  }
}
