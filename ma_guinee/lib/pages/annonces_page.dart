import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_guinee/models/annonce_model.dart';

import 'favoris_page.dart';
import 'create_annonce_page.dart';
import 'annonce_detail_page.dart';

class AnnoncesPage extends StatefulWidget {
  const AnnoncesPage({Key? key}) : super(key: key);

  @override
  State<AnnoncesPage> createState() => _AnnoncesPageState();
}

class _AnnoncesPageState extends State<AnnoncesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  // données
  List<Map<String, dynamic>> _allAnnonces = [];
  bool _loading = true;
  String? _error;

  // favoris (cache local) – pour éviter FutureBuilder par carte
  final Set<String> _favIds = <String>{};
  bool _favLoaded = false;

  // catégories
  final Map<String, dynamic> _catTous = {'label': 'Tous', 'icon': Icons.apps, 'id': null};
  final List<Map<String, dynamic>> _cats = const [
    {'label': 'Immobilier', 'icon': Icons.home_work_outlined, 'id': 1},
    {'label': 'Véhicules', 'icon': Icons.directions_car, 'id': 2},
    {'label': 'Vacances', 'icon': Icons.beach_access, 'id': 3},
    {'label': 'Emploi', 'icon': Icons.work_outline, 'id': 4},
    {'label': 'Services', 'icon': Icons.handshake, 'id': 5},
    {'label': 'Famille', 'icon': Icons.family_restroom, 'id': 6},
    {'label': 'Électronique', 'icon': Icons.devices_other, 'id': 7},
    {'label': 'Mode', 'icon': Icons.checkroom, 'id': 8},
    {'label': 'Loisirs', 'icon': Icons.sports_soccer, 'id': 9},
    {'label': 'Animaux', 'icon': Icons.pets, 'id': 10},
    {'label': 'Maison & Jardin', 'icon': Icons.chair_alt, 'id': 11},
    {'label': 'Matériel pro', 'icon': Icons.build, 'id': 12},
    {'label': 'Autres', 'icon': Icons.category, 'id': 13},
  ];
  late final List<Map<String, dynamic>> _allCats;
  int? _selectedCatId;
  String _selectedLabel = 'Tous';

  @override
  void initState() {
    super.initState();
    _allCats = [_catTous, ..._cats];
    _loadAnnonces();
    _preloadFavoris();
    _searchCtrl.addListener(() => setState(() {})); // filtre à la volée sans refetch
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAnnonces() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await Supabase.instance.client
          .from('annonces')
          .select()
          .order('date_creation', ascending: false);
      _allAnnonces = (raw as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _preloadFavoris() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _favLoaded = true);
        return;
      }
      final data = await Supabase.instance.client
          .from('favoris')
          .select('annonce_id')
          .eq('utilisateur_id', user.id);
      final ids = (data as List)
          .map((e) => (e['annonce_id'] ?? '').toString())
          .where((id) => id.isNotEmpty);
      setState(() {
        _favIds
          ..clear()
          ..addAll(ids);
        _favLoaded = true;
      });
    } catch (_) {
      setState(() => _favLoaded = true);
    }
  }

  // toggle optimiste -> pas de rechargement / pas de saut en haut
  Future<void> _toggleFavori(String annonceId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final wasFav = _favIds.contains(annonceId);
    setState(() {
      wasFav ? _favIds.remove(annonceId) : _favIds.add(annonceId);
    });

    try {
      if (wasFav) {
        await Supabase.instance.client
            .from('favoris')
            .delete()
            .eq('utilisateur_id', user.id)
            .eq('annonce_id', annonceId);
      } else {
        await Supabase.instance.client.from('favoris').insert({
          'utilisateur_id': user.id,
          'annonce_id': annonceId,
          'date_ajout': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {
      if (!mounted) return;
      // rollback en cas d'erreur
      setState(() {
        wasFav ? _favIds.add(annonceId) : _favIds.remove(annonceId);
      });
    }
  }

  List<Map<String, dynamic>> _filtered() {
    final cat = _selectedCatId;
    final f = _searchCtrl.text.trim().toLowerCase();

    Iterable<Map<String, dynamic>> it = _allAnnonces;
    if (cat != null) {
      it = it.where((a) => a['categorie_id'] == cat);
    }
    if (f.isNotEmpty) {
      it = it.where((a) {
        final t = (a['titre'] ?? '').toString().toLowerCase();
        final d = (a['description'] ?? '').toString().toLowerCase();
        return t.contains(f) || d.contains(f);
      });
    }
    return it.toList();
  }

  // ---------- UI helpers ----------
  String _fmtGNF(dynamic value) {
    if (value == null) return '0';
    final num n = (value is num) ? value : num.tryParse(value.toString()) ?? 0;
    final int i = n.round();
    final s = NumberFormat('#,##0', 'en_US').format(i);
    return s.replaceAll(',', '.');
  }

  Widget _categoryChip(Map<String, dynamic> cat, bool selected) {
    return GestureDetector(
      onTap: () => setState(() {
        _selectedCatId = cat['id'];
        _selectedLabel = cat['label'];
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF113CFC) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF113CFC) : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cat['icon'],
                size: 18,
                color: selected ? Colors.white : const Color(0xFF113CFC)),
            const SizedBox(width: 4),
            Text(
              cat['label'],
              style: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoriesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        child: Wrap(
          spacing: 8,
          runSpacing: 12,
          children: [_catTous, ..._cats]
              .map((c) => _categoryChip(c, _selectedLabel == c['label']))
              .toList(),
        ),
      ),
    );
  }

  Widget _sellBanner() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final primary = cs.primary;
    final onPrimary = cs.onPrimary;
    final bannerBg = primary.withOpacity(0.08);
    final bannerBorder = primary.withOpacity(0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: bannerBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: bannerBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "C’est le moment de vendre",
                    style: theme.textTheme.titleMedium!
                        .copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Touchez des milliers d’acheteurs près de chez vous.",
                    style: theme.textTheme.bodySmall!
                        .copyWith(color: cs.onSurface.withOpacity(0.6), height: 1.2),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("Déposer une annonce"),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateAnnoncePage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _annonceCard(Map<String, dynamic> data) {
    final images = List<String>.from(data['images'] ?? []);
    final id = data['id']?.toString() ?? '';
    final prix = data['prix'] ?? 0;
    final devise = data['devise'] ?? 'GNF';
    final ville = data['ville'] ?? '';
    final catId = data['categorie_id'] as int?;
    final catLabel = _cats
            .firstWhere((c) => c['id'] == catId, orElse: () => {'label': ''})['label']
        as String;

    final rawDate = data['date_creation'] as String? ?? '';
    DateTime date;
    try {
      date = DateTime.parse(rawDate);
    } catch (_) {
      date = DateTime.now();
    }
    final now = DateTime.now();
    final dateText = (date.year == now.year && date.month == now.month && date.day == now.day)
        ? "aujourd'hui ${DateFormat.Hm().format(date)}"
        : DateFormat('dd/MM/yyyy').format(date);

    final isFav = _favIds.contains(id);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnnonceDetailPage(annonce: AnnonceModel.fromJson(data)),
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 11,
                  child: Image.network(
                    images.isNotEmpty
                        ? images.first
                        : 'https://via.placeholder.com/600x400?text=Photo+indisponible',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      alignment: Alignment.center,
                      child:
                          const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['titre'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${_fmtGNF(prix)} $devise",
                        style: const TextStyle(
                          color: Color(0xFF009460),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (catLabel.isNotEmpty)
                        Text(catLabel,
                            style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      Text(ville, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(dateText, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IgnorePointer(
                ignoring: !_favLoaded,
                child: InkWell(
                  onTap: () => _toggleFavori(id),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3)],
                    ),
                    child: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      size: 24,
                      color: isFav ? Colors.red : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    int crossAxis = 2;
    if (width >= 1400) {
      crossAxis = 5;
    } else if (width >= 1100) {
      crossAxis = 4;
    } else if (width >= 800) {
      crossAxis = 3;
    }

    final annonces = _filtered();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
        title: TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Rechercher une annonce...',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: Colors.grey),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Color(0xFF113CFC)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavorisPage()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur : $_error'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Catégories (fixes sous l'AppBar)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: LayoutBuilder(
                        builder: (_, c) {
                          final isMobile = c.maxWidth < 600;
                          if (isMobile) {
                            // 👉 Swipe gauche/droite pour voir tous les filtres
                            return SizedBox(
                              height: 44,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [_catTous, ..._cats].map((cat) {
                                    final sel = _selectedLabel == cat['label'];
                                    return _categoryChip(cat, sel);
                                  }).toList(),
                                ),
                              ),
                            );
                          }
                          // Desktop/tablette: wrap comme avant
                          return Wrap(
                            spacing: 6,
                            runSpacing: 8,
                            children: [_catTous, ..._cats].map((cat) {
                              final sel = _selectedLabel == cat['label'];
                              return _categoryChip(cat, sel);
                            }).toList(),
                          );
                        },
                      ),
                    ),

                    // Tout le reste scrolle ensemble
                    Expanded(
                      child: CustomScrollView(
                        controller: _scrollCtrl,
                        slivers: [
                          SliverToBoxAdapter(child: _sellBanner()),
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(left: 18, bottom: 4, top: 8),
                              child: Text(
                                'Annonces récentes',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          if (annonces.isEmpty)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(child: Text('Aucune annonce trouvée.')),
                            )
                          else
                            SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              sliver: SliverGrid(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxis,
                                  crossAxisSpacing: 10, // ← resserré
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.72,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _annonceCard(annonces[index]),
                                  childCount: annonces.length,
                                ),
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
