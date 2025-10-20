import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ---- Couleurs globales ----
const Color danger = Color(0xFFCE1126);          // rouge suppression
const Color defaultPrimary = Color(0xFF1E3A8A);  // fallback (bleu annonces)

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

  // Images nouvellement choisies (préviews + fichier)
  final List<_LocalImage> _localPreviews = [];

  bool _isUploading = false;

  // État localisation
  bool _detectingPosition = false;
  bool _modeManuel = false;

  // champs lat/lng pour le mode manuel
  final TextEditingController _latCtrl = TextEditingController();
  final TextEditingController _lngCtrl = TextEditingController();

  // nom du bucket Supabase
  final String _bucket = 'lieux-photos';

  // Centre par défaut (Conakry)
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
    latitude = l['latitude'] != null ? double.tryParse('${l['latitude']}') : null;
    longitude = l['longitude'] != null ? double.tryParse('${l['longitude']}') : null;
    if (l['images'] is List && (l['images'] as List).isNotEmpty) {
      _uploadedImages = List<String>.from(l['images']);
    }
    _syncLatLngCtrls();
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  void _syncLatLngCtrls() {
    _latCtrl.text = latitude != null ? latitude!.toStringAsFixed(6) : '';
    _lngCtrl.text = longitude != null ? longitude!.toStringAsFixed(6) : '';
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
          ],
        ),
      );

      // 1) Service activé ?
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError("La localisation est désactivée sur l’appareil. Veuillez l’activer.");
      }

      // 2) Permissions
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        _showError("Permission de localisation refusée. Autorisez-la pour détecter votre position.");
        return;
      }
      if (perm == LocationPermission.deniedForever) {
        _showError("La permission de localisation est bloquée. Ouvrez les réglages pour l’autoriser.");
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
          _showError("Impossible d’obtenir la position pour le moment. Veuillez réessayer.");
          return;
        }
      }

      // 4) Reverse geocoding
      String? adr;
      String? city;
      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          adr = _formatAdresse(p);
          city = _nonVide(p.locality) ?? _nonVide(p.subAdministrativeArea) ?? _nonVide(p.administrativeArea);
        }
      } catch (_) {}

      setState(() {
        latitude = position?.latitude;
        longitude = position?.longitude;
        if (adr != null && adr.trim().isNotEmpty) adresse = adr;
        if (city != null && city.trim().isNotEmpty) ville = city;
        _syncLatLngCtrls();
      });

      _showInfo("Position détectée avec succès.");
    } catch (_) {
      _showError("Une erreur est survenue lors de la localisation. Veuillez réessayer.");
    } finally {
      if (mounted) setState(() => _detectingPosition = false);
    }
  }

  Future<void> _reverseGeocodeFromLatLng() async {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) {
      _showError("Veuillez d’abord choisir un point sur la carte ou saisir des coordonnées.");
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
        _showInfo("Adresse déduite à partir des coordonnées.");
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
      if (_nonVide(p.administrativeArea) != null) _nonVide(p.administrativeArea)!,
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
    final picked = await picker.pickMultiImage(imageQuality: 80);
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

  Future<String?> _uploadOne(Uint8List bytes, String userId) async {
    try {
      final mime = lookupMimeType('', headerBytes: bytes) ?? 'application/octet-stream';
      String ext = 'bin';
      if (mime.contains('jpeg')) ext = 'jpg';
      else if (mime.contains('png')) ext = 'png';
      else if (mime.contains('webp')) ext = 'webp';
      else if (mime.contains('gif')) ext = 'gif';

      final ts = DateTime.now().millisecondsSinceEpoch;
      final objectPath = 'u/$userId/$ts.$ext';

      await Supabase.instance.client.storage.from(_bucket).uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: mime),
          );

      final publicUrl =
          Supabase.instance.client.storage.from(_bucket).getPublicUrl(objectPath);

      return publicUrl;
    } catch (e) {
      debugPrint('Erreur upload image: $e');
      return null;
    }
  }

  Future<List<String>> _uploadImages() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    final urls = <String>[];
    for (final li in _localPreviews) {
      final url = await _uploadOne(li.bytes, userId);
      if (url != null) urls.add(url);
    }
    return urls;
  }

  // ---------- ENREGISTREMENT ----------

  Future<void> _enregistrerLieu() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if (latitude == null || longitude == null) {
      _showError("Veuillez définir la position (détection automatique ou carte).");
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

    setState(() => _isUploading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception("Utilisateur non connecté.");
      }

      // Upload des nouvelles images si besoin
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

      final existingId = widget.lieu != null ? widget.lieu!['id'] : null;

      if (existingId != null) {
        await Supabase.instance.client.from('lieux').update(data).eq('id', existingId);
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
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Erreur enregistrement : $e");
      _showError("Une erreur est survenue lors de l’enregistrement. Veuillez réessayer.");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final enEdition = widget.lieu != null;
    final showMap = _modeManuel || (latitude != null && longitude != null);

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
              // Boutons localisation
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _modeManuel ? null : (_detectingPosition ? null : _recupererPosition),
                      icon: _detectingPosition
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.my_location),
                      label: Text(_detectingPosition ? "Détection en cours…" : "Détecter ma position"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                value: _modeManuel,
                onChanged: (v) => setState(() => _modeManuel = v),
                title: const Text("Définir la position manuellement"),
                subtitle: const Text("Touchez la carte pour placer le marqueur"),
                activeColor: _primaryColor,
              ),

              if (showMap) ...[
                const SizedBox(height: 8),
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
                        center: LatLng(
                          latitude ?? _defaultCenter.latitude,
                          longitude ?? _defaultCenter.longitude,
                        ),
                        zoom: latitude != null ? 16 : 12,
                        onTap: (tapPosition, point) {
                          if (!_modeManuel) {
                            _showInfo("Activez le mode manuel pour déplacer le marqueur.");
                            return;
                          }
                          setState(() {
                            latitude = point.latitude;
                            longitude = point.longitude;
                            _syncLatLngCtrls();
                          });
                          _showInfo(
                              "Position choisie : ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}");
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        if (latitude != null && longitude != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                width: 40,
                                height: 40,
                                point: LatLng(latitude!, longitude!),
                                child: Icon(Icons.location_on, color: _primaryColor, size: 40),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Saisie manuelle lat/lng
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(signed: true, decimal: true),
                        decoration: const InputDecoration(labelText: 'Latitude'),
                        onChanged: (v) {
                          final d = double.tryParse(v.replaceAll(',', '.'));
                          setState(() => latitude = d);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _lngCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(signed: true, decimal: true),
                        decoration: const InputDecoration(labelText: 'Longitude'),
                        onChanged: (v) {
                          final d = double.tryParse(v.replaceAll(',', '.'));
                          setState(() => longitude = d);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _reverseGeocodeFromLatLng,
                    icon: const Icon(Icons.place),
                    label: const Text("Déduire l’adresse depuis les coordonnées"),
                  ),
                ),
              ],

              if (latitude != null && longitude != null && !_modeManuel) ...[
                const SizedBox(height: 6),
                Text("Latitude : ${latitude!.toStringAsFixed(6)}"),
                Text("Longitude : ${longitude!.toStringAsFixed(6)}"),
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
                validator: (v) => v == null || v.isEmpty ? "Champ requis" : null,
                onChanged: (v) => nom = v,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: "Type de lieu"),
                items: _typesLieu.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
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
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
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
              _isUploading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _enregistrerLieu,
                      icon: const Icon(Icons.save),
                      label: Text(enEdition ? "Mettre à jour" : "Enregistrer"),
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
      tiles.add(_PhotoTile(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(url, fit: BoxFit.cover),
        ),
        onRemove: () => _removeUploadedImage(url),
      ));
    }

    // Nouvelles photos (préviews mémoire)
    for (final li in _localPreviews) {
      tiles.add(_PhotoTile(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(li.bytes, fit: BoxFit.cover),
        ),
        onRemove: () => _removeLocalPreview(li),
      ));
    }

    if (tiles.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text("Aucune photo sélectionnée", style: TextStyle(color: Colors.grey[700])),
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
  const _PhotoTile({super.key, required this.child, required this.onRemove});

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
            icon: const Icon(Icons.close, size: 20, color: danger),
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ],
    );
  }
}
