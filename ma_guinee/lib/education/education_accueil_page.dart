// lib/education/education_accueil_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';

import 'education_quiz_page.dart';
import 'education_calcul_page.dart';
import 'education_ressources_page.dart';

class EducationAccueilPage extends StatefulWidget {
  const EducationAccueilPage({super.key});

  @override
  State<EducationAccueilPage> createState() => _EducationAccueilPageState();
}

class _EducationAccueilPageState extends State<EducationAccueilPage> {
  static const String _kEducationBgAsset = 'assets/education.png';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.shortestSide >= 600;

    final expandedH = isTablet ? 520.0 : 470.0;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // HEADER: image uniquement (texte défilant supprimé)
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            title: const Text(
              'Éducation',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            expandedHeight: expandedH,
            flexibleSpace: FlexibleSpaceBar(
              background: _EducationHeroOnly(
                assetPath: _kEducationBgAsset,
              ),
            ),
          ),

          // BODY: cartes dans la zone blanche, alignées côte à côte quand possible
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sélectionne une section ci-dessous.',
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _EducationCardsGrid(
                    // ✅ BRANCHEMENT vers les vraies pages
                    onTapQuiz: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EducationQuizPage()),
                    ),
                    onTapCalcul: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EducationCalculPage()),
                    ),
                    onTapRessources: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EducationRessourcesPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EducationHeroOnly extends StatelessWidget {
  final String assetPath;

  const _EducationHeroOnly({
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          assetPath,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, __, ___) => Container(
            color: cs.surfaceVariant.withOpacity(0.65),
            alignment: Alignment.center,
            child: Text(
              'Image introuvable:\n$assetPath',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withOpacity(0.75)),
            ),
          ),
        ),

        // overlay (on garde ton look)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.22),
                  Colors.black.withOpacity(0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EducationCardsGrid extends StatelessWidget {
  final VoidCallback onTapQuiz;
  final VoidCallback onTapCalcul;
  final VoidCallback onTapRessources;

  const _EducationCardsGrid({
    required this.onTapQuiz,
    required this.onTapCalcul,
    required this.onTapRessources,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // ✅ Objectif: côte à côte quand possible
    // - < 520px => 1 colonne (cartes larges)
    // - 520-880 => 2 colonnes
    // - >= 880 => 3 colonnes
    final w = size.width;
    final int columns = w >= 880 ? 3 : (w >= 520 ? 2 : 1);

    final spacing = 12.0;
    final aspect = columns == 1 ? 3.2 : 2.25;

    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      childAspectRatio: aspect,
      children: [
        _EduCard(
          title: 'Quiz & Culture générale',
          subtitle: 'Questions sur l’histoire, la géographie et la culture.',
          badge: 'Classement',
          icon: Icons.quiz_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF0B1220), Color(0xFF2563EB), Color(0xFF38BDF8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: onTapQuiz,
        ),
        _EduCard(
          title: 'Calcul mental',
          subtitle: 'Addition, soustraction, multiplication, division.',
          badge: '3 niveaux',
          icon: Icons.calculate_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF0B1220), Color(0xFF0F766E), Color(0xFF34D399)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: onTapCalcul,
        ),
        _EduCard(
          title: 'Ressources éducatives',
          subtitle: 'Fiches simples à consulter (texte).',
          badge: 'Fiches',
          icon: Icons.menu_book_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF0B1220), Color(0xFF7C3AED), Color(0xFFE879F9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: onTapRessources,
        ),
      ],
    );
  }
}

class _EduCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _EduCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Petit correctif hit-test: Material + InkWell + Ink
    // (ça garde le même design, mais rend le clic fiable)
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: gradient,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.white.withOpacity(0.06)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.92),
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.75),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
