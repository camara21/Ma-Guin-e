import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../services/logement_service.dart';
import '../../models/logement_models.dart';
import '../../routes.dart';

enum _MapStyle { voyager, satellite }

const String _logementMapCacheBox = 'logements_map_box_v1';

// Centre par défaut sur Conakry (comme avant)
const LatLng _conakryCenter = LatLng(9.5412, -13.6773);
const double _conakryZoom = 12.0;

class LogementMapPage extends StatefulWidget {
  const LogementMapPage({
    super.key,
    this.ville,
    this.commune,
    // focus précis (passé par la route)
    this.focusId,
    this.focusLat,
    this.focusLng,
    this.focusTitre,
    this.focusVille,
    this.focusCommune,
  });

  final String? ville;
  final String? commune;

  // --- focus d’un logement précis ---
  final String? focusId;
  final double? focusLat;
  final double? focusLng;
  final String? focusTitre;
  final String? focusVille;
  final String? focusCommune;

  @override
  State<LogementMapPage> createState() => _LogementMapPageState();
}

class _LogementMapPageState extends State<LogementMapPage> {
  final _svc = LogementService();
  final MapController _map = MapController();

  List<LogementModel> _items = [];
  bool _loading = false; // seulement pour le bouton refresh
  String? _error;

  LatLng? _me;
  _MapStyle _style = _MapStyle.voyager;

  // Thème
  Color get _primary => const Color(0xFF0B3A6A);
  Color get _accent => const Color(0xFFE1005A);
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get _chipBg =>
      _isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);

  String get _cacheKey =>
      'map|${widget.ville ?? ''}|${widget.commune ?? ''}|v1';

  @override
  void initState() {
    super.initState();

    // 1) lecture synchronisée du cache (aucun setState → déjà prêt avant 1er build)
    _loadCacheSync();

    // 2) centrer la carte dès la première frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_hasFocus) {
        _fitAll();
      }
    });

    // 3) tâches réseau en arrière-plan (position + refresh Supabase)
    _init();
  }

  // =========================================================
  //          CACHE HIVE SYNCHRONE (avant 1er build)
  // =========================================================
  void _loadCacheSync() {
    try {
      if (!Hive.isBoxOpen(_logementMapCacheBox)) return;
      final box = Hive.box(_logementMapCacheBox);
      final raw = box.get(_cacheKey);
      if (raw is List) {
        final list = <LogementModel>[];
        for (final e in raw) {
          if (e is Map) {
            final m = Map<String, dynamic>.from(e as Map);
            list.add(_fromCacheMap(m));
          }
        }
        _items = list;
      }
    } catch (_) {
      // on ignore les erreurs de cache
    }
  }

  Future<void> _saveToCache(List<LogementModel> list) async {
    try {
      final box = await Hive.openBox(_logementMapCacheBox);
      final data = list.map(_toCacheMap).toList();
      await box.put(_cacheKey, data);
    } catch (_) {
      // silencieux
    }
  }

  Map<String, dynamic> _toCacheMap(LogementModel b) => {
        'id': b.id,
        'userId': b.userId,
        'titre': b.titre,
        'description': b.description,
        'prixGnf': b.prixGnf,
        'mode': b.mode.index,
        'categorie': b.categorie.index,
        'lat': b.lat,
        'lng': b.lng,
        'ville': b.ville,
        'commune': b.commune,
        'photos': b.photos,
        'adresse': b.adresse,
        'chambres': b.chambres,
        'superficieM2': b.superficieM2,
        'creeLe': b.creeLe.toIso8601String(),
      };

  LogementModel _fromCacheMap(Map<String, dynamic> m) {
    LogementMode _modeFrom(dynamic v) {
      if (v is int && v >= 0 && v < LogementMode.values.length) {
        return LogementMode.values[v];
      }
      return LogementMode.location;
    }

    LogementCategorie _catFrom(dynamic v) {
      if (v is int && v >= 0 && v < LogementCategorie.values.length) {
        return LogementCategorie.values[v];
      }
      return LogementCategorie.appartement;
    }

    return LogementModel(
      id: (m['id'] ?? '') as String,
      userId: (m['userId'] ?? '') as String,
      titre: (m['titre'] ?? '') as String,
      description: (m['description'] ?? '') as String,
      prixGnf: (m['prixGnf'] as num?)?.toInt(),
      mode: _modeFrom(m['mode']),
      categorie: _catFrom(m['categorie']),
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      ville: m['ville'] as String?,
      commune: m['commune'] as String?,
      photos: (m['photos'] as List?)?.cast<String>() ?? const [],
      adresse: m['adresse'] as String?,
      chambres: m['chambres'] as int?,
      superficieM2: (m['superficieM2'] as num?)?.toDouble(),
      creeLe: DateTime.tryParse(m['creeLe'] as String? ?? '') ?? DateTime.now(),
    );
  }

  // =========================================================
  //          INITIALISATION RÉSEAU (en arrière-plan)
  // =========================================================
  Future<void> _init() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    await _getMe(); // position utilisateur
    await _loadFromNetwork(); // refresh Supabase
    await _focusIfNeeded(); // si focus explicite

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  Future<void> _loadFromNetwork() async {
    try {
      final list = await _svc.nearMe(
        ville: widget.ville,
        commune: widget.commune,
        limit: 400,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
      });
      _saveToCache(list);
    } catch (e) {
      if (!mounted) return;
      // on garde la carte avec les données du cache
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _getMe() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (!mounted) return;
      setState(() {
        _me = LatLng(pos.latitude, pos.longitude);
      });
    } catch (_) {}
  }

  // ---------- Focus ----------
  bool get _hasFocus => (widget.focusLat != null && widget.focusLng != null);

  Future<void> _focusIfNeeded() async {
    if (!_hasFocus) {
      // pas de focus explicite → on reste centrés sur Conakry
      _fitAll();
      return;
    }

    final center = LatLng(widget.focusLat!, widget.focusLng!);

    // attendre 1 frame pour que la Map s’attache bien
    await Future.delayed(const Duration(milliseconds: 50));
    _map.move(center, 17.5); // désactive le cluster pour ce bien

    // trouver l’élément ou fallback
    final b = _items.firstWhere(
      (e) => e.id == widget.focusId,
      orElse: () => LogementModel(
        id: widget.focusId ?? '',
        userId: '',
        titre: widget.focusTitre ?? 'Annonce',
        description: '',
        prixGnf: null,
        mode: LogementMode.location,
        categorie: LogementCategorie.appartement,
        lat: widget.focusLat,
        lng: widget.focusLng,
        ville: widget.focusVille,
        commune: widget.focusCommune,
        photos: const [],
        adresse: null,
        chambres: null,
        superficieM2: null,
        creeLe: DateTime.now(),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) _showPreview(b);
  }

  /// Centre toujours sur Conakry (comme avant), même si des annonces
  /// existent dans d'autres pays.
  void _fitAll() {
    try {
      _map.move(_conakryCenter, _conakryZoom);
    } catch (_) {}
  }

  String _fmtGNF(num? v, {bool perMonth = false}) {
    if (v == null) return 'Prix à discuter';
    final s = _thousands(v.toInt());
    return perMonth ? '$s GNF / mois' : '$s GNF';
  }

  String _fmtShort(num? v, {bool perMonth = false}) {
    if (v == null) return '—';
    double n = v.toDouble();
    String suf = '';
    if (n >= 1e9) {
      n /= 1e9;
      suf = 'B';
    } else if (n >= 1e6) {
      n /= 1e6;
      suf = 'M';
    } else if (n >= 1e3) {
      n /= 1e3;
      suf = 'k';
    }
    final s = (n % 1 == 0) ? n.toStringAsFixed(0) : n.toStringAsFixed(1);
    return perMonth ? '$s$suf/mois' : '$s$suf';
  }

  String _thousands(int n) {
    final s = n.toString();
    final b = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      b.write(s[i]);
      if (++c == 3 && i != 0) {
        b.write('.');
        c = 0;
      }
    }
    return b.toString().split('').reversed.join();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle =
        [widget.ville, widget.commune].whereType<String>().join(' • ');

    final bool showErrorBox = _error != null && _items.isEmpty;

    final body = showErrorBox
        ? _errorBox(_error!)
        : Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  // Carte visible immédiatement, centrée sur Conakry
                  initialCenter: _conakryCenter,
                  initialZoom: _conakryZoom,
                ),
                children: [
                  if (_style == _MapStyle.voyager)
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.ma_guinee',
                      subdomains: const ['a', 'b', 'c'],
                    )
                  else
                    TileLayer(
                      urlTemplate:
                          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                      userAgentPackageName: 'com.example.ma_guinee',
                    ),

                  // Cluster + marqueurs
                  MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      markers: _buildMarkers(),
                      maxClusterRadius: 45,
                      disableClusteringAtZoom: 17,
                      size: const Size(44, 44),
                      padding: const EdgeInsets.all(50),
                      zoomToBoundsOnClick: true,
                      builder: (context, markers) => Container(
                        decoration: BoxDecoration(
                          color: _primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.20),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${markers.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (_me != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: _me!,
                        width: 80,
                        height: 95,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.blueAccent, width: 3),
                                shape: BoxShape.circle,
                              ),
                              child: const CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.person_pin_circle,
                                  color: Colors.blueAccent,
                                  size: 28,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Moi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),

                  // Marqueur de secours si le bien ciblé n'est pas dans la liste
                  if (_hasFocus && !_items.any((e) => e.id == widget.focusId))
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(widget.focusLat!, widget.focusLng!),
                        width: 60,
                        height: 60,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_on,
                          size: 40,
                          color: Color(0xFFE1005A),
                        ),
                      ),
                    ]),
                ],
              ),

              // switch style
              Positioned(
                top: 12,
                right: 12,
                child: SafeArea(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _isDark
                          ? const Color(0xFF121826).withOpacity(0.85)
                          : Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isDark
                            ? const Color(0xFF2A3242)
                            : const Color(0xFFE6E6E6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _styleButton(
                          'Voyager',
                          _style == _MapStyle.voyager,
                          () => setState(() => _style = _MapStyle.voyager),
                        ),
                        _styleButton(
                          'Satellite',
                          _style == _MapStyle.satellite,
                          () => setState(() => _style = _MapStyle.satellite),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // FAB
              Positioned(
                bottom: 24,
                right: 18,
                child: FloatingActionButton(
                  onPressed: () {
                    if (_me != null) _map.move(_me!, 15);
                  },
                  backgroundColor: Colors.blueAccent,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.my_location),
                  tooltip: 'Ma position',
                ),
              ),
            ],
          );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        title: const Text(
          'Carte des logements',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _loading ? null : _init,
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              subtitle.isEmpty ? 'Guinée' : subtitle,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
      body: body,
    );
  }

  Widget _styleButton(String label, bool active, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? Colors.white
                : (_isDark ? const Color(0xFFBFC6D1) : const Color(0xFF222222)),
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  // === Image adaptative (évite le "pixel" partout) ===
  Widget _adaptiveNetImage(String url, double w, double h,
      {BorderRadius? radius}) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cw = (w * dpr).round();
    final ch = (h * dpr).round();
    final img = CachedNetworkImage(
      imageUrl: url,
      memCacheWidth: cw,
      memCacheHeight: ch,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => Container(color: Colors.grey.shade200),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      ),
    );
    return radius != null ? ClipRRect(borderRadius: radius, child: img) : img;
  }

  List<Marker> _buildMarkers() {
    final out = <Marker>[];
    for (final b in _items) {
      if (b.lat == null || b.lng == null) continue;
      final p = LatLng(b.lat!, b.lng!);
      final photo = (b.photos.isNotEmpty) ? b.photos.first : null;
      final priceShort =
          _fmtShort(b.prixGnf, perMonth: b.mode == LogementMode.location);

      out.add(
        Marker(
          point: p,
          width: 70,
          height: 92,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _showPreview(b),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.20),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: photo == null
                      ? Container(
                          color: const Color(0xFFEFEFEF),
                          child: const Icon(
                            Icons.home_rounded,
                            color: Colors.black38,
                          ),
                        )
                      : _adaptiveNetImage(photo, 60, 60),
                ),
                Positioned(
                  bottom: -6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        priceShort,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black.withOpacity(0.12)),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Transform.rotate(
                  angle: 0.785398, // 45°
                  child: Container(color: Colors.white),
                ),
              ),
            ]),
          ),
        ),
      );
    }
    return out;
  }

  void _showPreview(LogementModel b) {
    final price = (b.prixGnf != null)
        ? (b.mode == LogementMode.achat
            ? _fmtGNF(b.prixGnf)
            : _fmtGNF(b.prixGnf, perMonth: true))
        : 'Prix à discuter';

    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? const Color(0xFF0B1220) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: LayoutBuilder(
            builder: (ctx, cons) {
              final double maxW = cons.maxWidth;
              final bool compact = maxW < 380;
              final double thumb = compact ? 72.0 : 92.0;
              final photo = (b.photos.isNotEmpty) ? b.photos.first : null;

              Widget actions;
              if (maxW < 400) {
                // Layout compact : actions en colonne
                actions = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          AppRoutes.logementDetail,
                          arguments: b.id,
                        );
                      },
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Voir la fiche'),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Fermer'),
                      ),
                    ),
                  ],
                );
              } else {
                // Layout large : actions en ligne
                actions = Row(
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fermer'),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          AppRoutes.logementDetail,
                          arguments: b.id,
                        );
                      },
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Voir la fiche'),
                    ),
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: thumb,
                        height: thumb,
                        child: (photo == null)
                            ? Container(
                                color: _chipBg,
                                child: const Icon(
                                  Icons.image,
                                  color: Colors.black26,
                                  size: 32,
                                ),
                              )
                            : _adaptiveNetImage(photo, thumb, thumb),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.titre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: -6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _miniChip(
                                b.mode == LogementMode.achat
                                    ? 'Achat'
                                    : 'Location',
                              ),
                              _miniChip(_labelCat(b.categorie)),
                              if (b.chambres != null)
                                _miniChip('${b.chambres} ch'),
                              if (b.superficieM2 != null)
                                _miniChip(
                                  '${b.superficieM2!.toStringAsFixed(0)} m²',
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            [b.ville, b.commune]
                                .whereType<String>()
                                .join(' • '),
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _miniChip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(t, style: const TextStyle(fontSize: 12)),
      );

  String _labelCat(LogementCategorie c) {
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

  Widget _errorBox(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.red),
              const SizedBox(height: 10),
              Text(msg, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                ),
                onPressed: _init,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
}
