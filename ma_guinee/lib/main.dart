import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

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
  const settings = InitializationSettings(android: androidSettings, iOS: DarwinInitializationSettings());
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
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Supabase
  await Supabase.initialize(
    url: 'https://zykbcgqgkdsguirjvwxg.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp5a2JjZ3Fna2RzZ3Vpcmp2d3hnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI3ODMwMTEsImV4cCI6MjA2ODM1OTAxMX0.R-iSxRy-vFvmmE80EdI2AlZCKqgADvLd9_luvrLQL-E',
  );

  // Notifications
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FirebaseMessaging.instance.requestPermission();
  await _initLocalNotification();
  await _createAndroidNotificationChannel();

  // Notifications push foreground
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
        ChangeNotifierProvider(create: (_) => PrestatairesProvider()..loadPrestataires()),
      ],
      child: const MyApp(),
    ),
  );
}

/// Écoute notifications en temps réel via Supabase (version 2.5.x et +)
void _subscribeToSupabaseRealtime(String userId) {
  final supabase = Supabase.instance.client;
  supabase
      .channel('public:notifications')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq, // <- ici, l'enum pour version 2.5+
          column: 'utilisateur_id',
          value: userId,
        ),
        callback: (payload) {
          final notif = payload.newRecord;
          if (notif != null) {
            _showNotification(notif['titre'] ?? 'Notification', notif['contenu'] ?? '');
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
