// lib/pages/logement/logement_edit_page.dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/logement_service.dart';
import '../../models/logement_models.dart';

// ✅ Compression (même module que Annonces)
import 'package:ma_guinee/utils/image_compressor/image_compressor.dart';

class LogementEditPage extends StatefulWidget {
  const LogementEditPage({super.key, this.existing});
  final LogementModel? existing;

  @override
  State<LogementEditPage> createState() => _LogementEditPageState();
}

class _LogementEditPageState extends State<LogementEditPage> {
  final _form = GlobalKey<FormState>();
  final _svc = LogementService();

  // Palette
  Color get _primary => const Color(0xFF0B3A6A);
  Color get _accent => const Color(0xFFE1005A);
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get _fieldFill =>
      _isDark ? const Color(0xFF1F2937) : const Color(0xFFF6F7FB);
  Color get _chipBg =>
      _isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);

  // Champs
  late TextEditingController _titre;
  late TextEditingController _desc;
  late TextEditingController _prix;
  late TextEditingController _ville;
  late TextEditingController _commune;
  late TextEditingController _adresse;
  late TextEditingController _surface;
  late TextEditingController _phone;

  // Choix utilisateur
  int? _chambres;
  LogementMode? _mode;
  LogementCategorie? _cat;

  // Localisation
  double? _lat;
  double? _lng;
  final _mapCtrl = MapController();

  // Plan / Satellite
  bool _satellite = false;

  // Sécurité zoom
  static const double _kMinZoom = 2.0;
  static const double _kMaxZoom = 19.0;

  // Tuiles
  static const String _tileUrlNormal =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
  static const List<String> _tileSubdomainsNormal = ['a', 'b', 'c', 'd'];

  static const String _tileUrlSatellite =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  // Photos
  static const _kMaxPhotos = 10;
  final List<_PhotoItem> _photos = [];

  // ✅ Pour supprimer dans Storage ce qui est remplacé/supprimé au moment du save
  final Set<String> _originalPhotoUrls = <String>{};
  final Set<String> _pendingDeleteUrls = <String>{};

  bool _saving = false;
  bool _loadedFromRouteArg = false;

  @override
  void initState() {
    super.initState();
    _titre = TextEditingController();
    _desc = TextEditingController();
    _prix = TextEditingController();
    _ville = TextEditingController();
    _commune = TextEditingController();
    _adresse = TextEditingController();
    _surface = TextEditingController();
    _phone = TextEditingController();

    if (widget.existing != null) {
      _prefillFrom(widget.existing!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedFromRouteArg || widget.existing != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    _loadedFromRouteArg = true;

    if (args is LogementModel) {
      _prefillFrom(args);
    } else if (args is String && args.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final m = await _svc.getById(args);
          if (m != null && mounted) {
            _prefillFrom(m);
            final tel = await _svc.getContactPhone(m.id);
            if (mounted && (tel ?? '').isNotEmpty) _phone.text = tel!;
          }
        } catch (e) {
          if (mounted) _snack('Erreur chargement : $e');
        }
      });
    }
  }

  void _prefillFrom(LogementModel e) {
    _titre.text = e.titre;
    _desc.text = e.description ?? '';
    _prix.text = _formatThousandsFromNum(e.prixGnf);

    _ville.text = e.ville ?? '';
    _commune.text = e.commune ?? '';
    _adresse.text = e.adresse ?? '';
    _surface.text = e.superficieM2?.toString() ?? '';
    _phone.text = e.contactTelephone ?? '';

    _chambres = e.chambres;
    _mode = e.mode;
    _cat = e.categorie;

    _lat = e.lat;
    _lng = e.lng;

    _photos.clear();
    _originalPhotoUrls.clear();
    _pendingDeleteUrls.clear();

    for (final u in e.photos) {
      final s = u.trim();
      if (s.isNotEmpty) {
        _photos.add(_PhotoItem(url: s));
        _originalPhotoUrls.add(s);
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _titre.dispose();
    _desc.dispose();
    _prix.dispose();
    _ville.dispose();
    _commune.dispose();
    _adresse.dispose();
    _surface.dispose();
    _phone.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: _fieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    final routeArg = ModalRoute.of(context)?.settings.arguments;
    final isEdit = widget.existing != null ||
        (routeArg is String && routeArg.trim().isNotEmpty);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: Text(isEdit ? "Modifier le bien" : "Publier un bien"),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Stack(
          children: [
            Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  TextFormField(
                    controller: _titre,
                    decoration: _dec("Titre *"),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? "Obligatoire" : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _desc,
                    minLines: 3,
                    maxLines: 6,
                    decoration: _dec("Description"),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<LogementMode>(
                          value: _mode,
                          items: const [
                            DropdownMenuItem(
                                value: LogementMode.location,
                                child: Text("Location")),
                            DropdownMenuItem(
                                value: LogementMode.achat,
                                child: Text("Achat")),
                          ],
                          onChanged: (v) => setState(() => _mode = v),
                          decoration:
                              _dec("Type d’opération *", hint: "Sélectionner…"),
                          validator: (v) =>
                              v == null ? "Choisir le type" : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<LogementCategorie>(
                          value: _cat,
                          items: const [
                            DropdownMenuItem(
                                value: LogementCategorie.maison,
                                child: Text("Maison")),
                            DropdownMenuItem(
                                value: LogementCategorie.appartement,
                                child: Text("Appartement")),
                            DropdownMenuItem(
                                value: LogementCategorie.studio,
                                child: Text("Studio")),
                            DropdownMenuItem(
                                value: LogementCategorie.terrain,
                                child: Text("Terrain")),
                            DropdownMenuItem(
                                value: LogementCategorie.autres,
                                child: Text("Autres")),
                          ],
                          onChanged: (v) => setState(() => _cat = v),
                          decoration:
                              _dec("Catégorie *", hint: "Sélectionner…"),
                          validator: (v) =>
                              v == null ? "Choisir la catégorie" : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _prix,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            ThousandsDotFormatter(),
                          ],
                          decoration: _dec("Prix / Loyer (GNF)"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _surface,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: _dec("Superficie (m²)"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: _chambres,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text("1")),
                      DropdownMenuItem(value: 2, child: Text("2")),
                      DropdownMenuItem(value: 3, child: Text("3")),
                      DropdownMenuItem(value: 4, child: Text("4")),
                      DropdownMenuItem(value: 5, child: Text("5+")),
                    ],
                    onChanged: (v) => setState(() => _chambres = v),
                    decoration: _dec("Chambres (optionnel)",
                        hint: "Laisser vide si peu importe"),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ville,
                          decoration: _dec("Ville"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _commune,
                          decoration: _dec("Commune / Quartier"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _adresse,
                    decoration: _dec("Adresse (optionnelle)"),
                  ),
                  const SizedBox(height: 12),
                  _localisationCard(),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: _dec("Téléphone de contact *",
                        hint: "+224 6x xx xx xx"),
                    validator: (v) {
                      final val = v?.trim() ?? '';
                      if (val.isEmpty) return "Numéro requis";
                      final ok = RegExp(r'^[0-9 +()\-]{6,20}$').hasMatch(val);
                      if (!ok) return "Numéro invalide";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _photosSection(),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? "Enregistrement..." : "Enregistrer"),
                  ),
                ],
              ),
            ),
            if (_saving) const PositionedFillLoading(),
          ],
        ),
      ),
    );
  }

  // ===================== Localisation =====================

  Widget _localisationCard() {
    final hasPos = _lat != null && _lng != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Localisation précise",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            "Pour une localisation exacte, placez-vous DANS le logement (ou à l’entrée) "
            "puis appuyez sur « Localiser ». Vous pouvez aussi déplacer le repère manuellement.",
            style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.2),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _pickLocation,
                icon: const Icon(Icons.my_location),
                label: const Text("Localiser"),
              ),
              const SizedBox(width: 10),
              if (hasPos)
                Expanded(
                  child: Text(
                    '(${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              const SizedBox(width: 10),
              ToggleButtons(
                isSelected: [_satellite == false, _satellite == true],
                onPressed: (i) => setState(() => _satellite = (i == 1)),
                borderRadius: BorderRadius.circular(10),
                constraints: const BoxConstraints(minHeight: 36, minWidth: 72),
                children: const [Text('Plan'), Text('Satellite')],
              ),
            ],
          ),
          if (hasPos) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: LatLng(_lat!, _lng!),
                    initialZoom: 16,
                    minZoom: _kMinZoom,
                    maxZoom: _kMaxZoom,
                    onTap: (tapPos, latLng) {
                      setState(() {
                        _lat = latLng.latitude;
                        _lng = latLng.longitude;
                      });
                    },
                    onLongPress: (tapPos, latLng) {
                      setState(() {
                        _lat = latLng.latitude;
                        _lng = latLng.longitude;
                      });
                      _mapCtrl.move(latLng, 17);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          _satellite ? _tileUrlSatellite : _tileUrlNormal,
                      subdomains: _satellite ? const [] : _tileSubdomainsNormal,
                      maxZoom: _kMaxZoom,
                      maxNativeZoom: _satellite ? 18 : 19,
                      userAgentPackageName: 'com.soneya.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(_lat!, _lng!),
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on,
                              size: 36, color: Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _openMapFullscreen,
                icon: const Icon(Icons.fullscreen),
                label: const Text("Ouvrir la carte en plein écran"),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Astuce : touchez la carte pour déplacer le repère. "
              "Maintenez appuyé pour recentrer et zoomer.",
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _snack("Active d’abord la localisation (GPS).");
        return;
      }

      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        _snack("Permission de localisation refusée.");
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });

      try {
        _mapCtrl.move(LatLng(_lat!, _lng!), 16);
      } catch (_) {}
    } catch (e) {
      _snack('Localisation impossible : $e');
    }
  }

  Future<void> _openMapFullscreen() async {
    if (_lat == null || _lng == null) return;

    final initial = LatLng(_lat!, _lng!);

    final _MapFullResult? res =
        await Navigator.of(context).push<_MapFullResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _LogementMapFullScreenPage(
          pointInitial: initial,
          satelliteInitial: _satellite,
        ),
      ),
    );

    if (res == null) return;

    setState(() {
      _lat = res.point.latitude;
      _lng = res.point.longitude;
      _satellite = res.satellite;
    });

    try {
      _mapCtrl.move(LatLng(_lat!, _lng!), 16);
    } catch (_) {}
  }

  // ===================== Photos =====================

  Widget _photosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("Photos", style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _accent),
                foregroundColor: _accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text("Ajouter une photo"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _photos.length + (_photos.length < _kMaxPhotos ? 1 : 0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (_, i) =>
              (i < _photos.length) ? _photoTile(i) : _addTile(),
        ),
      ],
    );
  }

  Widget _addTile() {
    return InkWell(
      onTap: _pickFromGallery,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Icon(Icons.add, size: 36, color: _accent),
      ),
    );
  }

  Widget _photoTile(int index) {
    final p = _photos[index];

    Widget img;
    if (p.bytes != null) {
      img = Image.memory(p.bytes!, fit: BoxFit.cover);
    } else if ((p.url ?? '').isNotEmpty) {
      img = Image.network(p.url!, fit: BoxFit.cover);
    } else {
      img = const ColoredBox(
        color: Color(0xFFE5E7EB),
        child: Center(child: Icon(Icons.image, color: Colors.black26)),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(color: Colors.grey.shade200, child: img),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            style: IconButton.styleFrom(backgroundColor: Colors.black45),
            icon: const Icon(Icons.close, size: 18, color: Colors.white),
            onPressed: () {
              // ✅ on marque pour suppression au save (on ne supprime pas immédiatement)
              final url = (p.url ?? '').trim();
              if (url.isNotEmpty) _pendingDeleteUrls.add(url);
              setState(() => _photos.removeAt(index));
            },
            tooltip: "Supprimer",
          ),
        ),
      ],
    );
  }

  Future<void> _pickFromGallery() async {
    if (_photos.length >= _kMaxPhotos) return;
    final left = _kMaxPhotos - _photos.length;

    final picker = ImagePicker();

    // ✅ pas de imageQuality ici : on compresse comme Annonces
    final files = await picker.pickMultiImage();
    if (files.isEmpty) return;

    for (final f in files.take(left)) {
      final bytes = await f.readAsBytes();
      _photos.add(_PhotoItem(bytes: bytes, name: f.name));
    }
    setState(() {});
  }

  // ===================== Storage delete helpers =====================

  _StorageRef? _parseStorageRefFromUrl(String url) {
    try {
      final u = Uri.parse(url);
      final seg = u.pathSegments;

      // formats:
      // /storage/v1/object/public/<bucket>/<path...>
      // /storage/v1/object/sign/<bucket>/<path...>
      final idx = seg.indexOf('object');
      if (idx < 0) return null;
      if (idx + 2 >= seg.length) return null;

      final mode = seg[idx + 1]; // public | sign | ...
      if (mode != 'public' && mode != 'sign') return null;

      final bucket = Uri.decodeComponent(seg[idx + 2]);
      if (bucket.isEmpty) return null;

      final rest = seg.sublist(idx + 3);
      if (rest.isEmpty) return null;

      final path = rest.map(Uri.decodeComponent).join('/');
      if (path.isEmpty) return null;

      return _StorageRef(bucket: bucket, path: path);
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteUrlsFromStorage(Set<String> urls) async {
    if (urls.isEmpty) return;

    final Map<String, List<String>> byBucket = {};
    for (final url in urls) {
      final ref = _parseStorageRefFromUrl(url);
      if (ref == null) continue;
      byBucket.putIfAbsent(ref.bucket, () => <String>[]).add(ref.path);
    }

    if (byBucket.isEmpty) return;

    final client = Supabase.instance.client;

    for (final entry in byBucket.entries) {
      final bucket = entry.key;
      final paths = entry.value.toSet().toList(); // unique
      try {
        await client.storage.from(bucket).remove(paths);
      } catch (e) {
        // On ne bloque pas la sauvegarde si la policy Storage refuse la suppression
        debugPrint('Erreur suppression storage ($bucket): $e');
      }
    }
  }

  String _buildFilename(String? originalName, String ext, int i) {
    final raw = (originalName ?? '').trim();
    final safe =
        raw.isEmpty ? 'photo_$i' : raw.replaceAll(RegExp(r'[^\w\-.]+'), '_');

    final noExt = safe.replaceAll(RegExp(r'\.[a-zA-Z0-9]{1,5}$'), '');
    final e = ext.trim().toLowerCase().replaceAll('.', '');
    return '$noExt.$e';
  }

  // ===================== Save =====================

  Future<void> _save() async {
    final form = _form.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    if (_mode == null || _cat == null) {
      _snack("Merci de choisir le type d’opération et la catégorie.");
      return;
    }

    setState(() => _saving = true);

    try {
      final model = LogementModel(
        id: widget.existing?.id ?? 'new',
        userId: widget.existing?.userId ?? '',
        titre: _titre.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        mode: _mode!,
        categorie: _cat!,
        prixGnf: _parseGnf(_prix.text),
        ville: _ville.text.trim().isEmpty ? null : _ville.text.trim(),
        commune: _commune.text.trim().isEmpty ? null : _commune.text.trim(),
        adresse: _adresse.text.trim().isEmpty ? null : _adresse.text.trim(),
        superficieM2: _surface.text.trim().isEmpty
            ? null
            : num.tryParse(_surface.text.trim()),
        chambres: _chambres,
        lat: _lat ?? widget.existing?.lat,
        lng: _lng ?? widget.existing?.lng,
        photos: const [],
        creeLe: widget.existing?.creeLe ?? DateTime.now(),
        contactTelephone:
            _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      );

      final routeArg = ModalRoute.of(context)?.settings.arguments;
      final bool isEditing = widget.existing != null ||
          (routeArg is String && routeArg.trim().isNotEmpty);

      String id;
      if (!isEditing) {
        id = await _svc.create(model);
      } else {
        id = widget.existing?.id ?? (routeArg is String ? routeArg : 'new');
        if (id == 'new' || id.trim().isEmpty) {
          id = await _svc.create(model);
        } else {
          await _svc.updateFromModel(id, model);
        }
      }

      final tel = _phone.text.trim();
      if (tel.isNotEmpty) await _svc.update(id, {'contact_telephone': tel});

      // ✅ Construit la liste finale d’URLs (compression + upload)
      final urls = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        final p = _photos[i];

        if ((p.url ?? '').trim().isNotEmpty) {
          urls.add(p.url!.trim());
          continue;
        }

        if (p.bytes == null) continue;

        // ✅ Compression identique à Annonces
        final c = await ImageCompressor.compressBytes(
          p.bytes!,
          maxSide: 1600,
          quality: 82,
          maxBytes: 900 * 1024,
          keepPngIfTransparent: true,
        );

        final filename = _buildFilename(p.name, c.extension, i);

        final res = await _svc.uploadPhoto(
          bytes: c.bytes,
          filename: filename,
          logementId: id,
        );

        urls.add(res.publicUrl);
      }

      await _svc.setPhotos(id, urls);

      // ✅ Suppression storage : anciennes URLs qui ne sont plus dans "urls"
      final keep = urls.toSet();
      final toDelete = <String>{};

      // 1) ce qui était dans l’existant mais plus gardé
      for (final u in _originalPhotoUrls) {
        if (!keep.contains(u)) toDelete.add(u);
      }

      // 2) ce que l’utilisateur a supprimé pendant l’édition (sécurité)
      for (final u in _pendingDeleteUrls) {
        if (!keep.contains(u)) toDelete.add(u);
      }

      await _deleteUrlsFromStorage(toDelete);

      // ✅ reset “baseline” après succès
      _originalPhotoUrls
        ..clear()
        ..addAll(keep);
      _pendingDeleteUrls.clear();

      if (!mounted) return;
      _snack(!isEditing ? "Annonce créée" : "Annonce mise à jour");
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack("Erreur : $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ===================== Helpers prix =====================

  num? _parseGnf(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final cleaned = s.replaceAll('.', '').replaceAll(' ', '');
    return num.tryParse(cleaned);
  }

  String _formatThousandsFromNum(num? n) {
    if (n == null) return '';
    final v = n.round();
    final s = v.toString();
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (m) => '.');
  }
}

// ===================== Plein écran carte (comme ANP) =====================

class _MapFullResult {
  final LatLng point;
  final bool satellite;
  _MapFullResult(this.point, this.satellite);
}

class _LogementMapFullScreenPage extends StatefulWidget {
  const _LogementMapFullScreenPage({
    super.key,
    required this.pointInitial,
    required this.satelliteInitial,
  });

  final LatLng pointInitial;
  final bool satelliteInitial;

  @override
  State<_LogementMapFullScreenPage> createState() =>
      _LogementMapFullScreenPageState();
}

class _LogementMapFullScreenPageState
    extends State<_LogementMapFullScreenPage> {
  static const double _kMinZoom = 2.0;
  static const double _kMaxZoom = 19.0;

  static const String _tileUrlNormal =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
  static const List<String> _tileSubdomainsNormal = ['a', 'b', 'c', 'd'];

  static const String _tileUrlSatellite =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  final MapController _ctrl = MapController();
  late LatLng _point;
  late bool _satellite;

  @override
  void initState() {
    super.initState();
    _point = widget.pointInitial;
    _satellite = widget.satelliteInitial;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.move(_point, 18);
    });
  }

  void _onTap(TapPosition tapPosition, LatLng latLng) {
    setState(() => _point = latLng);
  }

  void _validate() {
    Navigator.of(context)
        .pop<_MapFullResult>(_MapFullResult(_point, _satellite));
  }

  Widget _toggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _satellite = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _satellite ? Colors.transparent : Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                "Plan",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _satellite ? Colors.black87 : const Color(0xFF0B3A6A),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _satellite = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _satellite ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                "Satellite",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _satellite ? const Color(0xFF0B3A6A) : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3A6A),
        foregroundColor: Colors.white,
        title: const Text("Ajuster la position"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(child: _toggle()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _ctrl,
              options: MapOptions(
                initialCenter: _point,
                initialZoom: 18,
                minZoom: _kMinZoom,
                maxZoom: _kMaxZoom,
                onTap: _onTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: _satellite ? _tileUrlSatellite : _tileUrlNormal,
                  subdomains: _satellite ? const [] : _tileSubdomainsNormal,
                  maxZoom: _kMaxZoom,
                  maxNativeZoom: _satellite ? 18 : 19,
                  userAgentPackageName: 'com.soneya.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _point,
                      width: 52,
                      height: 52,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 44,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _validate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE1005A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: const Text(
                    "Valider cette position",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Overlay de chargement =====================

class PositionedFillLoading extends StatelessWidget {
  const PositionedFillLoading({super.key});
  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: ColoredBox(
        color: Color(0x44000000),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

// ===================== Types internes =====================

class _PhotoItem {
  _PhotoItem({this.bytes, this.url, this.name});
  final Uint8List? bytes;
  final String? url;
  final String? name;
}

class _StorageRef {
  final String bucket;
  final String path;
  _StorageRef({required this.bucket, required this.path});
}

// Formatter : 50000 -> 50.000
class ThousandsDotFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');

    final formatted = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => '.',
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
