// lib/pages/logement/logement_home_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../services/logement_service.dart';
import '../../models/logement_models.dart';
import '../../routes.dart';

// Provider / modèle utilisateur
import '../../providers/user_provider.dart';
import '../../models/utilisateur_model.dart';

// Pages internes
import 'favoris_page.dart';
import 'mes_annonces_page.dart';

class LogementHomePage extends StatefulWidget {
  const LogementHomePage({super.key});

  @override
  State<LogementHomePage> createState() => _LogementHomePageState();
}

class _LogementHomePageState extends State<LogementHomePage> {
  final _searchCtrl = TextEditingController();
  final _svc = LogementService();
  final _sb = Supabase.instance.client;

  // Filtres
  String _mode = 'location'; // location | achat
  String _categorie = 'tous'; // tous | maison | appartement | studio | terrain

  // Flux paginé
  static const int _pageSize = 20;
  final ScrollController _scrollCtrl = ScrollController();

  // Cache global en mémoire (comme AnnoncesPage._cacheAnnonces)
  static List<LogementModel> _cacheFeed = [];

  final List<LogementModel> _feed = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  // (toujours présents côté code, même si non affichés)
  List<Map<String, dynamic>> _favoris = [];
  List<Map<String, dynamic>> _mine = [];

  // -------- Hero / Carousel --------
  final PageController _heroCtrl = PageController();
  int _heroIndex = 0;
  Timer? _heroTimer;
  int? _pendingHeroIndex; // si on veut changer de page avant l’attache

  static const List<String> _heroImages = [
    'https://images.unsplash.com/photo-1600585154526-990dced4db0d?q=80&w=1600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1560185127-6ed189bf02f4?q=80&w=1600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1507089947368-19c1da9775ae?q=80&w=1600&auto=format&fit=crop',
  ];

  // Palette
  static const _primary = Color(0xFF0D3B66);
  static const _accent = Color(0xFFE0006D);
  static const _ctaGreen = Color(0xFF0E9F6E);
  static const _neutralBg = Color(0xFFF5F7FB);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();

    _attachInfiniteScroll();

    // 1) Essayer de charger depuis le cache disque (Hive) -> ouverture app instantanée
    _tryLoadFromCache();

    // 2) Si pas de cache disque mais cache mémoire dispo (même session)
    if (_feed.isEmpty && _cacheFeed.isNotEmpty) {
      _feed.addAll(_cacheFeed);
      _loading = false;
      _hasMore = true;
    }

    // 3) Requête réseau en arrière-plan pour rafraîchir les données
    _reloadAll();

    // Auto-slide du hero
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_heroIndex + 1) % _heroImages.length;
      _animateHeroTo(next);
    });
  }

  void _tryLoadFromCache() {
    try {
      if (Hive.isBoxOpen('logement_feed_box')) {
        final box = Hive.box('logement_feed_box');
        final cached = box.get('logements') as List?;
        if (cached != null && cached.isNotEmpty) {
          final items = cached
              .whereType<Map>()
              .map(
                (e) => LogementModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();

          _cacheFeed = List<LogementModel>.from(items);

          setState(() {
            _feed
              ..clear()
              ..addAll(items);
            _loading = false;
            _hasMore = true;
          });
        }
      }
    } catch (_) {
      // on ignore, ça ne doit pas casser l'affichage
    }
  }

  void _animateHeroTo(int index) {
    if (_heroCtrl.hasClients) {
      _heroCtrl.animateToPage(
        index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    } else {
      _pendingHeroIndex = index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pendingHeroIndex != null && _heroCtrl.hasClients) {
          _heroCtrl
              .jumpToPage(_pendingHeroIndex!.clamp(0, _heroImages.length - 1));
          _pendingHeroIndex = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // =================================== DATA ===================================

  void _attachInfiniteScroll() {
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 300 &&
          !_loadingMore &&
          !_loading &&
          _hasMore) {
        _loadMore();
      }
    });
  }

  Future<void> _reloadAll() async {
    if (!mounted) return;

    // Comme pour Annonces : on ne vide pas la liste si on a déjà des données
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });

    try {
      final firstPageF = _fetchPage(offset: 0);
      final favF = _loadFavoris();
      final mineF = _loadMine();

      final results = await Future.wait([firstPageF, favF, mineF]);

      final pageItems = results[0] as List<LogementModel>;

      if (!mounted) return;
      setState(() {
        _feed
          ..clear()
          ..addAll(pageItems);
        _hasMore = pageItems.length == _pageSize;
        _favoris = results[1] as List<Map<String, dynamic>>;
        _mine = results[2] as List<Map<String, dynamic>>;
        _loading = false;
      });

      // Met à jour le cache mémoire
      _cacheFeed = List<LogementModel>.from(pageItems);

      // Sauvegarde disque (Hive) pour les prochains lancements
      await _saveFeedToDisk(pageItems);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveFeedToDisk(List<LogementModel> items) async {
    try {
      if (!Hive.isBoxOpen('logement_feed_box')) return;
      final box = Hive.box('logement_feed_box');
      await box.put(
        'logements',
        items.map((e) => e.toJson()).toList(),
      );
    } catch (_) {
      // ne casse pas l'UI
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final items = await _fetchPage(offset: _feed.length);
      setState(() {
        _feed.addAll(items);
        _hasMore = items.length == _pageSize;
      });

      // Met à jour le cache mémoire + disque avec le feed étendu
      _cacheFeed = List<LogementModel>.from(_feed);
      await _saveFeedToDisk(_feed);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  LogementSearchParams _paramsForCurrentFilters({required int offset}) {
    final mode =
        (_mode == 'achat') ? LogementMode.achat : LogementMode.location;
    LogementCategorie? cat;
    switch (_categorie) {
      case 'maison':
        cat = LogementCategorie.maison;
        break;
      case 'appartement':
        cat = LogementCategorie.appartement;
        break;
      case 'studio':
        cat = LogementCategorie.studio;
        break;
      case 'terrain':
        cat = LogementCategorie.terrain;
        break;
      default:
        cat = null; // 'tous'
    }
    return LogementSearchParams(
      mode: mode,
      categorie: cat,
      orderBy: 'cree_le',
      ascending: false,
      limit: _pageSize,
      offset: offset,
    );
  }

  Future<List<LogementModel>> _fetchPage({required int offset}) {
    final p = _paramsForCurrentFilters(offset: offset);
    return _svc.search(p);
  }

  String? _currentUserId() {
    try {
      final u = context.read<UserProvider?>()?.utilisateur;
      final id = (u as UtilisateurModel?)?.id;
      if (id != null && id.toString().isNotEmpty) return id.toString();
    } catch (_) {}
    final sid = _sb.auth.currentUser?.id;
    return (sid != null && sid.isNotEmpty) ? sid : null;
  }

  Future<List<Map<String, dynamic>>> _loadFavoris() async {
    final uid = _currentUserId();
    if (uid == null) return [];
    final favRows = await _sb
        .from('logement_favoris')
        .select('logement_id, cree_le')
        .eq('user_id', uid)
        .order('cree_le', ascending: false);

    final List<String> ids = (favRows as List)
        .map((e) => (e as Map)['logement_id']?.toString())
        .whereType<String>()
        .toList(growable: false);
    if (ids.isEmpty) return [];

    final rows = await _sb
        .from('logements')
        .select(
            'id, titre, mode, categorie, prix_gnf, ville, commune, cree_le, logement_photos(url, position)')
        .inFilter('id', ids)
        .order('cree_le', ascending: false);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _loadMine() async {
    final uid = _currentUserId();
    if (uid == null) return [];
    final rows = await _sb
        .from('logements')
        .select(
            'id, titre, mode, categorie, prix_gnf, ville, commune, cree_le, logement_photos(url, position)')
        .eq('user_id', uid)
        .order('cree_le', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  // =================================== UI ===================================

  @override
  Widget build(BuildContext context) {
    // clamp léger du textScale
    final media = MediaQuery.of(context);
    final mf = media.textScaleFactor.clamp(1.0, 1.15);

    final padding = media.size.width > 600 ? 20.0 : 12.0;

    // Skeleton uniquement si on charge ET qu'on n'a pas encore de données
    final bool showSkeleton = _loading && _feed.isEmpty && _cacheFeed.isEmpty;

    return MediaQuery(
      data: media.copyWith(textScaleFactor: mf.toDouble()),
      child: Scaffold(
        backgroundColor: _isDark ? const Color(0xFF0F172A) : _neutralBg,
        appBar: AppBar(
          backgroundColor: _primary,
          elevation: 0,
          title: const Text(
            "Logements en Guinée",
            style: TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            Builder(
              builder: (ctx) => IconButton(
                tooltip: "Menu",
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                icon: const Icon(Icons.menu, color: Colors.white),
              ),
            ),
          ],
        ),
        endDrawer: _buildEndDrawer(),
        body: RefreshIndicator(
          onRefresh: _reloadAll,
          child: ListView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(padding),
            children: [
              _heroBanner(),
              const SizedBox(height: 16),
              _modeSwitch(),
              const SizedBox(height: 10),
              _categoriesBar(),
              const SizedBox(height: 16),
              _quickActions(),
              const SizedBox(height: 22),

              // ====== FEED ======
              if (showSkeleton)
                _skeletonGrid(context)
              else if (_error != null && _feed.isEmpty)
                _errorBox(_error!)
              else ...[
                _sectionTitle("Tous les biens"),
                const SizedBox(height: 12),
                _gridFeed(_feed),
                const SizedBox(height: 12),
                _loadingMore
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : (!_hasMore
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                "— Fin de la liste —",
                                style: TextStyle(color: Colors.black45),
                              ),
                            ),
                          )
                        : const SizedBox.shrink()),
                const SizedBox(height: 80),
              ],
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _ctaGreen,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.logementEdit)
              .then((_) => _reloadAll()),
          icon: const Icon(Icons.add_home_work_outlined),
          label: const Text("Publier un bien"),
        ),
      ),
    );
  }

  // ================== END DRAWER (menu) ==================
  Widget _buildEndDrawer() {
    UtilisateurModel? user;
    try {
      user = context.read<UserProvider?>()?.utilisateur;
    } catch (_) {
      user = null;
    }
    final nom = (user?.nom ?? '').trim();
    final prenom = (user?.prenom ?? '').trim();
    final full = ([prenom, nom]..removeWhere((s) => s.isEmpty)).join(' ');
    final photo = user?.photoUrl;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: _neutralBg,
                  backgroundImage: (photo != null && photo.isNotEmpty)
                      ? NetworkImage(photo)
                      : null,
                  child: (photo == null || photo.isEmpty)
                      ? const Icon(Icons.person, size: 28, color: _primary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    full.isEmpty ? 'Utilisateur' : full,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _drawerActionButton(
              icon: Icons.favorite_border,
              label: "Mes favoris",
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context)
                    .push(
                        MaterialPageRoute(builder: (_) => const FavorisPage()))
                    .then((_) => _reloadAll());
              },
            ),
            const SizedBox(height: 10),
            _drawerActionButton(
              icon: Icons.library_books_outlined,
              label: "Mes annonces",
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => const MesAnnoncesPage()))
                    .then((_) => _reloadAll());
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _drawerActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _primary,
          alignment: Alignment.centerLeft,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: _primary),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ------------------ Widgets du corps ------------------

  Widget _heroBanner() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          PageView.builder(
            controller: _heroCtrl,
            itemCount: _heroImages.length,
            onPageChanged: (i) => setState(() => _heroIndex = i),
            itemBuilder: (_, i) => LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final h = c.maxHeight;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _FadeInNetworkImage(
                      url: _heroImages[i],
                      cacheWidth: w.isFinite ? (w * 2).round() : null,
                      cacheHeight: h.isFinite ? (h * 2).round() : null,
                      cover: true,
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xAA0D3B66), Color(0x660A2C4C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const Positioned(
            left: 18,
            right: 18,
            top: 16,
            child: Text(
              "Trouvez votre logement idéal,\nsimplement.",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: Row(
              children: List.generate(_heroImages.length, (i) {
                final active = (i == _heroIndex);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 10 : 8,
                  height: active ? 10 : 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(active ? 0.95 : 0.65),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _searchField(),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      child: TextField(
        controller: _searchCtrl,
        onSubmitted: (_) {
          final q = _searchCtrl.text.trim();
          final args = <String, dynamic>{'q': q, 'mode': _mode};
          if (_categorie != 'tous') args['categorie'] = _categorie;
          Navigator.pushNamed(context, AppRoutes.logementList, arguments: args);
        },
        decoration: InputDecoration(
          hintText: "Rechercher : ville, quartier, mot-clé…",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _modeSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text("Location"),
          selected: _mode == "location",
          onSelected: (_) {
            setState(() => _mode = "location");
            _reloadAll();
          },
          selectedColor: _accent,
          labelStyle: TextStyle(
            color: _mode == "location" ? Colors.white : Colors.black87,
          ),
          backgroundColor: Colors.white,
          shape: StadiumBorder(
            side: BorderSide(
              color: _mode == "location" ? _accent : Colors.black12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        ChoiceChip(
          label: const Text("Achat"),
          selected: _mode == "achat",
          onSelected: (_) {
            setState(() => _mode = "achat");
            _reloadAll();
          },
          selectedColor: _accent,
          labelStyle: TextStyle(
            color: _mode == "achat" ? Colors.white : Colors.black87,
          ),
          backgroundColor: Colors.white,
          shape: StadiumBorder(
            side: BorderSide(
              color: _mode == "achat" ? _accent : Colors.black12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _categoriesBar() {
    final cats = const [
      (Icons.grid_view, 'Tous', 'tous'),
      (Icons.home, 'Maison', 'maison'),
      (Icons.apartment, 'Appartement', 'appartement'),
      (Icons.meeting_room, 'Studio', 'studio'),
      (Icons.park, 'Terrain', 'terrain'),
    ];

    return Row(
      children: List.generate(cats.length, (i) {
        final (icon, label, id) = cats[i];
        final selected = _categorie == id;
        return Expanded(
          child: InkWell(
            onTap: () {
              setState(() => _categorie = id);
              _reloadAll();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: selected ? _accent : Colors.white,
                  child: Icon(
                    icon,
                    size: 22,
                    color: selected ? Colors.white : _primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _quickActions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _ctaGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.logementEdit)
              .then((_) => _reloadAll()),
          icon: const Icon(Icons.add),
          label: const Text("Publier"),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: const BorderSide(color: _primary),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.logementMap),
          icon: const Icon(Icons.map_outlined),
          label: const Text("Carte"),
        ),
      ],
    );
  }

  Widget _sectionTitle(String txt, {Widget? trailing}) {
    return Row(
      children: [
        Text(
          txt,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _primary,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  // ---------- Skeleton grid (cold start uniquement) ----------
  Widget _skeletonGrid(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final crossCount = screenW < 600
        ? max(2, (screenW / 200).floor())
        : max(3, (screenW / 240).floor());
    final totalHGap = (crossCount - 1) * 8.0;
    final itemW = (screenW - totalHGap - 24 /* padding list */) / crossCount;
    final itemH = itemW * (11 / 16) + 120.0;
    final ratio = itemW / itemH;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: ratio,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const _SkeletonBienCard(),
    );
  }

  // ---------- GRILLE responsive (espaces serrés) ----------
  Widget _gridFeed(List<LogementModel> items) {
    if (items.isEmpty) {
      return _emptyCard("Aucun bien pour ces filtres");
    }

    final screenW = MediaQuery.of(context).size.width;
    final crossCount = screenW < 600
        ? max(2, (screenW / 200).floor())
        : max(3, (screenW / 240).floor());
    final totalHGap = (crossCount - 1) * 8.0;
    final itemW = (screenW - totalHGap - 24 /*padding list*/) / crossCount;
    final itemH = itemW * (11 / 16) + 120.0;
    final ratio = itemW / itemH;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: ratio,
      ),
      cacheExtent: 1000,
      itemCount: items.length,
      itemBuilder: (_, i) => _BienCardTight(bien: items[i]),
    );
  }

  // Helpers
  Widget _emptyCard(String msg) => Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(msg, style: const TextStyle(color: Colors.black54)),
      );

  Widget _errorBox(String msg) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF2F4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFCCD6)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
            TextButton(onPressed: _reloadAll, child: const Text('Réessayer')),
          ],
        ),
      );
}

// ======================== Carte logement adaptative ===========================
class _BienCardTight extends StatelessWidget {
  final LogementModel bien;
  const _BienCardTight({required this.bien});

  static const _accent = Color(0xFFE0006D);
  static const _primary = Color(0xFF0D3B66);
  static const _neutralBg = Color(0xFFF5F7FB);

  @override
  Widget build(BuildContext context) {
    final image = (bien.photos.isNotEmpty) ? bien.photos.first : null;
    final mode = bien.mode == LogementMode.achat ? 'Achat' : 'Location';
    final cat = _labelCat(bien.categorie);
    final price = (bien.prixGnf != null)
        ? _formatPrice(bien.prixGnf!, bien.mode)
        : 'Prix à discuter';
    final loc = [
      if (bien.ville != null) bien.ville!,
      if (bien.commune != null) bien.commune!,
    ].join(' • ');

    return InkWell(
      onTap: () {
        if (bien.id.isEmpty) return;
        Navigator.pushNamed(
          context,
          AppRoutes.logementDetail,
          arguments: bien.id,
        );
      },
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final h = w * (11 / 16);
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (image == null || image.isEmpty)
                        Container(
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.image,
                            size: 46,
                            color: Colors.black26,
                          ),
                        )
                      else
                        _FadeInNetworkImage(
                          url: image,
                          cacheWidth: w.isFinite ? (w * 2).round() : null,
                          cacheHeight: h.isFinite ? (h * 2).round() : null,
                          cover: true,
                        ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            mode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bien.titre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _chip(mode),
                      _chip(cat),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _labelCat(LogementCategorie c) {
    switch (c) {
      case LogementCategorie.maison:
        return 'Maison';
      case LogementCategorie.appartement:
        return 'Appartement';
      case LogementCategorie.studio:
        return 'Studio';
      case LogementCategorie.terrain:
        return 'Terrain';
      case LogementCategorie.autres:
        return 'Autres';
    }
  }

  static String _formatPrice(num value, LogementMode mode) {
    if (value >= 1000000) {
      final m = (value / 1000000)
          .toStringAsFixed(1)
          .replaceAll('.0', '')
          .replaceAll(',', '.');
      return mode == LogementMode.achat ? '$m M GNF' : '$m M GNF / mois';
    }
    final s = value.toStringAsFixed(0);
    return mode == LogementMode.achat ? '$s GNF' : '$s GNF / mois';
  }

  static Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _neutralBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );
}

// ----------------- Skeleton Card --------------------
class _SkeletonBienCard extends StatelessWidget {
  const _SkeletonBienCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 11,
            child: Container(color: Colors.grey.shade200),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 150,
                  color: Colors.grey.shade200,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      height: 18,
                      width: 60,
                      color: Colors.grey.shade200,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      height: 18,
                      width: 70,
                      color: Colors.grey.shade200,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 14,
                  width: 90,
                  color: Colors.grey.shade200,
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: 120,
                  color: Colors.grey.shade200,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- Image réseau avec fade-in SANS SPINNER -----------------
class _FadeInNetworkImage extends StatefulWidget {
  final String url;
  final int? cacheWidth;
  final int? cacheHeight;
  final bool cover;

  const _FadeInNetworkImage({
    required this.url,
    this.cacheWidth,
    this.cacheHeight,
    this.cover = false,
  });

  @override
  State<_FadeInNetworkImage> createState() => _FadeInNetworkImageState();
}

class _FadeInNetworkImageState extends State<_FadeInNetworkImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _ctrl.value = 0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.url,
      fit: widget.cover ? BoxFit.cover : BoxFit.contain,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      filterQuality: FilterQuality.high,

      // Chargement : image grise SANS spinner
      loadingBuilder: (ctx, child, ev) {
        if (ev == null) {
          _ctrl.forward();
          return FadeTransition(opacity: _fade, child: child);
        }
        return Container(
          color: Colors.grey.shade200,
        );
      },

      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined,
            size: 40, color: Colors.black26),
      ),
    );
  }
}
