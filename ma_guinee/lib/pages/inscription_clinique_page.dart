import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class InscriptionCliniquePage extends StatefulWidget {
  const InscriptionCliniquePage({super.key});

  @override
  State<InscriptionCliniquePage> createState() => _InscriptionCliniquePageState();
}

class _InscriptionCliniquePageState extends State<InscriptionCliniquePage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  String nom = '';
  String ville = '';
  String telephone = '';
  String whatsapp = '';
  String description = '';
  double? latitude;
  double? longitude;
  String adresse = '';

  bool _gettingLocation = false;
  bool _saving = false;

  final List<XFile> _images = [];

  // ------------------ GEO ------------------
  Future<void> _detectLocation() async {
    setState(() => _gettingLocation = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) throw 'Permission refusée';
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      latitude = pos.latitude;
      longitude = pos.longitude;

      final placemarks = await placemarkFromCoordinates(latitude!, longitude!);
      final place = placemarks.first;
      adresse = "${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}";
      ville = ville.isEmpty ? (place.locality ?? '') : ville;
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur localisation : $e')),
      );
    } finally {
      setState(() => _gettingLocation = false);
    }
  }

  // ------------------ IMAGES ------------------
  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;
    setState(() => _images.addAll(picked));
  }

  void _removeImage(int i) => setState(() => _images.removeAt(i));

  Widget _thumb(XFile f) {
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: f.readAsBytes(),
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
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(File(f.path), width: 70, height: 70, fit: BoxFit.cover),
    );
  }

  Future<List<String>> _uploadImages(String uid) async {
    final storage = Supabase.instance.client.storage.from('clinique-photos');
    final urls = <String>[];

    for (final f in _images) {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(f.path).replaceAll(' ', '_')}';
      final objectPath = '$uid/$fileName';

      if (kIsWeb) {
        final bytes = await f.readAsBytes();
        await storage.uploadBinary(objectPath, bytes,
            fileOptions: const FileOptions(upsert: true));
      } else {
        await storage.upload(objectPath, File(f.path),
            fileOptions: const FileOptions(upsert: true));
      }
      urls.add(storage.getPublicUrl(objectPath));
    }
    return urls;
  }

  // ------------------ SAVE ------------------
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci de détecter votre position.')),
      );
      return;
    }
    setState(() => _saving = true);
    _formKey.currentState!.save();

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) throw 'Utilisateur non connecté';

      final imageUrls = await _uploadImages(uid);

      final data = {
        'user_id': uid,
        'nom': nom,
        'ville': ville,
        'tel': telephone,
        'whatsapp': whatsapp,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'adresse': adresse,
        'images': imageUrls,
        'created_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client.from('cliniques').insert(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clinique enregistrée avec succès !')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ------------------ UI ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inscription Clinique')),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _gettingLocation ? null : _detectLocation,
                      icon: const Icon(Icons.location_on),
                      label: Text(_gettingLocation ? 'Recherche…' : 'Détecter ma position'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (latitude != null && longitude != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Latitude : $latitude'),
                            Text('Longitude : $longitude'),
                            Text('Adresse : $adresse'),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Nom de la clinique'),
                      validator: (v) => v!.isEmpty ? 'Champ requis' : null,
                      onSaved: (v) => nom = v!.trim(),
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Ville'),
                      validator: (v) => v!.isEmpty ? 'Champ requis' : null,
                      initialValue: ville.isEmpty ? null : ville,
                      onSaved: (v) => ville = v!.trim(),
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Téléphone'),
                      keyboardType: TextInputType.phone,
                      validator: (v) => v!.isEmpty ? 'Champ requis' : null,
                      onSaved: (v) => telephone = v!.trim(),
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'WhatsApp'),
                      keyboardType: TextInputType.phone,
                      onSaved: (v) => whatsapp = (v ?? '').trim(),
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                      onSaved: (v) => description = (v ?? '').trim(),
                    ),
                    const SizedBox(height: 18),
                    const Text('Photos de la clinique :',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (int i = 0; i < _images.length; i++)
                          Stack(
                            children: [
                              _thumb(_images[i]),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removeImage(i),
                                  child: const CircleAvatar(
                                    radius: 11,
                                    backgroundColor: Colors.red,
                                    child: Icon(Icons.close,
                                        size: 14, color: Colors.white),
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
                            child: const Icon(Icons.add_a_photo,
                                size: 30, color: Colors.orange),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
