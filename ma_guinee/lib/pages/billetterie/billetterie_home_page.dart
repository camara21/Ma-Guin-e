// lib/pages/billetterie/billetterie_home_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_detail_page.dart';
import 'mes_billets_page.dart';
import 'pro_evenements_page.dart';
import 'pro_inscription_organisateur_page.dart';

class BilletterieHomePage extends StatefulWidget {
  const BilletterieHomePage({super.key});

  @override
  State<BilletterieHomePage> createState() => _BilletterieHomePageState();
}

class _BilletterieHomePageState extends State<BilletterieHomePage> {
  final _sb = Supabase.instance.client;

  // Palette événementielle
  static const _kEventPrimary = Color(0xFF7B2CBF);
  static const _kOnPrimary = Colors.white;

  // Filtres
  final _qCtrl = TextEditingController();
  final _villeCtrl = TextEditingController();
  String _selectedCat = 'toutes';

  // Données
  List<Map<String, dynamic>> _allEvents = [];
  bool _loading = true;
  String? _error;

  // Catégories (inclut kermesse)
  final List<String> _categories = const [
    'toutes',
    'concert',
    'festival',
    'sport',
    'conférence',
    'kermesse',
    'théâtre',
    'party',
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _qCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    _villeCtrl.dispose();
    super.dispose();
  }

  /// Flow organisateur (inscription si besoin)
  Future<void> _openOrganisateurFlow() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter.')),
      );
      return;
    }
    try {
      final rows =
          await _sb.from('organisateurs').select('id').eq('user_id', uid).limit(1);
      final exists = rows is List && rows.isNotEmpty;
      if (exists) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProEvenementsPage()),
        );
      } else {
        final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const ProInscriptionOrganisateurPage()),
        );
        if (created == true && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProEvenementsPage()),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _sb
          .from('evenements')
          .select(
              'id, titre, description, ville, categorie, lieu, date_debut, image_url, is_published, is_cancelled')
          .eq('is_published', true)
          .eq('is_cancelled', false)
          .order('date_debut');
      _allEvents = (raw as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- filtrage côté client ---
  List<Map<String, dynamic>> _filtered() {
    final f = _qCtrl.text.trim().toLowerCase();
    final v = _villeCtrl.text.trim().toLowerCase();
    final c = _selectedCat.toLowerCase();

    Iterable<Map<String, dynamic>> it = _allEvents;

    if (v.isNotEmpty) {
      it = it.where((e) => (e['ville'] ?? '').toString().toLowerCase().contains(v));
    }
    if (c.isNotEmpty && c != 'toutes') {
      it = it.where((e) => (e['categorie'] ?? '').toString().toLowerCase() == c);
    }
    if (f.isNotEmpty) {
      it = it.where((e) {
        final t = (e['titre'] ?? '').toString().toLowerCase();
        final d = (e['description'] ?? '').toString().toLowerCase();
        final l = (e['lieu'] ?? '').toString().toLowerCase();
        return t.contains(f) || d.contains(f) || l.contains(f);
      });
    }
    return it.toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kEventPrimary,
        foregroundColor: _kOnPrimary,
        title: const Text('Billetterie'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: (v) {
              if (v == 'pro') _openOrganisateurFlow();
              if (v == 'tickets') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MesBilletsPage()),
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'pro',
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_outlined),
                    const SizedBox(width: 10),
                    const Text('Organisateur'),
                    const Spacer(),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kEventPrimary.withOpacity(.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('PRO', style: TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'tickets',
                child: Row(
                  children: [
                    Icon(Icons.confirmation_num_outlined),
                    SizedBox(width: 10),
                    Text('Mes billets'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recherche
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: TextField(
                        controller: _qCtrl,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un événement…',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: const Color(0xFFF1E9FF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE7D9FF)),
                          ),
                        ),
                      ),
                    ),

                    // FILTRES SUR LA PAGE (sous la recherche)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          // Champ Ville en pilule
                          Expanded(
                            child: TextField(
                              controller: _villeCtrl,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Ville… (ex: Conakry)',
                                isDense: true,
                                prefixIcon: const Icon(Icons.place, size: 18),
                                filled: true,
                                fillColor: const Color(0xFFF7F3FF),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(
                                      color: _kEventPrimary.withOpacity(.25)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Bouton "Effacer"
                          TextButton(
                            onPressed: () {
                              _villeCtrl.clear();
                              setState(() {
                                _selectedCat = 'toutes';
                              });
                            },
                            child: const Text('Effacer'),
                          ),
                        ],
                      ),
                    ),

                    // Ruban de catégories (chips)
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final cat = _categories[i];
                          final selected = _selectedCat == cat;
                          return ChoiceChip(
                            label: Text(cat),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _selectedCat = cat),
                            backgroundColor: const Color(0xFFF7F3FF),
                            selectedColor: _kEventPrimary,
                            labelStyle: TextStyle(
                              color: selected ? _kOnPrimary : Colors.black87,
                              fontWeight: selected ? FontWeight.w600 : null,
                            ),
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: selected
                                    ? _kEventPrimary
                                    : _kEventPrimary.withOpacity(.25),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Liste des cartes (une colonne, image ~90%)
                    if (items.isEmpty)
                      const Expanded(
                        child: Center(child: Text('Aucun événement disponible.')),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (_, i) {
                            final e = items[i];
                            final imageUrl =
                                _publicImageUrl(e['image_url'] as String?);
                            final d =
                                DateTime.tryParse(e['date_debut']?.toString() ?? '');
                            final dateFmt = (d != null)
                                ? DateFormat('EEE d MMM • HH:mm', 'fr_FR').format(d)
                                : '';

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EventDetailPage(eventId: e['id'].toString()),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  children: [
                                    // Image plein-largeur (90% de la carte)
                                    AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child: imageUrl != null
                                          ? Image.network(
                                              imageUrl,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: const Color(0xFFEFE7FF),
                                              child: const Center(
                                                child: Icon(Icons.event,
                                                    size: 48,
                                                    color: Color(0xFF9A77D6)),
                                              ),
                                            ),
                                    ),

                                    // Overlay dégradé
                                    Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(.65),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Titre + meta
                                    Positioned(
                                      left: 12,
                                      right: 12,
                                      bottom: 12,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(.9),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              (e['categorie'] ?? '').toString(),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            (e['titre'] ?? '').toString(),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              height: 1.1,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.schedule,
                                                  size: 16, color: Colors.white),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  dateFmt,
                                                  style: const TextStyle(
                                                      color: Colors.white),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(Icons.place,
                                                  size: 16, color: Colors.white),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  '${e['lieu'] ?? ''} • ${e['ville'] ?? ''}',
                                                  style: const TextStyle(
                                                      color: Colors.white),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
    );
  }

  String? _publicImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return _sb.storage.from('evenement-photos').getPublicUrl(path);
  }

  void _openFilters() {
    // plus utilisé (les filtres sont sur la page), mais on garde au cas où
    setState(() {});
  }
}
