// lib/pages/splash_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin { // ✅ autorise plusieurs tickers
  static const Duration _minSplash = Duration(milliseconds: 3200);

  Timer? _t;
  bool _navigated = false;

  // Anim titre (fade + scale)
  late final AnimationController _ctl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  // Anim dégradé texte baseline
  late final AnimationController _gradientCtl;
  late final Animation<double> _slide; // 0 → 1 (repeat)

  @override
  void initState() {
    super.initState();

    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _fade = CurvedAnimation(parent: _ctl, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.94, end: 1.0)
        .animate(CurvedAnimation(parent: _ctl, curve: Curves.easeOutBack));

    _gradientCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _slide = CurvedAnimation(parent: _gradientCtl, curve: Curves.linear);

    _t = Timer(_minSplash, _goNextOnce);
  }

  Future<void> _goNextOnce() async {
    if (_navigated || !mounted) return;
    _navigated = true;

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
        if (role == 'admin' || role == 'owner') {
          dest = AppRoutes.adminCenter;
        } else {
          dest = AppRoutes.mainNav;
        }
      } catch (_) {
        dest = AppRoutes.mainNav;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(dest); // un seul replacement
  }

  @override
  void dispose() {
    _t?.cancel();
    _ctl.dispose();
    _gradientCtl.dispose();
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
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/logo_guinee.png', height: 160),
                    const SizedBox(height: 28),
                    Text(
                      "Soneya",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            blurRadius: 5,
                            color: Colors.white.withOpacity(0.95),
                          ),
                          Shadow(
                            blurRadius: 8,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: _slide,
                      builder: (context, _) {
                        final t = (_slide.value * 2.0) - 1.0; // -1 → +1
                        return _AnimatedGradientText(
                          "Là où tout commence",
                          slide: t,
                          fontSize: 18,
                        );
                      },
                    ),
                    // plus de "chargement…"
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Texte coloré par un dégradé Rouge → Jaune → Vert qui glisse horizontalement.
/// `slide` décale le dégradé de –1.0 à +1.0.
class _AnimatedGradientText extends StatelessWidget {
  final String text;
  final double slide; // –1.0 .. +1.0
  final double fontSize;

  const _AnimatedGradientText(
    this.text, {
    required this.slide,
    this.fontSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final begin = Alignment(-1.5 + slide, 0);
    final end = Alignment(1.5 + slide, 0);

    final gradient = LinearGradient(
      begin: begin,
      end: end,
      colors: const [
        Color(0xFFCE1126), // rouge
        Color(0xFFFCD116), // jaune
        Color(0xFF009460), // vert
      ],
      stops: const [0.0, 0.5, 1.0],
      tileMode: TileMode.clamp,
    );

    return ShaderMask(
      shaderCallback: (Rect bounds) => gradient.createShader(bounds),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: Colors.white, // sert aux ombres
          letterSpacing: 1.1,
          shadows: const [
            Shadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
    }
}
