import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class InscriptionCliniquePage extends StatefulWidget {
  final Map<String, dynamic>? clinique;

  const InscriptionCliniquePage({super.key, this.clinique});

  @override
  State<InscriptionCliniquePage> createState() => _InscriptionCliniquePageState();
}

class _InscriptionCliniquePageState extends State<InscriptionCliniquePage> {
  final _formKey = GlobalKey<FormState>();

  String nom = '';
  String adresse = '';
  String ville = '';
  String tel = '';
  String description = '';
  String specialites = '';
  String horaires = '';
  double? latitude;
  double? longitude;

  // --- MULTI PHOTOS ---
  final List<XFile> _pickedImages = [];        // nouvelles images non encore uploadées
  final List<String> _existingImageUrls = [];  // images déjà en base (édition)

  bool _isUploading = false;
  final String _bucket = 'clinique-photos';

  @override
  void initState() {
    super.initState();
    final c = widget.clinique ?? {};
    nom = c['nom'] ?? '';
    adresse = c['adresse'] ?? '';
    ville = c['ville'] ?? '';
    tel = c['tel'] ?? '';
    description = c['description'] ?? '';
    specialites = c['specialites'] ?? '';
    horaires = c['horaires'] ?? '';
    latitude = c['latitude'] != null ? double.tryParse('${c['latitude']}') : null;
    longitude = c['longitude'] != null ? double.tryParse('${c['longitude']}') : null;

    if (c['images'] is List) {
      for (final it in (c['images'] as List)) {
        if (it is String && it.isNotEmpty) _existingImageUrls.add(it);
      }
    }
  }

  Future<void> _recupererPosition() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });

      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        adresse = [
          placemark.street,
          placemark.subLocality,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country
        ].where((e) => e != null && e.isNotEmpty).join(", ");
        ville = placemark.locality ?? ville;
        setState(() {});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Position récupérée. Placez-vous à l’intérieur de l’établissement.")),
        );
      }
    } catch (e) {
      debugPrint("Erreur géolocalisation : $e");
    }
  }

  // --- Sélection MULTI images ---
  Future<void> _choisirImagesMultiples() async {
    final picker = ImagePicker();
    final pickedList = await picker.pickMultiImage();
    if (pickedList.isNotEmpty) {
      setState(() {
        _pickedImages.addAll(pickedList);
      });
    }
  }

  // (Optionnel) Prendre une photo
  Future<void> _prendrePhoto() async {
    final picker = ImagePicker();
    final shot = await picker.pickImage(source: ImageSource.camera);
    if (shot != null) {
      setState(() => _pickedImages.add(shot));
    }
  }

  // Util: extraire le "path" Storage depuis une URL publique
  String? _storagePathFromPublicUrl(String url) {
    // Format public courant:
    // https://<project>.supabase.co/storage/v1/object/public/<bucket>/<path>
    final marker = '/storage/v1/object/public/$_bucket/';
    final idx = url.indexOf(marker);
    if (idx != -1) {
      return url.substring(idx + marker.length);
    }
    // fallback: essayer après "<bucket>/"
    final alt = '$_bucket/';
    final idx2 = url.indexOf(alt);
    if (idx2 != -1) {
      return url.substring(idx2 + alt.length);
    }
    return null; // introuvable
  }

  // Upload d'UNE image -> URL publique
  Future<String?> _uploadImage(XFile imageFile) async {
    try {
      final ext = imageFile.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'cliniques/$fileName';
      final bytes = await imageFile.readAsBytes();

      await Supabase.instance.client.storage
          .from(_bucket)
          .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));

      return Supabase.instance.client.storage.from(_bucket).getPublicUrl(path);
    } catch (e) {
      debugPrint("Erreur d'upload : $e");
      return null;
    }
  }

  Future<void> _supprimerImage(String imageUrl, {required bool isExisting}) async {
    try {
      // 1) supprimer du storage si on a une URL publique en base
      final storagePath = _storagePathFromPublicUrl(imageUrl);
      if (storagePath != null) {
        await Supabase.instance.client.storage.from(_bucket).remove([storagePath]);
      }

      // 2) MAJ UI & base si c'était une image existante
      if (isExisting && widget.clinique != null) {
        final updated = List<String>.from(_existingImageUrls)..remove(imageUrl);
        await Supabase.instance.client
            .from('cliniques')
            .update({'images': updated})
            .eq('id', widget.clinique!['id']);
        setState(() => _existingImageUrls.remove(imageUrl));
      }
    } catch (e) {
      debugPrint("Erreur suppression image : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de la suppression de l'image")),
        );
      }
    }
  }

  Future<void> _enregistrerClinique() async {
    if (!_formKey.currentState!.validate()) return;
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez définir la position géographique.")),
      );
      return;
    }

    setState(() => _isUploading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isUploading = false);
      return;
    }

    // 1) On part des images existantes (édition) – déjà nettoyées si suppressions
    final List<String> finalUrls = List<String>.from(_existingImageUrls);

    // 2) Upload des nouvelles images
    for (final x in _pickedImages) {
      final url = await _uploadImage(x);
      if (url != null) finalUrls.add(url);
    }

    final data = {
      'nom': nom,
      'adresse': adresse,
      'ville': ville,
      'tel': tel,
      'description': description,
      'specialites': specialites,
      'horaires': horaires,
      'latitude': latitude,
      'longitude': longitude,
      'images': finalUrls, // liste d’URLs (ARRAY/TEXT ou JSONB côté DB)
      'user_id': userId,
    };

    try {
      if (widget.clinique != null) {
        await Supabase.instance.client.from('cliniques').update(data).eq('id', widget.clinique!['id']);
      } else {
        await Supabase.instance.client.from('cliniques').insert(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Erreur enregistrement : $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur enregistrement.")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // Widget vignette pour une URL existante
  Widget _thumbFromUrl(String url) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(url, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: InkWell(
            onTap: () => _supprimerImage(url, isExisting: true),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  // Widget vignette pour un XFile local (pas encore uploadé)
  Widget _thumbFromXFile(XFile xf) {
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: kIsWeb
          ? Image.network(xf.path, fit: BoxFit.cover) // blob: URL côté Web
          : Image.file(File(xf.path), fit: BoxFit.cover),
    );

    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: 4,
          right: 4,
          child: InkWell(
            onTap: () {
              setState(() => _pickedImages.remove(xf)); // juste UI locale
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final enEdition = widget.clinique != null;

    // Première image pour l'avatar
    ImageProvider? firstImage;
    if (_pickedImages.isNotEmpty) {
      firstImage = kIsWeb
          ? NetworkImage(_pickedImages.first.path)
          : FileImage(File(_pickedImages.first.path)) as ImageProvider;
    } else if (_existingImageUrls.isNotEmpty) {
      firstImage = NetworkImage(_existingImageUrls.first);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(enEdition ? "Modifier la clinique" : "Inscription Clinique"),
        backgroundColor: Colors.purple,
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
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),

              if (latitude != null && longitude != null) ...[
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
                          const SnackBar(content: Text("Position modifiée manuellement")),
                        );
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
                            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Avatar (première image)
              CircleAvatar(
                radius: 50,
                backgroundImage: firstImage,
                child: firstImage == null ? const Icon(Icons.camera_alt, size: 30) : null,
              ),
              const SizedBox(height: 10),

              // Boutons d'ajout
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _choisirImagesMultiples,
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Ajouter des photos"),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _prendrePhoto,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text("Prendre une photo"),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Grille (existantes + nouvelles)
              if (_existingImageUrls.isNotEmpty || _pickedImages.isNotEmpty)
                GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    ..._existingImageUrls.map(_thumbFromUrl),
                    ..._pickedImages.map(_thumbFromXFile),
                  ],
                ),

              const SizedBox(height: 20),
              TextFormField(
                initialValue: nom,
                decoration: const InputDecoration(labelText: "Nom"),
                onChanged: (v) => nom = v,
                validator: (v) => v == null || v.isEmpty ? "Champ requis" : null,
              ),
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
                initialValue: tel,
                decoration: const InputDecoration(labelText: "Téléphone"),
                keyboardType: TextInputType.phone,
                onChanged: (v) => tel = v,
              ),
              TextFormField(
                initialValue: specialites,
                decoration: const InputDecoration(labelText: "Spécialités"),
                onChanged: (v) => specialites = v,
              ),
              TextFormField(
                initialValue: horaires,
                decoration: const InputDecoration(labelText: "Horaires d'ouverture"),
                onChanged: (v) => horaires = v,
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
                      onPressed: _enregistrerClinique,
                      icon: const Icon(Icons.save),
                      label: Text(enEdition ? "Mettre à jour" : "Enregistrer"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
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
}
