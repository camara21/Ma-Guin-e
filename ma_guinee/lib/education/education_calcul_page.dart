import 'package:flutter/material.dart';
import 'education_moteur_calcul.dart';
import 'education_voix_off.dart';

class EducationCalculPage extends StatefulWidget {
  const EducationCalculPage({super.key});

  @override
  State<EducationCalculPage> createState() => _EducationCalculPageState();
}

class _EducationCalculPageState extends State<EducationCalculPage> {
  final EducationMoteurCalcul _moteur = EducationMoteurCalcul();

  TypeCalcul _type = TypeCalcul.addition;
  NiveauCalcul _niveau = NiveauCalcul.facile;

  int _score = 0;
  int _numero = 1;
  int _totalQuestions = 10;

  QuestionCalcul? _question;
  int? _indexChoisi;
  bool _termine = false;

  @override
  void initState() {
    super.initState();
    _nouvelleQuestion();
  }

  Future<void> _nouvelleQuestion() async {
    setState(() {
      _indexChoisi = null;
      _question = _moteur.generer(type: _type, niveau: _niveau);
    });

    await EducationVoixOff.instance.lireQuestion(_question!.enonce);
  }

  Future<void> _relire() async {
    final q = _question;
    if (q == null) return;
    await EducationVoixOff.instance.relireQuestion(q.enonce);
  }

  Future<void> _repondre(int index) async {
    if (_termine) return;
    if (_indexChoisi != null) return;

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

  @override
  Widget build(BuildContext context) {
    final q = _question;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calcul mental'),
        actions: [
          IconButton(
            tooltip: 'Relire la question',
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
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<TypeCalcul>(
                          value: _type,
                          decoration: const InputDecoration(
                            labelText: 'Opération',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: TypeCalcul.addition,
                                child: Text('Addition')),
                            DropdownMenuItem(
                                value: TypeCalcul.soustraction,
                                child: Text('Soustraction')),
                            DropdownMenuItem(
                                value: TypeCalcul.multiplication,
                                child: Text('Multiplication')),
                            DropdownMenuItem(
                                value: TypeCalcul.division,
                                child: Text('Division')),
                          ],
                          onChanged: (v) async {
                            if (v == null) return;
                            setState(() => _type = v);
                            await _nouvelleQuestion();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<NiveauCalcul>(
                          value: _niveau,
                          decoration: const InputDecoration(
                            labelText: 'Niveau',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: NiveauCalcul.facile,
                                child: Text('Facile')),
                            DropdownMenuItem(
                                value: NiveauCalcul.moyen,
                                child: Text('Moyen')),
                            DropdownMenuItem(
                                value: NiveauCalcul.avance,
                                child: Text('Avancé')),
                          ],
                          onChanged: (v) async {
                            if (v == null) return;
                            setState(() => _niveau = v);
                            await _nouvelleQuestion();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Question $_numero / $_totalQuestions • Score: $_score',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (q != null) _BlocQuestion(texte: q.enonce),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: q?.propositions.length ?? 0,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final etat = _etatChoix(q!, i);
                        return _ChoixQcm(
                          texte: '${q.propositions[i]}',
                          etat: etat,
                          onTap: () => _repondre(i),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _indexChoisi == null ? null : _suivante,
                      child: Text(
                        _numero >= _totalQuestions
                            ? 'Voir le résultat'
                            : 'Question suivante',
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  _EtatChoix _etatChoix(QuestionCalcul q, int index) {
    if (_indexChoisi == null) return _EtatChoix.neutre;
    if (index == q.indexBonneReponse) return _EtatChoix.correct;
    if (index == _indexChoisi && index != q.indexBonneReponse)
      return _EtatChoix.faux;
    return _EtatChoix.neutre;
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
                fontWeight: FontWeight.w800,
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
    Color? couleurFond;
    Color? couleurBordure;

    switch (etat) {
      case _EtatChoix.neutre:
        couleurFond = null;
        couleurBordure = Theme.of(context).dividerColor;
        break;
      case _EtatChoix.correct:
        couleurFond = Colors.green.withOpacity(0.12);
        couleurBordure = Colors.green;
        break;
      case _EtatChoix.faux:
        couleurFond = Colors.red.withOpacity(0.12);
        couleurBordure = Colors.red;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: couleurFond,
          border: Border.all(
            color: couleurBordure ?? Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          texte,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
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
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRejouer,
            child: const Text('Rejouer'),
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
