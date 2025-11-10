// lib/services/push_service.dart (avec RPC enable_push_token)
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/widgets.dart' show WidgetsBinding;

import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushService {
  PushService._();
  static final instance = PushService._();

  final _sb  = Supabase.instance.client;
  final _fm  = FirebaseMessaging.instance;
  final _fln = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'messages_channel',
    'Messages',
    description: 'Notifications de messages',
    importance: Importance.high,
  );

  Future<void> initAndRegister() async {
    await _initLocalNotifications();

    // Permissions
    final settings = await _fm.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );
    await _fm.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Token
    String? token;
    if (kIsWeb) {
      final vapid = const String.fromEnvironment('FCM_VAPID_KEY', defaultValue: '');
      token = await _fm.getToken(vapidKey: vapid.isEmpty ? null : vapid);
    } else {
      token = await _fm.getToken();
    }
    if (token == null || token.isEmpty) return;

    // Métadonnées minimales
    final platform = _platformString(); // android / ios / web / other
    String model = 'unknown';
    if (kIsWeb) {
      try {
        // ignore: undefined_prefixed_name
        final ua = const String.fromEnvironment('FLUTTER_WEB_USER_AGENT');
        if (ua.isNotEmpty) model = ua;
      } catch (_) {}
    }

    final pkg    = await PackageInfo.fromPlatform();
    final userId = _sb.auth.currentUser?.id;
    if (userId == null) return;
    final locale = WidgetsBinding.instance.platformDispatcher.locale.toString();

    // 1) Upsert métadonnées pour ce token
    await _sb.from('push_devices').upsert({
      'user_id'     : userId,
      'token'       : token,
      'platform'    : platform,
      'model'       : model,
      'app_version' : pkg.version,
      'enabled'     : true,
      'locale'      : locale,
    }, onConflict: 'user_id,token');

    // 2) Enforce "un seul token actif" via RPC
    await _sb.rpc('enable_push_token', params: {
      'p_user': userId,
      'p_token': token,
    });

    // Refresh token → upsert + RPC
    _fm.onTokenRefresh.listen((t) async {
      try {
        await _sb.from('push_devices').upsert({
          'user_id'  : userId,
          'token'    : t,
          'platform' : platform,
          'enabled'  : true,
        }, onConflict: 'user_id,token');

        await _sb.rpc('enable_push_token', params: {
          'p_user': userId,
          'p_token': t,
        });
      } catch (_) {}
    });

    // Affichage local en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage m) async {
      final n = m.notification;
      if (n == null) return;
      await _fln.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        n.title ?? 'Notification',
        n.body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id, _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: n.android?.smallIcon,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: m.data.isEmpty ? null : m.data.toString(),
      );
    });
  }

  Future<void> disableForThisDevice() async {
    final userId = _sb.auth.currentUser?.id;
    final token  = await _fm.getToken();
    if (userId == null || token == null) return;
    await _sb.from('push_devices')
        .update({'enabled': false})
        .eq('user_id', userId)
        .eq('token', token);
  }

  Future<void> signOutCleanup() async {
    final userId = _sb.auth.currentUser?.id;
    final token  = await _fm.getToken();
    if (userId == null || token == null) return;
    await _sb.from('push_devices')
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

    final androidImpl =
        _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_channel);
  }

  String _platformString() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return 'android';
      case TargetPlatform.iOS:     return 'ios';
      default:                     return 'other';
    }
  }
}
