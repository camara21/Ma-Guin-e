import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

/// Barrière d'accès pour les pages Admin.
/// - si non connecté → propose d'aller au /login
/// - si connecté mais rôle ≠ admin/owner → "Accès refusé"
class AdminGate extends StatelessWidget {
  final Widget child;
  const AdminGate({super.key, required this.child});

  static const _allowedRoles = {'admin', 'owner'}; // ajoute 'moderator' si tu veux

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UserProvider>();
    final u = prov.utilisateur;

    // 1) Pas connecté → invite à se connecter
    if (u == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Connexion requise')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Veuillez vous connecter pour accéder à l’admin.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text('Se connecter'),
              ),
            ],
          ),
        ),
      );
    }

    // 2) Rôle (robuste) : tente plusieurs chemins possibles
    final role = _extractRole(u);
    final ok = _allowedRoles.contains(role);
    if (!ok) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accès refusé')),
        body: const Center(
          child: Text('Cette section est réservée aux administrateurs.'),
        ),
      );
    }

    // 3) OK → on affiche la page protégée
    return child;
  }

  /// Essaie de récupérer le rôle sans dépendre du type concret du modèle.
  /// - propriété `role`
  /// - map retournée par `toJson()`
  /// - propriété `extra['role']` (au cas où)
  String _extractRole(dynamic user) {
    // a) propriété directe
    try {
      final r = user.role;
      if (r != null) return r.toString().toLowerCase();
    } catch (_) {}

    // b) via toJson()
    try {
      final m = user.toJson();
      if (m is Map) {
        final r = (m as Map)['role'];
        if (r != null) return r.toString().toLowerCase();
      }
    } catch (_) {}

    // c) via extra['role'] si ton modèle a un champ "extra"
    try {
      final extra = user.extra;
      if (extra is Map) {
        final r = extra['role'];
        if (r != null) return r.toString().toLowerCase();
      }
    } catch (_) {}

    return '';
  }
}
