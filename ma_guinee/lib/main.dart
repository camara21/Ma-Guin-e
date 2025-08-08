import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'routes.dart';

import 'providers/user_provider.dart';
import 'providers/favoris_provider.dart';
import 'providers/prestataires_provider.dart';

// Notifications locales
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Notifications en arrière-plan
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  _showNotification(message.notification?.title, message.notification?.body);
}

/// Affichage d'une notification locale
void _showNotification(String? title, String? body) {
  flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title ?? 'Notification',
    body ?? '',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'messages_channel',
        'Messages',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
}

/// Initialisation notifications locales
Future<void> _initLocalNotification() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(
    android: androidSettings,
    iOS: DarwinInitializationSettings(),
  );
  await flutterLocalNotificationsPlugin.initialize(settings);
}

/// Création du channel Android
Future<void> _createAndroidNotificationChannel() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'messages_channel',
    'Messages',
    description: 'Notifications de messages Ma Guinée',
    importance: Importance.high,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Supabase
  await Supabase.initialize(
    url: 'https://zykbcgqgkdsguirjvwxg.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp5a2JjZ3Fna2RzZ3Vpcmp2d3hnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI3ODMwMTEsImV4cCI6MjA2ODM1OTAxMX0.R-iSxRy-vFvmmE80EdI2AlZCKqgADvLd9_luvrLQL-E',
  );

  // Notifications — NE PAS DEMANDER ICI (iOS Safari bloque sans geste utilisateur)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await _initLocalNotification();
  await _createAndroidNotificationChannel();

  // iOS natif : montrer les notifs quand l'app est au premier plan
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // Notifications push en premier plan (affiche via local notif)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    _showNotification(message.notification?.title, message.notification?.body);
  });

  // Notifications push cliquées
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('Notification cliquée: ${message.data}');
  });

  // Chargement de l’utilisateur
  final userProvider = UserProvider();
  await userProvider.chargerUtilisateurConnecte();

  // Notifications Supabase Realtime pour utilisateur connecté
  final user = Supabase.instance.client.auth.currentUser;
  if (user != null) {
    _subscribeToSupabaseRealtime(user.id);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
        ChangeNotifierProvider(create: (_) => FavorisProvider()..loadFavoris()),
        ChangeNotifierProvider(
            create: (_) => PrestatairesProvider()..loadPrestataires()),
      ],
      child: const MyApp(),
    ),
  );
}

/// Appeler CETTE FONCTION APRÈS UN CLIC UTILISATEUR (bouton “Activer les notifications”)
Future<void> enablePushNotifications() async {
  try {
    final messaging = FirebaseMessaging.instance;

    // 1) Demande d’autorisation (uniquement après un geste utilisateur)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional:
          false, // tu peux passer à true si tu veux des notifs silencieuses iOS
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      debugPrint('Notifications non autorisées');
      return;
    }

    // 2) Récupération du token
    String? token;
    if (kIsWeb) {
      // IMPORTANT: remplace par ta clé VAPID publique (Firebase project settings)
      token = await messaging.getToken(
        vapidKey: 'TA_CLE_VAPID_PUBLIQUE_ICI',
      );
    } else {
      token = await messaging.getToken();
    }

    debugPrint('FCM token: $token');

    // TODO: Enregistrer le token côté Supabase si tu gères l’envoi ciblé
    // await Supabase.instance.client.from('user_tokens').upsert({ ... });

  } catch (e, st) {
    debugPrint('Erreur enablePushNotifications: $e\n$st');
  }
}

/// Écoute notifications en temps réel via Supabase
void _subscribeToSupabaseRealtime(String userId) {
  final supabase = Supabase.instance.client;
  supabase
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
            _showNotification(
                notif['titre'] ?? 'Notification', notif['contenu'] ?? '');
          }
        },
      )
      .subscribe();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Montserrat',
        useMaterial3: false,
      ),
    );
  }
}
