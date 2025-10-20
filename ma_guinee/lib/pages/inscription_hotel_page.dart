import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class InscriptionHotelPage extends StatefulWidget {
  final Map<String, dynamic>? hotel;

  const InscriptionHotelPage({super.key, this.hotel});

  @override
  State<InscriptionHotelPage> createState() => _InscriptionHotelPageState();
}

class _InscriptionHotelPageState extends State<InscriptionHotelPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // ===== Palette Hôtels (spécifique à cette page) =====
  static const Color hotelsPrimary   = Color(0xFF264653);
  static const Color hotelsSecondary = Color(0xFF2A9D8F);
  static const Color onPrimary       = Colors.white;

  String nom = '';
  String adresse = '';
  String ville = '';
  String telephone = '';
  String description = '';
  String prix = '';
  int etoiles = 1;
  double? latitude;
  double? longitude;

  bool _gettingLocation = false;
  bool _loading = false;

  final List<XFile> _pickedImages = [];
  static const String _bucket = 'hotel-photos';

  @override
  void initState() {
    super.initState();
    final h = widget.hotel;
    if (h != null) {
      nom = (h['nom'] ?? '').toString();
      adresse = (h['adresse'] ?? '').toString();
      ville = (h['ville'] ?? '').toString();
      telephone = (h['telephone'] ?? '').toString();
      description = (h['description'] ?? '').toString();
      prix = (h['prix'] ?? '').toString();
      etoiles = (h['etoiles'] as int?) ?? 1;
      latitude = (h['latitude'] as num?)?.toDouble();
      longitude = (h['longitude'] as num?)?.toDouble();
    }
  }

  // -------------------- Localisation --------------------
  Future<void> _detectLocation() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Astuce : placez-vous à l’intérieur de l’hôtel pour enregistrer sa position exacte.",
        ),
        duration: Duration(seconds: 2),
      ),
    );

    setState(() => _gettingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Service de localisation désactivé';
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'Permission refusée';
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      latitude = pos.latitude;
      longitude = pos.longitude;

      // Geocoding : adresse + ville
      try {
        final placemarks =
            await placemarkFromCoordinates(latitude!, longitude!);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          adresse = [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
            p.country
          ].where((e) => (e != null && e!.trim().isNotEmpty)).join(', ');
          ville = p.locality ?? ville;
        }
      } catch (_) {}

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Position récupérée. Touchez la carte pour ajuster si besoin."),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur localisation : $e')),
      );
    } finally {
      setState(() => _gettingLocation = false);
    }
  }

  // -------------------- Images --------------------
  Future<void> _pickImages() async {
    final res = await _picker.pickMultiImage(imageQuality: 80);
    if (res.isEmpty) return;
    setState(() => _pickedImages.addAll(res));
  }

  void _removeImage(int i) => setState(() => _pickedImages.removeAt(i));

  Widget _imagePreview(XFile f) {
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
            child: Image.memory(snap.data!,
                width: 70, height: 70, fit: BoxFit.cover),
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
    final storage = Supabase.instance.client.storage.from(_bucket);
    final urls = <String>[];

    for (final img in _pickedImages) {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(img.path).replaceAll(' ', '_')}';
      final objectPath = '$uid/$fileName';

      if (kIsWeb) {
        final bytes = await img.readAsBytes();
        await storage.uploadBinary(objectPath, bytes,
            fileOptions: const FileOptions(upsert: true));
      } else {
        await storage.upload(objectPath, File(img.path),
            fileOptions: const FileOptions(upsert: true));
      }
      urls.add(storage.getPublicUrl(objectPath));
    }
    return urls;
  }

  // -------------------- Enregistrement --------------------
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Cliquez sur "Détecter ma position" ou choisissez manuellement sur la carte.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    _formKey.currentState!.save();

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) throw 'Utilisateur non connecté';

      final urls = await _uploadImages(uid);

      final data = {
        'user_id': uid,
        'nom': nom,
        'adresse': adresse,
        'ville': ville,
        'telephone': telephone,
        'description': description,
        'prix': prix,
        'etoiles': etoiles,
        'latitude': latitude,
        'longitude': longitude,
        'images': urls,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.hotel == null) {
        data['created_at'] = DateTime.now().toIso8601String();
        await Supabase.instance.client.from('hotels').insert(data);

        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Succès"),
              content: const Text("Hôtel enregistré avec succès."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("OK")),
              ],
            ),
          );
        }
      } else {
        final id = widget.hotel!['id'];
        await Supabase.instance.client.from('hotels').update(data).eq('id', id);

        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Succès"),
              content: const Text("Hôtel mis à jour avec succès."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("OK")),
              ],
            ),
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        title:
            Text(widget.hotel == null ? 'Inscription Hôtel' : 'Modifier Hôtel'),
        backgroundColor: Colors.white,
        foregroundColor: hotelsPrimary,
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
                    const Text(
                      "Placez-vous dans l’hôtel pour enregistrer sa position exacte.",
                      style: TextStyle(color: Colors.blueGrey, fontSize: 13.5),
                    ),
                    const SizedBox(height: 9),
                    ElevatedButton.icon(
                      onPressed: _gettingLocation ? null : _detectLocation,
                      icon: const Icon(Icons.location_on),
                      label: Text(
                          _gettingLocation ? 'Recherche en cours…' : 'Détecter ma position'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hotelsPrimary,
                        foregroundColor: onPrimary,
                      ),
                    ),
                    if (latitude != null && longitude != null) ...[
                      const SizedBox(height: 6),
                      Text('Latitude : $latitude'),
                      Text('Longitude : $longitude'),
                      if (adresse.isNotEmpty) Text('Adresse : $adresse'),
                      const SizedBox(height: 12),
                      const Text("Position sur la carte :",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 220,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(latitude!, longitude!),
                            initialZoom: 16.0,
                            onTap: (tapPosition, point) {
                              setState(() {
                                latitude = point.latitude;
                                longitude = point.longitude;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Position ajustée manuellement."),
                                  duration: Duration(milliseconds: 900),
                                ),
                              );
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                              subdomains: const ['a', 'b', 'c'],
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  width: 40.0,
                                  height: 40.0,
                                  point: LatLng(latitude!, longitude!),
                                  child: const Icon(Icons.location_on,
                                      color: Colors.red, size: 40),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      initialValue: nom,
                      decoration:
                          const InputDecoration(labelText: "Nom de l'hôtel"),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Champ requis' : null,
                      onSaved: (v) => nom = v ?? '',
                    ),
                    TextFormField(
                      initialValue: adresse,
                      decoration: const InputDecoration(labelText: 'Adresse'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Champ requis' : null,
                      onSaved: (v) => adresse = v ?? '',
                    ),
                    TextFormField(
                      initialValue: ville,
                      decoration: const InputDecoration(labelText: 'Ville'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Champ requis' : null,
                      onSaved: (v) => ville = v ?? '',
                    ),
                    TextFormField(
                      initialValue: telephone,
                      decoration:
                          const InputDecoration(labelText: 'Téléphone'),
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Champ requis' : null,
                      onSaved: (v) => telephone = v ?? '',
                    ),
                    TextFormField(
                      initialValue: description,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                      onSaved: (v) => description = v ?? '',
                    ),
                    TextFormField(
                      initialValue: prix,
                      decoration: const InputDecoration(
                          labelText: 'Prix moyen (ex: 500 000 GNF)'),
                      onSaved: (v) => prix = v ?? '',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text("Nombre d’étoiles :"),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: etoiles,
                          onChanged: (v) => setState(() => etoiles = v!),
                          items: [1, 2, 3, 4, 5]
                              .map((e) => DropdownMenuItem(
                                  value: e, child: Text('$e ★')))
                              .toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text('Photos de l’hôtel :',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
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
                            child: const Icon(Icons.add_a_photo, size: 30),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: Text(
                          widget.hotel == null ? 'Enregistrer' : 'Mettre à jour'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hotelsPrimary,
                        foregroundColor: onPrimary,
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
