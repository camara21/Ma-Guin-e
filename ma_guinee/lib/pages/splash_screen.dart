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
  static const Duration _minSplash = Duration(milliseconds: 4200);

  Timer? _t;
  bool _navigated = false;

  // Anim tagline + rope (style Heetch)
  late final AnimationController _tagCtl; // texte dégradé
  late final AnimationController _ropeCtl; // petit loader "rope"

  // Glow doux derrière le logo
  late final AnimationController _glowCtl;
  late final Animation<double> _glowScale;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();

    // Précharger le logo pour affichage instantané
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/logo_guinee.png'), context);
    });

    _tagCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _ropeCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    _glowCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowScale = Tween<double>(begin: 0.92, end: 1.06)
        .animate(CurvedAnimation(parent: _glowCtl, curve: Curves.easeInOut));

    _glowOpacity = Tween<double>(begin: 0.10, end: 0.45)
        .animate(CurvedAnimation(parent: _glowCtl, curve: Curves.easeInOut));

    _t = Timer(_minSplash, _goNextOnce);
  }

  Future<void> _goNextOnce() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    // ✅ utilise l'alias rg (et pas RecoveryGuard directement)
    if (rg.RecoveryGuard.isActive) {
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
    _tagCtl.dispose();
    _ropeCtl.dispose();
    _glowCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0175C2),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
              child: const SizedBox(),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // LOGO agrandi + glow
                SizedBox(
                  height: 260,
                  width: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _glowCtl,
                        builder: (context, _) {
                          return Transform.scale(
                            scale: _glowScale.value,
                            child: Opacity(
                              opacity: _glowOpacity.value,
                              child: Container(
                                width: 220,
                                height: 220,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Color(0xFFFF2E63), // rose
                                      Color(0x00FF2E63),
                                    ],
                                    stops: [0.0, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      Image.asset(
                        'assets/logo_guinee.png',
                        height: 200,
                        filterQuality: FilterQuality.high,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Texte animé dégradé
                AnimatedBuilder(
                  animation: _tagCtl,
                  builder: (context, _) {
                    final slide = (_tagCtl.value * 2.0) - 1.0; // -1 → +1
                    return _AnimatedGradientText(
                      'Là où tout commence',
                      slide: slide,
                      fontSize: 22,
                      colors: const [
                        Color(0xFFFF2E63),
                        Color(0xFFFF6B6B),
                        Color(0xFFFFA62B),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Loader capsule "rope"
                AnimatedBuilder(
                  animation: _ropeCtl,
                  builder: (context, _) {
                    return _HeetchRopeLoader(progress: _ropeCtl.value);
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

/// Texte avec dégradé animé horizontal
class _AnimatedGradientText extends StatelessWidget {
  final String text;
  final double slide; // −1.0 .. +1.0
  final double fontSize;
  final List<Color> colors;

  const _AnimatedGradientText(
    this.text, {
    required this.slide,
    required this.colors,
    this.fontSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final begin = Alignment(-1.5 + slide, 0);
    final end = Alignment(1.5 + slide, 0);

    final gradient = LinearGradient(
      colors: colors,
      stops: const [0.0, 0.5, 1.0],
      begin: begin,
      end: end,
    );

    return ShaderMask(
      shaderCallback: (Rect bounds) =>
          gradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 1.05,
          shadows: const [
            Shadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
  }
}

/// Petit loader capsule "rope"
class _HeetchRopeLoader extends StatelessWidget {
  final double progress; // 0..1

  const _HeetchRopeLoader({required this.progress});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0x26FFFFFF);
    const fg1 = Color(0xFFFF2E63);
    const fg2 = Color(0xFFFFA62B);

    return SizedBox(
      width: 160,
      height: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: bg),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (0.25 + (progress * 0.75)).clamp(0.20, 1.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [fg1, fg2],
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
