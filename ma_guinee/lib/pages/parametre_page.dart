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

class _ParametrePageState extends State<ParametrePage>
    with WidgetsBindingObserver {
  bool _busy = false;

  // ✅ Choix utilisateur (consentement app)
  bool _optIn = false;

  // ✅ Permission OS (réalité système)
  bool _systemAllowed = false;

  static const String _prefKey = 'notif_opt_in';

  static const String _vapidKey =
      'BNEG_lKXVJrvVDLYkI5ZJbLQSyfxZpLtaTDPgCMKOCnoisvDiqtCfS_tF5f57oGCa92obijXr6AYe-_QcAkOe2c';

  bool get _effectiveEnabled => _optIn && _systemAllowed;

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
    await _loadOptInPref();
    await _syncWithSystemPermission();
    // ⚠️ IMPORTANT: on ne force JAMAIS opt-in à true ici.
    // On ne fait qu’appliquer l’état final.
    await _applyEffectiveStateSilently();
  }

  Future<void> _loadOptInPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _optIn =
          prefs.getBool(_prefKey) ?? false; // par défaut OFF (consentement)
    });
  }

  Future<void> _saveOptInPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  /// Lit l’état système (autorisation OS) et met à jour _systemAllowed.
  /// Ne touche PAS au consentement utilisateur (_optIn).
  Future<void> _syncWithSystemPermission() async {
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();

      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!mounted) return;
      setState(() => _systemAllowed = allowed);
    } catch (_) {
      // On laisse l'état existant
    }
  }

  Future<void> _onToggleNotifications(bool wantEnable) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      if (wantEnable) {
        // L’utilisateur donne son consentement => on enregistre d’abord
        _optIn = true;
        await _saveOptInPref(true);

        final ok = await _enablePushWithPromptIfNeeded();
        if (!ok) {
          // Permission refusée => on revient OFF + consentement OFF
          _optIn = false;
          await _saveOptInPref(false);
          if (mounted) setState(() {});
          return;
        }
      } else {
        // L’utilisateur retire son consentement => OFF durable
        _optIn = false;
        await _saveOptInPref(false);
        await _disablePush();
      }

      if (mounted) setState(() {});
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

  /// Applique l'état final sans afficher de popup :
  /// - si (_optIn && _systemAllowed) => auto-init ON + token si possible
  /// - sinon => auto-init OFF (et pas de recréation)
  Future<void> _applyEffectiveStateSilently() async {
    try {
      final messaging = FirebaseMessaging.instance;

      if (_effectiveEnabled) {
        await messaging.setAutoInitEnabled(true);

        // Pas de requestPermission ici (pas de prompt).
        final token = kIsWeb
            ? await messaging.getToken(vapidKey: _vapidKey)
            : await messaging.getToken();

        if (token != null && token.isNotEmpty) {
          await _upsertUserToken(token);
        }

        // iOS: affichage foreground
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } else {
        // Le point clé: si l’utilisateur a OFF, on ne remet pas ON au refresh.
        await messaging.setAutoInitEnabled(false);
        // Optionnel: ne supprime pas systématiquement token ici,
        // on le fait seulement au OFF explicite (switch).
      }
    } catch (_) {}
  }

  /// Active les notifications après geste utilisateur (switch ON)
  Future<bool> _enablePushWithPromptIfNeeded() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // On redemande l'état système
      NotificationSettings settings = await messaging.getNotificationSettings();

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        settings = await messaging.requestPermission(
          alert: true,
          sound: true,
          badge: true,
          provisional: false,
        );
      }

      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!allowed) {
        if (mounted) setState(() => _systemAllowed = false);
        return false;
      }

      if (mounted) setState(() => _systemAllowed = true);

      await messaging.setAutoInitEnabled(true);

      final String? token = kIsWeb
          ? await messaging.getToken(vapidKey: _vapidKey)
          : await messaging.getToken();

      if (token == null || token.isEmpty) return false;

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await _upsertUserToken(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Désactive les notifications (switch OFF) — consentement respecté durablement
  Future<void> _disablePush() async {
    try {
      final messaging = FirebaseMessaging.instance;

      await _deleteUserTokens();

      // Supprimer token local pour couper net
      await messaging.deleteToken();

      // Couper auto-init pour éviter recréation au refresh
      await messaging.setAutoInitEnabled(false);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _busy;

    String subtitle;
    if (isLoading) {
      subtitle = 'Activation en cours…';
    } else if (!_systemAllowed) {
      subtitle = 'Désactivées (permission système refusée)';
    } else {
      subtitle = _effectiveEnabled
          ? 'Notifications activées'
          : 'Notifications désactivées';
    }

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
          IconButton(
            tooltip: 'Resynchroniser',
            onPressed: isLoading
                ? null
                : () async {
                    await _syncWithSystemPermission();
                    await _applyEffectiveStateSilently();
                    if (mounted) setState(() {});
                  },
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        children: [
          Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  secondary: const Icon(Icons.notifications_active,
                      color: Colors.teal),
                  title: const Text('Notifications push'),
                  subtitle: Text(subtitle),

                  // ✅ Le switch reflète l'état FINAL (OS && consentement).
                  value: _effectiveEnabled,

                  // ✅ L’utilisateur peut toujours tenter ON (ça demandera la permission si nécessaire).
                  // OFF reste OFF et ne se réactive plus au refresh.
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

                        await Supabase.instance.client.auth.admin
                            .deleteUser(widget.user.id);

                        await Supabase.instance.client.auth.signOut();
                        if (!mounted) return;
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      } catch (e) {
                        if (!mounted) return;
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
