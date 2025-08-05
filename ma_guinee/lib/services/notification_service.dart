import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';

class NotificationService {
  final _client = Supabase.instance.client;

  // Doit être initialisé UNE FOIS dans main.dart
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// À mettre dans main() au démarrage de l'app
  static Future<void> initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(),
    );
    await flutterLocalNotificationsPlugin.initialize(settings);
  }

  /// Crée un channel Android si pas encore créé (à faire au lancement)
  static Future<void> createAndroidNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'messages_channel', // Même id que dans main.dart
      'Messages',
      description: 'Notifications Ma Guinée',
      importance: Importance.high,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// À appeler dans main() au démarrage
  static Future<void> globalInit() async {
    await initLocalNotifications();
    await createAndroidNotificationChannel();
  }

  Future<void> initializeFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    String? token = await messaging.getToken();
    print("FCM Token: $token");

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        _showLocal(notification.title ?? 'Nouvelle notification', notification.body ?? '');
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('Notification cliquée: ${message.data}');
    });
  }

  void _showLocal(String title, String body) {
    flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'messages_channel', // Même id que le channel créé
          'Messages',
          channelDescription: 'Notifications Ma Guinée',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Écoute Supabase Realtime pour les notifications pour un utilisateur donné
  void subscribeRealtime(String userId, void Function(Map<String, dynamic>) onNotification) {
    _client
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'utilisateur_id',
            value: userId,
          ),
          callback: (payload) {
            final notif = payload.newRecord;
            if (notif != null) {
              _showLocal(
                notif['titre'] ?? 'Nouvelle notification',
                notif['contenu'] ?? '',
              );
              onNotification(notif);
            }
          },
        )
        .subscribe();
  }
}
