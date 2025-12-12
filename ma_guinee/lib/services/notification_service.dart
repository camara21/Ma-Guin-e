import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';

class NotificationService {
  final _client = Supabase.instance.client;

  static const _channelId = 'messages_channel';
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  RealtimeChannel? _rtChannel;

  /// Initialisation des notifications locales (Android / iOS)
  static Future<void> initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await flutterLocalNotificationsPlugin.initialize(settings);
  }

  /// Création du canal de notification Android pour les messages
  static Future<void> createAndroidNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      'Messages',
      description: 'Notifications Ma Guinée',
      importance: Importance.high,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Initialisation globale (canal + notifications locales)
  static Future<void> globalInit() async {
    await initLocalNotifications();
    await createAndroidNotificationChannel();
  }

  /// Initialisation de Firebase Cloud Messaging (FCM)
  Future<void> initializeFCM() async {
    final messaging = FirebaseMessaging.instance;

    // Demande d’autorisation (iOS, Web, etc.)
    await messaging.requestPermission();

    // Affichage des notifications en foreground
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Écoute des messages reçus lorsque l’app est ouverte
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n != null) {
        _showLocal(n.title ?? 'Nouvelle notification', n.body ?? '');
      }
    });
  }

  /// Affiche une notification locale sur l’appareil
  void _showLocal(String title, String body) {
    flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
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

  /// Écoute en temps réel les INSERT sur `public.notifications` pour l'utilisateur courant
  void subscribeRealtime(
    String userId,
    void Function(Map<String, dynamic>) onNotification,
  ) {
    // Évite les doublons si on ré-appelle cette méthode
    _rtChannel?.unsubscribe();

    _rtChannel = _client
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id', // Champ filtré par identifiant utilisateur
            value: userId,
          ),
          callback: (payload) {
            final notif = payload.newRecord;
            if (notif != null) {
              _showLocal(
                (notif['titre'] ?? 'Nouvelle notification').toString(),
                (notif['contenu'] ?? '').toString(),
              );
              onNotification(Map<String, dynamic>.from(notif));
            }
          },
        )
        .subscribe();
  }

  /// Stoppe l’écoute temps réel des notifications
  void unsubscribeRealtime() {
    _rtChannel?.unsubscribe();
    _rtChannel = null;
  }
}
