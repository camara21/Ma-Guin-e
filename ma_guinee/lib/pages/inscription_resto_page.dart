import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class InscriptionRestoPage extends StatefulWidget {
  final Map<String, dynamic>? restaurant;

  const InscriptionRestoPage({super.key, this.restaurant});

  @override
  State<InscriptionRestoPage> createState() => _InscriptionRestoPageState();
}

class _InscriptionRestoPageState extends State<InscriptionRestoPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  String nom = '';
  String ville = '';
  String telephone = '';
  String description = '';
  String specialites = '';
  String horaires = '';
  double? latitude;
  double? longitude;
  String adresse = '';
  bool _gettingLocation = false;
  bool _loading = false;

  final List<XFile> _pickedImages = [];
  final List<String> _existingImageUrls = [];
  final List<String> _imagesToDelete = [];

  static const String _bucket = 'restaurant-photos';

  @override
  void initState() {
    super.initState();
    if (widget.restaurant != null) {
      final resto = widget.restaurant!;
      nom = resto['nom'] ?? '';
      ville = resto['ville'] ?? '';
      telephone = resto['tel'] ?? '';
      description = resto['description'] ?? '';
      specialites = resto['specialites'] ?? '';
      horaires = resto['horaires'] ?? '';
      latitude = resto['latitude'];
      longitude = resto['longitude'];
      adresse = resto['adresse'] ?? '';
      if (resto['images'] is List) {
        _existingImageUrls.addAll(List<String>.from(resto['images']));
      }
    }
  }

  Future<void> _detectLocation() async {
    setState(() => _gettingLocation = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) throw 'Permission refusée';
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      latitude = pos.latitude;
      longitude = pos.longitude;
      final placemarks = await placemarkFromCoordinates(latitude!, longitude!);
      final place = placemarks.first;
      adresse = "${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}";
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur localisation : $e')));
    } finally {
      setState(() => _gettingLocation = false);
    }
  }

  Future<void> _pickImages() async {
    final res = await _picker.pickMultiImage(imageQuality: 75);
    if (res.isEmpty) return;
    setState(() => _pickedImages.addAll(res));
  }

  void _removeImage(int i) {
    setState(() => _pickedImages.removeAt(i));
  }

  void _removeExistingImage(int i) {
    final removed = _existingImageUrls.removeAt(i);
    _imagesToDelete.add(removed);
    setState(() {});
  }

  Widget _imagePreview(XFile file) {
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: file.readAsBytes(),
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(
              width: 70,
              height: 70,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(snap.data!, width: 70, height: 70, fit: BoxFit.cover),
          );
        },
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(file.path), width: 70, height: 70, fit: BoxFit.cover),
      );
    }
  }

  Future<List<String>> _uploadImages(String uid) async {
    final storage = Supabase.instance.client.storage.from(_bucket);
    final List<String> urls = [];
    for (final img in _pickedImages) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(img.path).replaceAll(' ', '_')}';
      final objectPath = '$uid/$fileName';
      if (kIsWeb) {
        final bytes = await img.readAsBytes();
        await storage.uploadBinary(objectPath, bytes, fileOptions: const FileOptions(upsert: true));
      } else {
        await storage.upload(objectPath, File(img.path), fileOptions: const FileOptions(upsert: true));
      }
      urls.add(storage.getPublicUrl(objectPath));
    }
    return urls;
  }

  Future<void> _deleteImagesFromStorage(List<String> urls) async {
    final storage = Supabase.instance.client.storage.from(_bucket);
    for (final url in urls) {
      final uri = Uri.parse(url);
      final path = uri.pathSegments.skipWhile((v) => v != _bucket).skip(1).join('/');
      try {
        await storage.remove([path]);
      } catch (e) {
        debugPrint("Erreur suppression image : $e");
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clique sur "Détecter ma position" d\'abord.')));
      return;
    }

    setState(() => _loading = true);
    _formKey.currentState!.save();

    try {
      final supa = Supabase.instance.client;
      final uid = supa.auth.currentUser?.id;
      if (uid == null) throw 'Utilisateur non connecté';

      // Supprimer images retirées du formulaire
      if (_imagesToDelete.isNotEmpty) {
        await _deleteImagesFromStorage(_imagesToDelete);
      }

      final newImageUrls = await _uploadImages(uid);

      final data = {
        'nom': nom,
        'ville': ville,
        'tel': telephone,
        'description': description,
        'specialites': specialites,
        'horaires': horaires,
        'latitude': latitude,
        'longitude': longitude,
        'adresse': adresse,
        'images': [..._existingImageUrls, ...newImageUrls],
        'user_id': uid,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.restaurant != null) {
        await supa.from('restaurants').update(data).eq('id', widget.restaurant!['id']);
      } else {
        data['created_at'] = DateTime.now().toIso8601String();
        await supa.from('restaurants').insert(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enregistré avec succès.')));
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        title: const Text('Inscription Restaurant'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.orange,
        elevation: 1,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Text("Placez-vous dans votre établissement pour enregistrer sa position exacte.",
                        style: TextStyle(color: Colors.blueGrey, fontSize: 13.5)),
                    const SizedBox(height: 9),
                    ElevatedButton.icon(
                      onPressed: _gettingLocation ? null : _detectLocation,
                      icon: const Icon(Icons.location_on),
                      label: Text(_gettingLocation ? 'Recherche en cours…' : 'Détecter ma position'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (latitude != null && longitude != null) ...[
                      const SizedBox(height: 6),
                      Text("Latitude : $latitude"),
                      Text("Longitude : $longitude"),
                      Text("Adresse : $adresse"),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: nom,
                      decoration: const InputDecoration(labelText: 'Nom du restaurant'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
                      onSaved: (v) => nom = v ?? '',
                    ),
                    TextFormField(
                      initialValue: ville,
                      decoration: const InputDecoration(labelText: 'Ville'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
                      onSaved: (v) => ville = v ?? '',
                    ),
                    TextFormField(
                      initialValue: telephone,
                      decoration: const InputDecoration(labelText: 'Téléphone'),
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
                      onSaved: (v) => telephone = v ?? '',
                    ),
                    TextFormField(
                      initialValue: description,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                      onSaved: (v) => description = v ?? '',
                    ),
                    TextFormField(
                      initialValue: specialites,
                      decoration: const InputDecoration(labelText: 'Spécialités'),
                      onSaved: (v) => specialites = v ?? '',
                    ),
                    TextFormField(
                      initialValue: horaires,
                      decoration: const InputDecoration(labelText: 'Horaires d’ouverture'),
                      onSaved: (v) => horaires = v ?? '',
                    ),
                    const SizedBox(height: 20),
                    const Text('Photos du restaurant', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (int i = 0; i < _existingImageUrls.length; i++)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(_existingImageUrls[i],
                                    width: 70, height: 70, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removeExistingImage(i),
                                  child: const CircleAvatar(
                                    radius: 11,
                                    backgroundColor: Colors.red,
                                    child: Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        for (int i = 0; i < _pickedImages.length; i++)
                          Stack(
                            children: [
                              _imagePreview(_pickedImages[i]),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removeImage(i),
                                  child: const CircleAvatar(
                                    radius: 11,
                                    backgroundColor: Colors.red,
                                    child: Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        InkWell(
                          onTap: _pickImages,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Icon(Icons.add_a_photo, size: 30, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('Enregistrer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
