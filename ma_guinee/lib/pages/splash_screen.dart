import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../routes.dart';
import '../utils/recovery_guard.dart' as rg; // ✅ alias correct

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Duration _minSplash = Duration(milliseconds: 5200);

  Timer? _t;
  bool _navigated = false;

  // Animations
  late final AnimationController _barCtl;   // défilement de la barre
  late final AnimationController _glowCtl;  // halo du logo
  late final Animation<double> _glowScale;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/logo_guinee.png'), context);
    });

    // ✅ uniquement la barre (plus de texte)
    _barCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _glowCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowScale = Tween<double>(begin: 0.94, end: 1.06)
        .animate(CurvedAnimation(parent: _glowCtl, curve: Curves.easeInOut));
    _glowOpacity = Tween<double>(begin: 0.12, end: 0.40)
        .animate(CurvedAnimation(parent: _glowCtl, curve: Curves.easeInOut));

    _t = Timer(_minSplash, _goNextOnce);
  }

  Future<void> _goNextOnce() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    if (rg.RecoveryGuard.isActive) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.resetPassword);
      return;
    }

    final supa = Supabase.instance.client;
    final user = supa.auth.currentUser;

    String dest = AppRoutes.welcome;

    if (user != null) {
      try {
        final row = await supa
            .from('utilisateurs')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        final role = (row?['role'] as String?)?.toLowerCase() ?? '';
        dest = (role == 'admin' || role == 'owner')
            ? AppRoutes.adminCenter
            : AppRoutes.mainNav;
      } catch (_) {
        dest = AppRoutes.mainNav;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(dest);
  }

  @override
  void dispose() {
    _t?.cancel();
    _barCtl.dispose();
    _glowCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size;

    // ✅ Barre raccourcie (30–40% de la largeur selon l’écran)
    final double barWidth = (s.width * 0.36).clamp(140.0, 220.0);
    final double barHeight = 5.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0175C2),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Léger flou du fond (rendu doux)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
              child: const SizedBox(),
            ),
          ),

          // ===== CONTENU : LOGO FIXE AU CENTRE =====
          Center(
            child: Builder(
              builder: (context) {
                final double box = (s.shortestSide * 0.70).clamp(360.0, 560.0);
                final double glow = box * 0.90;
                final double imgH = box * 0.86;

                return SizedBox(
                  height: box,
                  width: box,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Halo animé (le logo, lui, reste fixe)
                      AnimatedBuilder(
                        animation: _glowCtl,
                        builder: (context, _) {
                          return Transform.scale(
                            scale: _glowScale.value,
                            child: Opacity(
                              opacity: _glowOpacity.value,
                              child: Container(
                                width: glow,
                                height: glow,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                                    stops: [0.0, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // ✅ LOGO FIXE
                      Image.asset(
                        'assets/logo_guinee.png',
                        height: imgH,
                        filterQuality: FilterQuality.high,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ===== BARRE ANIMÉE EN BAS (raccourcie) =====
          Positioned(
            left: 0,
            right: 0,
            bottom: 44, // marge depuis le bas
            child: Center(
              child: AnimatedBuilder(
                animation: _barCtl,
                builder: (context, _) {
                  return _SoneyaUnderline(
                    width: barWidth,
                    height: barHeight,
                    progress: _barCtl.value, // 0..1
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soulignement animé aux couleurs Soneya (dégradé qui défile de gauche à droite)
class _SoneyaUnderline extends StatelessWidget {
  final double width;
  final double height;
  final double progress; // 0..1

  const _SoneyaUnderline({
    required this.width,
    required this.height,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    // Couleurs Soneya (rouge → orange → jaune → vert → bleu → violet)
    const soneya = [
      Color(0xFFE53935),
      Color(0xFFFB8C00),
      Color(0xFFFDD835),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
      Color(0xFF8E24AA),
    ];

    // défilement -1 → +1
    final slide = (progress * 2.0) - 1.0;

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.white24),
            FractionalTranslation(
              translation: Offset(slide, 0),
              child: Container(
                width: width * 2,
                height: height,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: soneya,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
