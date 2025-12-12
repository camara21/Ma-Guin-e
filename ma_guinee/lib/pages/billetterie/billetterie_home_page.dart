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

  // Palette
  static const _kEventPrimary = Color(0xFF7B2CBF);
  static const _kOnPrimary = Colors.white;

  // Données
  List<Map<String, dynamic>> _allEvents = [];
  bool _loading = true;
  String? _error;

  // Filtres
  final _qCtrl = TextEditingController();
  String _selectedCat = 'toutes';
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
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _sb
          .from('evenements_card_info')
          .select('''
            id, titre, description, ville, categorie, lieu, date_debut, image_url,
            is_published, is_cancelled, prix_min, devise, tickets_restants
          ''')
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

  Future<void> _openOrganisateurFlow() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter.')),
      );
      return;
    }
    try {
      final rows = await _sb
          .from('organisateurs')
          .select('id')
          .eq('user_id', uid)
          .limit(1);
      final exists = rows is List && rows.isNotEmpty;
      if (!mounted) return;
      if (exists) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProEvenementsPage()));
      } else {
        final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
              builder: (_) => const ProInscriptionOrganisateurPage()),
        );
        if (created == true && mounted) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProEvenementsPage()));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  List<Map<String, dynamic>> _filtered() {
    final f = _qCtrl.text.trim().toLowerCase();
    final c = _selectedCat.toLowerCase();
    Iterable<Map<String, dynamic>> it = _allEvents;
    if (c.isNotEmpty && c != 'toutes') {
      it =
          it.where((e) => (e['categorie'] ?? '').toString().toLowerCase() == c);
    }
    if (f.isNotEmpty) {
      it = it.where((e) {
        final t = (e['titre'] ?? '').toString().toLowerCase();
        final d = (e['description'] ?? '').toString().toLowerCase();
        final l = (e['lieu'] ?? '').toString().toLowerCase();
        final v = (e['ville'] ?? '').toString().toLowerCase();
        return t.contains(f) || d.contains(f) || l.contains(f) || v.contains(f);
      });
    }
    return it.toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered();
    final w = MediaQuery.of(context).size.width;
    final isPhone = w < 600;

    return Scaffold(
      backgroundColor: Colors.white, // ⬅️ fond blanc
      appBar: AppBar(
        backgroundColor: _kEventPrimary,
        foregroundColor: _kOnPrimary,
        title: const Text('Billetterie'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.white),
            onSelected: (v) {
              if (v == 'pro') _openOrganisateurFlow();
              if (v == 'tickets') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MesBilletsPage()));
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'tickets',
                child: Row(
                  children: const [
                    Icon(Icons.confirmation_num_outlined,
                        color: Color(0xFF4CAF50)),
                    SizedBox(width: 10),
                    Text('Mes billets'),
                    Spacer(),
                    _Badge(
                        label: 'BILLETS',
                        color: Color(0xFF4CAF50)), // ⬅️ badge remis
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'pro',
                child: Row(
                  children: const [
                    Icon(Icons.workspace_premium_outlined,
                        color: Color(0xFF7B2CBF)),
                    SizedBox(width: 10),
                    Text('Espace organisateur'),
                    Spacer(),
                    _Badge(
                        label: 'PRO',
                        color: Color(0xFF7B2CBF)), // ⬅️ badge remis
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
              ? Center(
                  child: Text('Erreur: $_error',
                      style: const TextStyle(color: Colors.black87)))
              : CustomScrollView(
                  slivers: [
                    // Barre de recherche + chips (sur fond blanc)
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            child: TextField(
                              controller: _qCtrl,
                              style: const TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Rechercher un événement…',
                                hintStyle:
                                    const TextStyle(color: Colors.black45),
                                prefixIcon: const Icon(Icons.search,
                                    color: Colors.black54),
                                filled: true,
                                fillColor: const Color(0xFFF2F2F7),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE0E0E0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE0E0E0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: _kEventPrimary, width: 1.2),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 44,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              scrollDirection: Axis.horizontal,
                              itemCount: _categories.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) {
                                final cat = _categories[i];
                                final selected = _selectedCat == cat;
                                return ChoiceChip(
                                  label: Text(
                                    cat,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  selected: selected,
                                  onSelected: (_) =>
                                      setState(() => _selectedCat = cat),
                                  backgroundColor: const Color(0xFFECECEC),
                                  selectedColor: _kEventPrimary,
                                  shape: StadiumBorder(
                                    side: BorderSide(
                                      color: selected
                                          ? _kEventPrimary
                                          : Colors.black12,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Liste (une seule image par événement)
                    if (items.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text('Aucun événement disponible.',
                              style: TextStyle(color: Colors.black45)),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final e = items[index];
                              return _EventCardNeo(
                                data: e,
                                imageUrl:
                                    _publicImageUrl(e['image_url'] as String?),
                                onTap: () => _openDetail(e['id'].toString()),
                              );
                            },
                            childCount: items.length,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 1,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: isPhone ? 1.15 : 0.92,
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  void _openDetail(String eventId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailPage(eventId: eventId)),
    );
  }

  String? _publicImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return _sb.storage.from('evenement-photos').getPublicUrl(path);
  }
}

/// —————————————————————————————————————————————————————————————
/// Carte "NEO" : affiche XL, prix & tickets si présents (vue)
/// —————————————————————————————————————————————————————————————
class _EventCardNeo extends StatelessWidget {
  final Map<String, dynamic> data;
  final String? imageUrl;
  final VoidCallback onTap;

  const _EventCardNeo({
    required this.data,
    required this.imageUrl,
    required this.onTap,
  });

  String _formatPrice(num? p, String? devise) {
    if (p == null) return '';
    final nf = NumberFormat.decimalPattern('fr_FR');
    final amount = nf.format(p);
    switch ((devise ?? 'GNF').toString().toUpperCase()) {
      case 'EUR':
      case '€':
        return '$amount €';
      case 'USD':
      case '\$':
        return '\$$amount';
      default:
        return '$amount GNF';
    }
  }

  Color _stockColor(int n) {
    if (n <= 10) return const Color(0xFFE53935);
    if (n <= 50) return const Color(0xFFFFA000);
    return const Color(0xFF43A047);
  }

  @override
  Widget build(BuildContext context) {
    final d = DateTime.tryParse(data['date_debut']?.toString() ?? '');
    final dateFmt =
        (d != null) ? DateFormat('EEE d MMM • HH:mm', 'fr_FR').format(d) : '';
    final titre = (data['titre'] ?? '').toString();
    final cat = (data['categorie'] ?? '').toString();
    final lieu = (data['lieu'] ?? '').toString();
    final ville = (data['ville'] ?? '').toString();

    final num? prix = (data['prix'] ?? data['prix_min']) as num?;
    final String? devise = data['devise']?.toString();
    final int? ticketsRestants = (data['tickets_restants'] as num?)?.toInt();
    final String prixTxt = _formatPrice(prix, devise);

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          // Image
          Positioned.fill(
            child: imageUrl != null
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF101010),
                      alignment: Alignment.center,
                      child:
                          const Icon(Icons.broken_image, color: Colors.white54),
                    ),
                  )
                : Container(
                    color: const Color(0xFF101010),
                    alignment: Alignment.center,
                    child: const Icon(Icons.event,
                        size: 54, color: Colors.white54),
                  ),
          ),
          // Dégradé
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withOpacity(.15),
                      Colors.black.withOpacity(.65)
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Ruban catégorie
          Positioned(
              left: 0, top: 18, child: _Ribbon(label: cat.toUpperCase())),
          // Badge tickets
          if (ticketsRestants != null)
            Positioned(
              right: 14,
              top: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _stockColor(ticketsRestants).withOpacity(.95),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.confirmation_number,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      '$ticketsRestants restants',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          // Panneau infos + prix
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _GlassPanel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Infos
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              letterSpacing: -.2,
                            )),
                        const SizedBox(height: 10),
                        _MetaLine(
                            icon: Icons.schedule,
                            text: dateFmt.isEmpty ? 'Date à venir' : dateFmt),
                        const SizedBox(height: 6),
                        _MetaLine(icon: Icons.place, text: '$lieu • $ville'),
                      ],
                    ),
                  ),
                  if (prixTxt.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('à partir de',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                          Text(prixTxt,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: Colors.black12, width: 1), // contour léger sur fond blanc
        ),
        child: card,
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaLine({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withOpacity(.95)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withOpacity(.95))),
        ),
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.18), width: 1),
      ),
      child: child,
    );
  }
}

class _Ribbon extends StatelessWidget {
  final String label;
  const _Ribbon({required this.label});
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -.06,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: .6,
                fontSize: 12)),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .4)),
    );
  }
}
