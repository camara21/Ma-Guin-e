import 'package:flutter/material.dart';
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

  // —————————————————— CATEGORIES ——————————————————
  final Map<String, dynamic> _catTous = {
    'label': 'Tous',
    'icon': Icons.apps,
    'id': null,
  };

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
  }

  // —————————————————— DATA ——————————————————
  Future<List<Map<String, dynamic>>> _fetchAnnonces() async {
    final raw = await Supabase.instance.client
        .from('annonces')
        .select()
        .order('date_creation', ascending: false);

    final list = (raw as List).cast<Map<String, dynamic>>();

    // filtre catégorie
    final filteredCat = _selectedCatId != null
        ? list.where((a) => a['categorie_id'] == _selectedCatId).toList()
        : list;

    // filtre recherche
    final f = _searchCtrl.text.trim().toLowerCase();
    if (f.isEmpty) return filteredCat;
    return filteredCat.where((a) {
      final t = (a['titre'] ?? '').toString().toLowerCase();
      final d = (a['description'] ?? '').toString().toLowerCase();
      return t.contains(f) || d.contains(f);
    }).toList();
  }

  // —————————————————— FAVORIS ——————————————————
  Future<bool> _isFavori(String annonceId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    final data = await Supabase.instance.client
        .from('favoris')
        .select('id')
        .eq('utilisateur_id', user.id)
        .eq('annonce_id', annonceId)
        .maybeSingle();
    return data != null;
  }

  Future<void> _toggleFavori(String annonceId, bool isFavNow) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (isFavNow) {
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
    setState(() {});
  }

  // —————————————————— UI HELPERS ——————————————————
  Widget _categoryChip(Map<String, dynamic> cat, bool selected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCatId = cat['id'];
          _selectedLabel = cat['label'];
        });
      },
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
          children: _allCats.map((c) {
            final sel = _selectedLabel == c['label'];
            return _categoryChip(c, sel);
          }).toList(),
        ),
      ),
    );
  }

  Widget _annonceCard(Map<String, dynamic> data) {
    final images = List<String>.from(data['images'] ?? []);
    final id = data['id']?.toString() ?? '';
    final prix = data['prix'] ?? 0;
    final devise = data['devise'] ?? 'GNF';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnnonceDetailPage(
            annonce: AnnonceModel.fromJson(data),
          ),
        ),
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
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
                      child: const Icon(Icons.image_not_supported,
                          size: 40, color: Colors.grey),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['titre'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$prix $devise",
                        style: const TextStyle(
                          color: Color(0xFF009460),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data['ville'] ?? '',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Favori
            Positioned(
              top: 10,
              right: 10,
              child: FutureBuilder<bool>(
                future: _isFavori(id),
                builder: (_, snap) {
                  final fav = snap.data ?? false;
                  return InkWell(
                    onTap: () => _toggleFavori(id, fav),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: Icon(
                        fav ? Icons.favorite : Icons.favorite_border,
                        size: 24,
                        color: fav ? Colors.red : Colors.grey.shade600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // —————————————————— BUILD ——————————————————
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // responsive grid
    int crossAxis = 2;
    double ratio = 0.72;
    if (width >= 1400) {
      crossAxis = 5;
      ratio = 0.78;
    } else if (width >= 1100) {
      crossAxis = 4;
      ratio = 0.76;
    } else if (width >= 800) {
      crossAxis = 3;
      ratio = 0.74;
    }

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
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Color(0xFF113CFC)),
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FavorisPage())),
          ),
          IconButton(
            icon: const Icon(Icons.post_add, color: Color(0xFF113CFC)),
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateAnnoncePage())),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ——— Chips catégories ———
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: LayoutBuilder(
              builder: (_, c) {
                final isMobile = c.maxWidth < 600;
                if (isMobile) {
                  // Scroll limité + bouton "..."
                  return Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _allCats.take(6).map((cat) {
                              final sel = _selectedLabel == cat['label'];
                              return _categoryChip(cat, sel);
                            }).toList(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.expand_more,
                            color: Color(0xFF113CFC)),
                        onPressed: _showCategoriesSheet,
                      )
                    ],
                  );
                }
                // Web/Desktop : Wrap auto retour
                return Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  children: _allCats.map((cat) {
                    final sel = _selectedLabel == cat['label'];
                    return _categoryChip(cat, sel);
                  }).toList(),
                );
              },
            ),
          ),

          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 18, bottom: 4),
            child: Text(
              'Annonces récentes',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Colors.grey),
            ),
          ),

          // ——— Liste des annonces ———
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchAnnonces(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Erreur : ${snap.error}'));
                }
                final annonces = snap.data ?? [];
                if (annonces.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucune annonce trouvée.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return GridView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxis,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: ratio,
                  ),
                  itemCount: annonces.length,
                  itemBuilder: (_, i) => _annonceCard(annonces[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
