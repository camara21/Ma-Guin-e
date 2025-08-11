import 'dart:ui';
import 'package:flutter/material.dart';
import '../routes.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 700;

    void openPolicySheet() => _openPolicySheet(context);

    return Scaffold(
      backgroundColor: isWeb ? const Color(0xFFF8F8FB) : Colors.white,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // IMAGE DE FOND
            Positioned.fill(
              child: Image.asset(
                'assets/nimba.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),

            // BOUTONS EN BAS
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                        child: const Text(
                          "Connexion",
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFFCE1126),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                        child: const Text(
                          "Créer un compte",
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF009460),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // GRABBER
            _PolicyGrabber(onOpen: openPolicySheet),
          ],
        ),
      ),
    );
  }

  // ---------- BOTTOM SHEET ----------
  static Future<void> _openPolicySheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: DraggableScrollableSheet(
            maxChildSize: 0.95,
            initialChildSize: 0.55,
            minChildSize: 0.35,
            builder: (ctx, scrollCtrl) {
              return ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(color: Colors.black.withOpacity(0.45)),
                    ),
                    ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),

                        // Contact
                        const _SectionTitle("Contact"),
                        const _Item("Contactez-nous"),
                        const SizedBox(height: 10),

                        // Mentions légales
                        const _SectionTitle("Mentions légales"),
                        const _LegalAccordion(
                          title: "Politique de confidentialité",
                          body:
                              "Votre confidentialité est importante. Cette section décrit la collecte, l’utilisation et la conservation de vos données personnelles.",
                        ),
                        const _LegalAccordion(
                          title: "Mentions légales",
                          body:
                              "Informations éditeur, hébergeur, propriété intellectuelle et conditions d’utilisation de l’application.",
                        ),
                        const _LegalAccordion(
                          title: "Politique de modération",
                          body:
                              "Règles de publication, comportements interdits, signalement et sanctions applicables aux contenus.",
                        ),
                        const _LegalAccordion(
                          title: "Charte d’utilisation",
                          body:
                              "Bonnes pratiques d’utilisation de Ma Guinée : respect, sécurité, intégrité des informations et respect des lois en vigueur.",
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ---------- Widgets utilitaires ----------

class _PolicyGrabber extends StatefulWidget {
  final VoidCallback onOpen;
  const _PolicyGrabber({required this.onOpen});

  @override
  State<_PolicyGrabber> createState() => _PolicyGrabberState();
}

class _PolicyGrabberState extends State<_PolicyGrabber> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 16,
      child: GestureDetector(
        onTap: widget.onOpen,
        onVerticalDragUpdate: (d) {
          _drag += d.delta.dy;
          if (_drag < -24) {
            _drag = 0;
            widget.onOpen();
          }
        },
        onVerticalDragEnd: (_) => _drag = 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text(
              "Politique de Ma Guinée",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final String text;
  const _Item(this.text);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
      title: Text(text, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white),
      onTap: () {},
    );
  }
}

class _LegalAccordion extends StatelessWidget {
  final String title;
  final String body;
  const _LegalAccordion({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.white24,
        splashColor: Colors.white10,
        highlightColor: Colors.white10,
      ),
      child: ExpansionTile(
        collapsedIconColor: Colors.white,
        iconColor: Colors.white,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        childrenPadding: const EdgeInsets.only(left: 14, right: 6, bottom: 12),
        children: [
          Text(
            body,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
        ],
      ),
    );
  }
}
