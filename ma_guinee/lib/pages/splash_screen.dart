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
    with SingleTickerProviderStateMixin {
  // ⏱ Durée minimale d'affichage du splash
  static const Duration _minSplash = Duration(milliseconds: 3200);

  Timer? _t;
  bool _navigated = false;

  late final AnimationController _ctl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

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

    // ⏳ Augmenté : affichage minimum du splash
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
    Navigator.of(context).pushReplacementNamed(dest); // ✅ un seul replacement
  }

  @override
  void dispose() {
    _t?.cancel();
    _ctl.dispose();
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
                          Shadow(blurRadius: 5, color: Colors.white.withOpacity(0.95)),
                          Shadow(blurRadius: 8, color: Colors.white.withOpacity(0.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Là où tout commence",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.92),
                        letterSpacing: 1.1,
                        shadows: [
                          Shadow(blurRadius: 3, color: Colors.white.withOpacity(0.85)),
                          Shadow(blurRadius: 5, color: Colors.white.withOpacity(0.32)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const _Dots(),
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

class _Dots extends StatefulWidget {
  const _Dots();

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _a = CurvedAnimation(parent: _ctl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: const Text(
        'chargement…',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}
