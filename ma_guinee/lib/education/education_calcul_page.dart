// lib/education/education_calcul_page.dart
import 'dart:math';
import 'package:flutter/material.dart';

import 'education_moteur_calcul.dart';
import 'education_voix_off.dart';

class EducationCalculPage extends StatefulWidget {
  const EducationCalculPage({super.key});

  @override
  State<EducationCalculPage> createState() => _EducationCalculPageState();
}

class _EducationCalculPageState extends State<EducationCalculPage> {
  final Random _rng = Random();
  final EducationMoteurCalcul _moteur = EducationMoteurCalcul();

  TypeCalcul _type = TypeCalcul.addition;
  NiveauCalcul _niveau = NiveauCalcul.facile;

  int _score = 0;
  int _numero = 1;
  final int _totalQuestions = 10;

  QuestionCalcul? _question;
  int? _indexChoisi;
  bool _termine = false;

  @override
  void initState() {
    super.initState();
    _initVoix();
    _nouvelleQuestion();
  }

  @override
  void dispose() {
    // ✅ coupe la voix quand on quitte la page
    EducationVoixOff.instance.arreter();
    super.dispose();
  }

  Future<void> _initVoix() async {
    await EducationVoixOff.instance.initialiser();
    if (!mounted) return;
    setState(() {});
  }

  bool get _modeQuestionnaireActif => !_termine && _question != null;

  Future<void> _nouvelleQuestion() async {
    // ✅ petit “bruit” pour éviter une impression de répétition
    // (sans modifier le moteur)
    _rng.nextInt(1000000);

    setState(() {
      _indexChoisi = null;
      _question = _moteur.generer(type: _type, niveau: _niveau);
    });

    final q = _question;
    if (q != null) {
      await EducationVoixOff.instance.lireQuestion(q.enonce);
      for (int i = 0; i < q.propositions.length; i++) {
        await EducationVoixOff.instance
            .lireQuestion('Réponse ${i + 1} : ${q.propositions[i]}');
      }
    }
  }

  Future<void> _relire() async {
    final q = _question;
    if (q == null) return;

    await EducationVoixOff.instance.arreter();
    await EducationVoixOff.instance.lireQuestion(q.enonce);
    for (int i = 0; i < q.propositions.length; i++) {
      await EducationVoixOff.instance
          .lireQuestion('Réponse ${i + 1} : ${q.propositions[i]}');
    }
  }

  Future<void> _repondre(int index) async {
    if (_termine) return;
    if (_indexChoisi != null) return;

    // ✅ stop lecture réponses dès que l’utilisateur choisit
    await EducationVoixOff.instance.arreter();

    final q = _question!;
    final estCorrect = index == q.indexBonneReponse;

    setState(() {
      _indexChoisi = index;
      if (estCorrect) _score += 1;
    });

    await EducationVoixOff.instance.feedback(
      correct: estCorrect,
      explicationSiFaux: estCorrect ? null : q.explication,
    );
  }

  Future<void> _suivante() async {
    if (_termine) return;

    if (_numero >= _totalQuestions) {
      setState(() => _termine = true);
      return;
    }

    setState(() => _numero += 1);
    await _nouvelleQuestion();
  }

  void _reinitialiser() {
    setState(() {
      _score = 0;
      _numero = 1;
      _termine = false;
    });
    _nouvelleQuestion();
  }

  Future<void> _setType(TypeCalcul v) async {
    if (_type == v) return;
    setState(() => _type = v);

    await EducationVoixOff.instance.arreter();
    await _nouvelleQuestion();
  }

  Future<void> _setNiveau(NiveauCalcul v) async {
    if (_niveau == v) return;
    setState(() => _niveau = v);

    await EducationVoixOff.instance.arreter();
    await _nouvelleQuestion();
  }

  _EtatChoix _etatChoix(QuestionCalcul q, int index) {
    if (_indexChoisi == null) return _EtatChoix.neutre;
    if (index == q.indexBonneReponse) return _EtatChoix.correct;
    if (index == _indexChoisi && index != q.indexBonneReponse) return _EtatChoix.faux;
    return _EtatChoix.neutre;
  }

  Future<void> _stopVoixAvantPop() async {
    await EducationVoixOff.instance.arreter();
  }

  @override
  Widget build(BuildContext context) {
    final q = _question;
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop) {
          await _stopVoixAvantPop();
        }
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          title: const Text('Calcul mental'),
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
              tooltip: 'Relire',
              onPressed: q == null ? null : _relire,
              icon: const Icon(Icons.replay_rounded),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: _termine
              ? _VueResultatCalcul(
                  score: _score,
                  total: _totalQuestions,
                  onRejouer: _reinitialiser,
                )
              : ListView(
                  children: [
                    const _SectionTitle(title: 'Opération'),
                    const SizedBox(height: 10),
                    _MiniOptionsGrid<TypeCalcul>(
                      items: const [
                        _MiniOptItem(value: TypeCalcul.addition, label: 'Addition', symbol: '+'),
                        _MiniOptItem(value: TypeCalcul.soustraction, label: 'Soustraction', symbol: '−'),
                        _MiniOptItem(value: TypeCalcul.multiplication, label: 'Multiplication', symbol: '×'),
                        _MiniOptItem(value: TypeCalcul.division, label: 'Division', symbol: '÷'),
                      ],
                      selected: _type,
                      onSelect: _setType,
                      columnsOverride: (ctx) {
                        final w = MediaQuery.sizeOf(ctx).width;
                        if (w >= 420) return 4;
                        if (w >= 340) return 3;
                        return 2;
                      },
                    ),
                    const SizedBox(height: 16),
                    const _SectionTitle(title: 'Niveau'),
                    const SizedBox(height: 10),
                    _MiniOptionsGrid<NiveauCalcul>(
                      items: const [
                        _MiniOptItem(value: NiveauCalcul.facile, label: 'Facile', symbol: 'F'),
                        _MiniOptItem(value: NiveauCalcul.moyen, label: 'Moyen', symbol: 'M'),
                        _MiniOptItem(value: NiveauCalcul.avance, label: 'Avancé', symbol: 'A'),
                      ],
                      selected: _niveau,
                      onSelect: _setNiveau,
                      fixedColumns: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Question $_numero / $_totalQuestions • Score: $_score',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface.withOpacity(0.80),
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (q != null) _BlocQuestion(texte: q.enonce),
                    if (q == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    const SizedBox(height: 12),
                    if (q != null)
                      ...List.generate(q.propositions.length, (i) {
                        final etat = _etatChoix(q, i);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ChoixQcm(
                            texte: '${q.propositions[i]}',
                            etat: etat,
                            onTap: () => _repondre(i),
                          ),
                        );
                      }),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _indexChoisi == null ? null : _suivante,
                        child: Text(
                          _numero >= _totalQuestions ? 'Voir le résultat' : 'Question suivante',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
        ),
      ),
    );
  }
}

/// ✅ Toggle Voix : label + badge ON/OFF visible + switch après
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

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: cs.onSurface.withOpacity(0.92),
          ),
    );
  }
}

class _MiniOptItem<T> {
  final T value;
  final String label;
  final String symbol;

  const _MiniOptItem({
    required this.value,
    required this.label,
    required this.symbol,
  });
}

class _MiniOptionsGrid<T> extends StatelessWidget {
  final List<_MiniOptItem<T>> items;
  final T selected;
  final Future<void> Function(T v) onSelect;

  final int? fixedColumns;
  final int Function(BuildContext context)? columnsOverride;

  const _MiniOptionsGrid({
    required this.items,
    required this.selected,
    required this.onSelect,
    this.fixedColumns,
    this.columnsOverride,
  });

  @override
  Widget build(BuildContext context) {
    int cols = fixedColumns ?? (columnsOverride?.call(context) ?? 4);
    cols = cols.clamp(1, items.length);

    const double tileExtent = 84;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
        mainAxisExtent: tileExtent,
      ),
      itemBuilder: (_, i) {
        final it = items[i];
        final isSelected = it.value == selected;

        return _MiniSelectTile(
          symbol: it.symbol,
          label: it.label,
          selected: isSelected,
          onTap: () => onSelect(it.value),
        );
      },
    );
  }
}

class _MiniSelectTile extends StatelessWidget {
  final String symbol;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MiniSelectTile({
    required this.symbol,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final base = cs.onSurface.withOpacity(0.08);
    final border = cs.onSurface.withOpacity(0.10);
    final ring = cs.primary.withOpacity(0.95);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: base,
            border: Border.all(
              color: selected ? ring : border,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 3,
                  color: selected ? ring : Colors.transparent,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      symbol,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        color: cs.onSurface.withOpacity(0.88),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: cs.onSurface.withOpacity(0.82),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: ring,
                      shape: BoxShape.circle,
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

class _BlocQuestion extends StatelessWidget {
  final String texte;
  const _BlocQuestion({required this.texte});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          texte,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

enum _EtatChoix { neutre, correct, faux }

class _ChoixQcm extends StatelessWidget {
  final String texte;
  final _EtatChoix etat;
  final VoidCallback onTap;

  const _ChoixQcm({
    required this.texte,
    required this.etat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color? bg;
    Color border = Theme.of(context).dividerColor;

    if (etat == _EtatChoix.correct) {
      bg = Colors.green.withOpacity(0.12);
      border = Colors.green;
    } else if (etat == _EtatChoix.faux) {
      bg = Colors.red.withOpacity(0.12);
      border = Colors.red;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: bg,
            border: Border.all(color: border),
          ),
          child: Text(
            texte,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ),
    );
  }
}

class _VueResultatCalcul extends StatelessWidget {
  final int score;
  final int total;
  final VoidCallback onRejouer;

  const _VueResultatCalcul({
    required this.score,
    required this.total,
    required this.onRejouer,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Résultat',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '$score / $total',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRejouer, child: const Text('Rejouer')),
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
