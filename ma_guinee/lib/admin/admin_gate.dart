// lib/admin/admin_gate.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../routes.dart';


class AdminGate extends StatefulWidget {
  final Widget child;
  const AdminGate({super.key, required this.child});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  static const _allowedRoles = {'admin', 'owner'};
  late Future<_GateResult> _future;
  bool _navigating = false; // évite les doubles clics/navigation en doublon

  @override
  void initState() {
    super.initState();
    _future = _resolveGate();
  }

  Future<_GateResult> _resolveGate() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) {
      return const _GateResult.notLogged();
    }
    try {
      final row = await Supabase.instance.client
          .from('utilisateurs')
          .select('role')
          .eq('id', authUser.id)
          .maybeSingle();

      final role = (row?['role'] as String?)?.toLowerCase() ?? '';
      if (_allowedRoles.contains(role)) {
        return const _GateResult.admin();
      }
      return const _GateResult.notAdmin();
    } catch (_) {
      // En cas d’erreur réseau/SQL, on ne redirige pas : on montre « Accès refusé ».
      return const _GateResult.notAdmin();
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _goLogin(BuildContext context) {
    if (_navigating) return;
    _navigating = true;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  void _goHome(BuildContext context) {
    if (_navigating) return;
    _navigating = true;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.mainNav, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GateResult>(
      future: _future,
      builder: (context, snap) {
        // CHARGEMENT — aucun push ; évite tout « flash »
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(
                title: const Text('Vérification administrateur')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Erreur pendant la vérification des permissions.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _safeSetState(() {
                      _navigating = false;
                      _future = _resolveGate();
                    }),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }

        final res = snap.data ?? const _GateResult.notAdmin();

        if (res.isNotLogged) {
          // Pas connecté — pas de redirection automatique
          return Scaffold(
            appBar: AppBar(title: const Text('Connexion requise')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Veuillez vous connecter pour accéder à l’admin.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        _goLogin(context), // navigation par remplacement
                    child: const Text('Se connecter'),
                  ),
                ],
              ),
            ),
          );
        }

        if (res.isAdmin) {
          // Admin confirmé — on rend la page enfant sans navigation
          return widget.child;
        }

        // Non admin — pas de redirection automatique (anti-flash).
        return Scaffold(
          appBar: AppBar(title: const Text('Accès refusé')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Cette section est réservée aux administrateurs.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _goHome(context),
                  child: const Text(
                      'Aller à l’accueil'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GateResult {
  final bool isAdmin;
  final bool isNotAdmin;
  final bool isNotLogged;
  const _GateResult._(this.isAdmin, this.isNotAdmin, this.isNotLogged);
  const _GateResult.admin() : this._(true, false, false);
  const _GateResult.notAdmin() : this._(false, true, false);
  const _GateResult.notLogged() : this._(false, false, true);
}
