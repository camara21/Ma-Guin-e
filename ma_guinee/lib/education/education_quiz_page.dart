import 'package:flutter/material.dart';
import 'education_donnees.dart';
import 'education_voix_off.dart';

class EducationQuizPage extends StatefulWidget {
  const EducationQuizPage({super.key});

  @override
  State<EducationQuizPage> createState() => _EducationQuizPageState();
}

class _EducationQuizPageState extends State<EducationQuizPage> {
  String? _categorieId;
  bool _demarre = false;

  late List<QuestionQuiz> _questions;
  int _index = 0;
  int _score = 0;

  /// ✅ Sélection multi (et aussi pour simple, on utilise la même logique)
  final Set<int> _selection = {};

  /// Après validation, on fige l’état
  bool _validee = false;

  @override
  void initState() {
    super.initState();
    _categorieId = EducationDonnees.categoriesQuiz.isNotEmpty
        ? EducationDonnees.categoriesQuiz.first.id
        : null;
    _questions = [];
  }

  QuestionQuiz get _q => _questions[_index];

  void _commencer() {
    if (_categorieId == null) return;
    _demarre = true;
    _chargerSession();
  }

  void _chargerSession() {
    final id = _categorieId!;
    _questions = EducationDonnees.questionsParCategorie(id);

    _index = 0;
    _score = 0;
    _selection.clear();
    _validee = false;

    setState(() {});
    _lireQuestion();
  }

  Future<void> _lireQuestion() async {
    if (!_demarre) return;
    if (_questions.isEmpty) return;
    await EducationVoixOff.instance.lireQuestion(_q.question);
  }

  Future<void> _relireQuestion() async {
    if (!_demarre) return;
    if (_questions.isEmpty) return;
    await EducationVoixOff.instance.relireQuestion(_q.question);
  }

  void _toggleChoix(int i) {
    if (_validee) return;

    setState(() {
      if (_q.estMultiChoix) {
        // ✅ multi: toggle normal
        if (_selection.contains(i)) {
          _selection.remove(i);
        } else {
          _selection.add(i);
        }
      } else {
        // ✅ simple: on remplace la sélection par un seul index
        _selection
          ..clear()
          ..add(i);
      }
    });
  }

  Future<void> _valider() async {
    if (_validee) return;
    if (_selection.isEmpty) return;

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
      setState(() {
        _index += 1; // marque fin via _index == length
      });
      return;
    }

    setState(() {
      _index += 1;
      _selection.clear();
      _validee = false;
    });

    await _lireQuestion();
  }

  bool get _termine =>
      _demarre && _questions.isNotEmpty && _index >= _questions.length;

  @override
  Widget build(BuildContext context) {
    final categories = EducationDonnees.categoriesQuiz;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz & Culture générale'),
        actions: [
          IconButton(
            tooltip: 'Relire la question',
            onPressed: (!_demarre || _termine) ? null : _relireQuestion,
            icon: const Icon(Icons.replay_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: !_demarre
            ? _VueChoixCategorie(
                categories: categories,
                categorieId: _categorieId,
                onChanged: (v) => setState(() => _categorieId = v),
                onCommencer: _commencer,
              )
            : (_questions.isEmpty)
                ? const Center(child: Text('Aucune question disponible.'))
                : _termine
                    ? _VueResultat(
                        score: _score,
                        total: _questions.length,
                        onRejouer: _chargerSession,
                        onChangerCategorie: () {
                          setState(() {
                            _demarre = false;
                            _questions = [];
                            _index = 0;
                            _score = 0;
                            _selection.clear();
                            _validee = false;
                          });
                        },
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: _categorieId,
                            decoration: const InputDecoration(
                              labelText: 'Catégorie',
                              border: OutlineInputBorder(),
                            ),
                            items: categories
                                .map((c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.titre),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _categorieId = v);
                              _chargerSession();
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Question ${_index + 1} / ${_questions.length} • Score: $_score',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
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

                                // ✅ NOUVEAU (sans barrer) :
                                // bonne réponse NON choisie => style vert comme les autres
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
                                  onPressed: (!_demarre || _termine)
                                      ? null
                                      : _relireQuestion,
                                  icon: const Icon(Icons.volume_up_rounded),
                                  label: const Text('Relire'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: (_selection.isEmpty || _validee)
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

class _VueChoixCategorie extends StatelessWidget {
  final List<CategorieQuiz> categories;
  final String? categorieId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onCommencer;

  const _VueChoixCategorie({
    required this.categories,
    required this.categorieId,
    required this.onChanged,
    required this.onCommencer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choisis une catégorie',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: categorieId,
          decoration: const InputDecoration(
            labelText: 'Catégorie',
            border: OutlineInputBorder(),
          ),
          items: categories
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.titre)))
              .toList(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: categorieId == null ? null : onCommencer,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Commencer'),
          ),
        ),
      ],
    );
  }
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

  /// ✅ NOUVEAU : bonne réponse non choisie (multi) -> on la met en vert (sans barrer)
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
      // ✅ bonne réponse non cochée : même style vert, pas de barré
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
            Expanded(
              child: Text(
                texte,
                style: textStyle,
              ),
            ),
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
