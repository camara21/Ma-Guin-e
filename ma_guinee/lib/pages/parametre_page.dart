import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/utilisateur_model.dart';
import '../providers/user_provider.dart';
import 'modifier_profil_page.dart';

class ParametrePage extends StatefulWidget {
  final UtilisateurModel user;

  const ParametrePage({super.key, required this.user});

  @override
  State<ParametrePage> createState() => _ParametrePageState();
}

class _ParametrePageState extends State<ParametrePage> {
  bool _notifEnabled = false;
  bool _busy = false;

  static const String _vapidKey =
      'BNEG_lKXVJrvVDLYkI5ZJbLQSyfxZpLtaTDPgCMKOCnoisvDiqtCfS_tF5f57oGCa92obijXr6AYe-_QcAkOe2c';

  @override
  void initState() {
    super.initState();
    _loadNotifPref();
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

  Future<void> _onToggleNotifications(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      if (value) {
        final ok = await _enablePush();
        if (!ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Permission refusée ou échec d'activation.")),
            );
          }
          setState(() => _notifEnabled = false);
          await _saveNotifPref(false);
          return;
        }
        setState(() => _notifEnabled = true);
        await _saveNotifPref(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Notifications activées.")),
          );
        }
      } else {
        await _disablePush();
        setState(() => _notifEnabled = false);
        await _saveNotifPref(false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Notifications désactivées.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e")),
        );
      }
      setState(() => _notifEnabled = !_notifEnabled);
    } finally {
      setState(() => _busy = false);
    }
  }

  /// Active les notifications après geste utilisateur
  Future<bool> _enablePush() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Demande d'autorisation (nécessite le geste utilisateur : le switch)
      final settings = await messaging.requestPermission(
        alert: true,
        sound: true,
        badge: true,
        provisional: false,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return false;
      }

      // S'assurer que l'auto-init est actif
      await messaging.setAutoInitEnabled(true);

      // Récupération du token
      String? token;
      if (kIsWeb) {
        token = await messaging.getToken(vapidKey: _vapidKey);
      } else {
        token = await messaging.getToken();
      }
      if (token == null) return false;

      // iOS natif: afficher les notifs en foreground
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );

      // (Optionnel) Enregistrer le token côté serveur/Supabase
      // await Supabase.instance.client.from('user_tokens').upsert({
      //   'user_id': widget.user.id,
      //   'token': token,
      //   'platform': kIsWeb ? 'web' : 'mobile',
      // });

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Désactive les notifications (supprime le token)
  Future<void> _disablePush() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // (Optionnel) supprimer le token côté serveur d'abord
      // await Supabase.instance.client
      //   .from('user_tokens')
      //   .delete()
      //   .eq('user_id', widget.user.id);

      // Supprimer le token local
      await messaging.deleteToken();

      // Éteindre l’auto-init pour éviter une récréation du token
      await messaging.setAutoInitEnabled(false);
    } catch (_) {
      // Ignorer
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _busy;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Paramètres",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
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
                  secondary: const Icon(Icons.notifications_active, color: Colors.teal),
                  title: const Text("Notifications push"),
                  subtitle: Text(
                    _notifEnabled ? "Recevoir les notifications" : "Notifications désactivées",
                  ),
                  value: _notifEnabled,
                  onChanged: isLoading ? null : _onToggleNotifications,
                ),
                const Divider(height: 0),

                ListTile(
                  leading: const Icon(Icons.person, color: Colors.blue),
                  title: const Text("Modifier mon profil"),
                  onTap: () async {
                    final modified = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ModifierProfilPage(user: widget.user),
                      ),
                    );
                    if (modified == true) {
                      await Provider.of<UserProvider>(context, listen: false).chargerUtilisateurConnecte();
                      if (mounted) Navigator.pop(context, true);
                    }
                  },
                ),
                const Divider(height: 0),

                ListTile(
                  leading: const Icon(Icons.lock_reset, color: Colors.orange),
                  title: const Text("Mot de passe oublié ?"),
                  onTap: () async {
                    await Supabase.instance.client.auth.resetPasswordForEmail(widget.user.email);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Un lien de réinitialisation a été envoyé par email.")),
                    );
                  },
                ),
                const Divider(height: 0),

                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red, size: 28),
                  title: const Text("Supprimer mon compte", style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Supprimer mon compte"),
                        content: const Text("Cette action est irréversible. Es-tu sûr de vouloir supprimer ton compte ?"),
                        actions: [
                          TextButton(child: const Text("Annuler"), onPressed: () => Navigator.of(ctx).pop(false)),
                          TextButton(
                            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
                            onPressed: () => Navigator.of(ctx).pop(true),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await Supabase.instance.client.from('utilisateurs').delete().eq('id', widget.user.id);
                        await Supabase.instance.client.auth.admin.deleteUser(widget.user.id);
                        await Supabase.instance.client.auth.signOut();
                        if (!mounted) return;
                        Navigator.of(context).popUntil((route) => route.isFirst);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Compte supprimé avec succès.")),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Erreur lors de la suppression : $e")),
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
