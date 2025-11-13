// lib/pages/wontanara/pages/page_collecte.dart

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../api_wontanara.dart';
import '../models.dart';
import '../constantes.dart';
import '../theme_wontanara.dart';

class PageCollecte extends StatefulWidget {
  const PageCollecte({super.key});

  @override
  State<PageCollecte> createState() => _PageCollecteState();
}

class _PageCollecteState extends State<PageCollecte> {
  List<Collecte> _items = [];
  bool _loading = true;
  String? _error;

  // 🔹 Maquettes d’abonnements & offres (on branchera l’API après)
  final List<_AbonnementCollecte> _abonnements = const [
    _AbonnementCollecte(
      nomOffreur: 'Jeunes clean-up Dubréka',
      formule: 'Formule maison standard',
      frequence: '2 ramassages / semaine',
      prochainPassage: 'Jeu 14 mars • 9h–11h',
      prixMensuel: '80 000 GNF / mois',
      actif: true,
    ),
  ];

  final List<_OffreCollecte> _offres = const [
    _OffreCollecte(
      nom: 'GreenCity Collecte',
      description: 'Ménager + plastique • bacs fournis',
      prix: '120 000 GNF / mois',
    ),
    _OffreCollecte(
      nom: 'Startup Clean Jeunes',
      description: 'Ramassage sur appel + abonnement',
      prix: 'À partir de 60 000 GNF',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiCollecte.lister(ZONE_ID_DEMO);
      if (!mounted) return;
      setState(() {
        _items = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Impossible de charger l’historique de collecte.";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur chargement collecte : $e")),
      );
    }
  }

  void _gererAbonnement() {
    // TODO: ouvrir une page pour gérer l’abonnement (changer formule, résilier…)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Gestion d’abonnement à venir.")),
    );
  }

  void _sAbonner(_OffreCollecte offre) {
    // TODO: créer une demande d’abonnement pour cette offre
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Demande d’abonnement envoyée à ${offre.nom}.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: ThemeWontanara.texte,
        title: const Text(
          'Collecte des déchets',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // ---------- Mes abonnements ----------
            const _SectionTitle('Mes abonnements de collecte'),
            const SizedBox(height: 8),
            if (_abonnements.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: _cardBox,
                child: const Text(
                  'Vous n’avez pas encore d’abonnement actif.\n'
                  'Choisissez une offre de collecte pour que des équipes '
                  'viennent régulièrement récupérer vos déchets.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ..._abonnements.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AbonnementCard(
                    abonnement: a,
                    onGerer: _gererAbonnement,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ---------- Offres disponibles ----------
            const _SectionTitle('Offres de collecte disponibles'),
            const SizedBox(height: 8),
            ..._offres.map(
              (o) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OffreCard(
                  offre: o,
                  onAbonner: () => _sAbonner(o),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ---------- Historique / derniers ramassages ----------
            const _SectionTitle('Derniers ramassages dans votre quartier'),
            const SizedBox(height: 8),
            if (_loading)
              const _SkeletonCollecte()
            else if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Ionicons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              )
            else if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "Aucun passage enregistré pour l’instant.",
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ..._items.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CollecteRecordCard(collecte: c),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
 *  Modèles locaux (UI)
 * ==========================================================*/

class _AbonnementCollecte {
  final String nomOffreur;
  final String formule;
  final String frequence;
  final String prochainPassage;
  final String prixMensuel;
  final bool actif;

  const _AbonnementCollecte({
    required this.nomOffreur,
    required this.formule,
    required this.frequence,
    required this.prochainPassage,
    required this.prixMensuel,
    required this.actif,
  });
}

class _OffreCollecte {
  final String nom;
  final String description;
  final String prix;

  const _OffreCollecte({
    required this.nom,
    required this.description,
    required this.prix,
  });
}

/* ============================================================
 *  Cartes UI
 * ==========================================================*/

class _AbonnementCard extends StatelessWidget {
  final _AbonnementCollecte abonnement;
  final VoidCallback onGerer;

  const _AbonnementCard({
    required this.abonnement,
    required this.onGerer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardBox,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ThemeWontanara.menthe,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.recycling, // icône Material
                  color: ThemeWontanara.vertPetrole,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  abonnement.nomOffreur,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: abonnement.actif
                      ? Colors.green.withOpacity(.12)
                      : Colors.grey.withOpacity(.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  abonnement.actif ? 'Actif' : 'Inactif',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: abonnement.actif ? Colors.green : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            abonnement.formule,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            abonnement.frequence,
            style: TextStyle(
              fontSize: 13,
              color: ThemeWontanara.texte2,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16),
              const SizedBox(width: 4),
              Text(
                abonnement.prochainPassage,
                style: TextStyle(
                  fontSize: 13,
                  color: ThemeWontanara.texte2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            abonnement.prixMensuel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ThemeWontanara.vertPetrole,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onGerer,
              style: TextButton.styleFrom(
                foregroundColor: ThemeWontanara.vertPetrole,
              ),
              child: const Text(
                'Gérer mon abonnement',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OffreCard extends StatelessWidget {
  final _OffreCollecte offre;
  final VoidCallback onAbonner;

  const _OffreCard({
    required this.offre,
    required this.onAbonner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardBox,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ThemeWontanara.menthe,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Ionicons.business_outline,
              color: ThemeWontanara.vertPetrole,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offre.nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  offre.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: ThemeWontanara.texte2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  offre.prix,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ThemeWontanara.vertPetrole,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onAbonner,
            style: TextButton.styleFrom(
              foregroundColor: ThemeWontanara.vertPetrole,
            ),
            child: const Text(
              'S’abonner',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollecteRecordCard extends StatelessWidget {
  final Collecte collecte;

  const _CollecteRecordCard({required this.collecte});

  @override
  Widget build(BuildContext context) {
    final heure =
        '${collecte.createdAt.hour.toString().padLeft(2, '0')}:${collecte.createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: _cardBox,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ThemeWontanara.menthe,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Ionicons.trash_outline,
              color: ThemeWontanara.vertPetrole,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Type : ${collecte.type}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Statut : ${collecte.statut}',
                  style: TextStyle(
                    fontSize: 13,
                    color: ThemeWontanara.texte2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            heure,
            style: TextStyle(
              fontSize: 12,
              color: ThemeWontanara.texte2,
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
 *  Helpers UI
 * ==========================================================*/

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: ThemeWontanara.vertPetrole,
      ),
    );
  }
}

class _SkeletonCollecte extends StatelessWidget {
  const _SkeletonCollecte();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(4, (i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
        );
      }),
    );
  }
}

final _cardBox = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(18),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ],
);
