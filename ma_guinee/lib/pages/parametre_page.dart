import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/utilisateur_model.dart';
import '../providers/user_provider.dart';
import '../routes.dart';
import 'modifier_profil_page.dart';

class ParametrePage extends StatefulWidget {
  final UtilisateurModel user;

  const ParametrePage({super.key, required this.user});

  @override
  State<ParametrePage> createState() => _ParametrePageState();
}

class _ParametrePageState extends State<ParametrePage> with WidgetsBindingObserver {
  bool _notifEnabled = false;
  bool _busy = false;

  static const String _vapidKey =
      'BNEG_lKXVJrvVDLYkI5ZJbLQSyfxZpLtaTDPgCMKOCnoisvDiqtCfS_tF5f57oGCa92obijXr6AYe-_QcAkOe2c';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Si l'utilisateur revient de paramètres système, on resynchronise.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncWithSystemPermission();
    }
  }

  Future<void> _bootstrap() async {
    // 1) Charger la préférence locale (au cas où)
    await _loadNotifPref();
    // 2) Mais la vérité vient du système : on synchronise pour que le switch
    //    reflète exactement l'autorisation OS + état FCM.
    await _syncWithSystemPermission();
  }

  Future<void> _loadNotifPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifEnabled = prefs.getBool('notif_enabled') ?? false;
    });
  }

  Future<void> _saveNotifPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_enabled', value);
  }

  /// Lit l’état système (autorisation OS) et aligne le switch + FCM.
  Future<void> _syncWithSystemPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      final systemAllowed = settings.authorizationStatus == AuthorizationStatus.authorized
          || settings.authorizationStatus == AuthorizationStatus.provisional;

      // Si le système autorise, on s'assure que FCM est prêt; sinon on coupe.
      if (systemAllowed) {
        await FirebaseMessaging.instance.setAutoInitEnabled(true);
        // On ne force pas de getToken ici pour éviter de réafficher une popup.
        setState(() => _notifEnabled = true);
        await _saveNotifPref(true);
      } else {
        await _disablePush(); // coupe token + auto-init si besoin
        setState(() => _notifEnabled = false);
        await _saveNotifPref(false);
      }
    } catch (_) {
      // en cas d'erreur, on ne casse rien
    }
  }

  Future<void> _onToggleNotifications(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      if (value) {
        final ok = await _enablePush();
        if (!ok) {
          // Autorisation refusée → rester décoché
          setState(() => _notifEnabled = false);
          await _saveNotifPref(false);
          return;
        }
        setState(() => _notifEnabled = true);
        await _saveNotifPref(true);
      } else {
        await _disablePush();
        setState(() => _notifEnabled = false);
        await _saveNotifPref(false);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- Helpers Supabase (optionnels) ----------
  Future<void> _upsertUserToken(String token) async {
    try {
      final sb = Supabase.instance.client;
      await sb.from('user_tokens').upsert({
        'user_id': widget.user.id,
        'token': token,
        'platform': kIsWeb ? 'web' : 'mobile',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,token');
    } catch (_) {}
  }

  Future<void> _deleteUserTokens() async {
    try {
      final sb = Supabase.instance.client;
      await sb.from('user_tokens').delete().eq('user_id', widget.user.id);
    } catch (_) {}
  }

  /// Active les notifications après geste utilisateur (switch ON)
  Future<bool> _enablePush() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Vérifier l'état actuel avant de demander à nouveau
      NotificationSettings settings = await messaging.getNotificationSettings();

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        // Demande d'autorisation si non encore accordée
        settings = await messaging.requestPermission(
          alert: true,
          sound: true,
          badge: true,
          provisional: false,
        );
      }

      final allowed = settings.authorizationStatus == AuthorizationStatus.authorized
          || settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!allowed) return false;

      // Activer l'auto-init pour générer/régénérer un token si besoin
      await messaging.setAutoInitEnabled(true);

      // Récupérer le token (web: VAPID)
      final String? token = kIsWeb
          ? await messaging.getToken(vapidKey: _vapidKey)
          : await messaging.getToken();

      if (token == null) return false;

      // iOS: autoriser l'affichage au premier plan
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Enregistrer côté serveur (facultatif)
      await _upsertUserToken(token);

      // Pas de SnackBars : on reste silencieux comme demandé
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Désactive les notifications (switch OFF)
  Future<void> _disablePush() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Nettoyage serveur (optionnel)
      await _deleteUserTokens();

      // Supprimer le token local
      await messaging.deleteToken();

      // Couper l'auto-init pour éviter recréation
      await messaging.setAutoInitEnabled(false);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _busy;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Paramètres',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // Bouton discret pour resynchroniser manuellement si besoin
          IconButton(
            tooltip: 'Resynchroniser',
            onPressed: isLoading ? null : _syncWithSystemPermission,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        children: [
          Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                // --- Toggle Notifications push ---
                SwitchListTile.adaptive(
                  secondary:
                      const Icon(Icons.notifications_active, color: Colors.teal),
                  title: const Text('Notifications push'),
                  // Sous-titre simple, sans messages de "prêt"
                  subtitle: Text(
                    isLoading
                        ? 'Activation en cours…'
                        : _notifEnabled
                            ? 'Notifications activées'
                            : 'Notifications désactivées',
                  ),
                  value: _notifEnabled,
                  onChanged: isLoading ? null : _onToggleNotifications,
                ),
                const Divider(height: 0),

                ListTile(
                  leading: const Icon(Icons.person, color: Colors.blue),
                  title: const Text('Modifier mon profil'),
                  onTap: () async {
                    final modified = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ModifierProfilPage(user: widget.user),
                      ),
                    );
                    if (modified == true) {
                      await Provider.of<UserProvider>(context, listen: false)
                          .chargerUtilisateurConnecte();
                      if (mounted) Navigator.pop(context, true);
                    }
                  },
                ),
                const Divider(height: 0),

                ListTile(
                  leading: const Icon(Icons.lock_reset, color: Colors.orange),
                  title: const Text('Mot de passe oublié ?'),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.forgotPassword,
                      arguments: {'prefillEmail': widget.user.email},
                    );
                  },
                ),
                const Divider(height: 0),

                ListTile(
                  leading: const Icon(Icons.delete_forever,
                      color: Colors.red, size: 28),
                  title: const Text(
                    'Supprimer mon compte',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Supprimer mon compte'),
                        content: const Text(
                          'Cette action est irréversible. Es-tu sûr de vouloir supprimer ton compte ?',
                        ),
                        actions: [
                          TextButton(
                            child: const Text('Annuler'),
                            onPressed: () => Navigator.of(ctx).pop(false),
                          ),
                          TextButton(
                            child: const Text('Supprimer',
                                style: TextStyle(color: Colors.red)),
                            onPressed: () => Navigator.of(ctx).pop(true),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await Supabase.instance.client
                            .from('utilisateurs')
                            .delete()
                            .eq('id', widget.user.id);

                        // ⚠️ nécessite Service Role côté serveur.
                        await Supabase.instance.client.auth.admin
                            .deleteUser(widget.user.id);

                        await Supabase.instance.client.auth.signOut();
                        if (!mounted) return;
                        Navigator.of(context).popUntil((route) => route.isFirst);
                        // Pas de SnackBar — on reste discret comme demandé
                      } catch (e) {
                        if (!mounted) return;
                        // On peut garder un feedback d'erreur minimal si tu préfères le silence total, supprime aussi ceci
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
