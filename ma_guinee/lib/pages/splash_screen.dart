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
  late final AnimationController _textSweepCtl; // lettre -> lettre blanc → noir
  late final AnimationController _glowCtl;      // halo du logo
  late final Animation<double> _glowScale;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/logo_guinee.png'), context);
    });

    _textSweepCtl = AnimationController(
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
    _textSweepCtl.dispose();
    _glowCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size;

    // ✅ espaces égaux pour que la barre soit pile au milieu
    final double midGap = (s.shortestSide * 0.04).clamp(14.0, 24.0);

    // ✅ largeur max du texte pour éviter qu’il dépasse
    final double maxTextWidth = (s.width * 0.78).clamp(240.0, 520.0);

    // ✅ texte un peu plus petit qu’avant
    final double textSize = (s.shortestSide * 0.064).clamp(20.0, 30.0);

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

          // Contenu central
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // LOGO XXL (fixe) + halo blanc animé
                Builder(
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
                                        colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
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

                // espace après le logo
                SizedBox(height: midGap),

                // ✅ BARRE COLORÉE AU MILIEU (entre logo et texte)
                AnimatedBuilder(
                  animation: _textSweepCtl,
                  builder: (context, _) {
                    final sweep = _textSweepCtl.value; // 0..1
                    return _SoneyaUnderline(
                      width: maxTextWidth, // même largeur que le bloc texte
                      height: 6,
                      progress: sweep,
                    );
                  },
                ),

                // même espace avant le texte -> barre bien centrée
                SizedBox(height: midGap),

                // === TEXTE : blanc → noir lettre par lettre (avec largeur max) ===
                AnimatedBuilder(
                  animation: _textSweepCtl,
                  builder: (context, _) {
                    final progress = Curves.easeInOut.transform(_textSweepCtl.value); // 0..1
                    return SizedBox(
                      width: maxTextWidth,
                      child: _LetterByLetterText(
                        text: 'Là où tout commence',
                        fontSize: textSize,
                        progress: progress,
                      ),
                    );
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

/// Texte blanc → noir lettre par lettre (pas de superposition).
class _LetterByLetterText extends StatelessWidget {
  final String text;
  final double fontSize;
  final double progress; // 0..1

  const _LetterByLetterText({
    required this.text,
    required this.fontSize,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final chars = text.split('');
    final total = chars.length;
    final active = (progress * total).clamp(0, total.toDouble()).floor();

    final styleBase = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
      height: 1.1,
      shadows: const [
        Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1)),
      ],
    );

    return Text.rich(
      TextSpan(
        children: List.generate(total, (i) {
          final c = chars[i];
          final txt = c == ' ' ? ' ' : c;
          return TextSpan(
            text: txt,
            style: styleBase.copyWith(color: i < active ? Colors.black : Colors.white),
          );
        }),
      ),
      textAlign: TextAlign.center,
      softWrap: true,
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

    final slide = (progress * 2.0) - 1.0; // -1 → +1

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
