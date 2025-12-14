// lib/services/push_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../navigation/push_nav.dart';
import '../navigation/nav_key.dart';

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final SupabaseClient _sb = Supabase.instance.client;
  final FirebaseMessaging _fm = FirebaseMessaging.instance;

  // Local notifications (mobile uniquement)
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  String? _lastToken;
  String? _lastSavedUserId;

  Map<String, dynamic>? _launchAdminData;
  String? _launchAdminTitle;
  String? _launchAdminBody;

  static const String _androidChannelId = 'messages_channel';

  OverlayEntry? _bannerEntry;
  Timer? _bannerTimer;

  // --------------------------
  // Opt-in utilisateur (app)
  // --------------------------
  static const String _optInPrefKey = 'notif_opt_in';

  Future<bool> _isOptedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_optInPrefKey) ?? false; // défaut OFF
    } catch (_) {
      return false;
    }
  }

  // =========================================================
  // WEB (FCM)
  // =========================================================
  static const String _webVapidKey = String.fromEnvironment(
    'WEB_VAPID_KEY',
    defaultValue: '',
  );

  bool get _isWebIosLike {
    if (!kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  // ---------------------------------------------------------
  // Public API
  // ---------------------------------------------------------

  /// Appelé depuis main.dart après login.
  /// IMPORTANT: respecte le consentement utilisateur (notif_opt_in).
  Future<void> initAndRegister() async {
    final user = _sb.auth.currentUser;
    if (user == null) {
      debugPrint('[PushService] init ignoré → utilisateur NON connecté.');
      return;
    }

    // ✅ Garde-fou légal : si l’utilisateur n’a pas opt-in, on ne fait RIEN.
    final optedIn = await _isOptedIn();
    if (!optedIn) {
      debugPrint(
          '[PushService] opt-in = false → push désactivé (pas d’enregistrement).');
      // On coupe auto-init pour éviter recréation silencieuse
      try {
        await _fm.setAutoInitEnabled(false);
      } catch (_) {}
      return;
    }

    // ---------------- WEB ----------------
    if (kIsWeb) {
      _initialized = true;
      debugPrint('[PushService] Web détecté → init web soft (sans prompt).');
      await _refreshWebTokenSilentlyIfGranted();
      return;
    }

    // -------------- MOBILE --------------
    if (_initialized) {
      debugPrint('[PushService] déjà initialisé → refresh token/save.');
      await _refreshTokenAndSave();
      return;
    }
    _initialized = true;

    debugPrint('[PushService] Initialisation FCM (utilisateur connecté)...');

    await _initLocalNotifications();

    // ✅ Permission : ici c’est OK car opt-in déjà donné
    final settings = await _fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[PushService] permission = ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[PushService] Permission refusée → aucun token FCM.');
      return;
    }

    await _fm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _fm.setAutoInitEnabled(true);

    await _refreshTokenAndSave();

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      debugPrint('[PushService] Nouveau token FCM = $token');
      _lastToken = token;

      unawaited(_saveTokenToSupabase(token).then((_) {
        final uid = _sb.auth.currentUser?.id;
        if (uid != null) _lastSavedUserId = uid;
      }));
    });

    _setupForegroundListener();
    _setupClickRouting();
  }

  /// À appeler quand l’utilisateur désactive (switch OFF)
  /// => coupe local + serveur.
  Future<void> disableForCurrentUser() async {
    final user = _sb.auth.currentUser;
    if (user == null) return;

    try {
      // 1) Récupérer token courant si possible (pour disable côté serveur)
      final token = kIsWeb
          ? await _fm.getToken(
              vapidKey: _webVapidKey.isEmpty ? null : _webVapidKey)
          : await _fm.getToken();

      // 2) Supprimer token local
      await _fm.deleteToken();

      // 3) Couper auto-init (évite recréation au refresh)
      await _fm.setAutoInitEnabled(false);

      // 4) Désactiver côté serveur (important)
      if (token != null && token.trim().isNotEmpty) {
        await _disableTokenServerSide(token.trim());
      } else {
        // fallback : désactive par user_id si possible (selon RLS / RPC)
        await _disableUserServerSide(user.id);
      }
    } catch (e) {
      debugPrint('[PushService] disableForCurrentUser error: $e');
    } finally {
      _lastSavedUserId = null;
      _lastToken = null;
      _initialized = false;
    }
  }

  /// WEB : à appeler depuis un bouton "Activer notifications"
  /// (uniquement si opt-in true côté app).
  Future<bool> requestWebPermissionAndRegister() async {
    if (!kIsWeb) return false;

    final user = _sb.auth.currentUser;
    if (user == null) {
      debugPrint(
          '[PushService] Web register ignoré → utilisateur NON connecté.');
      return false;
    }

    final optedIn = await _isOptedIn();
    if (!optedIn) {
      debugPrint('[PushService] opt-in = false → refuse register web.');
      return false;
    }

    if (_isWebIosLike) {
      debugPrint(
          '[PushService] Safari iOS détecté → FCM Web Push non supporté.');
      return false;
    }

    if (_webVapidKey.trim().isEmpty) {
      debugPrint(
          '[PushService] WEB_VAPID_KEY manquant → getToken web impossible.');
      return false;
    }

    try {
      final settings = await _fm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint(
          '[PushService] web permission = ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[PushService] Web permission refusée.');
        return false;
      }

      await _fm.setAutoInitEnabled(true);

      final token = await _fm.getToken(vapidKey: _webVapidKey);
      if (token == null || token.trim().isEmpty) {
        debugPrint('[PushService] Web getToken() a renvoyé null/vide.');
        return false;
      }

      _lastToken = token;
      await _saveTokenToSupabase(token, forcePlatform: 'web');
      _lastSavedUserId = user.id;

      debugPrint('[PushService] Web token enregistré ✔️');
      return true;
    } catch (e) {
      debugPrint('[PushService] Web permission/register error: $e');
      return false;
    }
  }

  Future<void> onLogoutCleanup() async {
    // Logout ≠ opt-out. On ne touche pas au consentement ici.
    _lastSavedUserId = null;
    _lastToken = null;
    _initialized = false;
  }

  // ---------------------------------------------------------
  // Local notifications (mobile)
  // ---------------------------------------------------------

  Future<void> _initLocalNotifications() async {
    if (kIsWeb) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: iOS);

    await _localNotif.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse resp) {
        if (resp.notificationResponseType !=
            NotificationResponseType.selectedNotification) {
          return;
        }

        final payload = resp.payload;
        if (payload == null || payload.isEmpty) return;

        try {
          final Map<String, dynamic> data = jsonDecode(payload);

          if ((data['kind'] == 'message' || data['type'] == 'message')) {
            PushNav.openMessageFromData(data);
          } else if (PushNav.isAdminPayload(data)) {
            PushNav.showAdminDialog(
              title: data['title']?.toString() ?? 'Notification',
              body: data['body']?.toString() ?? '',
              data: data,
            );
          }
        } catch (e) {
          debugPrint('[PushService] erreur parse payload local notif: $e');
        }
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _androidChannelId,
      'Messages',
      description: 'Notifications de messages',
      importance: Importance.high,
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void showLocalNotification(
    String? title,
    String? body, {
    Map<String, dynamic>? payload,
  }) {
    if (kIsWeb) return;

    final kind =
        (payload?['kind'] ?? payload?['type'])?.toString().toLowerCase();

    if (kind == 'message') {
      final state = WidgetsBinding.instance.lifecycleState;
      final isForeground = state == AppLifecycleState.resumed;
      if (isForeground) return;
    }

    final t = title?.trim() ?? '';
    final b = body?.trim() ?? '';
    if (t.isEmpty && b.isEmpty) return;

    _showLocalNotificationInternal(title, body, payload: payload);
  }

  void _showLocalNotificationInternal(
    String? title,
    String? body, {
    Map<String, dynamic>? payload,
  }) {
    if (kIsWeb) return;

    try {
      final t = title?.trim() ?? '';
      final b = body?.trim() ?? '';
      if (t.isEmpty && b.isEmpty) return;

      _localNotif.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        t.isEmpty ? 'Notification' : t,
        b,
        NotificationDetails(
          android: const AndroidNotificationDetails(
            _androidChannelId,
            'Messages',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload == null ? null : jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('[PushService] _showLocalNotificationInternal error: $e');
    }
  }

  // ---------------------------------------------------------
  // Token management
  // ---------------------------------------------------------

  Future<void> _refreshTokenAndSave() async {
    final user = _sb.auth.currentUser;
    if (user == null) return;

    final uid = user.id;

    final token = await _fm.getToken();
    if (token == null || token.trim().isEmpty) return;

    final sameToken = token == _lastToken;
    final sameUser = uid == _lastSavedUserId;

    if (sameToken && sameUser) return;

    _lastToken = token;

    await _saveTokenToSupabase(token);
    _lastSavedUserId = uid;
  }

  Future<void> _saveTokenToSupabase(
    String token, {
    String? forcePlatform,
  }) async {
    final user = _sb.auth.currentUser;
    if (user == null) return;

    try {
      String platform;
      if (forcePlatform != null) {
        platform = forcePlatform;
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.iOS:
          case TargetPlatform.macOS:
            platform = 'ios';
            break;
          case TargetPlatform.android:
            platform = 'android';
            break;
          default:
            platform = 'other';
        }
      }

      String locale = 'fr-FR';
      try {
        locale =
            WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();
      } catch (_) {}

      await _sb.rpc('register_push_device', params: {
        'p_token': token,
        'p_platform': platform,
        'p_locale': locale,
      });

      debugPrint('[PushService] token enregistré via RPC ✔️');
    } catch (e) {
      debugPrint('[PushService] ERREUR token RPC: $e');
    }
  }

  Future<void> _disableTokenServerSide(String token) async {
    // Recommande un RPC SECURITY DEFINER (voir SQL plus bas)
    try {
      await _sb.rpc('disable_push_device', params: {'p_token': token});
      return;
    } catch (_) {}

    // fallback (si RLS le permet)
    try {
      await _sb.from('push_devices').update({
        'enabled': false,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('token', token);
    } catch (_) {}
  }

  Future<void> _disableUserServerSide(String uid) async {
    try {
      await _sb.from('push_devices').update({
        'enabled': false,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('user_id', uid);
    } catch (_) {}
  }

  Future<void> _refreshWebTokenSilentlyIfGranted() async {
    if (!kIsWeb) return;

    final user = _sb.auth.currentUser;
    if (user == null) return;

    final optedIn = await _isOptedIn();
    if (!optedIn) return;

    if (_isWebIosLike) return;
    if (_webVapidKey.trim().isEmpty) return;

    try {
      final token = await _fm.getToken(vapidKey: _webVapidKey);
      if (token == null || token.trim().isEmpty) return;

      final uid = user.id;
      final sameToken = token == _lastToken;
      final sameUser = uid == _lastSavedUserId;
      if (sameToken && sameUser) return;

      _lastToken = token;
      await _saveTokenToSupabase(token, forcePlatform: 'web');
      _lastSavedUserId = uid;
    } catch (_) {}
  }

  // ---------------------------------------------------------
  // FCM listeners
  // ---------------------------------------------------------

  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final data = _normalizeIncomingData(message.data);
      final kind = (data['kind'] ?? data['type'] ?? '').toString();

      if (kind == 'message') return;

      if (PushNav.isAdminPayload(data)) {
        final title =
            data['title'] ?? message.notification?.title ?? 'Notification';
        final body = data['body'] ?? message.notification?.body ?? '';
        await PushNav.showAdminDialog(
          title: title.toString(),
          body: body.toString(),
          data: data,
        );
        return;
      }

      final title =
          data['title'] ?? message.notification?.title ?? 'Notification';
      final body = data['body'] ?? message.notification?.body ?? '';
      _showLocalNotificationInternal(
        title.toString(),
        body.toString(),
        payload: data.isEmpty ? null : data,
      );
    });
  }

  void _setupClickRouting() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      try {
        final data = _normalizeIncomingData(message.data);

        if (PushNav.isAdminPayload(data)) {
          final title =
              data['title'] ?? message.notification?.title ?? 'Notification';
          final body = data['body'] ?? message.notification?.body ?? '';
          await PushNav.showAdminDialog(
            title: title.toString(),
            body: body.toString(),
            data: data,
          );
          return;
        }

        PushNav.openMessageFromData(data);
      } catch (_) {}
    });

    _fm.getInitialMessage().then((RemoteMessage? message) async {
      if (message == null) return;

      try {
        final data = _normalizeIncomingData(message.data);

        if (PushNav.isAdminPayload(data)) {
          _launchAdminData = data;
          _launchAdminTitle =
              data['title'] ?? message.notification?.title ?? 'Notification';
          _launchAdminBody =
              data['body'] ?? message.notification?.body ?? 'Notification';
          return;
        }

        PushNav.openMessageFromData(data);
      } catch (_) {}
    });
  }

  Future<void> showLaunchAdminIfPending() async {
    if (_launchAdminData == null) return;

    final data = _launchAdminData!;
    final title = _launchAdminTitle ?? 'Notification';
    final body = _launchAdminBody ?? '';

    _launchAdminData = null;
    _launchAdminTitle = null;
    _launchAdminBody = null;

    await PushNav.showAdminDialog(title: title, body: body, data: data);
  }

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
            out[k] = jsonDecode(s);
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
            decoded.forEach((nk, nv) {
              if (!out.containsKey(nk)) out[nk] = nv;
            });
          }
        } catch (_) {}
      } else if (nested is Map) {
        (nested as Map).forEach((nk, nv) {
          if (!out.containsKey(nk)) out[nk] = nv;
        });
      }
    }

    return out;
  }
}
