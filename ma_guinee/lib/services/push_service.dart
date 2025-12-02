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

  /// Appelé depuis main.dart : `PushService.instance.initAndRegister()`
  Future<void> initAndRegister() async {
    // Ce service est uniquement pour mobile, on ignore le Web
    if (kIsWeb) {
      debugPrint('[PushService] init ignoré sur Web.');
      return;
    }

    if (_initialized) {
      debugPrint('[PushService] déjà initialisé, refresh token éventuel.');
      await _refreshTokenIfNeeded();
      return;
    }
    _initialized = true;

    debugPrint('[PushService] initialisation FCM...');

    // Demande de permission (Android 13+ & iOS)
    final settings = await _fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      '[PushService] permission status = ${settings.authorizationStatus}',
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[PushService] permission refusée → pas de token.');
      return;
    }

    // Token initial
    await _refreshTokenIfNeeded();

    // Ecoute des changements de token
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      debugPrint('[PushService] onTokenRefresh = $token');
      _lastToken = token;
      unawaited(_saveTokenToSupabase(token));
    });

    // Messages FCM
    _setupForegroundListener();
    _setupClickRouting();
  }

  /// Récupère le token FCM et le pousse en BDD si nécessaire.
  Future<void> _refreshTokenIfNeeded() async {
    final user = _sb.auth.currentUser;
    if (user == null) {
      debugPrint('[PushService] pas de user connecté → skip token.');
      return;
    }

    final token = await _fm.getToken();
    if (token == null) {
      debugPrint('[PushService] getToken() a renvoyé null.');
      return;
    }

    if (token == _lastToken) {
      // Token identique, rien à faire
      return;
    }

    debugPrint('[PushService] FCM token courant = $token');

    _lastToken = token;
    await _saveTokenToSupabase(token);
  }

  /// Sauvegarde le token FCM dans `public.push_devices`.
  ///
  /// Stratégie : 1 seule ligne par user :
  ///   - DELETE tous les anciens devices pour ce user
  ///   - INSERT du nouveau device (android, enabled = true)
  Future<void> _saveTokenToSupabase(String token) async {
    final user = _sb.auth.currentUser;
    if (user == null) return;

    final uid = user.id;
    const platform = 'android';

    try {
      debugPrint('[PushService] enregistrement token pour user=$uid');

      // 1) Supprimer tous les anciens devices de ce user
      await _sb.from('push_devices').delete().eq('user_id', uid);

      // 2) Insérer le nouveau device unique
      await _sb.from('push_devices').insert({
        'user_id': uid,
        'token': token,
        'platform': platform,
        'enabled': true,
        'locale': 'fr_FR',
      });

      debugPrint(
        '[PushService] token enregistré en BDD ✅ (single row par user)',
      );
    } catch (e, st) {
      debugPrint('[PushService] ERREUR enregistrement token: $e');
      debugPrint('[PushService] stack: $st');
    }
  }

  /// Messages reçus quand l’app est au premier plan.
  /// Pour l’instant on log seulement, sans afficher de notif système.
  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '[PushService] onMessage (foreground) data=${message.data} '
        'notification=${message.notification}',
      );
      // Si tu veux plus tard afficher une bannière in-app ou rafraîchir un compteur,
      // c’est ici qu’on le fera.
    });
  }

  /// Routing quand l’utilisateur clique sur une notif FCM :
  ///  - app en background
  ///  - app lancée depuis un état "terminé"
  void _setupClickRouting() {
    // App en background → clique sur la notif FCM
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      try {
        final data = message.data;
        debugPrint('[PushService] onMessageOpenedApp data=$data');
        PushNav.openMessageFromData(data);
      } catch (e, st) {
        debugPrint('[PushService] erreur onMessageOpenedApp: $e');
        debugPrint('[PushService] stack: $st');
      }
    });

    // App lancée depuis une notif FCM (terminated → launch)
    _fm.getInitialMessage().then((RemoteMessage? message) {
      if (message == null) return;
      try {
        final data = message.data;
        debugPrint('[PushService] getInitialMessage data=$data');
        PushNav.openMessageFromData(data);
      } catch (e, st) {
        debugPrint('[PushService] erreur getInitialMessage: $e');
        debugPrint('[PushService] stack: $st');
      }
    });
  }
}
