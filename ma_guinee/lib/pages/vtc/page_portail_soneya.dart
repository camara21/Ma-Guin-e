// lib/pages/vtc/page_portail_soneya.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../routes.dart';

class PagePortailSoneya extends StatefulWidget {
  const PagePortailSoneya({super.key});

  @override
  State<PagePortailSoneya> createState() => _PagePortailSoneyaState();
}

class _PagePortailSoneyaState extends State<PagePortailSoneya>
    with SingleTickerProviderStateMixin {
  final _sb = Supabase.instance.client;

  bool _chargement = true;
  bool _aProfilChauffeur = false; // présence dans `chauffeurs`
  String _onglet = 'client'; // 'client' | 'chauffeur' (sélecteur UI)

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  // Palette Guinée
  static const kRed = Color(0xFFE73B2E);
  static const kYellow = Color(0xFFFFD400);
  static const kGreen = Color(0xFF1BAA5C);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _chargerEtat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _chargerEtat() async {
    final u = _sb.auth.currentUser;
    if (u == null) {
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    try {
      final ch = await _sb
          .from('chauffeurs')
          .select('id, user_id')
          .or('id.eq.${u.id},user_id.eq.${u.id}')
          .maybeSingle();

      final hasDriver = ch != null;
      if (!mounted) return;
      setState(() {
        _aProfilChauffeur = hasDriver;
        _onglet = hasDriver ? 'chauffeur' : 'client';
        _chargement = false;
      });
    } catch (_) {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _allerClient() async {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.soneyaClient);
  }

  Future<void> _allerChauffeur() async {
    final u = _sb.auth.currentUser;
    if (u == null) {
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }
    try {
      // Crée/assure un profil chauffeur minimal en base
      await _sb.from('chauffeurs').upsert(
        {'user_id': u.id, 'is_online': false},
        onConflict: 'user_id',
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.soneyaChauffeur);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Activation chauffeur indisponible pour le moment.")),
      );
    }
  }

  // Optionnel : "désactiver" le mode chauffeur sans supprimer la ligne
  // (utile si tu veux forcer le retour client + offline)
  Future<void> _mettreHorsLigneChauffeur() async {
    final u = _sb.auth.currentUser;
    if (u == null) return;
    try {
      await _sb
          .from('chauffeurs')
          .update({'is_online': false})
          .or('id.eq.${u.id},user_id.eq.${u.id}');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pad = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Bandeau néon Guinée en fond
          Positioned(
            top: -120,
            left: -60,
            right: -60,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) {
                final t = 0.75 + _pulse.value * 0.25;
                return Container(
                  height: 280,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kRed.withOpacity(.75), kYellow.withOpacity(.75), kGreen.withOpacity(.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kGreen.withOpacity(.25 * t),
                        blurRadius: 36 * t,
                        spreadRadius: 6 * t,
                      ),
                    ],
                    borderRadius: BorderRadius.circular(42),
                  ),
                );
              },
            ),
          ),

          // Contenu
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, pad.top + 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _enTeteFuturiste(context),

                    const SizedBox(height: 16),
                    _roleSwitcher(context),

                    const SizedBox(height: 16),
                    if (_onglet == 'client') _blocClient(context) else _blocChauffeur(context),

                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        "Astuce : vous pouvez changer d’espace à tout moment.",
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ——— UI ———

  Widget _roleSwitcher(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.78),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(.5), width: 0.8),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              _pillSwitch(
                label: 'Espace Client',
                selected: _onglet == 'client',
                onTap: () async {
                  await _mettreHorsLigneChauffeur(); // sécurité douce
                  setState(() => _onglet = 'client');
                  _allerClient();
                },
                gradient: const LinearGradient(
                  colors: [Color(0xFF0BA360), Color(0xFF3CBA92)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                icon: Icons.person_pin_circle,
              ),
              const SizedBox(width: 8),
              _pillSwitch(
                label: 'Espace Chauffeur',
                selected: _onglet == 'chauffeur',
                onTap: () async {
                  setState(() => _onglet = 'chauffeur');
                  await _allerChauffeur();
                },
                gradient: const LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFFFA726)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                icon: Icons.drive_eta_rounded,
                disabled: false, // on autorise l’activation à la volée
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillSwitch({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required LinearGradient gradient,
    required IconData icon,
    bool disabled = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: selected ? gradient : null,
            color: selected ? null : Colors.white,
            border: Border.all(color: Colors.black12),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 12, offset: const Offset(0, 6))]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : Colors.black87),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blocClient(BuildContext context) {
    return _carteFuturiste(
      leftIcon: Icons.phone_android,
      title: 'Je suis client',
      subtitle: "Réserver, suivre l’arrivée, payer, noter.",
      actionLabel: 'Entrer côté Client',
      onAction: _allerClient,
      gradient: const LinearGradient(
        colors: [Color(0xFF0BA360), Color(0xFF3CBA92)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      trailingIcons: const [
        Icon(Icons.two_wheeler, color: Colors.black87, size: 36),
        SizedBox(width: 8),
        Icon(Icons.directions_car, color: Colors.black87, size: 22),
      ],
    );
  }

  Widget _blocChauffeur(BuildContext context) {
    return _carteFuturiste(
      leftIcon: Icons.drive_eta_rounded,
      title: 'Je suis chauffeur',
      subtitle: _aProfilChauffeur
          ? 'Recevoir des demandes, naviguer, consulter vos gains.'
          : 'Active ton espace chauffeur (création rapide).',
      actionLabel: _aProfilChauffeur ? 'Entrer côté Chauffeur' : 'Activer & entrer',
      onAction: _allerChauffeur,
      gradient: const LinearGradient(
        colors: [Color(0xFFE53935), Color(0xFFFFA726)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      trailingIcons: const [
        Icon(Icons.navigation_rounded, color: Colors.black87, size: 28),
        SizedBox(width: 8),
        Icon(Icons.verified, color: Colors.black87, size: 22),
      ],
    );
  }

  Widget _carteFuturiste({
    required IconData leftIcon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
    required LinearGradient gradient,
    required List<Widget> trailingIcons,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.75),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(.6), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              ShaderMask(
                shaderCallback: (r) => gradient.createShader(r),
                child: Icon(leftIcon, size: 34, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 10),
                    _ButtonNeon(
                      label: actionLabel,
                      icon: Icons.arrow_forward,
                      onTap: onAction,
                      gradient: gradient,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ...trailingIcons,
            ],
          ),
        ),
      ),
    );
  }

  Widget _enTeteFuturiste(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.72),
            border: Border.all(color: Colors.white.withOpacity(.6), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.10),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: const [
              Positioned(left: 18, top: 18, child: Text('Soneya',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: .2))),
              Positioned(left: 18, bottom: 16, right: 120,
                child: Text('Transport simple et rapide.\nChoisissez votre espace.', style: TextStyle(fontSize: 14))),
              Positioned(right: 18, bottom: 16, child: Icon(Icons.two_wheeler, size: 48)),
              Positioned(right: 68, bottom: 16, child: Icon(Icons.directions_car, size: 28)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ButtonNeon extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final LinearGradient gradient;

  const _ButtonNeon({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.10),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Icon(icon, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
