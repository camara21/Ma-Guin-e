// lib/main.dart — PROD (Realtime + Heartbeat + FCM + RecoveryGuard)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

// ✅ Hive (cache disque)
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';
import 'routes.dart'; // RecoveryGuard + AppRoutes

// ✅ Service push centralisé (affichage FCM en foreground)
import 'services/push_service.dart';

// nécessaires pour onGenerateInitialRoutes
import 'pages/splash_screen.dart';
import 'pages/auth/reset_password_flow.dart';

import 'providers/favoris_provider.dart';
import 'providers/prestataires_provider.dart';
import 'providers/user_provider.dart';
import 'theme/app_theme.dart';

// ——— Constantes Hive ———
const String kAnnoncesBox = 'annonces_box';

// ——— Navigation globale ———
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
String? _lastRoutePushed;
void _pushUnique(String routeName) {
  if (_lastRoutePushed == routeName) return;
  _lastRoutePushed = routeName;
  navKey.currentState?.pushNamedAndRemoveUntil(routeName, (_) => false);
}

// ——— Demande de notifications une seule fois après connexion ———
bool _askedPushOnce = false;
void _askPushOnce() {
  if (_askedPushOnce) return;
  _askedPushOnce = true;
  unawaited(PushService.instance.initAndRegister());
}

// ——— Notifications locales (utilisées pour background/data-only + Realtime) ———
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _initLocalNotification() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iOS = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  const settings = InitializationSettings(android: android, iOS: iOS);
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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ Afficher uniquement si "data-only"
  if (message.notification == null) {
    _showNotification(
      message.data['title'] as String?,
      message.data['body'] as String?,
    );
  }
}

// ——— Realtime globals ———
RealtimeChannel? _kicksChan; // admin_kicks
RealtimeChannel? _notifChan; // notifications
Timer? _heartbeatTimer;

// ——— Heartbeat ———
Future<void> _startHeartbeat() async {
  _heartbeatTimer?.cancel();
  try {
    await Supabase.instance.client.rpc('update_heartbeat',
        params: {'_device': kIsWeb ? 'web' : 'flutter'});
  } catch (_) {}
  _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
    try {
      await Supabase.instance.client.rpc('update_heartbeat',
          params: {'_device': kIsWeb ? 'web' : 'flutter'});
    } catch (_) {}
  });
}

Future<void> _stopHeartbeat() async {
  _heartbeatTimer?.cancel();
  _heartbeatTimer = null;
}

// ——— Realtime : notifications utilisateur (table notifications) ———
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

/// Détecte si l’URL de démarrage est un lien de recovery Supabase
bool _isRecoveryUrl(Uri uri) {
  final hasCode = uri.queryParameters['code'] != null;
  final fragPath = uri.fragment.split('?').first; // ex: "/reset_password"
  final hasTypeRecovery = (uri.queryParameters['type'] ?? '') == 'recovery';
  return (hasCode && fragPath.contains('reset_password')) || hasTypeRecovery;
}

// ——— main ———
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Hive: cache disque global (annonces, plus tard d'autres box si besoin)
  await Hive.initFlutter();
  await Hive.openBox(kAnnoncesBox);
  await Hive.openBox('hotels_box');
  await Hive.openBox('logement_feed_box');

  if (kIsWeb) setUrlStrategy(const HashUrlStrategy());

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

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

  // Prépare les providers sans attendre des charges réseau
  final userProvider = UserProvider();

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

  // Post-frame: inits lentes **sans bloquer le splash**
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      // Recovery Guard (web)
      if (kIsWeb && _isRecoveryUrl(Uri.base)) {
        RecoveryGuard.activate();
      }

      // Notifications locales + channel + foreground iOS
      await _initLocalNotification();
      await _createAndroidNotificationChannel();
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Charge l'utilisateur connecté (réseau)
      await userProvider.chargerUtilisateurConnecte();

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _subscribeUserNotifications(user.id);
        _subscribeAdminKick(user.id);
        unawaited(_startHeartbeat());

        // ✅ Demande/registration push une seule fois après connexion
        _askPushOnce();
      }

      // Redirection initiale si PAS en recovery
      if (!RecoveryGuard.isActive) {
        await _goHomeBasedOnRole(userProvider);
      }

      // Auth state
      Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
        final session = event.session;

        if (event.event == AuthChangeEvent.passwordRecovery) {
          RecoveryGuard.activate();
          return;
        }
        if (RecoveryGuard.isActive && event.event == AuthChangeEvent.signedIn) {
          return;
        }

        if (session?.user != null) {
          final uid = session!.user.id;
          _subscribeUserNotifications(uid);
          _subscribeAdminKick(uid);
          await _startHeartbeat();

          await userProvider.chargerUtilisateurConnecte();

          _askPushOnce();

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
    } catch (_) {
      // on ignore: on préfère démarrer l'app même si une init échoue
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
      onGenerateInitialRoutes: (String _) {
        if (kIsWeb && _isRecoveryUrl(Uri.base)) {
          return [
            MaterialPageRoute(
              settings: const RouteSettings(name: AppRoutes.resetPassword),
              builder: (_) => const ResetPasswordPage(),
            ),
          ];
        }
        return [
          MaterialPageRoute(
            settings: const RouteSettings(name: AppRoutes.splash),
            builder: (_) => const SplashScreen(),
          ),
        ];
      },
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
