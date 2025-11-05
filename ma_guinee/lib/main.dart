// lib/main.dart — PROD (Realtime + Heartbeat + FCM + RecoveryGuard)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'firebase_options.dart';
import 'routes.dart'; // contient RecoveryGuard + AppRoutes

// ✅ nécessaires pour onGenerateInitialRoutes
import 'pages/splash_screen.dart';
import 'pages/auth/reset_password_flow.dart';

import 'providers/user_provider.dart';
import 'providers/favoris_provider.dart';
import 'providers/prestataires_provider.dart';
import 'theme/app_theme.dart';

// ——— Navigation globale ———
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
String? _lastRoutePushed;
void _pushUnique(String routeName) {
  if (_lastRoutePushed == routeName) return;
  _lastRoutePushed = routeName;
  navKey.currentState?.pushNamedAndRemoveUntil(routeName, (_) => false);
}

// ——— Notifications locales ———
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _initLocalNotification() async {
  // ⚙️ Initialisation adaptée à flutter_local_notifications ^17.x
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iOS = DarwinInitializationSettings(
    // On laisse les permissions à FirebaseMessaging.requestPermission()
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  const settings = InitializationSettings(android: android, iOS: iOS);

  await flutterLocalNotificationsPlugin.initialize(
    settings,
    // On ne change pas la navigation au tap pour éviter de modifier la logique existante
  );
}

Future<void> _createAndroidNotificationChannel() async {
  // ✅ Crée le channel "messages_channel" (ne fait rien si déjà créé)
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
    // Id unique
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
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
  );
}

// ——— FCM background ———
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 🔒 Requis en arrière-plan avec firebase_core ^3.x
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Si c'est une data-only, on affiche nous-mêmes.
  // Si c'est une "notification" FCM, Android/iOS la gèrent nativement.
  _showNotification(message.notification?.title, message.notification?.body);
}

// ——— Realtime globals ———
RealtimeChannel? _kicksChan; // admin_kicks
RealtimeChannel? _notifChan; // notifications
Timer? _heartbeatTimer;

// ——— Heartbeat ———
Future<void> _startHeartbeat() async {
  _heartbeatTimer?.cancel();
  try {
    await Supabase.instance.client
        .rpc('update_heartbeat', params: {'_device': kIsWeb ? 'web' : 'flutter'});
  } catch (_) {}
  _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
    try {
      await Supabase.instance.client
          .rpc('update_heartbeat', params: {'_device': kIsWeb ? 'web' : 'flutter'});
    } catch (_) {}
  });
}

Future<void> _stopHeartbeat() async {
  _heartbeatTimer?.cancel();
  _heartbeatTimer = null;
}

// ——— Realtime : notifications utilisateur ———
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

// ——— Realtime : kick admin ———
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

// ——— Helpers ———
// 🔁 PATCH: retourne le token et log en release (print) sans casser le flux existant
Future<String?> enablePushNotifications() async {
  try {
    final messaging = FirebaseMessaging.instance;

    // ✅ Permissions via FCM (iOS 12+/macOS & Android 13+ si manifest ok)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      print('🔔 Notifications refusées');
      return null;
    }

    // ✅ Token (web utilise VAPID si fourni via --dart-define)
    final token = kIsWeb
        ? await messaging.getToken(
            vapidKey:
                const String.fromEnvironment('FCM_VAPID_KEY', defaultValue: ''),
          )
        : await messaging.getToken();

    print('🎯 FCM token: $token'); // visible aussi en release
    return token;
  } catch (e, st) {
    print('❌ enablePushNotifications: $e\n$st');
    return null;
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

// ——— Redirection centralisée selon le rôle ———
Future<void> _goHomeBasedOnRole(UserProvider userProv) async {
  final role = (userProv.utilisateur?.role ?? '').toLowerCase();
  final dest = (role == 'admin' || role == 'owner')
      ? AppRoutes.adminCenter
      : AppRoutes.mainNav;
  _pushUnique(dest);
}

/// ——— Détecte si l’URL de démarrage est un lien de recovery Supabase ———
bool _isRecoveryUrl(Uri uri) {
  final hasCode = uri.queryParameters['code'] != null;
  final fragPath = uri.fragment.split('?').first; // ex: "/reset_password"
  final hasTypeRecovery = (uri.queryParameters['type'] ?? '') == 'recovery';
  return (hasCode && fragPath.contains('reset_password')) || hasTypeRecovery;
}

// ——— main ———
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) setUrlStrategy(const HashUrlStrategy());

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    // ✅ Requis pour FCM data-only en background avec firebase_messaging ^15.x
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  await _initLocalNotification();
  await _createAndroidNotificationChannel();

  // iOS : afficher les notifs système en foreground si message "notification"
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

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
  ); // ✅

  // ✅ Active le guard AVANT runApp si l’URL est un lien de recovery
  if (kIsWeb && _isRecoveryUrl(Uri.base)) {
    RecoveryGuard.activate();
  }

  // Foreground FCM → on affiche via LNP pour unifier Android/iOS/web
  FirebaseMessaging.onMessage.listen((m) {
    _showNotification(m.notification?.title, m.notification?.body);
  });

  final userProvider = UserProvider();
  await userProvider.chargerUtilisateurConnecte();

  final user = Supabase.instance.client.auth.currentUser;
  if (user != null) {
    _subscribeUserNotifications(user.id);
    _subscribeAdminKick(user.id);
    unawaited(_startHeartbeat());

    // ✅ Ajout : enregistre l’appareil et récupère le token (Android/iOS/Web)
    final token = await enablePushNotifications();
    // TODO (optionnel): upsert token -> table user_tokens avec user_id + platform + token
    if (token != null && !kReleaseMode) {
      debugPrint('Token enregistré: $token');
    }
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

  // Redirection initiale si PAS en recovery (sinon on laisse Reset/Splash gérer)
  scheduleMicrotask(() {
    if (!RecoveryGuard.isActive) {
      _goHomeBasedOnRole(userProvider);
    }
  });

  // Auth state
  Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
    final session = event.session;

    // ✅ Quand Supabase signale le flow de recovery, ne PUSHE rien ici
    if (event.event == AuthChangeEvent.passwordRecovery) {
      RecoveryGuard.activate();
      return;
    }

    // Pendant le recovery, ignorer toute connexion automatique
    if (RecoveryGuard.isActive && event.event == AuthChangeEvent.signedIn) {
      return;
    }

    if (session?.user != null) {
      final uid = session!.user.id;
      _subscribeUserNotifications(uid);
      _subscribeAdminKick(uid);
      await _startHeartbeat();

      await userProvider.chargerUtilisateurConnecte();

      // ✅ Ajout : enregistre l’appareil et récupère le token après connexion
      final token = await enablePushNotifications();
      // TODO (optionnel): upsert token côté Supabase
      if (token != null && !kReleaseMode) {
        debugPrint('Token enregistré (post-login): $token');
      }

      if (!RecoveryGuard.isActive) {
        await _goHomeBasedOnRole(userProvider);
      }
    } else {
      _unsubscribeUserNotifications();
      _unsubscribeAdminKick();
      await _stopHeartbeat();

      if (!RecoveryGuard.isActive) {
        _pushUnique(AppRoutes.welcome);
      }
    }
  });
}

// ——— App ———
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,

      // ❌ PAS d'initialRoute — on pilote la 1re page ici :
      onGenerateInitialRoutes: (String _) {
        if (kIsWeb && _isRecoveryUrl(Uri.base)) {
          // Lien de réinitialisation → ouvrir directement la page Reset
          return [
            MaterialPageRoute(
              settings: const RouteSettings(name: AppRoutes.resetPassword),
              builder: (_) => const ResetPasswordPage(),
            ),
          ];
        }
        // Sinon démarrer par Splash
        return [
          MaterialPageRoute(
            settings: const RouteSettings(name: AppRoutes.splash),
            builder: (_) => const SplashScreen(),
          ),
        ];
      },

      // Router app standard
      onGenerateRoute: AppRoutes.generateRoute,

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr'), Locale('en')],
      locale: const Locale('fr'),

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
