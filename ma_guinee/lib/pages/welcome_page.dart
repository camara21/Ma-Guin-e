import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../routes.dart';
import 'package:flutter/scheduler.dart';
import 'cgu_page.dart';
import 'politique_confidentialite_page.dart'; // ⬅️ ajout

/// =======================
/// RÉGLAGES TRANSPARENCE (ultra premium, “plus bas possible”)
/// =======================
const _kHaloOpacity = 0.10; // lueur néon autour de la barre
const _kGlassBgOpacity = 0.03; // fond de la barre (quasi invisible)
const _kGlassBorderOpac = 0.08; // bordure “verre” douce
const _kGlassBlur = 4.0; // blur minimal pour laisser passer l’image
const _kCTAOpacity = 0.72; // opacité du dégradé du bouton principal
const _kOutlineFillOpac = 0.04; // léger voile sous le bouton outline
const _kScrimTop = 0.06; // scrim global: top
const _kScrimMid1 = 0.10; // scrim global: milieu 1
const _kScrimMid2 = 0.12; // scrim global: milieu 2
const _kScrimBottom = 0.10; // scrim global: bas

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  // Couleur principale de l'app (contour)
  static const kPrimary = Color(0xFF0175C2);

  static const List<_ServiceChip> _services = [
    _ServiceChip(Icons.shield, 'ANP'),
    _ServiceChip(Icons.campaign, 'Annonces'),
    _ServiceChip(Icons.home_repair_service, 'Prestataires'),
    _ServiceChip(Icons.account_balance, 'Services Admin'),
    _ServiceChip(Icons.restaurant, 'Restaurants'),
    _ServiceChip(Icons.account_balance_wallet, 'Lieux de culte'),
    _ServiceChip(Icons.local_activity, 'Divertissement'),
    _ServiceChip(Icons.map, 'Tourisme'),
    _ServiceChip(Icons.health_and_safety, 'Santé'),
    _ServiceChip(Icons.local_hotel, 'Hôtels'),
    _ServiceChip(Icons.apartment, 'Logement'),
    _ServiceChip(Icons.work, 'Wali fen'),
    _ServiceChip(Icons.confirmation_number, 'Billetterie'),
  ];

  late final TapGestureRecognizer _termsTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MentionsLegalesPage(),
          ),
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
            // Image
            Positioned.fill(
              child: Image.asset(
                'assets/nimba.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),

            // Scrim global ultra léger (pour garder la lisibilité du texte du header)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.55, 0.85, 1.0],
                    colors: [
                      Colors.black.withOpacity(_kScrimTop),
                      Colors.black.withOpacity(_kScrimMid1),
                      Colors.black.withOpacity(_kScrimMid2),
                      Colors.black.withOpacity(_kScrimBottom),
                    ],
                  ),
                ),
              ),
            ),

            // HEADER défilant (inchangé)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _TopGlassHeader(services: _services),
              ),
            ),

            // ======= ZONE BAS ULTRA TRANSPARENTE =======
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
                child: _BottomGlassBar(
                  primaryColor: kPrimary,
                  onLogin: () => Navigator.pushNamed(context, AppRoutes.login),
                  onRegister: () =>
                      Navigator.pushNamed(context, AppRoutes.register),
                  termsRecognizer: _termsTap,
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

class _TopGlassHeaderState extends State<_TopGlassHeader>
    with SingleTickerProviderStateMixin {
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
    })
      ..start();
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF113CFC), Color(0xFF2EC4F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.star_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Soneya',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(
                            blurRadius: 8,
                            color: Colors.black54,
                            offset: Offset(0, 1))
                      ],
                    ),
                  ),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.22),
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: Colors.white.withOpacity(.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(s.icon, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            s.label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
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

// ==================== BOTTOM BAR ULTRA TRANSPARENTE ====================

class _BottomGlassBar extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final TapGestureRecognizer termsRecognizer;
  final Color primaryColor;

  const _BottomGlassBar({
    required this.onLogin,
    required this.onRegister,
    required this.termsRecognizer,
    required this.primaryColor,
  });

  @override
  State<_BottomGlassBar> createState() => _BottomGlassBarState();
}

class _BottomGlassBarState extends State<_BottomGlassBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Couleurs Soneya (avec légère opacité pour premium)
    final neon = [
      const Color(0xFF00E5FF).withOpacity(0.80),
      const Color(0xFF00FFB0).withOpacity(0.80),
      const Color(0xFF7B61FF).withOpacity(0.80),
      const Color(0xFFFF6EC7).withOpacity(0.80),
    ];

    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        final t = _ctl.value; // 0..1
        final slide = (t * 2.0) - 1.0; // -1..+1

        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // halo animé (ultra discret)
              Positioned.fill(
                child: Opacity(
                  opacity: _kHaloOpacity,
                  child: FractionalTranslation(
                    translation: Offset(slide, 0),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: neon,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // contenu "glass" quasi invisible mais présent (premium)
              BackdropFilter(
                filter:
                    ImageFilter.blur(sigmaX: _kGlassBlur, sigmaY: _kGlassBlur),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(_kGlassBgOpacity),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(_kGlassBorderOpac)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // CTA principal — dégradé animé très translucide
                      _AnimatedGradientButton(
                        label: 'Créer un compte',
                        onTap: widget.onRegister,
                        opacity: _kCTAOpacity,
                      ),
                      const SizedBox(height: 10),
                      // CTA secondaire — outline (voile ultra léger)
                      _OutlineButtonThin(
                        label: 'Connexion',
                        borderColor: widget.primaryColor.withOpacity(0.95),
                        onTap: widget.onLogin,
                        fillOpacity: _kOutlineFillOpac,
                      ),
                      const SizedBox(height: 8),
                      // Mentions légales (CGU + Politique)
                      Center(
                        child: Text.rich(
                          TextSpan(
                            text: 'Mentions légales',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(
                                    blurRadius: 6,
                                    color: Colors.black45,
                                    offset: Offset(0, 1))
                              ],
                            ),
                            recognizer: widget.termsRecognizer,
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
        );
      },
    );
  }
}

// ======= Bouton principal : dégradé animé + légèrement translucide =======
class _AnimatedGradientButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final double opacity; // 0..1

  const _AnimatedGradientButton({
    required this.label,
    required this.onTap,
    this.opacity = 1.0,
  });

  @override
  State<_AnimatedGradientButton> createState() =>
      _AnimatedGradientButtonState();
}

class _AnimatedGradientButtonState extends State<_AnimatedGradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grad = [
      const Color(0xFF00E5FF).withOpacity(widget.opacity),
      const Color(0xFF00FFB0).withOpacity(widget.opacity),
      const Color(0xFF7B61FF).withOpacity(widget.opacity),
      const Color(0xFFFF6EC7).withOpacity(widget.opacity),
    ];

    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        final t = _ctl.value; // 0..1
        final slide = (t * 2.0) - 1.0;

        return SizedBox(
          width: double.infinity,
          height: 54,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: grad,
                  begin: Alignment(-1 + slide, 0),
                  end: Alignment(1 + slide, 0),
                ),
              ),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // gloss très subtil
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(.08),
                              Colors.white.withOpacity(0)
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    const Center(
                      child: Text(
                        'Créer un compte',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 0.8,
                          shadows: [
                            Shadow(
                                blurRadius: 8,
                                color: Colors.black45,
                                offset: Offset(0, 2))
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ======= Bouton secondaire : outline élégant + voile ultra léger =======
class _OutlineButtonThin extends StatelessWidget {
  final String label;
  final Color borderColor;
  final VoidCallback onTap;
  final double fillOpacity;

  const _OutlineButtonThin({
    required this.label,
    required this.borderColor,
    required this.onTap,
    this.fillOpacity = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor, width: 1.4),
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(fillOpacity),
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: borderColor.withOpacity(0.08),
            highlightColor: borderColor.withOpacity(0.05),
            child: const Center(
              child: Text(
                'Connexion',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16.5,
                  letterSpacing: 0.6,
                  shadows: [
                    Shadow(
                        blurRadius: 6,
                        color: Colors.black45,
                        offset: Offset(0, 1))
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// =======================
/// =======================
/// Mentions légales = accès CGU + Politique
/// =======================
class MentionsLegalesPage extends StatelessWidget {
  const MentionsLegalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = _WelcomePageState.kPrimary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        title: const Text(
          'Mentions légales',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          const Text(
            "Retrouvez ici les principaux documents juridiques de l’application Soneya :",
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 1,
            child: ListTile(
              leading: Icon(Icons.article_outlined, color: primary),
              title: const Text('Conditions Générales d’Utilisation (CGU)'),
              subtitle: const Text(
                'Règles d’utilisation de l’application et obligations des utilisateurs.',
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CGUPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 1,
            child: ListTile(
              leading: Icon(Icons.privacy_tip_outlined, color: primary),
              title: const Text('Politique de confidentialité'),
              subtitle: const Text(
                'Informations sur la collecte, l’usage et la protection de vos données.',
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PolitiqueConfidentialitePage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
