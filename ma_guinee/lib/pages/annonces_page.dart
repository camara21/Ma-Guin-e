import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_guinee/models/annonce_model.dart';

// Cache disque & images
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'favoris_page.dart';
import 'create_annonce_page.dart';
import 'annonce_detail_page.dart';

class AnnoncesPage extends StatefulWidget {
  const AnnoncesPage({Key? key}) : super(key: key);

  @override
  State<AnnoncesPage> createState() => _AnnoncesPageState();
}

class _AnnoncesPageState extends State<AnnoncesPage>
    with AutomaticKeepAliveClientMixin {
  // ===== COULEURS =====
  static const Color _brandRed = Color(0xFFD92D20);
  static const Color _softRedBg = Color(0xFFFFF1F1);
  static const Color _pageBg = Color(0xFFF5F7FA);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _stroke = Color(0xFFE5E7EB);
  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _textSecondary = Color(0xFF6B7280);

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  // Cache global en mémoire pour toute l'app (instantané au retour)
  static List<Map<String, dynamic>> _cacheAnnonces = [];

  // données
  List<Map<String, dynamic>> _allAnnonces = [];
  bool _loading = true;
  String? _error;

  // favoris (cache local)
  final Set<String> _favIds = <String>{};
  bool _favLoaded = false;

  // catégories
  final Map<String, dynamic> _catTous = const {
    'label': 'Tous',
    'icon': Icons.apps,
    'id': null
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

    // 1) Essayer de charger depuis le cache disque (Hive) -> ouverture app instantanée
    try {
      if (Hive.isBoxOpen('annonces_box')) {
        final box = Hive.box('annonces_box');
        final cached = box.get('annonces') as List?;
        if (cached != null && cached.isNotEmpty) {
          _allAnnonces = cached
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _cacheAnnonces = List<Map<String, dynamic>>.from(_allAnnonces);
          _loading = false;
        }
      }
    } catch (_) {
      // ignore, on tombera sur le cache mémoire ou réseau
    }

    // 2) Si pas de cache disque mais cache mémoire dispo (même session)
    if (_allAnnonces.isEmpty && _cacheAnnonces.isNotEmpty) {
      _allAnnonces = List<Map<String, dynamic>>.from(_cacheAnnonces);
      _loading = false;
    }

    // 3) Requête réseau en arrière-plan pour rafraîchir
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

  @override
  bool get wantKeepAlive => true;

  // ========= DATA =========
  Future<void> _loadAnnonces() async {
    if (_allAnnonces.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      _loading = true;
      _error = null;
    }

    try {
      final supa = Supabase.instance.client;
      final raw = await supa.from('annonces').select('''
            *,
            proprietaire:utilisateurs!annonces_user_id_fkey (
              id, prenom, nom, photo_url,
              annonces:annonces!annonces_user_id_fkey ( count )
            )
          ''').order('date_creation', ascending: false);

      final list = (raw as List).cast<Map<String, dynamic>>();

      // Met à jour le cache mémoire
      _cacheAnnonces = List<Map<String, dynamic>>.from(list);

      // Sauvegarde sur disque (Hive) pour les prochains lancements
      try {
        if (Hive.isBoxOpen('annonces_box')) {
          final box = Hive.box('annonces_box');
          await box.put('annonces', list);
        }
      } catch (_) {
        // si Hive pas prêt -> on ne casse pas l'affichage
      }

      if (!mounted) return;
      setState(() {
        _allAnnonces = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
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
      setState(() {
        wasFav ? _favIds.add(annonceId) : _favIds.remove(annonceId);
      });
    }
  }

  // ========= FILTRES =========
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

  // ========= UI HELPERS =========
  Widget _categoryChip(Map<String, dynamic> cat, bool selected) {
    return GestureDetector(
      onTap: () => setState(() {
        _selectedCatId = cat['id'] as int?;
        _selectedLabel = cat['label'] as String;
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
            Icon(cat['icon'] as IconData,
                size: 18, color: selected ? _brandRed : _textSecondary),
            const SizedBox(width: 4),
            Text(
              cat['label'] as String,
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

  Widget _sellBanner() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  Text(
                    "C’est le moment de vendre",
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

  /// ======== CARD ANNONCE — compacte & pro ========
  Widget _annonceCard(Map<String, dynamic> data) {
    final images = List<String>.from(data['images'] ?? const []);
    final prix = data['prix'] ?? 0;
    final devise = data['devise'] ?? 'GNF';
    final ville = data['ville'] ?? '';
    final catId = data['categorie_id'] as int?;
    final catLabel = _cats.firstWhere(
      (c) => c['id'] == catId,
      orElse: () => const {'label': ''},
    )['label'] as String;

    final rawDate = data['date_creation']?.toString() ?? '';
    DateTime date;
    try {
      date = DateTime.parse(rawDate);
    } catch (_) {
      date = DateTime.now();
    }
    final dateText = DateFormat('dd/MM/yyyy').format(date);

    // --------- infos vendeur (SANS cast Map<String,dynamic>) ----------
    final Map? owner = data['proprietaire'] as Map?;

    final String sellerName = () {
      if (owner == null) return 'Utilisateur';
      final prenom = (owner['prenom'] ?? '').toString().trim();
      final nom = (owner['nom'] ?? '').toString().trim();
      final full = [prenom, nom].where((p) => p.isNotEmpty).join(' ');
      return full.isEmpty ? 'Utilisateur' : full;
    }();

    final String? sellerAvatar =
        owner != null ? (owner['photo_url'] as String?) : null;

    final int sellerAdsCount = () {
      if (owner == null) return 0;
      final lst = (owner['annonces'] as List?) ?? const [];
      if (lst.isEmpty) return 0;
      final first = (lst.first as Map)['count'];
      return (first is int) ? first : int.tryParse(first.toString()) ?? 0;
    }();

    return Card(
      color: _cardBg,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _stroke),
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        // tap instantané : pas d'await
        onTap: () {
          final enriched = Map<String, dynamic>.from(data);
          enriched['seller_name'] = sellerName;
          final annonce = AnnonceModel.fromJson(enriched);

          // precache en arrière-plan (ne bloque pas la navigation)
          if (images.isNotEmpty) {
            precacheImage(NetworkImage(images.first), context);
          }

          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => AnnonceDetailPage(annonce: annonce),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              transitionsBuilder: (_, __, ___, child) => child,
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image homogène + cache disque
            AspectRatio(
              aspectRatio: 16 / 11,
              child: CachedNetworkImage(
                imageUrl: images.isNotEmpty
                    ? images.first
                    : 'https://via.placeholder.com/600x400?text=Photo+indisponible',
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.grey[200]),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[200],
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported,
                    size: 40,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),

            // Corps : plus compact
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['titre'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _textPrimary,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_fmtGNF(prix)} $devise",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: _textPrimary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      catLabel.isEmpty ? ' ' : catLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 11.5,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$dateText · $ville",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 11.5,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFFE5E7EB),
                          child: sellerAvatar != null && sellerAvatar.isNotEmpty
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: sellerAvatar,
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.person,
                                      size: 14,
                                      color: _textSecondary,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 14,
                                  color: _textSecondary,
                                ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            sellerName.isEmpty ? "Utilisateur" : sellerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.0,
                            ),
                          ),
                        ),
                        Text(
                          "$sellerAdsCount annonce${sellerAdsCount > 1 ? 's' : ''}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: _textSecondary,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Skeleton de carte pour chargement (placeholder gris)
  Widget _annonceSkeletonCard() {
    return Card(
      color: _cardBg,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _stroke),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 11,
            child: Container(color: Colors.grey.shade300),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 10,
                    width: double.infinity,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 8,
                    width: 60,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 8,
                    width: 100,
                    color: Colors.grey.shade300,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.grey.shade300,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 8,
                          color: Colors.grey.shade300,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ======== RESPONSIVE GRID ========
  int _columnsForWidth(double w) {
    if (w >= 1600) return 6; // très grand écran
    if (w >= 1400) return 5; // xl desktop
    if (w >= 1100) return 4; // desktop
    if (w >= 800) return 3; // tablette
    return 2; // mobile
  }

  /// Calcule un `childAspectRatio` ajusté (évite overflow avec une carte plus compacte)
  double _ratioFor(
      double screenWidth, int cols, double spacing, double paddingH) {
    final usableWidth = screenWidth - paddingH * 2 - spacing * (cols - 1);
    final itemWidth = usableWidth / cols;

    // Hauteur image (fixe par ratio 16/11)
    final imageH = itemWidth * (11 / 16);

    // Hauteur “texte + vendeur”.
    double infoH;
    if (itemWidth < 220) {
      infoH = 136;
    } else if (itemWidth < 280) {
      infoH = 128;
    } else if (itemWidth < 340) {
      infoH = 122;
    } else {
      infoH = 118;
    }

    final totalH = imageH + infoH;
    final ratio = itemWidth / totalH;
    return ratio;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final screenW = MediaQuery.of(context).size.width;
    final gridCols = _columnsForWidth(screenW);

    const double gridSpacing = 4.0;
    const double gridHPadding = 6.0;

    final annonces = _filtered();
    final ratio = _ratioFor(screenW, gridCols, gridSpacing, gridHPadding);

    // Skeleton uniquement si on charge ET qu'on n'a pas encore de données
    final bool showSkeleton =
        _loading && _allAnnonces.isEmpty && _cacheAnnonces.isEmpty;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _cardBg,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: _textSecondary),
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
      body: _error != null
          ? Center(child: Text('Erreur : $_error'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Catégories
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: LayoutBuilder(
                    builder: (_, c) {
                      final isMobile = c.maxWidth < 600;
                      final chips = [_catTous, ..._cats].map((cat) {
                        final sel = _selectedLabel == cat['label'];
                        return _categoryChip(cat, sel);
                      }).toList();

                      if (isMobile) {
                        return SizedBox(
                          height: 44,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(children: chips),
                          ),
                        );
                      }
                      return Wrap(
                        spacing: 6,
                        runSpacing: 8,
                        children: chips,
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
                          padding: EdgeInsets.only(left: 16, bottom: 4, top: 4),
                          child: Text(
                            'Annonces récentes',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.5,
                              color: _textSecondary,
                            ),
                          ),
                        ),
                      ),
                      if (showSkeleton)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: gridHPadding, vertical: 4),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: gridCols,
                              crossAxisSpacing: gridSpacing,
                              mainAxisSpacing: gridSpacing,
                              childAspectRatio: ratio,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _annonceSkeletonCard(),
                              childCount: 6, // cartes fantômes
                            ),
                          ),
                        )
                      else if (annonces.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: Text('Aucune annonce trouvée.')),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: gridHPadding, vertical: 4),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: gridCols,
                              crossAxisSpacing: gridSpacing,
                              mainAxisSpacing: gridSpacing,
                              childAspectRatio: ratio,
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
        shape: const StadiumBorder(
          side: BorderSide(color: _brandRed, width: 1),
        ),
      ),
    );
  }
}
