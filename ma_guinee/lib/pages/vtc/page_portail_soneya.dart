// lib/pages/vtc/page_portail_soneya.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../routes.dart';

class PagePortailSoneya extends StatefulWidget {
  const PagePortailSoneya({super.key});
  @override
  State<PagePortailSoneya> createState() => _PagePortailSoneyaState();
}

class _PagePortailSoneyaState extends State<PagePortailSoneya>
    with TickerProviderStateMixin {
  final _sb = Supabase.instance.client;

  bool _loading = true;
  bool _hasDriverProfile = false;

  late final AnimationController _rotCtrl;   // halo rotatif
  late final AnimationController _pulseCtrl; // bandeau néon
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _loadState();
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final u = _sb.auth.currentUser;
    if (u == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
      });
      return;
    }
    try {
      final row = await _sb.from('chauffeurs').select('id').eq('user_id', u.id).maybeSingle();
      if (!mounted) return;
      setState(() {
        _hasDriverProfile = row != null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goClient() async {
    final u = _sb.auth.currentUser;
    if (u != null) {
      try { await _sb.from('chauffeurs').update({'is_online': false}).eq('user_id', u.id); } catch (_) {}
    }
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.soneyaClient);
  }

  Future<void> _goChauffeur() async {
    final u = _sb.auth.currentUser;
    if (u == null) {
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }
    try {
      await _sb.from('chauffeurs').upsert({'user_id': u.id, 'is_online': false}, onConflict: 'user_id');
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.soneyaChauffeur);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Soneya'), centerTitle: true, elevation: 0),
      body: Stack(
        children: [
          // Bandeau néon (haut)
          Positioned(
            top: -140, left: -80, right: -80,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) {
                final t = 0.7 + _pulse.value * 0.3;
                return Container(
                  height: 300,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFE73B2E).withOpacity(.70),
                        const Color(0xFFFFD400).withOpacity(.70),
                        const Color(0xFF1BAA5C).withOpacity(.70),
                      ],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF1BAA5C).withOpacity(.20 * t), blurRadius: 40 * t, spreadRadius: 6 * t),
                    ],
                    borderRadius: BorderRadius.circular(48),
                  ),
                );
              },
            ),
          ),

          // Contenu
          Positioned.fill(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Text('Choisissez votre espace',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Transport simple et rapide.', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),

                  _RoleCard(
                    rotCtrl: _rotCtrl,
                    haloColors: const [Color(0x330BA360), Color(0x333CBA92), Color(0x330BA360)],
                    icon: Icons.phone_android,
                    title: 'Je suis client',
                    subtitle: 'Réserver, suivre, payer.',
                    bullets: const ['Réservation instantanée', 'Suivi en temps réel', 'Paiement sécurisé'],
                    buttonLabel: 'Entrer côté Client',
                    buttonGradient: const LinearGradient(colors: [Color(0xFF0BA360), Color(0xFF3CBA92)]),
                    onPressed: _goClient,
                    trailing: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Icon(Icons.two_wheeler), SizedBox(width: 8), Icon(Icons.directions_car)],
                    ),
                  ),

                  const SizedBox(height: 12),

                  _RoleCard(
                    rotCtrl: _rotCtrl,
                    haloColors: const [Color(0x33E53935), Color(0x33FFA726), Color(0x33E53935)],
                    icon: Icons.drive_eta_rounded,
                    title: 'Je suis chauffeur',
                    subtitle: _hasDriverProfile
                        ? 'Recevoir des demandes et suivre vos gains.'
                        : 'Activez votre espace chauffeur.',
                    bullets: const ['Demandes proches', 'Navigation intégrée', 'Gains & portefeuille'],
                    buttonLabel: _hasDriverProfile ? 'Entrer côté Chauffeur' : 'Activer & entrer',
                    buttonGradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFFA726)]),
                    onPressed: _goChauffeur,
                    trailing: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Icon(Icons.navigation_rounded), SizedBox(width: 8), Icon(Icons.verified)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Cartes et éléments UI ---

class _RoleCard extends StatelessWidget {
  final AnimationController rotCtrl;
  final List<Color> haloColors;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final String buttonLabel;
  final Gradient buttonGradient;
  final VoidCallback onPressed;
  final Widget trailing;

  const _RoleCard({
    required this.rotCtrl,
    required this.haloColors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.buttonLabel,
    required this.buttonGradient,
    required this.onPressed,
    required this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RotatingHaloIcon(controller: rotCtrl, colors: haloColors, icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: bullets.map((b) => _Chip(b)).toList(),
                  ),
                  const SizedBox(height: 12),
                  _PrimaryGradientButton(label: buttonLabel, onTap: onPressed, gradient: buttonGradient),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 14, color: Colors.black54),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _RotatingHaloIcon extends StatelessWidget {
  final AnimationController controller;
  final List<Color> colors;
  final IconData icon;
  const _RotatingHaloIcon({required this.controller, required this.colors, required this.icon, super.key});

  @override
  Widget build(BuildContext context) {
    const double size = 44;
    const double ring = 54;
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final angle = controller.value * 2 * math.pi;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: angle,
              child: Container(
                width: ring, height: ring,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(colors: colors, stops: const [0.0, 0.6, 1.0]),
                ),
              ),
            ),
            Container(width: ring - 8, height: ring - 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            Container(
              width: size, height: size,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black12)),
              child: Icon(icon, size: 24),
            ),
          ],
        );
      },
    );
  }
}

class _PrimaryGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Gradient gradient;
  const _PrimaryGradientButton({required this.label, required this.onTap, required this.gradient, super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: gradient),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            // texte à gauche pour les langues RTL auto gérées
          ],
        ),
      ),
    );
  }
}
