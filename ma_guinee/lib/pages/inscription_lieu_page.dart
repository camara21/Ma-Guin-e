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

  // ⚠️ nom du bucket Supabase
  final String _bucket = 'lieux-photos';

  final List<String> _typesLieu = ['divertissement', 'culte', 'tourisme'];
  final Map<String, List<String>> sousCategoriesParType = {
    'divertissement': [
      'Boîte de nuit',
      'Bar',
      'Salle de jeux',
      'Cinéma',
      'Parc d’attraction',
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
    if (l['images'] is List && l['images'].isNotEmpty) {
      _uploadedImages = List<String>.from(l['images']);
    }
  }

  Color get mainColor => const Color(0xFF1E3FCF);
  Color get red => const Color(0xFFCE1126);

  Future<void> _recupererPosition() async {
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

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Permission de localisation refusée.")));
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Activez la localisation dans les paramètres.")));
        return;
      }

      final position =
          await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      latitude = position.latitude;
      longitude = position.longitude;

      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        adresse = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
          p.country
        ].where((e) => e != null && e.isNotEmpty).join(", ");
        ville = p.locality ?? ville;
      }

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Position détectée avec succès.")));
    } catch (e) {
      debugPrint("Erreur géolocalisation : $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erreur localisation : $e")));
    }
  }

  // ---------- IMAGES ----------

  Future<void> _choisirImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;

    // Charger les bytes pour affichage (Web/Mobile)
    for (final x in picked) {
      // éviter doublons (par path + nom)
      final already =
          _localPreviews.any((e) => e.file.path == x.path) || _uploadedImages.contains(x.path);
      if (already) continue;

      final bytes = await x.readAsBytes();
      _localPreviews.add(_LocalImage(file: x, bytes: bytes));
    }
    setState(() {});
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

      await Supabase.instance.client.storage
          .from(_bucket)
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: mime),
          );

      final publicUrl = Supabase.instance.client.storage
          .from(_bucket)
          .getPublicUrl(objectPath);

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
    if (!_formKey.currentState!.validate()) return;
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Veuillez détecter la position.")));
      return;
    }
    if (type == null || type!.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Veuillez choisir un type de lieu.")));
      return;
    }
    if (sousCategorie.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Veuillez choisir une sous-catégorie.")));
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

      if (widget.lieu != null) {
        await Supabase.instance.client.from('lieux').update(data).eq('id', widget.lieu!['id']);
      } else {
        await Supabase.instance.client.from('lieux').insert(data);
      }

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Succès"),
          content: Text(widget.lieu != null
              ? "Lieu mis à jour avec succès ✅"
              : "Lieu enregistré avec succès ✅"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
          ],
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Erreur enregistrement : $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final enEdition = widget.lieu != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(enEdition ? "Modifier le lieu" : "Inscription Lieu"),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: _recupererPosition,
                icon: const Icon(Icons.my_location),
                label: const Text("Détecter ma position"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  foregroundColor: Colors.white,
                ),
              ),
              if (latitude != null && longitude != null) ...[
                const SizedBox(height: 10),
                Text("Latitude : $latitude"),
                Text("Longitude : $longitude"),
                if (adresse.isNotEmpty) Text("Adresse : $adresse"),
                const SizedBox(height: 10),
                SizedBox(
                  height: 200,
                  child: FlutterMap(
                    options: MapOptions(
                      center: LatLng(latitude!, longitude!),
                      zoom: 16,
                      onTap: (tapPosition, point) {
                        setState(() {
                          latitude = point.latitude;
                          longitude = point.longitude;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Position modifiée")));
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 40,
                            height: 40,
                            point: LatLng(latitude!, longitude!),
                            child: Icon(Icons.location_on, color: red, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                items: _typesLieu
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
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
                        backgroundColor: mainColor,
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
        child: Text("Aucune photo sélectionnée",
            style: TextStyle(color: Colors.grey[700])),
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
            icon: const Icon(Icons.close, size: 20, color: Colors.red),
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ],
    );
  }
}
