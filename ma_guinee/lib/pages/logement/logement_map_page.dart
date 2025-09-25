// lib/pages/logement/logement_map_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/logement_service.dart';
import '../../models/logement_models.dart';
import '../../routes.dart'; // ✅ pour ouvrir le détail

enum _MapStyle { voyager, satellite }

class LogementMapPage extends StatefulWidget {
  const LogementMapPage({super.key, this.ville, this.commune});

  final String? ville;
  final String? commune;

  @override
  State<LogementMapPage> createState() => _LogementMapPageState();
}

class _LogementMapPageState extends State<LogementMapPage> {
  final _svc = LogementService();
  final MapController _mapController = MapController();

  List<LogementModel> _items = [];
  bool _loading = true;
  String? _error;

  LatLng? _maPosition; // Position utilisateur (si dispo)
  _MapStyle _style = _MapStyle.voyager;

  // ---------- FOCUS transmis depuis la page détail ----------
  String? _focusId;
  double? _focusLat;
  double? _focusLng;
  String? _focusTitre;
  String? _focusVille;
  String? _focusCommune;
  bool _argsLu = false;

  // ---------- Thème ----------
  Color get _primary => const Color(0xFF0B3A6A);
  Color get _accent  => const Color(0xFFE1005A);
  bool  get _isDark  => Theme.of(context).brightness == Brightness.dark;
  Color get _bg      => _isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get _chipBg  => _isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _init();
  }

  // ✅ On lit les arguments (id/lat/lng/…) une seule fois ici
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLu) return;
    _argsLu = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _focusId      = args['id']?.toString();
      _focusLat     = _toDouble(args['lat']);
      _focusLng     = _toDouble(args['lng']);
      _focusTitre   = args['titre']?.toString();
      _focusVille   = args['ville']?.toString();
      _focusCommune = args['commune']?.toString();
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
    }

  Future<void> _init() async {
    setState(() { _loading = true; _error = null; });
    await _getMaPosition();
    await _load();
    await _postLoadFocus(); // ✅ centre/ouvre l’offre si fournie, sinon fit markers
  }

  Future<void> _load() async {
    try {
      final list = await _svc.nearMe(
        ville: widget.ville,
        commune: widget.commune,
        limit: 400,
      );
      if (!mounted) return;
      setState(() { _items = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _postLoadFocus() async {
    // Si on a un bien ciblé, on se centre dessus et on ouvre sa fiche
    if (_focusLat != null && _focusLng != null) {
      _mapController.move(LatLng(_focusLat!, _focusLng!), 15.5);

      // Cherche le logement dans la liste chargée
      final target = _items.firstWhere(
        (e) => e.id == _focusId,
        orElse: () => LogementModel(
          id: _focusId ?? '',
          userId: '',
          titre: _focusTitre ?? 'Annonce',
          description: '',
          prixGnf: null,
          mode: LogementMode.location,
          categorie: LogementCategorie.appartement,
          lat: _focusLat,
          lng: _focusLng,
          ville: _focusVille,
          commune: _focusCommune,
          photos: const [],
          adresse: null,
          chambres: null,
          superficieM2: null,
          creeLe: DateTime.now(),
        ),
      );

      // Laisse le temps au layout puis ouvre la fiche
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) _showPreview(target);
    } else {
      _fitToMarkers();
    }
  }

  Future<void> _getMaPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      _maPosition = LatLng(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  // ---- Helpers ----
  LatLng? _coordsOf(LogementModel b) {
    final double? lat = b.lat, lng = b.lng;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  void _fitToMarkers() {
    try {
      final pts = _items.map(_coordsOf).whereType<LatLng>().toList();
      if (pts.isEmpty) {
        _mapController.move(const LatLng(9.5412, -13.6773), 12); // Conakry
        return;
      }
      final bounds = LatLngBounds.fromPoints(pts);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
      );
    } catch (_) {}
  }

  String _fmtGNF(num? v, {bool parMois = false}) {
    if (v == null) return 'Prix à discuter';
    final s = _thousands(v.toInt());
    return parMois ? '$s GNF / mois' : '$s GNF';
  }

  String _fmtShortGNF(num? v, {bool parMois = false}) {
    if (v == null) return '—';
    double n = v.toDouble(); String suf = '';
    if (n >= 1e9) { n/=1e9; suf='B'; }
    else if (n >= 1e6) { n/=1e6; suf='M'; }
    else if (n >= 1e3) { n/=1e3; suf='k'; }
    final s = (n % 1 == 0) ? n.toStringAsFixed(0) : n.toStringAsFixed(1);
    return parMois ? '$s$suf/mois' : '$s$suf';
  }

  String _thousands(int n) {
    final s = n.toString(); final b = StringBuffer(); int c = 0;
    for (int i = s.length - 1; i >= 0; i--) { b.write(s[i]); if (++c==3 && i!=0){ b.write('.'); c=0; } }
    return b.toString().split('').reversed.join();
  }

  bool get _focusDansListe => _focusId != null && _items.any((e) => e.id == _focusId);

  @override
  Widget build(BuildContext context) {
    final subtitle = [widget.ville, widget.commune].whereType<String>().join(' • ');

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        title: const Text("Carte des logements", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(onPressed: _init, tooltip: "Rafraîchir", icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(subtitle.isEmpty ? "Guinée" : subtitle, style: const TextStyle(color: Colors.white70)),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorBox(_error!)
              : Stack(
                  children: [
                    // ---------- CARTE ----------
                    FlutterMap(
                      mapController: _mapController,
                      options: const MapOptions(
                        initialCenter: LatLng(9.5412, -13.6773),
                        initialZoom: 12,
                      ),
                      children: [
                        if (_style == _MapStyle.voyager)
                          TileLayer(
                            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                            userAgentPackageName: 'com.example.ma_guinee',
                            subdomains: const ['a', 'b', 'c'],
                          )
                        else
                          TileLayer(
                            urlTemplate: "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
                            userAgentPackageName: 'com.example.ma_guinee',
                          ),

                        // ----- CLUSTER + MARQUEURS -----
                        MarkerClusterLayerWidget(
                          options: MarkerClusterLayerOptions(
                            markers: _buildLogementMarkers(),
                            maxClusterRadius: 45,
                            disableClusteringAtZoom: 17,
                            size: const Size(44, 44),
                            padding: const EdgeInsets.all(50),
                            zoomToBoundsOnClick: true,
                            builder: (context, markers) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: _primary, shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.20), blurRadius: 8, offset: const Offset(0, 4))],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  markers.length.toString(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              );
                            },
                          ),
                        ),

                        // Marqueur utilisateur
                        if (_maPosition != null)
                          MarkerLayer(markers: [
                            Marker(
                              point: _maPosition!,
                              width: 80, height: 95,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(border: Border.all(color: Colors.blueAccent, width: 3), shape: BoxShape.circle),
                                    child: const CircleAvatar(radius: 20, backgroundColor: Colors.white,
                                      child: Icon(Icons.person_pin_circle, color: Colors.blueAccent, size: 28)),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(8)),
                                    child: const Text('Moi', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            ),
                          ]),

                        // ✅ Marqueur de secours si le bien ciblé n'est pas dans la liste (_items)
                        if (_focusLat != null && _focusLng != null && !_focusDansListe)
                          MarkerLayer(markers: [
                            Marker(
                              point: LatLng(_focusLat!, _focusLng!),
                              width: 60, height: 60, alignment: Alignment.topCenter,
                              child: const Icon(Icons.location_on, size: 40, color: Color(0xFFE1005A)),
                            ),
                          ]),
                      ],
                    ),

                    // ---------- SWITCH STYLE ----------
                    Positioned(
                      top: 12, right: 12,
                      child: SafeArea(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _isDark ? const Color(0xFF121826).withOpacity(0.85) : Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _isDark ? const Color(0xFF2A3242) : const Color(0xFFE6E6E6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _styleButton(label: 'Voyager',  active: _style == _MapStyle.voyager,  onTap: () => setState(() => _style = _MapStyle.voyager)),
                              _styleButton(label: 'Satellite', active: _style == _MapStyle.satellite, onTap: () => setState(() => _style = _MapStyle.satellite)),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ---------- FAB Ma position ----------
                    Positioned(
                      bottom: 24, right: 18,
                      child: FloatingActionButton(
                        onPressed: () { if (_maPosition != null) _mapController.move(_maPosition!, 15); },
                        backgroundColor: Colors.blueAccent, elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.my_location), tooltip: "Ma position",
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _styleButton({required String label, required bool active, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10), onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: active ? _primary : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(color: active ? Colors.white : (_isDark ? const Color(0xFFBFC6D1) : const Color(0xFF222222)),
            fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.2)),
      ),
    );
  }

  // ----- Marqueurs "photo" avec badge prix -----
  List<Marker> _buildLogementMarkers() {
    final markers = <Marker>[];
    for (final b in _items) {
      final p = _coordsOf(b);
      if (p == null) continue;

      final photo = (b.photos.isNotEmpty) ? b.photos.first : null;
      final priceShort = _fmtShortGNF(b.prixGnf, parMois: b.mode == LogementMode.location);

      markers.add(
        Marker(
          point: p, width: 70, height: 92, alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _showPreview(b),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.20), blurRadius: 8, offset: const Offset(0, 4))]),
                  clipBehavior: Clip.antiAlias,
                  child: photo == null
                      ? Container(color: const Color(0xFFEFEFEF), child: const Icon(Icons.home_rounded, color: Colors.black38))
                      : Image.network(photo, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: const Color(0xFFEFEFEF),
                            child: const Icon(Icons.home_rounded, color: Colors.black38))),
                ),
                Positioned(
                  bottom: -6, left: 0, right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2)),
                      child: Text(priceShort, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black.withOpacity(0.12)),
                    borderRadius: BorderRadius.circular(2)),
                child: Transform.rotate(angle: 0.785398, child: Container(color: Colors.white)),
              ),
            ]),
          ),
        ),
      );
    }
    return markers;
  }

  // --------- Aperçu (bottom sheet) ---------
  void _showPreview(LogementModel b) {
    final price = (b.prixGnf != null)
        ? (b.mode == LogementMode.achat ? _fmtGNF(b.prixGnf) : _fmtGNF(b.prixGnf, parMois: true))
        : 'Prix à discuter';

    showModalBottomSheet(
      context: context, backgroundColor: _isDark ? const Color(0xFF0B1220) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 92, height: 92,
                  child: (b.photos.isEmpty)
                      ? Container(color: _chipBg, child: const Icon(Icons.image, color: Colors.black26, size: 32))
                      : Image.network(b.photos.first, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.titre, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: -6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  _miniChip(b.mode == LogementMode.achat ? 'Achat' : 'Location'),
                  _miniChip(_labelCat(b.categorie)),
                  if (b.chambres != null) _miniChip('${b.chambres} ch'),
                  if (b.superficieM2 != null) _miniChip('${b.superficieM2!.toStringAsFixed(0)} m²'),
                ]),
                const SizedBox(height: 6),
                Text([b.ville, b.commune].whereType<String>().join(' • '),
                    style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ])),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Text(price, style: TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                onPressed: () { Navigator.pop(context); Navigator.pushNamed(context, AppRoutes.logementDetail, arguments: b.id); },
                icon: const Icon(Icons.chevron_right),
                label: const Text('Voir la fiche'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _miniChip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: _chipBg, borderRadius: BorderRadius.circular(8)),
        child: Text(t, style: const TextStyle(fontSize: 12)),
      );

  String _labelCat(LogementCategorie c) {
    switch (c) {
      case LogementCategorie.maison: return 'Maison';
      case LogementCategorie.appartement: return 'Appartement';
      case LogementCategorie.studio: return 'Studio';
      case LogementCategorie.terrain: return 'Terrain';
      case LogementCategorie.autres: return 'Autres';
    }
  }

  Widget _errorBox(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 10),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
              onPressed: _init, icon: const Icon(Icons.refresh), label: const Text("Réessayer"),
            ),
          ]),
        ),
      );
}
