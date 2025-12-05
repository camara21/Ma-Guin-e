// lib/services/push_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/push_nav.dart';
import '../navigation/nav_key.dart';

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final SupabaseClient _sb = Supabase.instance.client;
  final FirebaseMessaging _fm = FirebaseMessaging.instance;

  // Local notifications (internal)
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _lastToken;

  // If app launched from a "admin" notification while terminated
  Map<String, dynamic>? _launchAdminData;
  String? _launchAdminTitle;
  String? _launchAdminBody;

  // Android channel id
  static const String _androidChannelId = 'messages_channel';

  // Bannière in-app (foreground)
  OverlayEntry? _bannerEntry;
  Timer? _bannerTimer;

  /// Appelé depuis main.dart APRÈS runApp, et après login (onAuthStateChange).
  Future<void> initAndRegister() async {
    if (kIsWeb) {
      debugPrint('[PushService] Ignoré sur Web.');
      return;
    }

    final user = _sb.auth.currentUser;
    if (user == null) {
      debugPrint('[PushService] init ignoré → utilisateur NON connecté.');
      return;
    }

    if (_initialized) {
      debugPrint('[PushService] déjà initialisé → refresh token.');
      await _refreshTokenAndSave();
      return;
    }
    _initialized = true;

    debugPrint('[PushService] Initialisation FCM (utilisateur connecté)...');

    // initialise le plugin local (idempotent)
    await _initLocalNotifications();

    // demande permission (iOS) et obtient token
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

    await _refreshTokenAndSave();

    // token refresh listener
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      debugPrint('[PushService] Nouveau token FCM = $token');
      _lastToken = token;
      unawaited(_saveTokenToSupabase(token));
    });

    // listeners message
    _setupForegroundListener();
    _setupClickRouting();
  }

  // -------------------------
  // Notifications locales
  // -------------------------
  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings();

    const settings = InitializationSettings(android: android, iOS: iOS);

    await _localNotif.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse resp) {
        final payload = resp.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final Map<String, dynamic> data = jsonDecode(payload);
          // route selon kind / admin payload
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

    // create channel (idempotent)
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

  /// Méthode publique pour afficher une notif locale depuis le code (Supabase realtime etc.)
  void showLocalNotification(String? title, String? body,
      {Map<String, dynamic>? payload}) {
    _showLocalNotificationInternal(title, body, payload: payload);
  }

  // -------------------------
  // Token management
  // -------------------------
  Future<void> _refreshTokenAndSave() async {
    final user = _sb.auth.currentUser;
    if (user == null) {
      debugPrint('[PushService] refresh ignoré → pas de user.');
      return;
    }

    final token = await _fm.getToken();
    if (token == null) {
      debugPrint('[PushService] getToken() a renvoyé null.');
      return;
    }

    if (token == _lastToken) {
      debugPrint('[PushService] Token FCM inchangé.');
      return;
    }

    debugPrint('[PushService] Token FCM = $token');
    _lastToken = token;

    await _saveTokenToSupabase(token);
  }

  Future<void> _saveTokenToSupabase(String token) async {
    final user = _sb.auth.currentUser;
    if (user == null) return;
    final uid = user.id;

    try {
      debugPrint('[PushService] Enregistrement du token pour user=$uid');

      // supprime anciens devices -> un device par user (simple)
      await _sb.from('push_devices').delete().eq('user_id', uid);

      // platform proprement formatée
      String platform;
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

      // locale dynamique si possible
      String locale = 'fr_FR';
      try {
        locale = WidgetsBinding.instance.window.locale.toLanguageTag();
      } catch (_) {}

      await _sb.from('push_devices').insert({
        'user_id': uid,
        'token': token,
        'platform': platform,
        'enabled': true,
        'locale': locale,
      });

      debugPrint('[PushService] token enregistré en BDD (unique) ✔️');
    } catch (e) {
      debugPrint('[PushService] ERREUR token: $e');
    }
  }

  // -------------------------
  // Bannière in-app (foreground)
  // -------------------------
  void _showInAppMessageBanner(
    String title,
    String body, {
    required Map<String, dynamic> payload,
  }) {
    try {
      _bannerTimer?.cancel();
      _bannerEntry?.remove();
      _bannerTimer = null;
      _bannerEntry = null;

      final ctx =
          navKey.currentState?.overlay?.context ?? navKey.currentContext;
      if (ctx == null) {
        // fallback : vraie notif locale
        _showLocalNotificationInternal(title, body, payload: payload);
        return;
      }

      final overlay = Overlay.of(ctx);
      if (overlay == null) {
        _showLocalNotificationInternal(title, body, payload: payload);
        return;
      }

      final entry = OverlayEntry(
        builder: (context) {
          final mq = MediaQuery.of(context);
          final top = mq.padding.top + 8.0;

          return Positioned(
            top: top,
            left: 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {
                  _bannerTimer?.cancel();
                  _bannerEntry?.remove();
                  _bannerEntry = null;
                  // ouvrir directement la conversation
                  PushNav.openMessageFromData(payload);
                },
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, value, child) =>
                      Opacity(opacity: value, child: child),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              if (body.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

      overlay.insert(entry);
      _bannerEntry = entry;

      _bannerTimer = Timer(const Duration(seconds: 4), () {
        _bannerEntry?.remove();
        _bannerEntry = null;
      });
    } catch (e) {
      debugPrint('[PushService] banner error: $e');
      _showLocalNotificationInternal(title, body, payload: payload);
    }
  }

  // -------------------------
  // FOREGROUND listener
  // -------------------------
  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('════════ FOREGROUND FCM ════════');
      debugPrint('data = ${message.data}');
      debugPrint('notif = ${message.notification}');
      debugPrint('════════════════════════════════');

      final data = _normalizeIncomingData(message.data);
      final kind = (data['kind'] ?? data['type'] ?? '').toString();

      // 1) message chat -> bannière top (pas de notif système)
      if (kind == 'message') {
        debugPrint(
            '[PushService] → FCM "message" foreground (bannière in-app, pas notif système)');

        final title =
            (data['title'] ?? data['titre'] ?? 'Nouveau message').toString();
        final body = (data['body'] ?? data['contenu'] ?? '').toString();

        final payload = <String, dynamic>{
          'kind': 'message',
          'title': title,
          'body': body,
          ...data,
        };

        _showInAppMessageBanner(title, body, payload: payload);
        return;
      }

      // 2) admin payload -> popup overlay
      final isAdmin = PushNav.isAdminPayload(data);
      if (isAdmin) {
        final title =
            data['title'] ?? message.notification?.title ?? 'Notification';
        final body = data['body'] ?? message.notification?.body ?? '';

        debugPrint('[PushService] → Popup admin (foreground)');
        await PushNav.showAdminDialog(
          title: title.toString(),
          body: body.toString(),
          data: data,
        );
        return;
      }

      // 3) others -> show local notification
      final title =
          data['title'] ?? message.notification?.title ?? 'Notification';
      final body = data['body'] ?? message.notification?.body ?? '';
      _showLocalNotificationInternal(title.toString(), body.toString(),
          payload: data.isEmpty ? null : data);
    });
  }

  // Internal local notif helper used inside service (keeps try/catch)
  void _showLocalNotificationInternal(String? title, String? body,
      {Map<String, dynamic>? payload}) {
    try {
      _localNotif.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title ?? 'Notification',
        body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
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

  // -------------------------
  // BACKGROUND / CLICK routing
  // -------------------------
  void _setupClickRouting() {
    // App in background -> user taps a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      try {
        final data = _normalizeIncomingData(message.data);

        // admin?
        if (PushNav.isAdminPayload(data)) {
          final title =
              data['title'] ?? message.notification?.title ?? 'Notification';
          final body = data['body'] ?? message.notification?.body ?? '';
          await PushNav.showAdminDialog(
              title: title.toString(), body: body.toString(), data: data);
          return;
        }

        // otherwise open message/chat
        debugPrint('[PushService] onMessageOpenedApp → openMessageFromData');
        PushNav.openMessageFromData(data);
      } catch (e) {
        debugPrint('[PushService] onMessageOpenedApp error: $e');
      }
    });

    // App launched from terminated via notification
    _fm.getInitialMessage().then((RemoteMessage? message) async {
      if (message == null) return;

      try {
        final data = _normalizeIncomingData(message.data);

        // If admin payload, save for delayed popup after UI is ready
        if (PushNav.isAdminPayload(data)) {
          debugPrint('[PushService] Notif admin (terminated launch) → stockée');
          _launchAdminData = data;
          _launchAdminTitle =
              data['title'] ?? message.notification?.title ?? 'Notification';
          _launchAdminBody =
              data['body'] ?? message.notification?.body ?? 'Notification';
          return;
        }

        // otherwise open message
        debugPrint('[PushService] Launch from "message" notif (terminated)');
        PushNav.openMessageFromData(data);
      } catch (e) {
        debugPrint('[PushService] getInitialMessage handling error: $e');
      }
    });
  }

  /// Call from main.dart AFTER Home/Welcome are visible.
  Future<void> showLaunchAdminIfPending() async {
    if (_launchAdminData == null) return;
    final data = _launchAdminData!;
    final title = _launchAdminTitle ?? 'Notification';
    final body = _launchAdminBody ?? '';

    // reset
    _launchAdminData = null;
    _launchAdminTitle = null;
    _launchAdminBody = null;

    debugPrint('[PushService] → Affichage popup admin retardé (launch)');
    await PushNav.showAdminDialog(title: title, body: body, data: data);
  }

  // -------------------------
  // Helpers
  // -------------------------
  /// Normalise incoming data: decode JSON strings, flatten nested "data" maps/strings.
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
}
