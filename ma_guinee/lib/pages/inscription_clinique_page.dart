// lib/pages/inscription_clinique_page.dart
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Palette Santé (VERT + JAUNE)
const kHealthGreen = Color(0xFF009460);
const kHealthYellow = Color(0xFFFCD116);

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

  final List<XFile> _pickedImages = [];
  final List<String> _existingImageUrls = [];

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

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
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
        ].where((e) => e != null && e!.isNotEmpty).join(", ");
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

  Future<void> _choisirImagesMultiples() async {
    final picker = ImagePicker();
    final pickedList = await picker.pickMultiImage(imageQuality: 80);
    if (pickedList.isNotEmpty) {
      setState(() {
        _pickedImages.addAll(pickedList);
      });
    }
  }

  Future<void> _prendrePhoto() async {
    final picker = ImagePicker();
    final shot = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (shot != null) {
      setState(() => _pickedImages.add(shot));
    }
  }

  String? _storagePathFromPublicUrl(String url) {
    final marker = '/storage/v1/object/public/$_bucket/';
    final idx = url.indexOf(marker);
    if (idx != -1) {
      return url.substring(idx + marker.length);
    }
    final alt = '$_bucket/';
    final idx2 = url.indexOf(alt);
    if (idx2 != -1) {
      return url.substring(idx2 + alt.length);
    }
    return null;
  }

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
      final storagePath = _storagePathFromPublicUrl(imageUrl);
      if (storagePath != null) {
        await Supabase.instance.client.storage.from(_bucket).remove([storagePath]);
      }

      if (isExisting && widget.clinique != null) {
        final updated = List<String>.from(_existingImageUrls)..remove(imageUrl);
        await Supabase.instance.client.from('cliniques').update({'images': updated}).eq('id', widget.clinique!['id']);
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

  Future<bool> _dejaUnEtablissement(String userId) async {
    try {
      final rows = await Supabase.instance.client
          .from('cliniques')
          .select('id')
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .limit(1);
      return rows is List && rows.isNotEmpty;
    } catch (_) {
      return false;
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
      setState(() => _isUploading = false);
      return;
    }

    if (widget.clinique == null && await _dejaUnEtablissement(userId)) {
      if (mounted) {
        setState(() => _isUploading = false);
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Création impossible"),
            content: const Text(
              "Vous avez déjà un établissement de santé enregistré avec ce compte.\n\n"
              "Si vous gérez plusieurs établissements, merci de contacter le support "
              "depuis l’onglet « Profil » → « Support » afin que nous activions la multi-gestion.",
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
            ],
          ),
        );
      }
      return;
    }

    final List<String> finalUrls = List<String>.from(_existingImageUrls);
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
      'images': finalUrls,
      'photo_url': finalUrls.isNotEmpty ? finalUrls.first : null,
      'user_id': userId,
    };

    try {
      Map<String, dynamic> row;

      if (widget.clinique != null) {
        row = await Supabase.instance.client.from('cliniques').update(data).eq('id', widget.clinique!['id']).select().single();
      } else {
        row = await Supabase.instance.client.from('cliniques').insert(data).select().single();
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Succès"),
          content: Text(widget.clinique != null ? "Clinique mise à jour avec succès." : "Clinique enregistrée avec succès."),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
        ),
      );

      Navigator.pop(context, row);
    } catch (e) {
      debugPrint("Erreur enregistrement : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur enregistrement.")));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

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
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumbFromXFile(XFile xf) {
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: kIsWeb ? Image.network(xf.path, fit: BoxFit.cover) : Image.file(File(xf.path), fit: BoxFit.cover),
    );

    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: 4,
          right: 4,
          child: InkWell(
            onTap: () {
              setState(() => _pickedImages.remove(xf));
            },
            child: Container(
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
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

    ImageProvider? firstImage;
    if (_pickedImages.isNotEmpty) {
      firstImage = kIsWeb ? NetworkImage(_pickedImages.first.path) : FileImage(File(_pickedImages.first.path)) as ImageProvider;
    } else if (_existingImageUrls.isNotEmpty) {
      firstImage = NetworkImage(_existingImageUrls.first);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(enEdition ? "Modifier la clinique" : "Inscription Clinique"),
        backgroundColor: kHealthGreen,
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
                style: ElevatedButton.styleFrom(backgroundColor: kHealthGreen, foregroundColor: Colors.white),
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
                      // ✅ API v6+ (v8) : initialCenter / initialZoom
                      initialCenter: LatLng(latitude!, longitude!),
                      initialZoom: 16,
                      // ✅ onTap reste disponible (TapCallback: (tapPos, LatLng))
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
                        userAgentPackageName: 'com.ma_guinee.app',
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
              CircleAvatar(
                radius: 50,
                backgroundColor: kHealthYellow.withOpacity(.25),
                backgroundImage: firstImage,
                child: firstImage == null ? const Icon(Icons.camera_alt, size: 30, color: kHealthGreen) : null,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _choisirImagesMultiples,
                    icon: const Icon(Icons.photo_library, color: kHealthGreen),
                    label: const Text("Ajouter des photos", style: TextStyle(color: kHealthGreen)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: kHealthGreen)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _prendrePhoto,
                    icon: const Icon(Icons.photo_camera, color: kHealthGreen),
                    label: const Text("Prendre une photo", style: TextStyle(color: kHealthGreen)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: kHealthGreen)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                        backgroundColor: kHealthGreen,
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
