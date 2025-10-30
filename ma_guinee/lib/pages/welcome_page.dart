import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../routes.dart';
import 'package:flutter/scheduler.dart';
import 'cgu_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  // Couleur principale de l'app (contour)
  static const kPrimary = Color(0xFF0175C2);

  static const List<_ServiceChip> _services = [
    _ServiceChip(Icons.campaign, 'Annonces'),
    _ServiceChip(Icons.work, 'Emplois'),
    _ServiceChip(Icons.restaurant, 'Restaurants'),
    _ServiceChip(Icons.local_hotel, 'Hôtels'),
    _ServiceChip(Icons.health_and_safety, 'Santé'),
    _ServiceChip(Icons.church, 'Lieux de culte'),
    _ServiceChip(Icons.map, 'Tourisme'),
    _ServiceChip(Icons.local_activity, 'Divertissement'),
    _ServiceChip(Icons.store_mall_directory, 'Prestataires'),
  ];

  late final TapGestureRecognizer _termsTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CGUPage()));
      };
  }

  @override
  void dispose() {
    _termsTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 700;

    return Scaffold(
      backgroundColor: isWeb ? const Color(0xFFF8F8FB) : Colors.white,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            Positioned.fill(
              child: Image.asset('assets/nimba.png', fit: BoxFit.cover, alignment: Alignment.center),
            ),

            // Scrim léger pour lisibilité (ne masque pas l’image)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.55, 0.85, 1.0],
                    colors: [
                      Colors.black.withOpacity(0.10),
                      Colors.black.withOpacity(0.16),
                      Colors.black.withOpacity(0.22),
                      Colors.black.withOpacity(0.18),
                    ],
                  ),
                ),
              ),
            ),

            // HEADER défilant
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _TopGlassHeader(services: _services),
              ),
            ),

            // BOUTONS + CGU en bas
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 90),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ClassyTransparentButton(
                      label: 'Connexion',
                      borderColor: kPrimary,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.login),
                    ),
                    const SizedBox(height: 16),
                    _ClassyTransparentButton(
                      label: 'Créer un compte',
                      borderColor: kPrimary,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.register),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text.rich(
                        TextSpan(
                          text: 'Conditions Générales d’Utilisation',
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w700,
                            shadows: [Shadow(blurRadius: 6, color: Colors.black45, offset: Offset(0, 1))],
                          ),
                          recognizer: _termsTap,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= Header défilant =================

class _TopGlassHeader extends StatefulWidget {
  final List<_ServiceChip> services;
  const _TopGlassHeader({required this.services});

  @override
  State<_TopGlassHeader> createState() => _TopGlassHeaderState();
}

class _TopGlassHeaderState extends State<_TopGlassHeader> with SingleTickerProviderStateMixin {
  final _ctrl = ScrollController();
  late final Ticker _ticker;
  static const double _speed = 40;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (!_ctrl.hasClients) return;
      final max = _ctrl.position.maxScrollExtent;
      final newOffset = _ctrl.offset + (_speed / 60.0);
      if (newOffset >= max) {
        _ctrl.jumpTo(0);
      } else {
        _ctrl.jumpTo(newOffset);
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = [...widget.services, ...widget.services];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF113CFC), Color(0xFF2EC4F1)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Soneya',
                      style: TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black54, offset: Offset(0, 1))],
                      )),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  controller: _ctrl,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final s = items[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.22),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(s.icon, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(s.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceChip {
  final IconData icon;
  final String label;
  const _ServiceChip(this.icon, this.label);
}

// =============== Bouton OUTLINE 100% transparent + texte dégradé logo ===============

class _ClassyTransparentButton extends StatelessWidget {
  final String label;
  final Color borderColor;
  final VoidCallback onTap;

  const _ClassyTransparentButton({
    required this.label,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent, // intérieur totalement transparent
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: borderColor, width: 2.0), // contour classe
        ),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          splashColor: borderColor.withOpacity(0.12),
          highlightColor: borderColor.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _GradientText(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 0.8,
                  // ombre douce pour détacher sur la photo
                  shadows: [Shadow(blurRadius: 8, color: Colors.black45, offset: Offset(0, 2))],
                ),
                // dégradé “couleur du logo Soneya”
                colors: const [
                  Color(0xFFE53935), // rouge
                  Color(0xFFFB8C00), // orange
                  Color(0xFFFDD835), // jaune
                  Color(0xFF43A047), // vert
                  Color(0xFF1E88E5), // bleu
                  Color(0xFF8E24AA), // violet
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Texte en dégradé (shader) — parfait pour “couleur du logo”
class _GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final List<Color> colors;

  const _GradientText(this.text, {required this.style, required this.colors});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => LinearGradient(
        colors: colors,
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(
        text,
        style: style.copyWith(color: Colors.white), // la couleur est remplacée par le shader
      ),
    );
  }
}
