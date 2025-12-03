// lib/services/push_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/push_nav.dart';

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final SupabaseClient _sb = Supabase.instance.client;
  final FirebaseMessaging _fm = FirebaseMessaging.instance;

  bool _initialized = false;
  String? _lastToken;

  // Payload admin si l'app a été lancée depuis un état "terminé"
  Map<String, dynamic>? _launchAdminData;
  String? _launchAdminTitle;
  String? _launchAdminBody;

  /// Appelé depuis main.dart
  ///  - après runApp (session déjà existante)
  ///  - et après login dans onAuthStateChange
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

    // Demande la permission SEULEMENT quand user est connecté
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

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      debugPrint('[PushService] Nouveau token FCM = $token');
      _lastToken = token;
      unawaited(_saveTokenToSupabase(token));
    });

    _setupForegroundListener();
    _setupClickRouting();
  }

  // ============================================================
  // TOKEN
  // ============================================================

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

      // un seul device par user
      await _sb.from('push_devices').delete().eq('user_id', uid);

      await _sb.from('push_devices').insert({
        'user_id': uid,
        'token': token,
        'platform': 'android',
        'enabled': true,
        'locale': 'fr_FR',
      });

      debugPrint('[PushService] token enregistré en BDD (unique) ✔️');
    } catch (e) {
      debugPrint('[PushService] ERREUR token: $e');
    }
  }

  // ============================================================
  // FOREGROUND
  // ============================================================

  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('════════ FOREGROUND NOTIFICATION ════════');
      debugPrint('data = ${message.data}');
      debugPrint('notif = ${message.notification}');
      debugPrint('═════════════════════════════════════════');

      final data = message.data;
      final isAdmin = PushNav.isAdminPayload(data);

      if (isAdmin) {
        final title =
            data['title'] ?? message.notification?.title ?? 'Notification';
        final body = data['body'] ?? message.notification?.body ?? '';

        debugPrint('[PushService] → Popup admin (foreground)');
        await PushNav.showAdminDialog(
          title: title,
          body: body,
          data: data,
        );
        return;
      }

      debugPrint('[PushService] → Message normal foreground');
    });
  }

  // ============================================================
  // BACKGROUND / TERMINATED
  // ============================================================

  void _setupClickRouting() {
    // App en background → clic sur la notif
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      final data = message.data;

      if (PushNav.isAdminPayload(data)) {
        final title =
            data['title'] ?? message.notification?.title ?? 'Notification';
        final body = data['body'] ?? message.notification?.body ?? '';

        debugPrint('[PushService] → Popup admin (background click)');
        await PushNav.showAdminDialog(
          title: title,
          body: body,
          data: data,
        );
        return;
      }

      // sinon : notif message (chat, etc.)
      PushNav.openMessageFromData(data);
    });

    // App lancée depuis un état TERMINÉ (killed)
    _fm.getInitialMessage().then((message) async {
      if (message == null) return;

      final data = message.data;

      if (PushNav.isAdminPayload(data)) {
        final title =
            data['title'] ?? message.notification?.title ?? 'Notification';
        final body =
            data['body'] ?? message.notification?.body ?? 'Notification';

        debugPrint(
            '[PushService] Notif admin (terminated launch) → stockée en attente');
        _launchAdminData = data;
        _launchAdminTitle = title;
        _launchAdminBody = body;
        return;
      }

      // autre type: message de chat, etc.
      PushNav.openMessageFromData(data);
    });
  }

  /// À appeler depuis main.dart, APRÈS que Home / Welcome ont été ouverts.
  /// Permet d'éviter le "flash" du popup avant Home.
  Future<void> showLaunchAdminIfPending() async {
    if (_launchAdminData == null) return;

    final data = _launchAdminData!;
    final title = _launchAdminTitle ?? 'Notification';
    final body = _launchAdminBody ?? '';

    // reset pour ne pas rejouer plusieurs fois
    _launchAdminData = null;
    _launchAdminTitle = null;
    _launchAdminBody = null;

    debugPrint('[PushService] → Affichage popup admin retardé (launch)');
    await PushNav.showAdminDialog(
      title: title,
      body: body,
      data: data,
    );
  }
}
