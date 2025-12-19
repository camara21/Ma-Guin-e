// lib/main.dart — PROD (Realtime + Heartbeat + FCM + RecoveryGuard + Offline UX)
import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:hive_flutter/hive_flutter.dart';

// ✅ Détection réseau
import 'package:connectivity_plus/connectivity_plus.dart';

import 'firebase_options.dart';
import 'routes.dart';

import 'services/push_service.dart';

import 'pages/splash_screen.dart';
import 'pages/auth/reset_password_flow.dart';

import 'providers/favoris_provider.dart';
import 'providers/prestataires_provider.dart';
import 'providers/user_provider.dart';
import 'theme/app_theme.dart';

import 'navigation/nav_key.dart';
import 'navigation/push_nav.dart';

// ✅ Annonces (pré-chargement global)
import 'pages/annonces_page.dart';

// ✅ Supabase (helper centralisé)
import 'supabase_client.dart';

// ✅ Centre unique erreurs + overlay global
import 'utils/error_messages_fr.dart';

/// Hive boxes
const String kAnnoncesBox = 'annonces_box';

String? _lastRoutePushed;

/// ✅ Transitions fluides globales (style iOS) pour TOUTE l’app
const PageTransitionsTheme _kSmoothTransitions = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
    TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
    TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
  },
);

/// =========================
/// ✅ OFFLINE / CONNECTIVITY
/// =========================
final ValueNotifier<bool> _isOffline = ValueNotifier<bool>(false);
final Connectivity _connectivity = Connectivity();
StreamSubscription? _connSub;
bool _connInited = false;

/// Normalise ConnectivityResult (v5) et List<ConnectivityResult> (v6)
bool _offlineFromConnectivity(dynamic result) {
  try {
    if (result is ConnectivityResult) {
      return result == ConnectivityResult.none;
    }
    if (result is List<ConnectivityResult>) {
      if (result.isEmpty) return true;
      return result.every((r) => r == ConnectivityResult.none);
    }
  } catch (_) {}
  return false;
}

void _setOffline(dynamic connectivityResult) {
  final off = _offlineFromConnectivity(connectivityResult);
  if (_isOffline.value != off) _isOffline.value = off;

  // ✅ Offline intelligent (géré dans error_messages_fr.dart)
  SoneyaErrorCenter.setOffline(off, onRetry: () async {
    await _checkOfflineNow();
  });
}

/// Side-effects réseau: stop/start heartbeat + channels
void _applyNetworkSideEffects() {
  try {
    final uid = Supabase.instance.client.auth.currentSession?.user.id;
    if (_isOffline.value) {
      _unsubscribeUserNotifications();
      _unsubscribeAdminKick();
      unawaited(_stopHeartbeat());
    } else {
      if (uid != null) {
        _subscribeUserNotifications(uid);
        _subscribeAdminKick(uid);
        unawaited(_startHeartbeat());
        _askPushOnce();
        unawaited(AnnoncesPage.preload());
        unawaited(PushService.instance.showLaunchAdminIfPending());
      }
    }
  } catch (_) {}
}

Future<void> _initConnectivityWatch() async {
  if (_connInited) return;
  _connInited = true;

  try {
    final initial = await _connectivity.checkConnectivity();
    _setOffline(initial);

    _connSub = _connectivity.onConnectivityChanged.listen((result) {
      _setOffline(result);
      _applyNetworkSideEffects();
    });
  } catch (_) {}
}

Future<bool> _checkOfflineNow() async {
  try {
    final r = await _connectivity.checkConnectivity();
    _setOffline(r);
  } catch (_) {}
  return _isOffline.value;
}

/// Navigation centralisée avec protection contre les doubles push.
/// Si le navigator n'est pas encore prêt, on replanifie automatiquement.
void _pushUnique(String routeName) {
  if (_lastRoutePushed == routeName) return;

  final state = navKey.currentState;
  if (state == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pushUnique(routeName);
    });
    return;
  }

  _lastRoutePushed = routeName;
  state.pushNamedAndRemoveUntil(routeName, (_) => false);
}

/// Empêche double init PushService
bool _askedPushOnce = false;
void _askPushOnce() {
  if (_askedPushOnce) return;
  _askedPushOnce = true;
  unawaited(PushService.instance.initAndRegister());
}

/// Normalise/platifie la data entrante du FCM / payload server.
Map<String, dynamic> _normalizeIncomingData(Map<String, dynamic>? raw) {
  final Map<String, dynamic> out = {};
  if (raw == null) return out;

  raw.forEach((k, v) {
    if (v == null) return;
    if (v is String) {
      final s = v.trim();
      if ((s.startsWith('{') && s.endsWith('}')) ||
          (s.startsWith('[') && s.endsWith(']'))) {
        try {
          final decoded = jsonDecode(s);
          out[k] = decoded;
          return;
        } catch (_) {}
      }
    }
    out[k] = v;
  });

  final nested = out['data'];
  if (nested != null) {
    if (nested is String) {
      try {
        final decoded = jsonDecode(nested);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (!out.containsKey(k)) out[k] = v;
          });
        }
      } catch (_) {}
    } else if (nested is Map) {
      nested.forEach((k, v) {
        if (!out.containsKey(k)) out[k] = v;
      });
    }
  }
  return out;
}

// ------------------ Background handler top-level ------------------
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}

  debugPrint(
    '[main] background message received (minimal handling). data=${message.data}',
  );
}

RealtimeChannel? _notifChan;
RealtimeChannel? _kicksChan;
Timer? _heartbeatTimer;

Future<void> _startHeartbeat() async {
  _heartbeatTimer?.cancel();

  // Premier ping immédiat
  try {
    await Supabase.instance.client.rpc(
      'update_heartbeat',
      params: {'_device': kIsWeb ? 'web' : 'flutter'},
    );
    SoneyaErrorCenter.reportNetworkSuccess();
  } catch (_) {
    SoneyaErrorCenter.reportNetworkFailure();
    SoneyaErrorCenter.setOffline(true, onRetry: () async => _checkOfflineNow());
  }

  _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
    try {
      await Supabase.instance.client.rpc(
        'update_heartbeat',
        params: {'_device': kIsWeb ? 'web' : 'flutter'},
      );
      SoneyaErrorCenter.reportNetworkSuccess();
    } catch (_) {
      SoneyaErrorCenter.reportNetworkFailure();
      SoneyaErrorCenter.setOffline(true,
          onRetry: () async => _checkOfflineNow());
    }
  });
}

Future<void> _stopHeartbeat() async {
  _heartbeatTimer?.cancel();
  _heartbeatTimer = null;
}

/// Souscription aux notifications CRUD table `notifications` (Supabase realtime)
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
          if (n == null) return;

          if (n['type']?.toString() == 'message') return;

          PushService.instance.showLocalNotification(
            n['titre'] ?? 'Notification',
            n['contenu'] ?? '',
            payload: n is Map ? Map<String, dynamic>.from(n) : null,
          );
        },
      )
      .subscribe();
}

void _unsubscribeUserNotifications() {
  _notifChan?.unsubscribe();
  _notifChan = null;
}

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
          PushService.instance.showLocalNotification(
            'Déconnecté',
            payload.newRecord?['reason'] ??
                'Votre session a été fermée par un administrateur.',
            payload: payload.newRecord is Map
                ? Map<String, dynamic>.from(payload.newRecord as Map)
                : null,
          );
        },
      )
      .subscribe();
}

void _unsubscribeAdminKick() {
  _kicksChan?.unsubscribe();
  _kicksChan = null;
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
    final role = data?['role']?.toLowerCase();
    return role == 'admin' || role == 'owner';
  } catch (_) {
    return false;
  }
}

Future<void> _goHomeBasedOnRole(UserProvider userProv) async {
  final role = userProv.utilisateur?.role?.toLowerCase() ?? '';
  final dest = (role == 'admin' || role == 'owner')
      ? AppRoutes.adminCenter
      : AppRoutes.mainNav;
  _pushUnique(dest);
}

/// Détection URL de recovery (WEB uniquement)
bool _isRecoveryUrl(Uri uri) {
  final hasCode = uri.queryParameters['code'] != null;
  final frag = uri.fragment.split('?').first;
  final hasRecovery = (uri.queryParameters['type'] ?? '') == 'recovery';
  return (hasCode && frag.contains('reset_password')) || hasRecovery;
}

/// Bootstrap global
Future<void> _bootstrap(UserProvider userProvider) async {
  try {
    if (kIsWeb && _isRecoveryUrl(Uri.base)) {
      RecoveryGuard.activate();
    }

    final offline = await _checkOfflineNow();

    try {
      await userProvider
          .chargerUtilisateurConnecte()
          .timeout(Duration(seconds: offline ? 2 : 10));
      if (!offline) SoneyaErrorCenter.reportNetworkSuccess();
    } catch (_) {}

    final session = Supabase.instance.client.auth.currentSession;
    final user = session?.user;

    if (user != null) {
      if (!offline) {
        _subscribeUserNotifications(user.id);
        _subscribeAdminKick(user.id);
        unawaited(_startHeartbeat());
        _askPushOnce();
        unawaited(AnnoncesPage.preload());
      }

      if (!RecoveryGuard.isActive) {
        await _goHomeBasedOnRole(userProvider);
      }
    } else {
      if (!RecoveryGuard.isActive) {
        _pushUnique(AppRoutes.welcome);
      }
    }

    if (!offline) {
      await PushService.instance.showLaunchAdminIfPending();
    }

    Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
      final session = event.session;
      debugPrint('[auth] event=${event.event} user=${session?.user.id}');

      if (event.event == AuthChangeEvent.passwordRecovery) {
        RecoveryGuard.activate();
        if (!kIsWeb) {
          _pushUnique(AppRoutes.resetPassword);
        }
        return;
      }

      if (event.event == AuthChangeEvent.signedOut) {
        _unsubscribeUserNotifications();
        _unsubscribeAdminKick();
        await _stopHeartbeat();

        RecoveryGuard.deactivate();
        _pushUnique(AppRoutes.welcome);
        return;
      }

      if (RecoveryGuard.isActive && event.event == AuthChangeEvent.signedIn) {
        return;
      }

      final offlineNow = _isOffline.value;

      if (session?.user != null) {
        final uid = session!.user.id;

        if (!offlineNow) {
          _subscribeUserNotifications(uid);
          _subscribeAdminKick(uid);
          await _startHeartbeat();
          _askPushOnce();
          unawaited(AnnoncesPage.preload());
        }

        try {
          await userProvider
              .chargerUtilisateurConnecte()
              .timeout(Duration(seconds: offlineNow ? 2 : 10));
          if (!offlineNow) SoneyaErrorCenter.reportNetworkSuccess();
        } catch (_) {}

        if (!RecoveryGuard.isActive) {
          await _goHomeBasedOnRole(userProvider);
        }

        if (!offlineNow) {
          await PushService.instance.showLaunchAdminIfPending();
        }
      }
    });
  } catch (e, st) {
    debugPrint('[main] init error: $e');
    SoneyaErrorCenter.showException(e, st);
  }
}

Future<void> main() async {
  await SoneyaErrorCenter.runZoned(() async {
    // ✅ important : ensureInitialized dans la même zone (réduit zone mismatch)
    WidgetsFlutterBinding.ensureInitialized();

    // ✅ guards + démarrage (pas de popup au boot)
    SoneyaErrorCenter.installGlobalGuards();
    SoneyaErrorCenter.markAppStartedNow();

    // ✅ évite les gros widgets d’erreur techniques
    ErrorWidget.builder = (FlutterErrorDetails details) {
      SoneyaErrorCenter.showException(details.exception, details.stack);
      return const SizedBox.shrink();
    };

    await Hive.initFlutter();
    await Hive.openBox(kAnnoncesBox);
    await Hive.openBox('hotels_box');
    await Hive.openBox('logement_feed_box');
    await Hive.openBox('logements_map_box_v1');
    await Hive.openBox('sante_box');
    await Hive.openBox('tourisme_box');
    await Hive.openBox('prestataires_box');
    await Hive.openBox('lieux_box');

    if (kIsWeb) setUrlStrategy(const HashUrlStrategy());

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    }

    await initSupabase();
    await _initConnectivityWatch();

    final userProvider = UserProvider();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider(
              create: (_) => FavorisProvider()..loadFavoris()),
          ChangeNotifierProvider(
            create: (_) => PrestatairesProvider()..loadPrestataires(),
          ),
        ],
        child: const MyApp(),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap(userProvider);
    });
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final light =
        AppTheme.light.copyWith(pageTransitionsTheme: _kSmoothTransitions);
    final dark =
        AppTheme.dark.copyWith(pageTransitionsTheme: _kSmoothTransitions);

    return MaterialApp(
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      onGenerateInitialRoutes: (_) {
        if (kIsWeb && _isRecoveryUrl(Uri.base)) {
          return [
            CupertinoPageRoute(
              settings: const RouteSettings(name: AppRoutes.resetPassword),
              builder: (_) => const ResetPasswordPage(),
            ),
          ];
        }
        return [
          CupertinoPageRoute(
            settings: const RouteSettings(name: AppRoutes.splash),
            builder: (_) => const SplashScreen(),
          ),
        ];
      },
      onGenerateRoute: AppRoutes.generateRoute,
      theme: light,
      darkTheme: dark,
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
      ],
      locale: const Locale('fr'),
      builder: (context, child) {
        final bg = Theme.of(context).scaffoldBackgroundColor;

        return ColoredBox(
          color: bg,
          child: Stack(
            children: [
              child ?? const SizedBox.shrink(),

              // ✅ Overlay global erreurs/offline
              SoneyaErrorCenter.overlay(),

              // ✅ Bannière offline du bas seulement si overlay pas affiché
              ValueListenableBuilder<bool>(
                valueListenable: _isOffline,
                builder: (_, offline, __) {
                  if (!offline || SoneyaErrorCenter.isShowing) {
                    return const SizedBox.shrink();
                  }

                  return Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: SafeArea(
                      top: false,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.black.withOpacity(.86),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: const [
                              Icon(Icons.wifi_off,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Connexion internet indisponible. Activez le Wi-Fi ou les données mobiles, ou vérifiez votre réseau.",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    height: 1.15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
