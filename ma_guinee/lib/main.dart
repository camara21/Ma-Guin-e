// main.dart — PROD (Realtime + Heartbeat + FCM) — démarrage via Splash SANS flash

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ✅ Localizations & Intl (fr_FR)
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'routes.dart';

import 'providers/user_provider.dart';
import 'providers/favoris_provider.dart';
import 'providers/prestataires_provider.dart';
import 'theme/app_theme.dart';

// ───────────── Navigation globale ─────────────
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
String? _lastRoutePushed;
bool _authListenerArmed = false; // on n'agit pas sur l'event initial
DateTime _quietUntil = DateTime.fromMillisecondsSinceEpoch(0); // fenêtre anti-signedOut

String? _currentRouteName() {
  final ctx = navKey.currentContext;
  if (ctx == null) return null;
  final route = ModalRoute.of(ctx);
  return route?.settings.name;
}

bool _sameAsCurrentOrLast(String routeName) {
  final current = _currentRouteName();
  if (current == routeName) return true;
  if (_lastRoutePushed == routeName) return true;
  return false;
}

void _pushUnique(String routeName) {
  if (_sameAsCurrentOrLast(routeName)) return;
  _lastRoutePushed = routeName;
  final nav = navKey.currentState;
  if (nav == null) return; // nav pas prêt → évite flicker
  nav.pushNamedAndRemoveUntil(routeName, (_) => false);
}

// ───────────── Notifications locales ─────────────
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _initLocalNotification() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(
    android: androidSettings,
    iOS: DarwinInitializationSettings(),
  );
  await flutterLocalNotificationsPlugin.initialize(settings);
}

Future<void> _createAndroidNotificationChannel() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'messages_channel',
    'Messages',
    description: 'Notifications de messages',
    importance: Importance.high,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

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

// ───────────── FCM background ─────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  _showNotification(message.notification?.title, message.notification?.body);
}

// ───────────── Realtime globals ─────────────
RealtimeChannel? _kicksChan; // admin_kicks
RealtimeChannel? _notifChan; // notifications
Timer? _heartbeatTimer;

// ───────────── Heartbeat ─────────────
Future<void> _startHeartbeat() async {
  _heartbeatTimer?.cancel();
  try {
    await Supabase.instance.client.rpc(
      'update_heartbeat',
      params: {'_device': kIsWeb ? 'web' : 'flutter'},
    );
  } catch (_) {}
  _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
    try {
      await Supabase.instance.client.rpc(
        'update_heartbeat',
        params: {'_device': kIsWeb ? 'web' : 'flutter'},
      );
    } catch (_) {}
  });
}

Future<void> _stopHeartbeat() async {
  _heartbeatTimer?.cancel();
  _heartbeatTimer = null;
}

// ───────────── Realtime: notifications user ─────────────
void _subscribeUserNotifications(String userId) {
  _notifChan?.unsubscribe();
  _notifChan = Supabase.instance.client
      .channel('public:notifications:$userId')
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
          final n = payload.newRecord;
          if (n != null) {
            _showNotification(
              (n['titre'] as String?) ?? 'Notification',
              (n['contenu'] as String?) ?? '',
            );
          }
        },
      )
      .subscribe();
}

void _unsubscribeUserNotifications() {
  _notifChan?.unsubscribe();
  _notifChan = null;
}

// ───────────── Realtime: kick admin ─────────────
void _subscribeAdminKick(String userId) {
  _kicksChan?.unsubscribe();
  _kicksChan = Supabase.instance.client
      .channel('kicks-$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'admin_kicks',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) async {
          await Supabase.instance.client.auth.signOut();
          _showNotification(
            'Déconnecté',
            (payload.newRecord?['reason'] as String?) ??
                'Votre session a été fermée par un administrateur.',
          );
        },
      )
      .subscribe();
}

void _unsubscribeAdminKick() {
  _kicksChan?.unsubscribe();
  _kicksChan = null;
}

// ───────────── Helpers ─────────────
Future<void> enablePushNotifications() async {
  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      if (!kReleaseMode) debugPrint('Notifications non autorisées');
      return;
    }
    String? token;
    if (kIsWeb) {
      token = await messaging.getToken(
        vapidKey:
            const String.fromEnvironment('FCM_VAPID_KEY', defaultValue: ''),
      );
    } else {
      token = await messaging.getToken();
    }
    if (!kReleaseMode) debugPrint('FCM token: $token');
  } catch (e, st) {
    if (!kReleaseMode) {
      debugPrint('Erreur enablePushNotifications: $e\n$st');
    }
  }
}

Future<bool> isCurrentUserAdmin() async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return false;
  try {
    final data = await Supabase.instance.client
        .from('utilisateurs')
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    final role = (data?['role'] as String?)?.toLowerCase();
    return role == 'admin' || role == 'owner';
  } catch (_) {
    return false;
  }
}

// ───────────── Redirection centralisée selon le rôle ─────────────
Future<void> _goHomeBasedOnRole(UserProvider userProv) async {
  final role = (userProv.utilisateur?.role ?? '').toLowerCase();
  final dest = (role == 'admin' || role == 'owner')
      ? AppRoutes.adminCenter
      : AppRoutes.mainNav;
  if (_sameAsCurrentOrLast(dest)) return;
  _pushUnique(dest);
}

// ───────────── main ─────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Intl (fr_FR) – évite LocaleDataException
  await initializeDateFormatting('fr_FR');

  // Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await _initLocalNotification();
  await _createAndroidNotificationChannel();
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // Supabase
  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://zykbcgqgkdsguirjvwxg.supabase.co',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp5a2JjZ3Fna2RzZ3Vpcmp2d3hnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI3ODMwMTEsImV4cCI6MjA2ODM1OTAxMX0.R-iSxRy-vFvmmE80EdI2AlZCKqgADvLd9_luvrLQL-E',
    ),
  );

  // FCM foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    _showNotification(message.notification?.title, message.notification?.body);
  });

  // Providers
  final userProvider = UserProvider();
  await userProvider.chargerUtilisateurConnecte(); // hydrate le profil

  // Démarrage : si déjà connecté → souscriptions + heartbeat
  final user = Supabase.instance.client.auth.currentUser;
  if (user != null) {
    _subscribeUserNotifications(user.id);
    _subscribeAdminKick(user.id);
    unawaited(_startHeartbeat());
  }

  // ✅ On démarre toujours sur le Splash (route "/")
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
        ChangeNotifierProvider(create: (_) => FavorisProvider()..loadFavoris()),
        ChangeNotifierProvider(
          create: (_) => PrestatairesProvider()..loadPrestataires(),
        ),
      ],
      child: const MyApp(),
    ),
  );

  // bloque tout repush identique au boot + fenêtre de silence
  _lastRoutePushed = AppRoutes.splash;
  _quietUntil = DateTime.now().add(const Duration(milliseconds: 700));

  // Armer le listener APRÈS la 1re frame → évite la nav due à initialSession
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _authListenerArmed = true;
  });

  // Auth state: rebrancher realtime + recharger profil + rediriger
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final event = data.event;     // AuthChangeEvent
    final session = data.session; // Session?

    // Ignorer l'événement initial du boot ou si pas encore armé
    if (event == AuthChangeEvent.initialSession || !_authListenerArmed) {
      return;
    }

    // Pendant ~700ms après boot, ignorer les déconnexions transitoires
    final now = DateTime.now();
    final inQuietWindow = now.isBefore(_quietUntil);
    final isTransientSignOut =
        (event == AuthChangeEvent.signedOut || event == AuthChangeEvent.userDeleted);
    if (inQuietWindow && isTransientSignOut) return;

    if (session?.user != null) {
      final uid = session!.user.id;
      _subscribeUserNotifications(uid);
      _subscribeAdminKick(uid);
      await _startHeartbeat();

      await userProvider.chargerUtilisateurConnecte();

      // Ne rien pousser si on est sur le splash : c’est le Splash qui redirige
      final r = _currentRouteName();
      if (r == AppRoutes.splash) return;

      await _goHomeBasedOnRole(userProvider);
    } else {
      _unsubscribeUserNotifications();
      _unsubscribeAdminKick();
      await _stopHeartbeat();

      // Ne renvoyer /welcome que si on n'est pas déjà sur une page d'auth ni sur le splash
      final r = _currentRouteName();
      if (r != AppRoutes.welcome &&
          r != AppRoutes.login &&
          r != AppRoutes.register &&
          r != AppRoutes.splash) {
        _pushUnique(AppRoutes.welcome);
      }
    }
  });
}

// ───────────── App ─────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash, // route initiale = Splash
      onGenerateRoute: AppRoutes.generateRoute,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,

      // ✅ Localisation FR pour Material/Cupertino + formats de dates
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      builder: (context, child) {
        final style = AppTheme.light.textTheme.bodyMedium!;
        return DefaultTextStyle.merge(
          style: style,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
