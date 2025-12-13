import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, debugPrint;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ✅ Compression (même module que Annonces)
import 'package:ma_guinee/utils/image_compressor/image_compressor.dart';

// ---- Couleurs globales ----
const Color danger = Color(0xFFCE1126); // rouge suppression
const Color defaultPrimary = Color(0xFF1E3A8A); // fallback (bleu annonces)

class InscriptionLieuPage extends StatefulWidget {
  final Map<String, dynamic>? lieu;

  const InscriptionLieuPage({super.key, this.lieu});

  @override
  State<InscriptionLieuPage> createState() => _InscriptionLieuPageState();
}

class _InscriptionLieuPageState extends State<InscriptionLieuPage> {
  final _formKey = GlobalKey<FormState>();

  String nom = '';
  String adresse = '';
  String ville = '';
  String? type;
  String sousCategorie = '';
  String description = '';
  String contact = '';
  double? latitude;
  double? longitude;

  // Images déjà en ligne (URLs publiques)
  List<String> _uploadedImages = [];

  // Images nouvellement choisies (préviews + bytes)
  final List<_LocalImage> _localPreviews = [];

  bool _isUploading = false;

  // État localisation
  bool _detectingPosition = false;

  // nom du bucket Supabase
  final String _bucket = 'lieux-photos';

  // Centre par défaut (Conakry) pour fallback si besoin
  static const LatLng _defaultCenter = LatLng(9.6412, -13.5784);

  final List<String> _typesLieu = ['divertissement', 'culte', 'tourisme'];
  final Map<String, List<String>> sousCategoriesParType = {
    'divertissement': [
      'Boîte de nuit',
      'Bar',
      'Salle de jeux',
      'Cinéma',
      'Parc d’attractions',
      'Club',
      'Plage privée'
    ],
    'culte': ['Mosquée', 'Église', 'Temple', 'Sanctuaire', 'Chapelle'],
    'tourisme': [
      'Monument',
      'Musée',
      'Plage',
      'Cascade',
      'Parc naturel',
      'Site historique',
      'Montagne'
    ],
  };

  // ---------- Détection du type d’appareil ----------
  bool get _isMobile {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  // ---------- Palette par type ----------
  Color get _primaryColor {
    switch (type) {
      case 'divertissement':
        return const Color(0xFFE53935);
      case 'culte':
        return const Color(0xFF43A047);
      case 'tourisme':
        return const Color(0xFF1E88E5);
      default:
        return defaultPrimary;
    }
  }

  Color get _secondaryTint {
    switch (type) {
      case 'divertissement':
        return const Color(0xFFFFCDD2);
      case 'culte':
        return const Color(0xFFC8E6C9);
      case 'tourisme':
        return const Color(0xFFBBDEFB);
      default:
        return const Color(0xFFEFF2F7);
    }
  }

  @override
  void initState() {
    super.initState();
    final l = widget.lieu ?? {};
    nom = l['nom'] ?? '';
    adresse = l['adresse'] ?? '';
    ville = l['ville'] ?? '';
    type = l['type'];
    sousCategorie = l['sous_categorie'] ?? '';
    description = l['description'] ?? '';
    contact = l['contact'] ?? '';
    latitude =
        l['latitude'] != null ? double.tryParse('${l['latitude']}') : null;
    longitude =
        l['longitude'] != null ? double.tryParse('${l['longitude']}') : null;
    if (l['images'] is List && (l['images'] as List).isNotEmpty) {
      _uploadedImages = List<String>.from(l['images']);
    }
  }

  // ------------------ Localisation robuste ------------------

  Future<void> _recupererPosition() async {
    if (_detectingPosition) return;
    setState(() => _detectingPosition = true);

    try {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Astuce localisation"),
          content: const Text(
              "Pour plus de précision, placez-vous à l’intérieur de l’établissement avant de détecter la position."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );

      // 1) Service activé ?
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError(
            "La localisation est désactivée sur l’appareil. Veuillez l’activer.");
      }

      // 2) Permissions
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        _showError(
            "Permission de localisation refusée. Autorisez-la pour détecter votre position.");
        return;
      }
      if (perm == LocationPermission.deniedForever) {
        _showError(
            "La permission de localisation est bloquée. Ouvrez les réglages pour l’autoriser.");
        if (!kIsWeb) {
          unawaited(Geolocator.openAppSettings());
          unawaited(Geolocator.openLocationSettings());
        }
        return;
      }

      // 3) Position avec timeout + repli
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 8),
        );
      } on TimeoutException {
        position = await Geolocator.getLastKnownPosition();
        if (position == null) {
          _showError(
              "Délai dépassé pour obtenir la position. Réessayez près d’une fenêtre ou activez le GPS.");
          return;
        }
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
        if (position == null) {
          _showError(
              "Impossible d’obtenir la position pour le moment. Veuillez réessayer.");
          return;
        }
      }

      // 4) Reverse geocoding
      String? adr;
      String? city;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          adr = _formatAdresse(p);
          city = _nonVide(p.locality) ??
              _nonVide(p.subAdministrativeArea) ??
              _nonVide(p.administrativeArea);
        }
      } catch (_) {}

      setState(() {
        latitude = position?.latitude;
        longitude = position?.longitude;
        if (adr != null && adr.trim().isNotEmpty) adresse = adr;
        if (city != null && city.trim().isNotEmpty) ville = city;
      });

      _showInfo(
          "Position détectée. Vous pouvez maintenant ajuster le point exact sur la carte.");
    } catch (_) {
      _showError(
          "Une erreur est survenue lors de la localisation. Veuillez réessayer.");
    } finally {
      if (mounted) setState(() => _detectingPosition = false);
    }
  }

  Future<void> _reverseGeocodeFromLatLng() async {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) {
      _showError(
          "Détectez d’abord votre position puis ajustez éventuellement le point sur la carte.");
      return;
    }
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          adresse = _formatAdresse(p);
          ville = _nonVide(p.locality) ??
              _nonVide(p.subAdministrativeArea) ??
              _nonVide(p.administrativeArea) ??
              ville;
        });
        _showInfo("Adresse mise à jour à partir de la position.");
      } else {
        _showError("Aucune adresse trouvée pour ces coordonnées.");
      }
    } catch (_) {
      _showError("Impossible de déduire l’adresse pour ces coordonnées.");
    }
  }

  String _formatAdresse(Placemark p) {
    final parts = <String>[
      if (_nonVide(p.street) != null) _nonVide(p.street)!,
      if (_nonVide(p.postalCode) != null) _nonVide(p.postalCode)!,
      if (_nonVide(p.locality) != null) _nonVide(p.locality)!,
      if (_nonVide(p.administrativeArea) != null)
        _nonVide(p.administrativeArea)!,
      if (_nonVide(p.country) != null) _nonVide(p.country)!,
    ];
    return parts.join(', ');
  }

  String? _nonVide(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showInfo(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- IMAGES ----------

  Future<void> _choisirImages() async {
    final picker = ImagePicker();

    // ✅ comme Annonces: pas de "imageQuality" ici (on gère la compression nous-mêmes)
    final picked = await picker.pickMultiImage();
    if (picked.isEmpty) return;

    for (final x in picked) {
      final already = _localPreviews.any((e) => e.file.path == x.path) ||
          _uploadedImages.contains(x.path);
      if (already) continue;

      final bytes = await x.readAsBytes();
      _localPreviews.add(_LocalImage(file: x, bytes: bytes));
    }
    if (mounted) setState(() {});
  }

  void _removeLocalPreview(_LocalImage img) {
    setState(() => _localPreviews.remove(img));
  }

  void _removeUploadedImage(String url) {
    setState(() => _uploadedImages.remove(url));
  }

  // ✅ Upload 1 image avec compression (même logique que Annonces)
  Future<String?> _uploadOneCompressed(
    Uint8List rawBytes,
    String userId,
    int i,
  ) async {
    try {
      final storage = Supabase.instance.client.storage.from(_bucket);

      // ✅ compression prod (identique à ton CreateAnnoncePage)
      final c = await ImageCompressor.compressBytes(
        rawBytes,
        maxSide: 1600,
        quality: 82,
        maxBytes: 900 * 1024,
        keepPngIfTransparent: true,
      );

      final ts = DateTime.now().microsecondsSinceEpoch;
      final objectPath = 'u/$userId/${ts}_$i.${c.extension}';

      await storage.uploadBinary(
        objectPath,
        c.bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: c.contentType,
        ),
      );

      return storage.getPublicUrl(objectPath);
    } catch (e) {
      debugPrint('Erreur upload image (lieu): $e');
      return null;
    }
  }

  // ✅ Upload de toutes les images avec compression
  Future<List<String>> _uploadImages() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    final urls = <String>[];
    for (int i = 0; i < _localPreviews.length; i++) {
      final li = _localPreviews[i];

      final url = await _uploadOneCompressed(li.bytes, userId, i);
      if (url != null) urls.add(url);
    }
    return urls;
  }

  // ---------- Vérif quota : 1 lieu par type ----------
  Future<Map<String, dynamic>?> _findLieuByType(
    String userId,
    String typeLieu, {
    dynamic excludeId,
  }) async {
    try {
      var query = Supabase.instance.client
          .from('lieux')
          .select('id, nom, type')
          .eq('user_id', userId)
          .eq('type', typeLieu);

      if (excludeId != null) {
        query = query.neq('id', excludeId);
      }

      final res = await query.limit(1);

      if (res is List && res.isNotEmpty) {
        final row = res.first;
        if (row is Map<String, dynamic>) return row;
        return Map<String, dynamic>.from(row as Map);
      }
    } catch (e) {
      debugPrint('Erreur vérification lieu par type: $e');
    }
    return null;
  }

  // ---------- ENREGISTREMENT ----------

  Future<void> _enregistrerLieu() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if (latitude == null || longitude == null) {
      _showError(
          "Veuillez détecter votre position puis ajuster le point exact sur la carte.");
      return;
    }
    if (type == null || (type ?? '').isEmpty) {
      _showError("Veuillez choisir un type de lieu.");
      return;
    }
    if (sousCategorie.isEmpty) {
      _showError("Veuillez choisir une sous-catégorie.");
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showError("Utilisateur non connecté.");
      return;
    }

    final existingId = widget.lieu != null ? widget.lieu!['id'] : null;

    final existingSameType =
        await _findLieuByType(userId, type!, excludeId: existingId);

    if (existingSameType != null) {
      final nomExistant =
          (existingSameType['nom'] ?? '').toString().trim().isEmpty
              ? 'Sans nom'
              : existingSameType['nom'].toString();

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Lieu déjà enregistré'),
          content: Text(
            'Vous avez déjà un lieu de type "$type" enregistré :\n'
            '"$nomExistant".\n\n'
            'Chaque utilisateur peut créer au maximum un lieu de type divertissement, '
            'un lieu de type culte et un lieu de type tourisme.\n\n'
            'Si vous avez plusieurs lieux à gérer, merci de nous contacter '
            'depuis votre rubrique Aide.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      // ✅ Upload des nouvelles images (compressées) si besoin
      if (_localPreviews.isNotEmpty) {
        final newUrls = await _uploadImages();
        _uploadedImages = [..._uploadedImages, ...newUrls];
        _localPreviews.clear();
      }

      final data = {
        'nom': nom,
        'adresse': adresse,
        'ville': ville,
        'categorie': type,
        'sous_categorie': sousCategorie,
        'type': type,
        'description': description,
        'contact': contact,
        'latitude': latitude,
        'longitude': longitude,
        'images': _uploadedImages,
        'photo_url': _uploadedImages.isNotEmpty ? _uploadedImages.first : null,
        'user_id': userId,
      };

      if (existingId != null) {
        await Supabase.instance.client
            .from('lieux')
            .update(data)
            .eq('id', existingId);
      } else {
        await Supabase.instance.client.from('lieux').insert(data);
      }

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Succès"),
          content: Text(existingId != null
              ? "Lieu mis à jour avec succès."
              : "Lieu enregistré avec succès."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Erreur enregistrement : $e");
      _showError(
          "Une erreur est survenue lors de l’enregistrement. Veuillez réessayer.");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final enEdition = widget.lieu != null;
    final isMobile = _isMobile;

    // Inscription initiale obligatoire sur mobile
    final canSave = isMobile || enEdition;

    // On n’affiche la carte qu’après avoir une position (ou si lieu déjà géolocalisé)
    final showMap = latitude != null && longitude != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(enEdition ? "Modifier le lieu" : "Inscription Lieu"),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (!isMobile) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade700),
                  ),
                  child: Text(
                    enEdition
                        ? "Pour garantir une géolocalisation fiable, l’enregistrement initial de ce lieu a été fait avec un téléphone. Vous pouvez modifier les informations ci-dessous, mais la position doit rester cohérente."
                        : "L’inscription d’un lieu doit être réalisée avec votre téléphone pour une géolocalisation précise. Merci d’ouvrir l’application sur mobile et de refaire cette étape.",
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],

              // Bouton localisation
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (!isMobile || _detectingPosition)
                          ? null
                          : _recupererPosition,
                      icon: _detectingPosition
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.my_location),
                      label: Text(_detectingPosition
                          ? "Détection en cours…"
                          : "Détecter ma position"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Après la détection, vous pourrez déplacer le marqueur sur la carte pour ajuster votre position exacte (entrée, parking, etc.).",
                  style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                ),
              ),

              if (showMap) ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: _secondaryTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: SizedBox(
                    height: 240,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(
                          latitude ?? _defaultCenter.latitude,
                          longitude ?? _defaultCenter.longitude,
                        ),
                        initialZoom: 16,
                        onTap: (tapPosition, point) {
                          // Ajustement manuel direct sur la carte, uniquement sur mobile
                          if (!isMobile) return;
                          if (latitude == null || longitude == null) {
                            _showInfo(
                                "Détectez d’abord votre position avec le bouton au-dessus.");
                            return;
                          }
                          setState(() {
                            latitude = point.latitude;
                            longitude = point.longitude;
                          });
                          _showInfo(
                              "Position ajustée : ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}");
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        if (latitude != null && longitude != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                width: 40,
                                height: 40,
                                point: LatLng(latitude!, longitude!),
                                child: Icon(
                                  Icons.location_on,
                                  color: _primaryColor,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Astuce : déplacez le marqueur sur l’endroit exact (porte d’entrée, accueil…).",
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: (latitude == null || longitude == null)
                        ? null
                        : _reverseGeocodeFromLatLng,
                    icon: const Icon(Icons.place),
                    label: const Text(
                      "Mettre à jour l’adresse depuis la position",
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (latitude != null && longitude != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Latitude : ${latitude!.toStringAsFixed(6)}",
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Longitude : ${longitude!.toStringAsFixed(6)}",
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 10),

              // Choisir des photos
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _choisirImages,
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Ajouter des photos"),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Grille des photos (déjà en ligne + nouvelles)
              _buildPhotosGrid(),

              const SizedBox(height: 16),

              TextFormField(
                initialValue: nom,
                decoration: const InputDecoration(labelText: "Nom du lieu"),
                validator: (v) =>
                    v == null || v.isEmpty ? "Champ requis" : null,
                onChanged: (v) => nom = v,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: "Type de lieu"),
                items: _typesLieu
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  type = v;
                  sousCategorie = '';
                }),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: sousCategorie.isNotEmpty ? sousCategorie : null,
                decoration: const InputDecoration(labelText: "Sous-catégorie"),
                items: type != null
                    ? (sousCategoriesParType[type!] ?? [])
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          ),
                        )
                        .toList()
                    : [],
                onChanged: (v) => setState(() => sousCategorie = v ?? ''),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: adresse,
                decoration: const InputDecoration(labelText: "Adresse"),
                onChanged: (v) => adresse = v,
              ),
              TextFormField(
                initialValue: ville,
                decoration: const InputDecoration(labelText: "Ville"),
                onChanged: (v) => ville = v,
              ),
              TextFormField(
                initialValue: contact,
                decoration: const InputDecoration(labelText: "Contact"),
                onChanged: (v) => contact = v,
              ),
              TextFormField(
                initialValue: description,
                decoration: const InputDecoration(labelText: "Description"),
                maxLines: 3,
                onChanged: (v) => description = v,
              ),
              const SizedBox(height: 20),

              if (_isUploading)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: canSave ? _enregistrerLieu : null,
                  icon: const Icon(Icons.save),
                  label: Text(
                    enEdition ? "Mettre à jour" : "Enregistrer",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotosGrid() {
    final tiles = <Widget>[];

    // Photos déjà uploadées
    for (final url in _uploadedImages) {
      tiles.add(
        _PhotoTile(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(url, fit: BoxFit.cover),
          ),
          onRemove: () => _removeUploadedImage(url),
        ),
      );
    }

    // Nouvelles photos (préviews mémoire)
    for (final li in _localPreviews) {
      tiles.add(
        _PhotoTile(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(li.bytes, fit: BoxFit.cover),
          ),
          onRemove: () => _removeLocalPreview(li),
        ),
      );
    }

    if (tiles.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          "Aucune photo sélectionnée",
          style: TextStyle(color: Colors.grey[700]),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tiles,
    );
  }
}

// --------- Helpers ---------

class _LocalImage {
  final XFile file;
  final Uint8List bytes;
  _LocalImage({required this.file, required this.bytes});
}

class _PhotoTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;

  const _PhotoTile({
    super.key,
    required this.child,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey[200],
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
        Positioned(
          top: -8,
          right: -8,
          child: IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.close,
              size: 20,
              color: danger,
            ),
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ],
    );
  }
}
