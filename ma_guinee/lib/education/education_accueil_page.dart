// lib/education/education_accueil_page.dart
import 'package:flutter/material.dart';
import 'education_quiz_page.dart';
import 'education_calcul_page.dart';
import 'education_ressources_page.dart';

class EducationAccueilPage extends StatelessWidget {
  const EducationAccueilPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            title: const Text(
              'Éducation',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            centerTitle: false,
            expandedHeight: 170,
            flexibleSpace: const FlexibleSpaceBar(
              background: _EnteteFuturisteSansPremium(
                titre: 'Apprendre, progresser, réussir',
                sousTitre:
                    'Quiz, calcul mental et ressources. Une expérience simple et fluide.',
                icone: Icons.school_rounded,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _SectionCardPremium(
                    titre: 'Quiz & Culture générale',
                    description:
                        'Questions sur l’histoire, la géographie et la culture.',
                    icone: Icons.quiz_rounded,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0B1220),
                        Color(0xFF2563EB),
                        Color(0xFF38BDF8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    badge: 'Classement',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EducationQuizPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCardPremium(
                    titre: 'Calcul mental',
                    description:
                        'Addition, soustraction, multiplication, division.',
                    icone: Icons.calculate_rounded,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0B1220),
                        Color(0xFF0F766E),
                        Color(0xFF34D399),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    badge: '3 niveaux',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EducationCalculPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCardPremium(
                    titre: 'Ressources éducatives',
                    description: 'Fiches simples à consulter (texte).',
                    icone: Icons.menu_book_rounded,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0B1220),
                        Color(0xFF7C3AED),
                        Color(0xFFE879F9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    badge: 'Fiches',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EducationRessourcesPage(),
                      ),
                    ),
                  ),
                  // NOTE: Bloc "Conseil" supprimé comme demandé.
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnteteFuturisteSansPremium extends StatelessWidget {
  final String titre;
  final String sousTitre;
  final IconData icone;

  const _EnteteFuturisteSansPremium({
    required this.titre,
    required this.sousTitre,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B1220), Color(0xFF111E3A), Color(0xFF0B1220)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // “Glow” subtil
          Positioned(
            right: -40,
            top: -30,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8).withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB).withOpacity(0.12),
              ),
            ),
          ),

          // Contenu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 72, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const _IconeHalo(
                  icone: Icons.school_rounded,
                  gradient: LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sousTitre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.82),
                          fontSize: 13,
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCardPremium extends StatelessWidget {
  final String titre;
  final String description;
  final IconData icone;
  final LinearGradient gradient;
  final String badge;
  final VoidCallback onTap;

  const _SectionCardPremium({
    required this.titre,
    required this.description,
    required this.icone,
    required this.gradient,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // Bande gradient à gauche
                Positioned.fill(
                  child: Row(
                    children: [
                      Container(
                        width: 92,
                        decoration: BoxDecoration(gradient: gradient),
                      ),
                      Expanded(
                        child: Container(color: cs.surface),
                      ),
                    ],
                  ),
                ),

                // Glow discret
                Positioned(
                  left: 0,
                  top: -20,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Row(
                    children: [
                      _IconeHalo(icone: icone, gradient: gradient),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    titre,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                                _BadgePill(
                                  texte: badge,
                                  fond: cs.surfaceVariant.withOpacity(0.7),
                                  bordure: Colors.black.withOpacity(0.08),
                                  texteCouleur: cs.onSurface.withOpacity(0.85),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              description,
                              style: TextStyle(
                                color: cs.onSurface.withOpacity(0.72),
                                fontSize: 13,
                                height: 1.25,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: cs.onSurface.withOpacity(0.55),
                        size: 26,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconeHalo extends StatelessWidget {
  final IconData icone;
  final LinearGradient gradient;

  const _IconeHalo({
    required this.icone,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        icone,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final String texte;
  final Color fond;
  final Color bordure;
  final Color texteCouleur;

  const _BadgePill({
    required this.texte,
    required this.fond,
    required this.bordure,
    required this.texteCouleur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bordure),
      ),
      child: Text(
        texte,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: texteCouleur,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
