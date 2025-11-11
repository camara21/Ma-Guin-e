// lib/services/push_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/widgets.dart' show WidgetsBinding;

import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushService {
  PushService._();
  static final instance = PushService._();

  final _sb = Supabase.instance.client;
  final _fm = FirebaseMessaging.instance;
  final _fln = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'messages_channel',
    'Messages',
    description: 'Notifications de messages',
    importance: Importance.high,
  );

  bool _started = false; // ✅ une seule init
  StreamSubscription<String>? _tokenSub; // ✅ pour nettoyer au signout

  Future<void> initAndRegister() async {
    // 0) Sécurité : uniquement si connecté
    final userId = _sb.auth.currentUser?.id;
    if (userId == null) return;

    // 1) Ne pas lancer 2x
    if (_started) return;
    _started = true;

    await _initLocalNotifications();

    // 2) Demander la permission *après* login (ici) et seulement ici
    final settings = await _fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // iOS: autoriser l’affichage en foreground (n’affiche rien sans notif explicite)
    await _fm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Si l’utilisateur refuse → on arrête proprement
    if (settings.authorizationStatus == AuthorizationStatus.denied ||
        settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      return;
    }

    // 3) Récupérer le token
    String? token;
    if (kIsWeb) {
      final vapid =
          const String.fromEnvironment('FCM_VAPID_KEY', defaultValue: '');
      token = await _fm.getToken(vapidKey: vapid.isEmpty ? null : vapid);
    } else {
      token = await _fm.getToken();
    }
    if (token == null || token.isEmpty) return;

    // 4) Upsert métadonnées
    final platform = _platformString(); // android / ios / web / other
    String model = 'unknown';
    if (kIsWeb) {
      try {
        // ignore: undefined_prefixed_name
        final ua = const String.fromEnvironment('FLUTTER_WEB_USER_AGENT');
        if (ua.isNotEmpty) model = ua;
      } catch (_) {}
    }
    final pkg = await PackageInfo.fromPlatform();
    final locale = WidgetsBinding.instance.platformDispatcher.locale.toString();

    await _sb.from('push_devices').upsert({
      'user_id': userId,
      'token': token,
      'platform': platform,
      'model': model,
      'app_version': pkg.version,
      'enabled': true,
      'locale': locale,
    }, onConflict: 'user_id,token');

    // 5) RPC: activer ce token et désactiver les autres de l’utilisateur
    await _sb.rpc('enable_push_token', params: {
      'p_user': userId,
      'p_token': token,
    });

    // 6) Renouvellement de token (attaché à l’utilisateur courant)
    _tokenSub?.cancel();
    _tokenSub = _fm.onTokenRefresh.listen((t) async {
      try {
        final uid = _sb.auth.currentUser?.id;
        if (uid == null) return; // si déconnecté pendant le refresh
        await _sb.from('push_devices').upsert({
          'user_id': uid,
          'token': t,
          'platform': platform,
          'enabled': true,
        }, onConflict: 'user_id,token');

        await _sb.rpc('enable_push_token', params: {
          'p_user': uid,
          'p_token': t,
        });
      } catch (_) {}
    });

    // 7) Affichage local en foreground — seulement si permission accordée
    FirebaseMessaging.onMessage.listen((RemoteMessage m) async {
      if (!await _hasNotifPermission()) return; // ✅ garde anti-popup
      final n = m.notification;
      if (n == null) return;
      await _fln.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        n.title ?? 'Notification',
        n.body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            // on force l’icône app si null
            icon: n.android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: m.data.isEmpty ? null : m.data.toString(),
      );
    });
  }

  Future<void> disableForThisDevice() async {
    final userId = _sb.auth.currentUser?.id;
    final token = await _fm.getToken();
    if (userId == null || token == null) return;
    await _sb
        .from('push_devices')
        .update({'enabled': false})
        .eq('user_id', userId)
        .eq('token', token);
  }

  Future<void> signOutCleanup() async {
    // Nettoyage DB pour ce device + écouteurs
    _tokenSub?.cancel();
    _tokenSub = null;
    _started = false;

    final userId = _sb.auth.currentUser?.id;
    final token = await _fm.getToken();
    if (userId == null || token == null) return;
    await _sb
        .from('push_devices')
        .delete()
        .eq('user_id', userId)
        .eq('token', token);
  }

  Future<void> _initLocalNotifications() async {
    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const init = InitializationSettings(android: initAndroid, iOS: initIOS);
    await _fln.initialize(init);

    final androidImpl = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_channel);
    // ⚠️ on ne demande pas la permission Android 13+ ici : on la déclenche via FCM requestPermission après login
  }

  Future<bool> _hasNotifPermission() async {
    final s = await _fm.getNotificationSettings();
    return s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
  }

  String _platformString() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'other';
    }
  }
}
