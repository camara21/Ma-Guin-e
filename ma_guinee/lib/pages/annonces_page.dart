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
  // ===== PALETTE DOUCE : rouge seulement quand actif =====
  // (tu peux ajuster la teinte du rouge si besoin)
  static const Color _brandRed       = Color(0xFFD92D20); // rouge doux (actif)
  static const Color _softRedBg      = Color(0xFFFFF1F1); // fond très léger
  static const Color _pageBg         = Color(0xFFF5F7FA);
  static const Color _cardBg         = Color(0xFFFFFFFF);
  static const Color _stroke         = Color(0xFFE5E7EB);
  static const Color _textPrimary    = Color(0xFF1F2937);
  static const Color _textSecondary  = Color(0xFF6B7280);
  static const Color _onPrimary      = Color(0xFFFFFFFF);

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  // données
  List<Map<String, dynamic>> _allAnnonces = [];
  bool _loading = true;
  String? _error;

  // favoris (cache local)
  final Set<String> _favIds = <String>{};
  bool _favLoaded = false;

  // catégories
  final Map<String, dynamic> _catTous = {
    'label': 'Tous',
    'icon': Icons.apps,
    'id': null
  };
  final List<Map<String, dynamic>> _cats = const [
    {'label': 'Immobilier',        'icon': Icons.home_work_outlined, 'id': 1},
    {'label': 'Véhicules',         'icon': Icons.directions_car,     'id': 2},
    {'label': 'Vacances',          'icon': Icons.beach_access,       'id': 3},
    {'label': 'Emploi',            'icon': Icons.work_outline,       'id': 4},
    {'label': 'Services',          'icon': Icons.handshake,          'id': 5},
    {'label': 'Famille',           'icon': Icons.family_restroom,    'id': 6},
    {'label': 'Électronique',      'icon': Icons.devices_other,      'id': 7},
    {'label': 'Mode',              'icon': Icons.checkroom,          'id': 8},
    {'label': 'Loisirs',           'icon': Icons.sports_soccer,      'id': 9},
    {'label': 'Animaux',           'icon': Icons.pets,               'id': 10},
    {'label': 'Maison & Jardin',   'icon': Icons.chair_alt,          'id': 11},
    {'label': 'Matériel pro',      'icon': Icons.build,              'id': 12},
    {'label': 'Autres',            'icon': Icons.category,           'id': 13},
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
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAnnonces() async {
    setState(() { _loading = true; _error = null; });
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
      if (user == null) { setState(() => _favLoaded = true); return; }
      final data = await Supabase.instance.client
          .from('favoris')
          .select('annonce_id')
          .eq('utilisateur_id', user.id);
      final ids = (data as List)
          .map((e) => (e['annonce_id'] ?? '').toString())
          .where((id) => id.isNotEmpty);
      setState(() {
        _favIds..clear()..addAll(ids);
        _favLoaded = true;
      });
    } catch (_) {
      setState(() => _favLoaded = true);
    }
  }

  Future<void> _toggleFavori(String annonceId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final wasFav = _favIds.contains(annonceId);
    setState(() { wasFav ? _favIds.remove(annonceId) : _favIds.add(annonceId); });

    try {
      if (wasFav) {
        await Supabase.instance.client
            .from('favoris').delete()
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
      setState(() { wasFav ? _favIds.add(annonceId) : _favIds.remove(annonceId); });
    }
  }

  List<Map<String, dynamic>> _filtered() {
    final cat = _selectedCatId;
    final f = _searchCtrl.text.trim().toLowerCase();
    Iterable<Map<String, dynamic>> it = _allAnnonces;
    if (cat != null) it = it.where((a) => a['categorie_id'] == cat);
    if (f.isNotEmpty) {
      it = it.where((a) {
        final t = (a['titre'] ?? '').toString().toLowerCase();
        final d = (a['description'] ?? '').toString().toLowerCase();
        return t.contains(f) || d.contains(f);
      });
    }
    return it.toList();
  }

  String _fmtGNF(dynamic value) {
    if (value == null) return '0';
    final num n = (value is num) ? value : num.tryParse(value.toString()) ?? 0;
    final int i = n.round();
    final s = NumberFormat('#,##0', 'en_US').format(i);
    return s.replaceAll(',', '.');
  }

  // --- Chips : fond clair, texte + icône gris; quand sélectionné -> bord + texte/icône rouges (pas d'inversion) ---
  Widget _categoryChip(Map<String, dynamic> cat, bool selected) {
    return GestureDetector(
      onTap: () => setState(() {
        _selectedCatId = cat['id'];
        _selectedLabel = cat['label'];
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? _softRedBg : _cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? _brandRed : _stroke, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cat['icon'],
                size: 18,
                color: selected ? _brandRed : _textSecondary),
            const SizedBox(width: 4),
            Text(
              cat['label'],
              style: TextStyle(
                color: selected ? _brandRed : _textSecondary,
                fontWeight: FontWeight.w600,
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
      backgroundColor: _cardBg,
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

  // --- Bannière : CTA en outline rouge (pas de gros aplat) ---
  Widget _sellBanner() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _stroke),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("C’est le moment de vendre",
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      )),
                  const SizedBox(height: 6),
                  Text(
                    "Touchez des milliers d’acheteurs près de chez vous.",
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: _textSecondary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 20),
              label: const Text("Déposer une annonce"),
              style: OutlinedButton.styleFrom(
                foregroundColor: _brandRed,
                side: const BorderSide(color: _brandRed),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
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

  // --- Carte annonce : prix en texte normal, cœur devient rouge UNIQUEMENT si favori ---
  Widget _annonceCard(Map<String, dynamic> data) {
    final images = List<String>.from(data['images'] ?? []);
    final id = data['id']?.toString() ?? '';
    final prix = data['prix'] ?? 0;
    final devise = data['devise'] ?? 'GNF';
    final ville = data['ville'] ?? '';
    final catId = data['categorie_id'] as int?;
    final catLabel = _cats.firstWhere((c) => c['id'] == catId,
        orElse: () => {'label': ''})['label'] as String;

    final rawDate = data['date_creation'] as String? ?? '';
    DateTime date;
    try { date = DateTime.parse(rawDate); } catch (_) { date = DateTime.now(); }
    final now = DateTime.now();
    final dateText = (date.year == now.year && date.month == now.month && date.day == now.day)
        ? "aujourd’hui ${DateFormat.Hm().format(date)}"
        : DateFormat('dd/MM/yyyy').format(date);

    final isFav = _favIds.contains(id);

    return Card(
      elevation: 1,
      color: _cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _stroke),
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AnnonceDetailPage(annonce: AnnonceModel.fromJson(data)),
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
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${_fmtGNF(prix)} $devise",
                        style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (catLabel.isNotEmpty)
                        Text(catLabel,
                            style: const TextStyle(
                                color: _textSecondary, fontSize: 12)),
                      Text(ville,
                          style: const TextStyle(
                              color: _textSecondary, fontSize: 12)),
                      Text(dateText,
                          style: const TextStyle(
                              color: _textSecondary, fontSize: 12)),
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
                      color: isFav ? _brandRed : _textSecondary,
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
    if (width >= 1400) crossAxis = 5;
    else if (width >= 1100) crossAxis = 4;
    else if (width >= 800) crossAxis = 3;

    final annonces = _filtered();

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _cardBg,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: _textSecondary), // icônes grises
        title: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: _textPrimary),
          decoration: InputDecoration(
            hintText: 'Rechercher une annonce...',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            border: OutlineInputBorder(
              borderSide: const BorderSide(color: _stroke),
              borderRadius: BorderRadius.circular(24),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: _stroke),
              borderRadius: BorderRadius.circular(24),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: _brandRed, width: 1.4),
              borderRadius: BorderRadius.circular(24),
            ),
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            prefixIcon: const Icon(Icons.search, color: _textSecondary),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          ),
          cursorColor: _brandRed,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: _textSecondary),
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
                    // Catégories
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: LayoutBuilder(
                        builder: (_, c) {
                          final isMobile = c.maxWidth < 600;
                          if (isMobile) {
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

                    // Contenu
                    Expanded(
                      child: CustomScrollView(
                        controller: _scrollCtrl,
                        slivers: [
                          SliverToBoxAdapter(child: _sellBanner()),
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  EdgeInsets.only(left: 18, bottom: 4, top: 8),
                              child: Text(
                                'Annonces récentes',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: _textSecondary,
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              sliver: SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxis,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.72,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) =>
                                      _annonceCard(annonces[index]),
                                  childCount: annonces.length,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
      // --- FAB clair, bord rouge, texte/icon rouges (pas d’aplat) ---
      floatingActionButton: FloatingActionButton.extended(
        elevation: 2,
        backgroundColor: _cardBg,
        foregroundColor: _brandRed,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateAnnoncePage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Déposer une annonce'),
        shape: StadiumBorder(
          side: BorderSide(color: _brandRed, width: 1),
        ),
      ),
    );
  }
}
