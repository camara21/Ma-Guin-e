import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../routes.dart';
import '../utils/recovery_guard.dart' as rg;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Duration _minSplash = Duration(milliseconds: 5200);

  Timer? _t;
  bool _minElapsed = false;

  bool _navigated = false;
  bool _goNextRunning = false;

  // ✅ écoute réseau permanente (dès initState)
  StreamSubscription? _connSub;
  bool _lastOffline = false;

  // Animations
  late final AnimationController _barCtl; // défilement de la barre
  late final AnimationController _glowCtl; // halo du logo
  late final Animation<double> _glowScale;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/logo_guinee.png'), context);
    });

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

    // ✅ écoute réseau dès le début
    _startConnectivityListener();

    // ✅ après la durée minimale, on autorise la navigation
    _t = Timer(_minSplash, () {
      _minElapsed = true;
      _tryProceed(); // si déjà online -> on passe; sinon on attend le retour réseau
    });
  }

  bool _isOffline(dynamic result) {
    try {
      if (result is ConnectivityResult) {
        return result == ConnectivityResult.none;
      }
      if (result is List<ConnectivityResult>) {
        if (result.isEmpty) return true;
        return result.every((r) => r == ConnectivityResult.none);
      }
    } catch (_) {}
    return false;
  }

  void _startConnectivityListener() {
    if (_connSub != null) return;

    final c = Connectivity();

    // état initial
    c.checkConnectivity().then((res) {
      _lastOffline = _isOffline(res);
    });

    _connSub = c.onConnectivityChanged.listen((res) {
      if (!mounted || _navigated) return;

      final off = _isOffline(res);
      final becameOnline = _lastOffline && !off;
      _lastOffline = off;

      // ✅ dès qu’on redevient online, on retente (si la durée mini est passée)
      if (becameOnline) {
        _tryProceed();
      }
    });
  }

  Future<void> _tryProceed() async {
    if (_navigated || !mounted) return;
    if (!_minElapsed) return;

    // Recovery: pas besoin de réseau
    if (rg.RecoveryGuard.isActive) {
      _navigated = true;
      Navigator.of(context).pushReplacementNamed(AppRoutes.resetPassword);
      return;
    }

    // Vérifie si on est online (interface réseau)
    final res = await Connectivity().checkConnectivity();
    final offline = _isOffline(res);

    if (offline) {
      // on attend le retour réseau (listener)
      return;
    }

    // Online -> go
    await _goNextOnce();
  }

  Future<void> _goNextOnce() async {
    if (_navigated || !mounted) return;
    if (_goNextRunning) return;
    _goNextRunning = true;

    try {
      if (rg.RecoveryGuard.isActive) {
        if (!mounted) return;
        _navigated = true;
        Navigator.of(context).pushReplacementNamed(AppRoutes.resetPassword);
        return;
      }

      final supa = Supabase.instance.client;
      final user = supa.auth.currentUser;

      // Par défaut
      String dest = AppRoutes.welcome;

      if (user != null) {
        // ✅ timeout court : pas de blocage si réseau faible
        try {
          final row = await supa
              .from('utilisateurs')
              .select('role')
              .eq('id', user.id)
              .maybeSingle()
              .timeout(const Duration(seconds: 3));

          final role = (row?['role'] as String?)?.toLowerCase() ?? '';
          dest = (role == 'admin' || role == 'owner')
              ? AppRoutes.adminCenter
              : AppRoutes.mainNav;
        } catch (_) {
          // ✅ fallback : on ne bloque pas le démarrage
          dest = AppRoutes.mainNav;
        }
      }

      if (!mounted) return;
      _navigated = true;
      Navigator.of(context).pushReplacementNamed(dest);
    } finally {
      _goNextRunning = false;
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _connSub?.cancel();
    _barCtl.dispose();
    _glowCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size;

    final double barWidth = (s.width * 0.36).clamp(140.0, 220.0);
    final double barHeight = 5.0;

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
                                    colors: [
                                      Color(0xFFFFFFFF),
                                      Color(0x00FFFFFF),
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
                        height: imgH,
                        filterQuality: FilterQuality.high,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 44,
            child: Center(
              child: AnimatedBuilder(
                animation: _barCtl,
                builder: (context, _) {
                  return _SoneyaUnderline(
                    width: barWidth,
                    height: barHeight,
                    progress: _barCtl.value,
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

class _SoneyaUnderline extends StatelessWidget {
  final double width;
  final double height;
  final double progress;

  const _SoneyaUnderline({
    required this.width,
    required this.height,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    const soneya = [
      Color(0xFFE53935),
      Color(0xFFFB8C00),
      Color(0xFFFDD835),
      Color(0xFF43A047),
      Color(0xFF1E88E5),
      Color(0xFF8E24AA),
    ];

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
