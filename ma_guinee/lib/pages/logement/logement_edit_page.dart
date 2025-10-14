// lib/pages/logement/logement_edit_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/logement_service.dart';
import '../../models/logement_models.dart';

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
  Color get _fieldFill => _isDark ? const Color(0xFF1F2937) : const Color(0xFFF6F7FB);
  Color get _chipBg => _isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);

  // Champs
  late TextEditingController _titre;
  late TextEditingController _desc;
  late TextEditingController _prix;
  late TextEditingController _ville;
  late TextEditingController _commune;
  late TextEditingController _adresse;
  late TextEditingController _surface;
  late TextEditingController _phone;

  // Choix utilisateur (pas de valeur par défaut)
  int? _chambres;
  LogementMode? _mode;
  LogementCategorie? _cat;

  // Localisation
  double? _lat;
  double? _lng;
  final _mapCtrl = MapController();

  // Photos
  static const _kMaxPhotos = 10;
  final List<_PhotoItem> _photos = [];

  bool _saving = false;
  bool _loadedFromRouteArg = false;

  // ─────────────────────────── Cycle ───────────────────────────
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

    // Pré-remplissage immédiat si on reçoit déjà un modèle
    if (widget.existing != null) {
      _prefillFrom(widget.existing!);
    }
  }

  // Charge depuis arguments de route: id (String) ou modèle
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedFromRouteArg || widget.existing != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    _loadedFromRouteArg = true;

    if (args is LogementModel) {
      _prefillFrom(args);
    } else if (args is String && args.trim().isNotEmpty) {
      // Un ID → fetch DB
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final m = await _svc.getById(args);
          if (m != null && mounted) {
            _prefillFrom(m);
            // lis aussi le téléphone dans la colonne dédiée si besoin
            final tel = await _svc.getContactPhone(m.id);
            if (mounted && (tel ?? '').isNotEmpty) _phone.text = tel!;
          }
        } catch (e) {
          if (mounted) _snack('Erreur chargement: $e');
        }
      });
    }
  }

  void _prefillFrom(LogementModel e) {
    _titre.text = e.titre;
    _desc.text = e.description ?? '';
    _prix.text = e.prixGnf?.toString() ?? '';
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
    for (final u in e.photos) {
      final s = u.trim();
      if (s.isNotEmpty) _photos.add(_PhotoItem(url: s));
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      );

  // ─────────────────────────── UI ───────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null ||
        (ModalRoute.of(context)?.settings.arguments is String);

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
                            DropdownMenuItem(value: LogementMode.location, child: Text("Location")),
                            DropdownMenuItem(value: LogementMode.achat, child: Text("Achat")),
                          ],
                          onChanged: (v) => setState(() => _mode = v),
                          decoration: _dec("Type d’opération *", hint: "Sélectionner…"),
                          validator: (v) => v == null ? "Choisir le type" : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<LogementCategorie>(
                          value: _cat,
                          items: const [
                            DropdownMenuItem(value: LogementCategorie.maison, child: Text("Maison")),
                            DropdownMenuItem(value: LogementCategorie.appartement, child: Text("Appartement")),
                            DropdownMenuItem(value: LogementCategorie.studio, child: Text("Studio")),
                            DropdownMenuItem(value: LogementCategorie.terrain, child: Text("Terrain")),
                            DropdownMenuItem(value: LogementCategorie.autres, child: Text("Autres")),
                          ],
                          onChanged: (v) => setState(() => _cat = v),
                          decoration: _dec("Catégorie *", hint: "Sélectionner…"),
                          validator: (v) => v == null ? "Choisir la catégorie" : null,
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
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _dec("Prix / Loyer (GNF)"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _surface,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    decoration: _dec("Chambres (optionnel)", hint: "Laisser vide si peu importe"),
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
                    decoration: _dec("Téléphone de contact *", hint: "+224 6x xx xx xx"),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // ─────────────────────────── Localisation ───────────────────────────
  Widget _localisationCard() {
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
          const Text("Localisation précise", style: TextStyle(fontWeight: FontWeight.bold)),
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
              if (_lat != null && _lng != null)
                Text('(${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)})',
                    style: const TextStyle(color: Colors.black54)),
            ],
          ),
          if (_lat != null && _lng != null) ...[
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

                    // ➜ clic simple : déplacer le repère
                    onTap: (tapPos, latLng) {
                      setState(() {
                        _lat = latLng.latitude;
                        _lng = latLng.longitude;
                      });
                    },

                    // ➜ long-clic : déplacer + recentrer/zoomer
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
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(_lat!, _lng!),
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, size: 36, color: Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
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
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _snack("Active d’abord la localisation (GPS).");
        return;
      }

      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        _snack("Permission localisation refusée.");
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);

      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });

      try {
        _mapCtrl.move(LatLng(_lat!, _lng!), 16);
      } catch (_) {}
    } catch (e) {
      _snack('Localisation impossible: $e');
    }
  }

  // ─────────────────────────── Photos ───────────────────────────
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          itemBuilder: (_, i) => (i < _photos.length) ? _photoTile(i) : _addTile(),
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
            onPressed: () => setState(() => _photos.removeAt(index)),
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
    final files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;

    for (final f in files.take(left)) {
      final bytes = await f.readAsBytes();
      _photos.add(_PhotoItem(bytes: bytes, name: f.name));
    }
    setState(() {});
  }

  // ─────────────────────────── Save ───────────────────────────
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
        prixGnf: _prix.text.trim().isEmpty ? null : num.tryParse(_prix.text.trim()),
        ville: _ville.text.trim().isEmpty ? null : _ville.text.trim(),
        commune: _commune.text.trim().isEmpty ? null : _commune.text.trim(),
        adresse: _adresse.text.trim().isEmpty ? null : _adresse.text.trim(),
        superficieM2: _surface.text.trim().isEmpty ? null : num.tryParse(_surface.text.trim()),
        chambres: _chambres,
        lat: _lat ?? widget.existing?.lat,
        lng: _lng ?? widget.existing?.lng,
        photos: const [],
        creeLe: widget.existing?.creeLe ?? DateTime.now(),
        contactTelephone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      );

      // Détecte édition vs création
      final routeArg = ModalRoute.of(context)?.settings.arguments;
      final bool isEditing =
          widget.existing != null || (routeArg is String && routeArg.trim().isNotEmpty);

      String id;
      if (!isEditing) {
        // Création
        id = await _svc.create(model);
      } else {
        // Edition
        id = widget.existing?.id ?? (routeArg is String ? routeArg : 'new');
        if (id == 'new' || id.trim().isEmpty) {
          id = await _svc.create(model);
        } else {
          await _svc.updateFromModel(id, model);
        }
      }

      // Contact (sécurité si colonne séparée)
      final tel = _phone.text.trim();
      if (tel.isNotEmpty) await _svc.update(id, {'contact_telephone': tel});

      // Upload photos ➜ URLs
      final urls = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        final p = _photos[i];
        if ((p.url ?? '').isNotEmpty) {
          urls.add(p.url!);
        } else if (p.bytes != null) {
          final name = p.name ?? 'photo_$i.jpg';
          final res = await _svc.uploadPhoto(
            bytes: p.bytes!,
            filename: name,
            logementId: id,
          );
          urls.add(res.publicUrl);
        }
      }

      // Sauve l’ordre
      await _svc.setPhotos(id, urls);

      if (!mounted) return;
      _snack(!isEditing ? "Annonce créée" : "Annonce mise à jour");
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack("Erreur: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }
}

// Petit overlay de chargement
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

// Type interne
class _PhotoItem {
  _PhotoItem({this.bytes, this.url, this.name});
  final Uint8List? bytes;
  final String? url;
  final String? name;
}
