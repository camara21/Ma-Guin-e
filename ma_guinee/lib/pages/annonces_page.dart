// lib/pages/annonces_page.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_guinee/models/annonce_model.dart';

// Cache disque & images
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ✅ Centralisation erreurs (offline/supabase/timeout)
import 'package:ma_guinee/utils/error_messages_fr.dart';

import 'favoris_page.dart';
import 'create_annonce_page.dart';
import 'annonce_detail_page.dart';

class AnnoncesPage extends StatefulWidget {
  const AnnoncesPage({Key? key}) : super(key: key);

  /// Taille page (affichage progressif)
  static const int pageSize = 24;

  /// Préchargement : 1 page max (pour affichage instant)
  static Future<void> preload() async {
    try {
      final supa = Supabase.instance.client;

      final raw = await supa.from('annonces').select('''
            *,
            proprietaire:utilisateurs!annonces_user_id_fkey (
              id, prenom, nom, photo_url,
              annonces:annonces!annonces_user_id_fkey ( count )
            )
          ''').order('date_creation', ascending: false).range(0, pageSize - 1);

      final list = (raw as List).cast<Map<String, dynamic>>();

      _AnnoncesPageState.setGlobalCache(list);

      try {
        if (Hive.isBoxOpen('annonces_box')) {
          final box = Hive.box('annonces_box');
          await box.put('annonces', list);
        }
      } catch (_) {}
    } catch (_) {
      // preload silencieux (ne doit pas spam l’UI au démarrage)
    }
  }

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

  // Cache global mémoire
  static List<Map<String, dynamic>> _cacheAnnonces = [];
  static void setGlobalCache(List<Map<String, dynamic>> list) {
    _cacheAnnonces = List<Map<String, dynamic>>.from(list);
  }

  // data
  List<Map<String, dynamic>> _allAnnonces = [];
  bool _loading = true;
  String? _error;
  bool _initialFetchDone = false;

  // favoris
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

  // pagination locale (affichage progressif)
  static const int _pageSize = AnnoncesPage.pageSize;
  int _visibleCount = _pageSize;
  bool _loadingMore = false;
  bool _hasMore = true;

  // retour en haut
  bool _showToTopFab = false;
  static const double _kFabShowAfterPx = 520;

  // debounce
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _allCats = [_catTous, ..._cats];

    _scrollCtrl.addListener(_onScrollChanged);

    // cache disque (instant)
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
          _initialFetchDone = true;
          _resetVisible();
        }
      }
    } catch (_) {}

    // cache mémoire
    if (_allAnnonces.isEmpty && _cacheAnnonces.isNotEmpty) {
      _allAnnonces = List<Map<String, dynamic>>.from(_cacheAnnonces);
      _loading = false;
      _initialFetchDone = true;
      _resetVisible();
    }

    // ✅ IMPORTANT : on charge TOUT comme ton ancien code (méthode fiable)
    _reloadAll();

    _preloadFavoris();

    // ✅ Recherche locale (comme avant) — pas de query Supabase
    _searchCtrl.addListener(_onSearchChanged);
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

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      _scrollToTop();
      setState(() {
        _resetVisible(); // ✅ pagination locale recalculée
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _scrollCtrl.removeListener(_onScrollChanged);
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  // ===================== DATA (méthode ancien code) =====================

  /// ✅ Charge la liste (sans filtre serveur), comme ton ancien code
  Future<void> _reloadAll() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _error = null;
      });
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

      // caches
      _cacheAnnonces = List<Map<String, dynamic>>.from(list);
      try {
        if (Hive.isBoxOpen('annonces_box')) {
          final box = Hive.box('annonces_box');
          await box.put('annonces', list);
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _allAnnonces = list;
        _loading = false;
        _error = null;
        _initialFetchDone = true;
        _resetVisible();
      });

      // ✅ si un appel réussit, on considère que le réseau est OK
      SoneyaErrorCenter.reportNetworkSuccess();
    } catch (e, st) {
      // ✅ CENTRALISATION : overlay global + message FR sans URL dans la page
      SoneyaErrorCenter.showException(e, st);

      if (!mounted) return;
      setState(() {
        _error = frMessageFromError(e, st);
        _loading = false;
        _initialFetchDone = true;
      });
    }
  }

  /// ✅ Filtrage local EXACT (comme avant)
  List<Map<String, dynamic>> _filtered() {
    final cat = _selectedCatId;
    final f = _searchCtrl.text.trim().toLowerCase();

    Iterable<Map<String, dynamic>> it = _allAnnonces;
    if (cat != null) it = it.where((a) => a['categorie_id'] == cat);

    if (f.isNotEmpty) {
      it = it.where((a) {
        final t = (a['titre'] ?? '').toString().toLowerCase();
        final d = (a['description'] ?? '').toString().toLowerCase();
        final v = (a['ville'] ?? '').toString().toLowerCase();
        return t.contains(f) || d.contains(f) || v.contains(f);
      });
    }
    return it.toList();
  }

  void _resetVisible() {
    final total = _filtered().length;
    _visibleCount = min(_pageSize, total);
    _hasMore = total > _visibleCount;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore) return;

    setState(() => _loadingMore = true);

    // micro délai pour un feeling “progressif” (et garder ton spinner)
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    final total = _filtered().length;
    setState(() {
      _visibleCount = min(_visibleCount + _pageSize, total);
      _hasMore = total > _visibleCount;
      _loadingMore = false;
    });
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

      // ✅ action réussie => réseau OK
      SoneyaErrorCenter.reportNetworkSuccess();
    } catch (e, st) {
      // ✅ CENTRALISATION : overlay global (pas d’erreur brute)
      SoneyaErrorCenter.showException(e, st);

      if (!mounted) return;
      setState(() {
        wasFav ? _favIds.add(annonceId) : _favIds.remove(annonceId);
      });
    }
  }

  String _fmtGNF(dynamic value) {
    if (value == null) return '0';
    final num n = (value is num) ? value : num.tryParse(value.toString()) ?? 0;
    final int i = n.round();
    final s = NumberFormat('#,##0', 'en_US').format(i);
    return s.replaceAll(',', '.');
  }

  // ===================== UI =====================

  void _onSelectCategory(Map<String, dynamic> cat) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedCatId = cat['id'] as int?;
      _selectedLabel = cat['label'] as String;

      // ✅ méthode ancien code : juste recalculer la liste filtrée
      _resetVisible();
    });
    _scrollToTop();
  }

  Widget _categoryChip(Map<String, dynamic> cat, bool selected) {
    return GestureDetector(
      onTap: () => _onSelectCategory(cat),
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

  /// ✅ Recherche intégrée AppBar + fond comme filtres (blanc)
  Widget _appBarSearchField() {
    return Container(
      height: 40,
      alignment: Alignment.center,
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        style: const TextStyle(color: _textPrimary, fontSize: 13.5),
        cursorColor: _brandRed,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Rechercher une annonce...',
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13.2),
          filled: true,
          fillColor: _cardBg,
          prefixIcon: const Icon(Icons.search, color: _textSecondary, size: 20),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchCtrl,
            builder: (_, v, __) {
              if (v.text.trim().isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Effacer',
                icon: const Icon(Icons.close, size: 18, color: _textSecondary),
                onPressed: () {
                  _searchCtrl.clear();
                  FocusScope.of(context).unfocus();
                },
              );
            },
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: _stroke),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: _stroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: _brandRed, width: 1.4),
          ),
        ),
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
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
              onPressed: () async {
                await Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (_) => const CreateAnnoncePage()),
                );
                if (!mounted) return;
                await _reloadAll();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomFooter({required int shownCount, required int totalCount}) {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final hasMoreLocal = totalCount > shownCount;

    if (hasMoreLocal) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadMore,
              icon: const Icon(Icons.expand_more),
              label: const Text(
                "Charger plus",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "$shownCount / $totalCount annonce${totalCount > 1 ? 's' : ''}",
            style: const TextStyle(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      CupertinoPageRoute(
                          builder: (_) => const CreateAnnoncePage()),
                    );
                    if (!mounted) return;
                    await _reloadAll();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Déposer"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textPrimary,
                    side: const BorderSide(color: _stroke),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _scrollToTop,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textPrimary,
                  side: const BorderSide(color: _stroke),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Icon(Icons.keyboard_arrow_up),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        children: [
          const Text(
            "— Fin de la liste —",
            style: TextStyle(
              color: _textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    CupertinoPageRoute(
                        builder: (_) => const CreateAnnoncePage()),
                  );
                  if (!mounted) return;
                  await _reloadAll();
                },
                icon: const Icon(Icons.add),
                label: const Text("Déposer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _scrollToTop,
                icon: const Icon(Icons.keyboard_arrow_up),
                label: const Text("Haut"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textPrimary,
                  side: const BorderSide(color: _stroke),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imagePremiumPlaceholder() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 0.60),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (_, v, __) {
        return Container(
          color:
              Color.lerp(const Color(0xFFE5E7EB), const Color(0xFFF3F4F6), v),
        );
      },
    );
  }

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

    final String annonceId = (data['id'] ?? '').toString();
    final bool isFav = annonceId.isNotEmpty && _favIds.contains(annonceId);

    final String heroUrl = images.isNotEmpty
        ? images.first
        : 'https://via.placeholder.com/600x400?text=Photo+indisponible';

    return Card(
      key: ValueKey('annonce_card_$annonceId'),
      color: _cardBg,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _stroke),
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () async {
          final enriched = Map<String, dynamic>.from(data);
          enriched['seller_name'] = sellerName;
          final annonce = AnnonceModel.fromJson(enriched);

          if (images.isNotEmpty) {
            unawaited(precacheImage(
                CachedNetworkImageProvider(images.first), context));
          }

          await Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => AnnonceDetailPage(annonce: annonce),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    key: ValueKey('annonce_img_$heroUrl'),
                    imageUrl: heroUrl,
                    cacheKey: heroUrl,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholderFadeInDuration: Duration.zero,
                    useOldImageOnUrlChange: true,
                    imageBuilder: (context, provider) => Image(
                      image: provider,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.low,
                    ),
                    placeholder: (_, __) => _imagePremiumPlaceholder(),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFFE5E7EB),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  if (annonceId.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: ClipOval(
                        child: Material(
                          color: Colors.white.withOpacity(0.92),
                          child: InkWell(
                            onTap: () => _toggleFavori(annonceId),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                isFav ? Icons.favorite : Icons.favorite_border,
                                size: 20,
                                color: isFav ? _brandRed : Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
                                    cacheKey: sellerAvatar,
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.cover,
                                    fadeInDuration: Duration.zero,
                                    fadeOutDuration: Duration.zero,
                                    placeholderFadeInDuration: Duration.zero,
                                    useOldImageOnUrlChange: true,
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
            aspectRatio: 4 / 3,
            child: _imagePremiumPlaceholder(),
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
                      color: Colors.grey.shade300),
                  const SizedBox(height: 6),
                  Container(height: 10, width: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 6),
                  Container(height: 8, width: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 4),
                  Container(height: 8, width: 100, color: Colors.grey.shade300),
                  const Spacer(),
                  Row(
                    children: [
                      CircleAvatar(
                          radius: 12, backgroundColor: Colors.grey.shade300),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Container(
                              height: 8, color: Colors.grey.shade300)),
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

  int _columnsForWidth(double w) {
    if (w >= 1600) return 6;
    if (w >= 1400) return 5;
    if (w >= 1100) return 4;
    if (w >= 800) return 3;
    return 2;
  }

  double _ratioFor(
      double screenWidth, int cols, double spacing, double paddingH) {
    final usableWidth = screenWidth - paddingH * 2 - spacing * (cols - 1);
    final itemWidth = usableWidth / cols;

    final imageH = itemWidth * (3 / 4);

    double infoH;
    if (itemWidth < 220) {
      infoH = 134;
    } else if (itemWidth < 280) {
      infoH = 126;
    } else if (itemWidth < 340) {
      infoH = 120;
    } else {
      infoH = 116;
    }

    final totalH = imageH + infoH;
    return itemWidth / totalH;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final screenW = MediaQuery.of(context).size.width;
    final gridCols = _columnsForWidth(screenW);

    const double gridSpacing = 4.0;
    const double gridHPadding = 6.0;

    final filtered = _filtered();
    final shown = filtered.take(_visibleCount).toList(growable: false);

    final ratio = _ratioFor(screenW, gridCols, gridSpacing, gridHPadding);

    final bool showSkeleton = !_initialFetchDone &&
        _loading &&
        _allAnnonces.isEmpty &&
        _cacheAnnonces.isEmpty;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _cardBg,
        elevation: 0.5,
        toolbarHeight: 58,
        leadingWidth: 56,
        leading: Navigator.of(context).canPop()
            ? Padding(
                padding: const EdgeInsets.only(left: 10),
                child: _RoundIconButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              )
            : null,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _appBarSearchField(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _RoundIconButton(
              icon: Icons.favorite_border,
              onTap: () => Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const FavorisPage()),
              ),
            ),
          ),
        ],
      ),

      // ✅ Avant : affichage "Erreur : $e" (brut) => maintenant message FR + bouton
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _reloadAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      child: const Text(
                        "Réessayer",
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: LayoutBuilder(
                    builder: (_, c) {
                      final isMobile = c.maxWidth < 600;
                      final chips = _allCats.map((cat) {
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
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _reloadAll,
                    child: CustomScrollView(
                      key: const PageStorageKey('annonces_scroll'),
                      controller: _scrollCtrl,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      cacheExtent: 1400,
                      slivers: [
                        SliverToBoxAdapter(child: _sellBanner()),
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                EdgeInsets.only(left: 16, bottom: 4, top: 4),
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
                              horizontal: gridHPadding,
                              vertical: 4,
                            ),
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
                                childCount: 6,
                              ),
                            ),
                          )
                        else if (!_loading && filtered.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 24),
                              child: Column(
                                children: [
                                  const Text(
                                    'Aucune annonce trouvée.',
                                    style: TextStyle(
                                      color: _textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _bottomFooter(
                                    shownCount: 0,
                                    totalCount: 0,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else ...[
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: gridHPadding,
                              vertical: 4,
                            ),
                            sliver: SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: gridCols,
                                crossAxisSpacing: gridSpacing,
                                mainAxisSpacing: gridSpacing,
                                childAspectRatio: ratio,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _annonceCard(shown[index]),
                                childCount: shown.length,
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(10, 10, 10, 24),
                              child: _bottomFooter(
                                shownCount: shown.length,
                                totalCount: filtered.length,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
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
              heroTag: 'annoncesToTop',
              backgroundColor: _brandRed,
              foregroundColor: Colors.white,
              onPressed: _scrollToTop,
              child: const Icon(Icons.keyboard_arrow_up_rounded, size: 30),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  static const Color _stroke = Color(0xFFE5E7EB);
  static const Color _textSecondary = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _stroke),
          ),
          child: Icon(icon, color: _textSecondary, size: 22),
        ),
      ),
    );
  }
}
