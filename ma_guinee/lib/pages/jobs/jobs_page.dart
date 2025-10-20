import 'package:flutter/material.dart';
import 'package:ma_guinee/services/jobs_service.dart';
import 'package:ma_guinee/models/job_models.dart';
import 'package:ma_guinee/pages/jobs/job_detail_page.dart';

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  // Palette Ma Guinée
  static const kBlue = Color(0xFF1976D2);
  static const kBg = Color(0xFFF6F7F9);

  final _qCtrl = TextEditingController();
  final _communeAutreCtrl = TextEditingController();

  String? _ville;
  String? _commune;
  String? _contrat;
  String _teletravail = 'Peu importe';

  bool _showCommuneAutre = false;
  late Future<List<EmploiModel>> _future;

  final _svc = JobsService();

  // ---------- Villes (préfectures)
  static const List<String> _villesGuinee = [
    // Spécial
    'Conakry',
    // Région de Boké
    'Boké', 'Boffa', 'Fria', 'Gaoual', 'Koundara',
    // Région de Kindia
    'Kindia', 'Coyah', 'Dubréka', 'Forécariah', 'Télimélé',
    // Région de Labé
    'Labé', 'Koubia', 'Lélouma', 'Mali', 'Tougué',
    // Région de Mamou
    'Mamou', 'Dalaba', 'Pita',
    // Région de Faranah
    'Faranah', 'Dabola', 'Dinguiraye', 'Kissidougou',
    // Région de Kankan
    'Kankan', 'Kérouané', 'Kouroussa', 'Mandiana', 'Siguiri',
    // Région de Nzérékoré
    'Nzérékoré', 'Beyla', 'Guéckédou', 'Lola', 'Macenta', 'Yomou',
  ];

  // ---------- Communes par ville
  static const Map<String, List<String>> _communesByVille = {
    'Conakry': ['Kaloum', 'Dixinn', 'Matam', 'Ratoma', 'Matoto'],

    // Boké
    'Boké': ['Boké'],
    'Boffa': ['Boffa'],
    'Fria': ['Fria'],
    'Gaoual': ['Gaoual'],
    'Koundara': ['Koundara'],

    // Kindia
    'Kindia': ['Kindia'],
    'Coyah': ['Coyah'],
    'Dubréka': ['Dubréka'],
    'Forécariah': ['Forécariah'],
    'Télimélé': ['Télimélé'],

    // Labé
    'Labé': ['Labé'],
    'Koubia': ['Koubia'],
    'Lélouma': ['Lélouma'],
    'Mali': ['Mali'],
    'Tougué': ['Tougué'],

    // Mamou
    'Mamou': ['Mamou'],
    'Dalaba': ['Dalaba'],
    'Pita': ['Pita'],

    // Faranah
    'Faranah': ['Faranah'],
    'Dabola': ['Dabola'],
    'Dinguiraye': ['Dinguiraye'],
    'Kissidougou': ['Kissidougou'],

    // Kankan
    'Kankan': ['Kankan'],
    'Kérouané': ['Kérouané'],
    'Kouroussa': ['Kouroussa'],
    'Mandiana': ['Mandiana'],
    'Siguiri': ['Siguiri'],

    // Nzérékoré
    'Nzérékoré': ['Nzérékoré'],
    'Beyla': ['Beyla'],
    'Guéckédou': ['Guéckédou'],
    'Lola': ['Lola'],
    'Macenta': ['Macenta'],
    'Yomou': ['Yomou'],
  };

  static const List<String> _contrats = <String>[
    'CDI',
    'CDD',
    'Stage',
    'Alternance',
    'Journalier',
    'Freelance',
    'Temps partiel',
    'Saisonnier',
  ];

  @override
  void initState() {
    super.initState();
    _future = _load(); // premier chargement (récents)
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    _communeAutreCtrl.dispose();
    super.dispose();
  }

  Future<List<EmploiModel>> _load() async {
    return _svc.chercher(
      q: _qCtrl.text.trim().isEmpty ? null : _qCtrl.text.trim(),
      ville: _ville,
      commune: _commune ??
          (_showCommuneAutre && _communeAutreCtrl.text.trim().isNotEmpty
              ? _communeAutreCtrl.text.trim()
              : null),
      typeContrat: _contrat,
      teletravail: _teletravail == 'Peu importe'
          ? null
          : (_teletravail == 'Oui' ? true : false),
      limit: 30,
      offset: 0,
    );
  }

  void _doSearch() => setState(() => _future = _load());

  InputDecoration _dec(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: kBlue) : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBlue, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        title: const Text('Emplois'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Barre de recherche
          TextField(
            controller: _qCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _doSearch(),
            decoration:
                _dec('Rechercher un poste (ex : Développeur)', icon: Icons.search),
          ),

          const SizedBox(height: 16),

          // Filtres (responsive 2 colonnes)
          LayoutBuilder(builder: (ctx, cst) {
            final twoCols = cst.maxWidth >= 560;

            final children = [
              // Ville
              DropdownButtonFormField<String>(
                value: _ville,
                isExpanded: true,
                decoration: _dec('Ville', icon: Icons.location_city),
                items: _villesGuinee
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _ville = v;
                    _commune = null;
                    _showCommuneAutre = false;
                    _communeAutreCtrl.clear();
                  });
                },
              ),

              // Commune (dépend de la ville)
              DropdownButtonFormField<String>(
                value: _commune,
                isExpanded: true,
                decoration: _dec('Commune', icon: Icons.place_outlined),
                items: (() {
                  final list =
                      (_ville != null && _communesByVille.containsKey(_ville))
                          ? [..._communesByVille[_ville]!, 'Autre commune…']
                          : <String>[];
                  return list
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList();
                })(),
                onChanged: _ville == null
                    ? null
                    : (c) {
                        setState(() {
                          _commune = c == 'Autre commune…' ? null : c;
                          _showCommuneAutre = c == 'Autre commune…';
                        });
                      },
              ),

              // Contrat
              DropdownButtonFormField<String>(
                value: _contrat,
                isExpanded: true,
                decoration: _dec('Contrat', icon: Icons.badge_outlined),
                items: _contrats
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (c) => setState(() => _contrat = c),
              ),

              // Télétravail
              DropdownButtonFormField<String>(
                value: _teletravail,
                isExpanded: true,
                decoration:
                    _dec('Télétravail', icon: Icons.home_work_outlined),
                items: const ['Peu importe', 'Oui', 'Non']
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (t) =>
                    setState(() => _teletravail = t ?? 'Peu importe'),
              ),
            ];

            if (twoCols) {
              return GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 3.9,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 10,
                children: children,
              );
            }
            return Column(
              children: [
                ...children.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: w,
                  ),
                ),
              ],
            );
          }),

          if (_showCommuneAutre) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _communeAutreCtrl,
              decoration: _dec('Préciser la commune',
                  icon: Icons.edit_location_alt_outlined),
            ),
          ],

          const SizedBox(height: 12),

          // Bouton rechercher
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: kBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _doSearch,
              icon: const Icon(Icons.search),
              label: const Text('Rechercher'),
            ),
          ),

          const SizedBox(height: 18),
          Text('Résultats', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          // Résultats (récents en haut)
          FutureBuilder<List<EmploiModel>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return const Text('Erreur de chargement.');
              }
              final items = snap.data ?? const <EmploiModel>[];
              if (items.isEmpty) {
                return const Text(
                    'Aucune offre trouvée — elles seront bientôt disponibles.');
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final e = items[i];
                  return _JobCard(
                    title: e.titre,
                    subtitle: _formatVilleContrat(e),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => JobDetailPage(jobId: e.id)),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatVilleContrat(EmploiModel e) {
    final parts = <String>[];
    if ((e.ville).isNotEmpty) parts.add(e.ville);
    if ((e.typeContrat).isNotEmpty) parts.add(e.typeContrat);
    return parts.join(' • ');
  }
}

// ==================== item de résultat ====================

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const kBlue = _JobsPageState.kBlue;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: kBlue,
                child: Icon(Icons.work_outline, color: Colors.white, size: 18),
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
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
