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
    with TickerProviderStateMixin {
  static const Duration _minSplash = Duration(milliseconds: 4200);

  Timer? _t;
  bool _navigated = false;

  late final AnimationController _ctl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  late final AnimationController _gradientCtl;
  late final Animation<double> _slide;

  late final AnimationController _glowCtl;
  late final Animation<double> _glowScale;
  late final Animation<double> _glowOpacity;

  late final AnimationController _shineCtl;
  late final Animation<double> _shine;

  @override
  void initState() {
    super.initState();

    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();

    _fade = CurvedAnimation(parent: _ctl, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.94, end: 1.0)
        .animate(CurvedAnimation(parent: _ctl, curve: Curves.easeOutBack));

    _gradientCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _slide = CurvedAnimation(parent: _gradientCtl, curve: Curves.linear);

    _glowCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _glowScale = Tween<double>(begin: 0.92, end: 1.08)
        .animate(CurvedAnimation(parent: _glowCtl, curve: Curves.easeInOut));
    _glowOpacity = Tween<double>(begin: 0.0, end: 0.6)
        .animate(CurvedAnimation(parent: _glowCtl, curve: Curves.easeInOut));

    _shineCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _shine = CurvedAnimation(parent: _shineCtl, curve: Curves.linear);

    _t = Timer(_minSplash, _goNextOnce);
  }

  Future<void> _goNextOnce() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    // ⛔️ Si un flux de recovery est actif, on va directement sur /reset_password
    if (RecoveryGuard.isActive) {
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
    Navigator.of(context).pushReplacementNamed(dest);
  }

  @override
  void dispose() {
    _t?.cancel();
    _ctl.dispose();
    _gradientCtl.dispose();
    _glowCtl.dispose();
    _shineCtl.dispose();
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
                    SizedBox(
                      height: 180,
                      width: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: Listenable.merge([_glowCtl]),
                            builder: (context, _) {
                              return Transform.scale(
                                scale: _glowScale.value,
                                child: Opacity(
                                  opacity: _glowOpacity.value * 0.6,
                                  child: Container(
                                    width: 150,
                                    height: 150,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          Color.fromARGB(180, 255, 255, 255),
                                          Color.fromARGB(0, 255, 255, 255),
                                        ],
                                        stops: [0.0, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          Image.asset('assets/logo_guinee.png', height: 160),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    AnimatedBuilder(
                      animation: _shine,
                      builder: (context, _) {
                        final slide = (_shine.value * 2.0) - 1.0; // -1 → +1
                        return _ShimmerText(
                          'Soneya',
                          slide: slide,
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
                        );
                      },
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

class _AnimatedGradientText extends StatelessWidget {
  final String text;
  final double slide; // −1.0 .. +1.0
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

    final gradient = const LinearGradient(
      colors: [
        Color(0xFFCE1126), // rouge
        Color(0xFFFCD116), // jaune
        Color(0xFF009460), // vert
      ],
      stops: [0.0, 0.5, 1.0],
    );

    return ShaderMask(
      shaderCallback: (Rect bounds) => gradient.createShader(Rect.fromLTWH(
        bounds.left + (begin.x * bounds.width * 0.3),
        bounds.top,
        bounds.width,
        bounds.height,
      )),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: Colors.white,
          letterSpacing: 1.1,
          shadows: const [
            Shadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
  }
}

class _ShimmerText extends StatelessWidget {
  final String text;
  final double slide; // -1 .. +1
  final TextStyle style;

  const _ShimmerText(this.text, {required this.slide, required this.style});

  @override
  Widget build(BuildContext context) {
    final begin = Alignment(-1.0 + slide, 0);
    final end = Alignment(1.0 + slide, 0);

    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: begin,
          end: end,
          colors: [
            Colors.white.withOpacity(0.20),
            Colors.white.withOpacity(0.95),
            Colors.white.withOpacity(0.20),
          ],
          stops: const [0.45, 0.50, 0.55],
        ).createShader(bounds);
      },
      child: Text(text, textAlign: TextAlign.center, style: style),
    );
  }
}
