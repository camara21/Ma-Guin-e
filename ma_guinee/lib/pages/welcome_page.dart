import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../routes.dart';
import 'package:flutter/scheduler.dart';
import 'cgu_page.dart'; // 👈 même dossier lib/pages/

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
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
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CGUPage()),
        );
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
            Positioned.fill(
              child: Image.asset('assets/nimba.png', fit: BoxFit.cover, alignment: Alignment.center),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _TopGlassHeader(services: _services),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 90),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(color: Color(0xFFCE1126), width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                        child: const Text('Connexion', style: TextStyle(fontSize: 18, color: Color(0xFFCE1126), fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(color: Color(0xFF009460), width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                        child: const Text('Créer un compte', style: TextStyle(fontSize: 18, color: Color(0xFF009460), fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.28),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(.25)),
                      ),
                      child: Center(
                        child: Text.rich(
                          TextSpan(
                            text: 'En créant un compte, vous acceptez les ',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.white,
                              height: 1.35,
                              shadows: [Shadow(blurRadius: 2, color: Colors.black54, offset: Offset(0, 1))],
                            ),
                            children: [
                              TextSpan(
                                text: 'Conditions Générales d’Utilisation',
                                style: const TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w700),
                                recognizer: _termsTap,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
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
    _ticker = createTicker((elapsed) {
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
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(colors: [Color(0xFF113CFC), Color(0xFF2EC4F1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    ),
                    child: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Soneya', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
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
