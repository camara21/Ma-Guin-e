// lib/education/education_quiz_page.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'education_donnees.dart';
import 'education_voix_off.dart';

class EducationQuizPage extends StatefulWidget {
  const EducationQuizPage({super.key});

  @override
  State<EducationQuizPage> createState() => _EducationQuizPageState();
}

class _EducationQuizPageState extends State<EducationQuizPage> {
  final Random _rng = Random();

  static const int _sessionSize = 20;

  String? _categorieId;
  bool _demarre = false;

  late List<QuestionQuiz> _questions;
  int _index = 0;
  int _score = 0;

  final Set<int> _selection = {};
  bool _validee = false;

  List<QuestionQuiz> _pool = [];

  @override
  void initState() {
    super.initState();
    _categorieId = EducationDonnees.categoriesQuiz.isNotEmpty
        ? EducationDonnees.categoriesQuiz.first.id
        : null;
    _questions = [];

    _initVoix();
  }

  @override
  void dispose() {
    EducationVoixOff.instance.arreter();
    super.dispose();
  }

  Future<void> _initVoix() async {
    await EducationVoixOff.instance.initialiser();
    if (!mounted) return;
    setState(() {});
  }

  QuestionQuiz get _q => _questions[_index];

  bool get _termine =>
      _demarre && _questions.isNotEmpty && _index >= _questions.length;

  bool get _modeQuestionnaireActif =>
      _demarre && !_termine && _questions.isNotEmpty;

  void _commencer() {
    if (_categorieId == null) return;
    _demarre = true;
    _resetPool();
    _chargerSession();
  }

  void _resetPool() {
    final id = _categorieId!;
    final base = EducationDonnees.questionsParCategorie(id);
    _pool = List<QuestionQuiz>.from(base)..shuffle(_rng);
  }

  void _chargerSession() {
    if (_categorieId == null) return;

    if (_pool.isEmpty) {
      _resetPool();
    }

    if (_pool.isEmpty) {
      setState(() {
        _questions = [];
        _index = 0;
        _score = 0;
        _selection.clear();
        _validee = false;
      });
      return;
    }

    final takeCount = _pool.length >= _sessionSize ? _sessionSize : _pool.length;

    _questions = _pool.take(takeCount).toList(growable: false);
    _pool.removeRange(0, takeCount);

    _index = 0;
    _score = 0;
    _selection.clear();
    _validee = false;

    setState(() {});
    _lireQuestionEtChoix();
  }

  Future<void> _lireQuestionEtChoix() async {
    if (!_modeQuestionnaireActif) return;

    await EducationVoixOff.instance.lireQuestion(_q.question);

    for (int i = 0; i < _q.choix.length; i++) {
      await EducationVoixOff.instance
          .lireQuestion('Choix ${i + 1} : ${_q.choix[i]}');
    }
  }

  Future<void> _relireQuestion() async {
    if (!_modeQuestionnaireActif) return;

    await EducationVoixOff.instance.arreter();
    await EducationVoixOff.instance.lireQuestion(_q.question);

    for (int i = 0; i < _q.choix.length; i++) {
      await EducationVoixOff.instance
          .lireQuestion('Choix ${i + 1} : ${_q.choix[i]}');
    }
  }

  void _toggleChoix(int i) {
    if (_validee) return;

    setState(() {
      if (_q.estMultiChoix) {
        if (_selection.contains(i)) {
          _selection.remove(i);
        } else {
          _selection.add(i);
        }
      } else {
        _selection
          ..clear()
          ..add(i);
      }
    });
  }

  Future<void> _valider() async {
    if (_validee) return;
    if (_selection.isEmpty) return;

    await EducationVoixOff.instance.arreter();

    final parfaite = _q.selectionEstParfaite(_selection);

    setState(() {
      _validee = true;
      if (parfaite) _score += 1;
    });

    await EducationVoixOff.instance.feedback(
      correct: parfaite,
      explicationSiFaux: parfaite ? null : _q.explication,
    );
  }

  Future<void> _suivante() async {
    if (!_validee) return;

    if (_index + 1 >= _questions.length) {
      setState(() => _index += 1);
      return;
    }

    setState(() {
      _index += 1;
      _selection.clear();
      _validee = false;
    });

    await _lireQuestionEtChoix();
  }

  Future<void> _ouvrirChoixCategorie() async {
    final categories = EducationDonnees.categoriesQuiz;
    if (categories.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return _SheetChoixCategorieCards(
          categories: categories,
          currentId: _categorieId,
        );
      },
    );

    if (selected == null) return;
    if (selected == _categorieId) return;

    setState(() => _categorieId = selected);

    if (_demarre) {
      _resetPool();
      _chargerSession();
    }
  }

  Future<void> _stopVoixAvantPop() async {
    await EducationVoixOff.instance.arreter();
  }

  @override
  Widget build(BuildContext context) {
    final categories = EducationDonnees.categoriesQuiz;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop) {
          await _stopVoixAvantPop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quiz & Culture générale'),
          actions: [
            if (_modeQuestionnaireActif)
              _VoixToggle(
                value: EducationVoixOff.instance.actif,
                onChanged: (v) async {
                  await EducationVoixOff.instance.definirActif(v);
                  if (!mounted) return;
                  setState(() {});
                },
              ),
            IconButton(
              tooltip: 'Catégorie',
              onPressed: categories.isEmpty ? null : _ouvrirChoixCategorie,
              icon: const Icon(Icons.category_rounded),
            ),
            IconButton(
              tooltip: 'Relire',
              onPressed: _modeQuestionnaireActif ? _relireQuestion : null,
              icon: const Icon(Icons.replay_rounded),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: !_demarre
              ? _VueChoixCategorieCards(
                  categories: categories,
                  categorieId: _categorieId,
                  onSelect: (v) => setState(() => _categorieId = v),
                  onCommencer: _commencer,
                )
              : (_questions.isEmpty)
                  ? const Center(child: Text('Aucune question disponible.'))
                  : _termine
                      ? _VueResultat(
                          score: _score,
                          total: _questions.length,
                          onRejouer: _chargerSession,
                          onChangerCategorie: () async {
                            await EducationVoixOff.instance.arreter();
                            setState(() {
                              _demarre = false;
                              _questions = [];
                              _pool = [];
                              _index = 0;
                              _score = 0;
                              _selection.clear();
                              _validee = false;
                            });
                            await _ouvrirChoixCategorie();
                          },
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoBar(
                              texte:
                                  'Question ${_index + 1} / ${_questions.length} • Score: $_score',
                              actionLabel: 'Catégorie',
                              onAction: _ouvrirChoixCategorie,
                            ),
                            const SizedBox(height: 10),
                            _BlocQuestion(
                              texte: _q.question,
                              hint: _q.estMultiChoix
                                  ? 'Plusieurs réponses possibles'
                                  : 'Une seule réponse',
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: ListView.separated(
                                itemCount: _q.choix.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final etat = _etatChoix(i);
                                  final checked = _selection.contains(i);

                                  final isCorrect = _q.estBonneReponseIndex(i);
                                  final highlightCorrectNotChosen = _validee &&
                                      _q.estMultiChoix &&
                                      isCorrect &&
                                      !checked;

                                  return _ChoixRouteStyle(
                                    texte: _q.choix[i],
                                    checked: checked,
                                    etat: etat,
                                    enabled: !_validee,
                                    highlight: highlightCorrectNotChosen,
                                    onTap: () => _toggleChoix(i),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _modeQuestionnaireActif
                                        ? _relireQuestion
                                        : null,
                                    icon: const Icon(Icons.volume_up_rounded),
                                    label: const Text('Relire'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        (_selection.isEmpty || _validee)
                                            ? null
                                            : _valider,
                                    icon: const Icon(Icons.check_circle_rounded),
                                    label: const Text('Valider'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _validee ? _suivante : null,
                                child: Text(
                                  (_index + 1) >= _questions.length
                                      ? 'Voir le résultat'
                                      : 'Suivant',
                                ),
                              ),
                            ),
                          ],
                        ),
        ),
      ),
    );
  }

  _EtatChoix _etatChoix(int i) {
    if (!_validee) return _EtatChoix.neutre;

    final estBon = _q.estBonneReponseIndex(i);
    final estCoche = _selection.contains(i);

    if (estCoche && estBon) return _EtatChoix.correct;
    if (estCoche && !estBon) return _EtatChoix.faux;

    return _EtatChoix.neutre;
  }
}

class _VoixToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _VoixToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Color badgeBg = value ? Colors.green : Colors.red;
    final String badgeText = value ? 'ON' : 'OFF';

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Voix',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: cs.onSurface.withOpacity(0.85),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _VueChoixCategorieCards extends StatelessWidget {
  final List<CategorieQuiz> categories;
  final String? categorieId;
  final ValueChanged<String> onSelect;
  final VoidCallback onCommencer;

  const _VueChoixCategorieCards({
    required this.categories,
    required this.categorieId,
    required this.onSelect,
    required this.onCommencer,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    final columns = (w >= 980)
        ? 3
        : (w >= 680)
            ? 2
            : 1;

    final aspect = columns == 1 ? 3.15 : 2.25;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choisis une catégorie',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Text(
          'Sélectionne une carte pour démarrer.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: GridView.count(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspect,
            children: categories.map((c) {
              final selected = c.id == categorieId;
              final grad = _gradFromId(c.id);

              return _CategoryCardPremium(
                title: c.titre,
                subtitle: c.description,
                gradient: grad,
                selected: selected,
                onTap: () => onSelect(c.id),
                trailing: selected ? 'Sélectionné' : null,
                icon: Icons.school_rounded,
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (categorieId == null) ? null : onCommencer,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(isTablet ? 'Commencer le quiz' : 'Commencer'),
          ),
        ),
      ],
    );
  }
}

class _SheetChoixCategorieCards extends StatelessWidget {
  final List<CategorieQuiz> categories;
  final String? currentId;

  const _SheetChoixCategorieCards({
    required this.categories,
    required this.currentId,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    final columns = (w >= 980)
        ? 3
        : (w >= 680)
            ? 2
            : 1;

    final aspect = columns == 1 ? 3.15 : 2.25;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Changer de catégorie',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: GridView.count(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: aspect,
                children: categories.map((c) {
                  final selected = c.id == currentId;
                  final grad = _gradFromId(c.id);

                  return _CategoryCardPremium(
                    title: c.titre,
                    subtitle: c.description,
                    gradient: grad,
                    selected: selected,
                    onTap: () => Navigator.pop(context, c.id),
                    trailing: selected ? 'Actuel' : null,
                    icon: Icons.category_rounded,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBar extends StatelessWidget {
  final String texte;
  final String actionLabel;
  final VoidCallback onAction;

  const _InfoBar({
    required this.texte,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Icon(Icons.insights_rounded, color: cs.onSurface.withOpacity(0.70)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texte,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface.withOpacity(0.80),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _CategoryCardPremium extends StatelessWidget {
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;
  final IconData icon;

  const _CategoryCardPremium({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.selected,
    required this.onTap,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
            border: selected
                ? Border.all(color: Colors.white.withOpacity(0.85), width: 2)
                : null,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                        border:
                            Border.all(color: Colors.white.withOpacity(0.18)),
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
              if (trailing != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      trailing!,
                      style: TextStyle(
                        color: cs.onSurface.withOpacity(0.80),
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

LinearGradient _gradFromId(String id) {
  int h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  final palettes = <List<Color>>[
    [const Color(0xFF0B1220), const Color(0xFF2563EB), const Color(0xFF38BDF8)],
    [const Color(0xFF0B1220), const Color(0xFF0F766E), const Color(0xFF34D399)],
    [const Color(0xFF0B1220), const Color(0xFF7C3AED), const Color(0xFFE879F9)],
    [const Color(0xFF0B1220), const Color(0xFFB45309), const Color(0xFFF59E0B)],
    [const Color(0xFF0B1220), const Color(0xFFBE123C), const Color(0xFFF43F5E)],
  ];
  final p = palettes[h % palettes.length];
  return LinearGradient(
    colors: p,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class _BlocQuestion extends StatelessWidget {
  final String texte;
  final String hint;
  const _BlocQuestion({required this.texte, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              texte,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _EtatChoix { neutre, correct, faux }

class _ChoixRouteStyle extends StatelessWidget {
  final String texte;
  final bool checked;
  final _EtatChoix etat;
  final bool enabled;
  final bool highlight;
  final VoidCallback onTap;

  const _ChoixRouteStyle({
    required this.texte,
    required this.checked,
    required this.etat,
    required this.enabled,
    required this.highlight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color border = Theme.of(context).dividerColor;
    Color? bg;

    if (etat == _EtatChoix.correct) {
      border = Colors.green;
      bg = Colors.green.withOpacity(0.12);
    } else if (etat == _EtatChoix.faux) {
      border = Colors.red;
      bg = Colors.red.withOpacity(0.12);
    } else if (highlight) {
      border = Colors.green;
      bg = Colors.green.withOpacity(0.12);
    }

    final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: highlight ? Colors.green.shade800 : null,
        );

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          color: bg,
        ),
        child: Row(
          children: [
            Icon(
              checked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: checked
                  ? Theme.of(context).colorScheme.primary
                  : Colors.black45,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(texte, style: textStyle)),
          ],
        ),
      ),
    );
  }
}

class _VueResultat extends StatelessWidget {
  final int score;
  final int total;
  final VoidCallback onRejouer;
  final VoidCallback onChangerCategorie;

  const _VueResultat({
    required this.score,
    required this.total,
    required this.onRejouer,
    required this.onChangerCategorie,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Résultat',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '$score / $total',
            style: Theme.of(context)
                .textTheme
                .displaySmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRejouer, child: const Text('Rejouer')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onChangerCategorie,
            child: const Text('Changer de catégorie'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }
}
