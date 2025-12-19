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

// ✅ Centralisation erreurs (offline/supabase/timeout)
import 'package:ma_guinee/utils/error_messages_fr.dart';

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

  // Cache global en mémoire
  static List<LogementModel> _cacheFeed = [];

  // ================== CACHE PERSISTANT (Hive) ==================
  static const String _kFeedBoxName = 'logement_feed_box';
  static const String _kCacheVersion =
      'v1'; // incrémente si tu changes le schema LogementModel

  String get _cacheKey => 'logements_${_kCacheVersion}_${_mode}_${_categorie}';
  String get _cacheMetaKey => '${_cacheKey}__meta';

  Future<Box> _ensureFeedBoxOpen() async {
    if (Hive.isBoxOpen(_kFeedBoxName)) return Hive.box(_kFeedBoxName);
    return await Hive.openBox(_kFeedBoxName);
  }

  Future<List<LogementModel>> _readFeedFromDisk(String key) async {
    try {
      final box = await _ensureFeedBoxOpen();
      final cached = box.get(key);
      if (cached is! List || cached.isEmpty) return const [];

      final items = cached
          .whereType<Map>()
          .map((e) => LogementModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);

      return items;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _warmFromDiskCache({
    required String key,
    required bool keepLoading,
  }) async {
    final items = await _readFeedFromDisk(key);
    if (items.isEmpty || !mounted) return;

    _cacheFeed = List<LogementModel>.from(items);

    setState(() {
      _feed
        ..clear()
        ..addAll(items);
      // initState : keepLoading=false => afficher immédiatement
      // reloadAll : keepLoading=true => on garde le refresh en cours
      if (!keepLoading) _loading = false;
      _hasMore = true;
      _error = null;
    });
  }
  // =============================================================

  final List<LogementModel> _feed = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  // (toujours présents côté code, même si non affichés)
  List<Map<String, dynamic>> _favoris = [];
  List<Map<String, dynamic>> _mine = [];

  // ✅ Favoris (IDs) pour icône coeur sur carte
  final Set<String> _favIds = <String>{};

  // ✅ FAB “retour en haut”
  bool _showToTopFab = false;
  static const double _kFabShowAfterPx = 520;

  // -------- Hero / Carousel --------
  final PageController _heroCtrl = PageController();
  int _heroIndex = 0;
  Timer? _heroTimer;
  int? _pendingHeroIndex;

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

    _scrollCtrl.addListener(_onScrollChanged);
    _tryLoadFromCache();

    if (_feed.isEmpty && _cacheFeed.isNotEmpty) {
      _feed.addAll(_cacheFeed);
      _loading = false;
      _hasMore = true;
    }

    _reloadAll();

    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_heroIndex + 1) % _heroImages.length;
      _animateHeroTo(next);
    });
  }

  void _onScrollChanged() {
    if (!_scrollCtrl.hasClients) return;

    final px = _scrollCtrl.position.pixels;
    final shouldShow = px >= _kFabShowAfterPx;

    if (shouldShow != _showToTopFab) {
      setState(() => _showToTopFab = shouldShow);
    }
  }

  void _scrollToTop() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _tryLoadFromCache() {
    // Warm start (initState) : afficher le cache immédiatement
    unawaited(_warmFromDiskCache(key: _cacheKey, keepLoading: false));
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
          _heroCtrl.jumpToPage(
            _pendingHeroIndex!.clamp(0, _heroImages.length - 1),
          );
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
    _scrollCtrl.removeListener(_onScrollChanged);
    _scrollCtrl.dispose();
    super.dispose();
  }

  // =================================== DATA ===================================

  Future<void> _reloadAll() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });

    // ✅ Affiche instantanément le cache persistant correspondant aux filtres
    // tout en laissant le refresh réseau continuer.
    unawaited(_warmFromDiskCache(key: _cacheKey, keepLoading: true));

    try {
      final firstPageF = _fetchPage(offset: 0);
      final favF = _loadFavoris(); // ✅ met aussi _favIds
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

      _cacheFeed = List<LogementModel>.from(pageItems);
      await _saveFeedToDisk(pageItems);

      // ✅ succès réseau
      SoneyaErrorCenter.reportNetworkSuccess();
    } catch (e, st) {
      // ✅ Centralise l’erreur (overlay global) + message FR sans URL dans la page
      SoneyaErrorCenter.showException(e, st);

      if (!mounted) return;
      setState(() {
        _error = frMessageFromError(e, st);
        _loading = false;
      });
    }
  }

  Future<void> _saveFeedToDisk(List<LogementModel> items) async {
    try {
      final box = await _ensureFeedBoxOpen();
      await box.put(_cacheKey, items.map((e) => e.toJson()).toList());
      await box.put(_cacheMetaKey, {
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'count': items.length,
      });
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore) return;

    setState(() => _loadingMore = true);
    try {
      final items = await _fetchPage(offset: _feed.length);
      if (!mounted) return;

      setState(() {
        _feed.addAll(items);
        _hasMore = items.length == _pageSize;
      });

      _cacheFeed = List<LogementModel>.from(_feed);
      await _saveFeedToDisk(_feed);

      // ✅ succès réseau
      SoneyaErrorCenter.reportNetworkSuccess();
    } catch (e, st) {
      if (!mounted) return;

      // ✅ Centralisation
      SoneyaErrorCenter.showException(e, st);

      // Optionnel : petit snack en FR (sans URL), sans casser ta logique existante
      _snack(frMessageFromError(e, st));
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
        cat = null; // tous
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
      final up = context.read<UserProvider?>();
      final id = up?.utilisateur?.id?.toString();
      if (id != null && id.trim().isNotEmpty) return id.trim();
    } catch (_) {}
    final sid = _sb.auth.currentUser?.id;
    return (sid != null && sid.isNotEmpty) ? sid : null;
  }

  Future<List<Map<String, dynamic>>> _loadFavoris() async {
    final uid = _currentUserId();
    if (uid == null) {
      _favIds.clear();
      return [];
    }

    final favRows = await _sb
        .from('logement_favoris')
        .select('logement_id, cree_le')
        .eq('user_id', uid)
        .order('cree_le', ascending: false);

    final List<String> ids = (favRows as List)
        .map((e) => (e as Map)['logement_id']?.toString())
        .whereType<String>()
        .toList(growable: false);

    _favIds
      ..clear()
      ..addAll(ids);

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

  Future<void> _toggleFav(String logementId) async {
    final uid = _currentUserId();
    if (uid == null) {
      _snack('Veuillez vous connecter pour ajouter aux favoris.');
      return;
    }

    final wasFav = _favIds.contains(logementId);

    setState(() {
      if (wasFav) {
        _favIds.remove(logementId);
      } else {
        _favIds.add(logementId);
      }
    });

    try {
      if (wasFav) {
        await _sb
            .from('logement_favoris')
            .delete()
            .eq('user_id', uid)
            .eq('logement_id', logementId);
      } else {
        await _sb.from('logement_favoris').insert({
          'user_id': uid,
          'logement_id': logementId,
        });
      }

      // ✅ succès réseau
      SoneyaErrorCenter.reportNetworkSuccess();
    } catch (e, st) {
      if (!mounted) return;

      setState(() {
        if (wasFav) {
          _favIds.add(logementId);
        } else {
          _favIds.remove(logementId);
        }
      });

      // ✅ Centralisation
      SoneyaErrorCenter.showException(e, st);

      // Message court FR sans URL
      _snack("Impossible de mettre à jour les favoris. Veuillez réessayer.");
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ✅ Bottom sheet “Filtres” (home)
  Future<void> _openHomeFilters() async {
    final res = await showModalBottomSheet<_HomeFilterResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _HomeFiltersSheet(
        initialMode: _mode,
        initialCategorie: _categorie,
        primary: _primary,
        accent: _accent,
      ),
    );

    if (res == null) return;

    setState(() {
      _mode = res.mode;
      _categorie = res.categorie;
    });
    _reloadAll();
  }

  void _openMap() {
    final args = <String, dynamic>{
      'mode': _mode,
      if (_categorie != 'tous') 'categorie': _categorie,
      if (_searchCtrl.text.trim().isNotEmpty) 'q': _searchCtrl.text.trim(),
    };
    Navigator.pushNamed(context, AppRoutes.logementMap, arguments: args);
  }

  void _openListAdvanced() {
    final args = <String, dynamic>{
      'q': _searchCtrl.text.trim(),
      'mode': _mode,
      if (_categorie != 'tous') 'categorie': _categorie,
    };
    Navigator.pushNamed(context, AppRoutes.logementList, arguments: args);
  }

  // =================================== UI ===================================

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final double mf = media.textScaleFactor.clamp(1.0, 1.15).toDouble();
    final padding = media.size.width > 600 ? 20.0 : 12.0;

    final bool showSkeleton = _loading && _feed.isEmpty && _cacheFeed.isEmpty;
    final muted = _isDark ? Colors.white70 : Colors.black54;

    return MediaQuery(
      data: media.copyWith(textScaleFactor: mf),
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
              if (showSkeleton)
                _skeletonGrid(context)
              else if (_error != null && _feed.isEmpty)
                _errorBox(_error!)
              else ...[
                _sectionTitle(
                  "Tous les biens",
                  trailing: TextButton.icon(
                    onPressed: _openHomeFilters,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text("Filtres"),
                    style: TextButton.styleFrom(foregroundColor: _primary),
                  ),
                ),
                const SizedBox(height: 12),
                _gridFeed(_feed),
                const SizedBox(height: 14),
                _paginationFooter(muted),
                const SizedBox(height: 40),
              ],
            ],
          ),
        ),
        floatingActionButton: IgnorePointer(
          ignoring: !_showToTopFab,
          child: AnimatedOpacity(
            opacity: _showToTopFab ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: AnimatedScale(
              scale: _showToTopFab ? 1 : 0.95,
              duration: const Duration(milliseconds: 180),
              child: FloatingActionButton(
                heroTag: 'logementHomeToTop',
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                onPressed: _scrollToTop,
                child: const Icon(Icons.keyboard_arrow_up_rounded, size: 30),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _paginationFooter(Color muted) {
    final isEmpty = _feed.isEmpty && !_loading;

    if (_loadingMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_hasMore && !isEmpty) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _loadMore,
                  icon: const Icon(Icons.expand_more_rounded),
                  label: const Text(
                    "Charger plus",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _openHomeFilters,
                child: const Icon(Icons.tune_rounded),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _openMap,
                child: const Icon(Icons.map_outlined),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _openListAdvanced,
            icon: const Icon(Icons.search_rounded),
            label: Text(
              "Recherche avancée",
              style: TextStyle(color: _primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isEmpty
                ? "Aucun résultat pour ces filtres."
                : "— Fin de la liste —",
            style: TextStyle(color: muted, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _openHomeFilters,
                icon: const Icon(Icons.tune_rounded),
                label: const Text("Filtres"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text("Carte"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.logementEdit)
                        .then((_) => _reloadAll()),
                icon: const Icon(Icons.add_home_work_outlined),
                label: const Text("Publier"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _ctaGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _scrollToTop,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            label: Text(
              "Retour en haut",
              style: TextStyle(color: _primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ================== END DRAWER ==================
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
            itemBuilder: (_, i) => Stack(
              fit: StackFit.expand,
              children: [
                _FadeInNetworkImage(url: _heroImages[i], cover: true),
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
          Positioned(left: 12, right: 12, bottom: 12, child: _searchField()),
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
              color: _mode == "location" ? Colors.white : Colors.black87),
          backgroundColor: Colors.white,
          shape: StadiumBorder(
            side: BorderSide(
                color: _mode == "location" ? _accent : Colors.black12),
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
              color: _mode == "achat" ? Colors.white : Colors.black87),
          backgroundColor: Colors.white,
          shape: StadiumBorder(
            side:
                BorderSide(color: _mode == "achat" ? _accent : Colors.black12),
          ),
        ),
      ],
    );
  }

  Widget _categoriesBar() {
    const cats = <_CatItem>[
      _CatItem(Icons.grid_view, 'Tous', 'tous'),
      _CatItem(Icons.home, 'Maison', 'maison'),
      _CatItem(Icons.apartment, 'Appartement', 'appartement'),
      _CatItem(Icons.meeting_room, 'Studio', 'studio'),
      _CatItem(Icons.park, 'Terrain', 'terrain'),
    ];

    return Row(
      children: List.generate(cats.length, (i) {
        final item = cats[i];
        final selected = _categorie == item.id;
        return Expanded(
          child: InkWell(
            onTap: () {
              setState(() => _categorie = item.id);
              _reloadAll();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: selected ? _accent : Colors.white,
                  child: Icon(item.icon,
                      size: 22, color: selected ? Colors.white : _primary),
                ),
                const SizedBox(height: 6),
                Text(
                  item.label,
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
          icon: const Icon(Icons.add_home_work_outlined),
          label: const Text("Publier un bien"),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: const BorderSide(color: _primary),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _openMap,
          icon: const Icon(Icons.map_outlined),
          label: const Text("Carte"),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: const BorderSide(color: _primary),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _openHomeFilters,
          icon: const Icon(Icons.tune_rounded),
          label: const Text("Filtres"),
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

  int _crossCountFor(double screenW) {
    if (screenW < 600) return 1;
    return max(2, (screenW / 360).floor());
  }

  // ✅ CORRECTION DEFINITIVE : carte plus haute => plus d’espace texte => plus de bande jaune/noir
  double _aspectRatioFor(double screenW) {
    // PLUS PETIT = PLUS HAUT (height = width / ratio)
    if (screenW < 600) return 0.95; // mobile : plus haut
    return 1.15; // grand écran : un peu plus haut aussi
  }

  Widget _skeletonGrid(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final crossCount = _crossCountFor(screenW);
    final ratio = _aspectRatioFor(screenW);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
        childAspectRatio: ratio,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => const _SkeletonBienCard(),
    );
  }

  Widget _gridFeed(List<LogementModel> items) {
    if (items.isEmpty) return _emptyCard("Aucun bien pour ces filtres");

    final screenW = MediaQuery.of(context).size.width;
    final crossCount = _crossCountFor(screenW);
    final ratio = _aspectRatioFor(screenW);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
        childAspectRatio: ratio,
      ),
      cacheExtent: 1200,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final b = items[i];
        final isFav = _favIds.contains(b.id);
        return _BienCardLuxury(
          bien: b,
          isFav: isFav,
          onToggleFav: () => _toggleFav(b.id),
        );
      },
    );
  }

  Widget _emptyCard(String msg) => Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)),
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

// ------------------- BottomSheet “Filtres” HOME -------------------

class _HomeFilterResult {
  final String mode;
  final String categorie;
  const _HomeFilterResult({required this.mode, required this.categorie});
}

class _HomeFiltersSheet extends StatefulWidget {
  const _HomeFiltersSheet({
    required this.initialMode,
    required this.initialCategorie,
    required this.primary,
    required this.accent,
  });

  final String initialMode;
  final String initialCategorie;
  final Color primary;
  final Color accent;

  @override
  State<_HomeFiltersSheet> createState() => _HomeFiltersSheetState();
}

class _HomeFiltersSheetState extends State<_HomeFiltersSheet> {
  late String _mode;
  late String _cat;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode; // location | achat
    _cat = widget.initialCategorie; // tous | maison | ...
  }

  void _reset() {
    setState(() {
      _mode = 'location';
      _cat = 'tous';
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets.bottom + 16;

    const cats = <_CatItem>[
      _CatItem(Icons.grid_view, 'Tous', 'tous'),
      _CatItem(Icons.home, 'Maison', 'maison'),
      _CatItem(Icons.apartment, 'Appartement', 'appartement'),
      _CatItem(Icons.meeting_room, 'Studio', 'studio'),
      _CatItem(Icons.park, 'Terrain', 'terrain'),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: padding, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 12),
            const Text("Filtres",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            const Text("Type d’opération"),
            const SizedBox(height: 8),
            Wrap(spacing: 10, children: [
              ChoiceChip(
                label: const Text('Location'),
                selected: _mode == 'location',
                selectedColor: widget.accent,
                labelStyle:
                    TextStyle(color: _mode == 'location' ? Colors.white : null),
                onSelected: (_) => setState(() => _mode = 'location'),
              ),
              ChoiceChip(
                label: const Text('Achat'),
                selected: _mode == 'achat',
                selectedColor: widget.accent,
                labelStyle:
                    TextStyle(color: _mode == 'achat' ? Colors.white : null),
                onSelected: (_) => setState(() => _mode = 'achat'),
              ),
            ]),
            const SizedBox(height: 16),
            const Text("Catégorie"),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final c in cats)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _cat == c.id,
                    selectedColor: widget.accent,
                    labelStyle:
                        TextStyle(color: _cat == c.id ? Colors.white : null),
                    onSelected: (_) => setState(() => _cat = c.id),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: widget.primary),
                      foregroundColor: widget.primary,
                    ),
                    onPressed: _reset,
                    child: const Text('Réinitialiser'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accent,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Appliquer'),
                    onPressed: () {
                      Navigator.pop(
                        context,
                        _HomeFilterResult(mode: _mode, categorie: _cat),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// Petit modèle pour catégories
class _CatItem {
  final IconData icon;
  final String label;
  final String id;
  const _CatItem(this.icon, this.label, this.id);
}

// ======================== Carte logement : LUXE ===========================
// (Aucune modification ci-dessous : UI intacte)
class _BienCardLuxury extends StatelessWidget {
  final LogementModel bien;
  final bool isFav;
  final VoidCallback onToggleFav;

  const _BienCardLuxury({
    required this.bien,
    required this.isFav,
    required this.onToggleFav,
  });

  static const _accent = Color(0xFFE0006D);

  static String _clean(String s) {
    return s
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final image = (bien.photos.isNotEmpty) ? bien.photos.first : null;
    final modeTxt = bien.mode == LogementMode.achat ? 'Achat' : 'Location';
    final catTxt = _labelCat(bien.categorie);

    final price = (bien.prixGnf != null)
        ? _formatPrice(bien.prixGnf!, bien.mode)
        : (bien.mode == LogementMode.achat
            ? 'Prix à discuter'
            : 'Loyer à discuter');

    final loc = [
      if ((bien.ville ?? '').trim().isNotEmpty) bien.ville!.trim(),
      if ((bien.commune ?? '').trim().isNotEmpty) bien.commune!.trim(),
    ].join(' • ');

    final safeTitle = _clean(bien.titre);
    final safeLoc = _clean(loc);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {
          if (bien.id.isEmpty) return;
          Navigator.pushNamed(context, AppRoutes.logementDetail,
              arguments: bien.id);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.black.withOpacity(.06), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.10),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: LayoutBuilder(
              builder: (ctx, c) {
                final ts = MediaQuery.textScaleFactorOf(context);
                final panelH = min(
                  c.maxHeight,
                  max(c.maxHeight * 0.48, 190.0 * ts),
                );

                return Stack(
                  children: [
                    Positioned.fill(
                      child: (image != null && image.isNotEmpty)
                          ? _FadeInNetworkImage(url: image, cover: true)
                          : Container(
                              color: const Color(0xFF101010),
                              alignment: Alignment.center,
                              child: const Icon(Icons.home_outlined,
                                  size: 56, color: Colors.white54),
                            ),
                    ),
                    Positioned(
                      left: 14,
                      top: 14,
                      child: _TopPill(
                        text: modeTxt,
                        icon: Icons.swap_horiz_rounded,
                      ),
                    ),
                    Positioned(
                      right: 14,
                      top: 14,
                      child: _FavButton(
                        active: isFav,
                        onTap: onToggleFav,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: panelH,
                      child: _LuxuryGlassPanel(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(22),
                          topRight: Radius.circular(22),
                          bottomLeft: Radius.circular(28),
                          bottomRight: Radius.circular(28),
                        ),
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              safeTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.08,
                                letterSpacing: -.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    catTxt,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(.92),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _PricePill(text: price),
                              ],
                            ),
                            const Spacer(),
                            if (safeLoc.isNotEmpty)
                              Row(
                                children: [
                                  Icon(Icons.place,
                                      size: 18,
                                      color: Colors.white.withOpacity(.92)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      safeLoc,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(.92),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
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
    final suffix = mode == LogementMode.achat ? 'GNF' : 'GNF / mois';
    final v = value.isFinite ? value : 0;

    if (v.abs() >= 1000000000) {
      final b = v / 1000000000;
      final s = _trimDec(b, 1);
      return '$s milliard $suffix';
    }

    if (v.abs() >= 1000000) {
      final m = v / 1000000;
      final s = _trimDec(m, 1);
      return '$s million $suffix';
    }

    final s = _withDots(v.round());
    return '$s $suffix';
  }

  static String _trimDec(num x, int decimals) {
    final s = x.toStringAsFixed(decimals);
    if (s.endsWith('.0')) return s.substring(0, s.length - 2);
    return s;
  }

  static String _withDots(int n) {
    final neg = n < 0;
    var s = n.abs().toString();
    final out = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final left = s.length - i;
      out.write(s[i]);
      if (left > 1 && left % 3 == 1) out.write('.');
    }
    return neg ? '-${out.toString()}' : out.toString();
  }
}

class _TopPill extends StatelessWidget {
  final String text;
  final IconData icon;
  const _TopPill({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.40),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.18), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(.95)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FavButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _FavButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(.30),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(.18), width: 1),
          ),
          child: Icon(
            active ? Icons.favorite : Icons.favorite_border,
            color: active ? const Color(0xFFE0006D) : Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  final String text;
  const _PricePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.22), width: 1),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFE0006D),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _LuxuryGlassPanel extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsets padding;

  const _LuxuryGlassPanel({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.08),
          borderRadius: borderRadius,
          border: Border.all(color: Colors.white.withOpacity(.18), width: 1),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                  child: Container(color: Colors.white.withOpacity(.06))),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(.10),
                        Colors.white.withOpacity(.05),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.30, 0.62, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                child: Container(
                    height: 1.2, color: Colors.white.withOpacity(.22)),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    border: Border.all(
                        color: Colors.white.withOpacity(.08), width: 1),
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBienCard extends StatelessWidget {
  const _SkeletonBienCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1.8,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (_, c) {
          final ts = MediaQuery.textScaleFactorOf(context);
          final panelH = min(c.maxHeight, max(c.maxHeight * 0.48, 190.0 * ts));

          return Stack(
            children: [
              Positioned.fill(child: Container(color: Colors.grey.shade300)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: panelH,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.30),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(22),
                      topRight: Radius.circular(22),
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

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
      loadingBuilder: (ctx, child, ev) {
        if (ev == null) {
          if (_ctrl.status != AnimationStatus.completed) _ctrl.forward();
          return FadeTransition(opacity: _fade, child: child);
        }
        return Container(color: Colors.grey.shade200);
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
