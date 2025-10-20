// lib/pages/inscription_resto_page.dart
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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

  // Prix moyen (GNF)
  final TextEditingController _prixCtrl = TextEditingController();
  int? prix;

  bool _gettingLocation = false;
  bool _loading = false;

  final List<XFile> _pickedImages = [];
  final List<String> _existingImageUrls = [];
  final List<String> _imagesToDelete = [];

  static const String _bucket = 'restaurant-photos';

  // Palette Restaurants
  static const Color kRestoPrimary = Color(0xFFE76F51);
  static const Color kRestoSecondary = Color(0xFFF4A261);
  static const Color kOnPrimary = Color(0xFFFFFFFF);

  Color get dark => const Color(0xFF263238);

  // ---- parseurs robustes (acceptent num ou String) ----
  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      final digits = s.replaceAll(RegExp(r'[^\d\-]'), '');
      return int.tryParse(digits);
    }
    return null;
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.replaceAll(',', '.').trim();
      return double.tryParse(s);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.restaurant != null) {
      final resto = widget.restaurant!;
      nom = (resto['nom'] ?? '').toString();
      ville = (resto['ville'] ?? '').toString();
      telephone = (resto['tel'] ?? '').toString();
      description = (resto['description'] ?? '').toString();
      specialites = (resto['specialites'] ?? '').toString();
      horaires = (resto['horaires'] ?? '').toString();
      latitude = _asDouble(resto['latitude']);
      longitude = _asDouble(resto['longitude']);
      adresse = (resto['adresse'] ?? '').toString();
      prix = _asInt(resto['prix']);
      if (prix != null) _prixCtrl.text = _formatGNF(prix!);

      final imgs = resto['images'];
      if (imgs is List) {
        _existingImageUrls.addAll(imgs.map((e) => e.toString()));
      } else if (imgs is String && imgs.trim().isNotEmpty) {
        _existingImageUrls.add(imgs);
      }
    }
  }

  @override
  void dispose() {
    _prixCtrl.dispose();
    super.dispose();
  }

  // ---------- Helpers prix ----------
  String _formatGNF(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final remaining = s.length - i - 1;
      buf.write(s[i]);
      if (remaining > 0 && remaining % 3 == 0) buf.write('\u202F');
    }
    return buf.toString();
  }

  int? _parseGNF(String input) {
    final digits = input.replaceAll(RegExp(r'[^\d\-]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  // ---------- Helpers filename / content-type ----------
  String _toAscii(String input) {
    const withD = 'ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖØòóôõöøÙÚÛÜùúûüÇçÑñŸÿŠšŽž';
    const noD   = 'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOOooooooUUUUuuuuCcNnYySsZz';
    final map = {for (int i = 0; i < withD.length; i++) withD[i]: noD[i]};
    final buf = StringBuffer();
    for (final ch in input.characters) {
      buf.write(map[ch] ?? ch);
    }
    return buf.toString();
  }

  String _slugify(String input) {
    final ascii = _toAscii(input)
        .replaceAll(RegExp(r"[^\w\.\- ]+"), " ")
        .replaceAll(RegExp(r"\s+"), "_")
        .replaceAll(RegExp(r"_+"), "_")
        .replaceAll(RegExp(r"^-+|_+$"), "");
    return ascii.toLowerCase();
  }

  String _safeFilename(String original) {
    final name = _slugify(original);
    final dot = name.lastIndexOf('.');
    final hasExt = dot > 0 && dot < name.length - 1;
    final ext = hasExt ? name.substring(dot).toLowerCase() : '.png';
    final base = hasExt ? name.substring(0, dot) : name;
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${ts}_$base$ext';
  }

  String _inferContentType(String filename) {
    final f = filename.toLowerCase();
    if (f.endsWith('.jpg') || f.endsWith('.jpeg')) return 'image/jpeg';
    if (f.endsWith('.png')) return 'image/png';
    if (f.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }

  // ---------- LOCALISATION ----------
  Future<void> _detectLocation() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Astuce : placez-vous à l’intérieur de l’établissement pour une position exacte.",
        ),
        duration: Duration(seconds: 2),
      ),
    );

    setState(() => _gettingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Service de localisation désactivé';
      }

      LocationPermission perm = await Geolocator.checkPermission();
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

      try {
        final placemarks = await placemarkFromCoordinates(latitude!, longitude!);
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          adresse = [
            pm.street,
            pm.subLocality,
            pm.locality,
            pm.administrativeArea,
            pm.country
          ].where((e) => (e != null && e.trim().isNotEmpty)).join(', ');
          ville = pm.locality ?? ville;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Position récupérée. Touchez la carte pour ajuster si besoin."),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur localisation : $e')),
      );
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  // ---------- IMAGES ----------
  Future<void> _pickImages() async {
    final res = await _picker.pickMultiImage(imageQuality: 75);
    if (res.isEmpty) return;
    setState(() => _pickedImages.addAll(res));
  }

  void _removeImage(int i) => setState(() => _pickedImages.removeAt(i));

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
          if (snap.connectionState != ConnectionState.done || snap.data == null) {
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
      final original = kIsWeb ? img.name : p.basename(img.path);
      final safeName = _safeFilename(original);
      final objectPath = 'users/$uid/$safeName';
      final contentType = _inferContentType(safeName);

      if (kIsWeb) {
        final bytes = await img.readAsBytes();
        await storage.uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: contentType),
        );
      } else {
        await storage.upload(
          objectPath,
          File(img.path),
          fileOptions: FileOptions(upsert: false, contentType: contentType),
        );
      }
      urls.add(storage.getPublicUrl(objectPath));
    }
    return urls;
  }

  Future<void> _deleteImagesFromStorage(List<String> urls) async {
    final storage = Supabase.instance.client.storage.from(_bucket);
    for (final url in urls) {
      try {
        final uri = Uri.parse(url);
        final seg = List<String>.from(uri.pathSegments);
        final idx = seg.indexOf(_bucket);
        if (idx == -1 || idx + 1 >= seg.length) continue;
        final objectPath = seg.sublist(idx + 1).join('/');
        await storage.remove([objectPath]);
      } catch (e) {
        debugPrint("Erreur suppression image : $e");
      }
    }
  }

  // ---------- ENREGISTREMENT ----------
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clique d’abord sur “Détecter ma position” pour localiser le restaurant.'),
        ),
      );
      return;
    }

    prix = _parseGNF(_prixCtrl.text);

    setState(() => _loading = true);
    _formKey.currentState!.save();

    try {
      final supa = Supabase.instance.client;
      final uid = supa.auth.currentUser?.id;
      if (uid == null) throw 'Utilisateur non connecté';

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
        'prix': prix, // int ou null
        'images': [..._existingImageUrls, ...newImageUrls],
        'user_id': uid,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.restaurant != null) {
        await supa.from('restaurants').update(data).eq('id', widget.restaurant!['id']);
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text("Succès"),
            content: Text("Restaurant mis à jour avec succès."),
          ),
        );
      } else {
        await supa.from('restaurants').insert({
          ...data,
          'created_at': DateTime.now().toIso8601String(),
        });
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text("Succès"),
            content: Text("Restaurant enregistré avec succès."),
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        title: const Text('Inscription Restaurant'),
        backgroundColor: kRestoPrimary,
        foregroundColor: kOnPrimary,
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
                      "Placez-vous dans votre établissement pour enregistrer sa position exacte.",
                      style: TextStyle(color: Colors.blueGrey, fontSize: 13.5),
                    ),
                    const SizedBox(height: 9),

                    ElevatedButton.icon(
                      onPressed: _gettingLocation ? null : _detectLocation,
                      icon: const Icon(Icons.location_on),
                      label: Text(_gettingLocation ? 'Recherche en cours…' : 'Détecter ma position'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kRestoPrimary,
                        foregroundColor: kOnPrimary,
                      ),
                    ),

                    if (latitude != null && longitude != null) ...[
                      const SizedBox(height: 8),
                      Text("Latitude : $latitude", style: TextStyle(color: dark)),
                      Text("Longitude : $longitude", style: TextStyle(color: dark)),
                      if (adresse.isNotEmpty)
                        Text("Adresse : $adresse", style: TextStyle(color: dark)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 220,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(latitude!, longitude!),
                            initialZoom: 16,
                            onTap: (tapPos, point) {
                              setState(() {
                                latitude = point.latitude;
                                longitude = point.longitude;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Position modifiée manuellement."),
                                  duration: Duration(milliseconds: 900),
                                ),
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
                                  point: LatLng(latitude!, longitude!),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
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

                    // PRIX MOYEN (GNF)
                    TextFormField(
                      controller: _prixCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Prix moyen (GNF)',
                        helperText: 'Exemple : 80000',
                      ),
                      onChanged: (v) {
                        final val = _parseGNF(v);
                        if (val != null) {
                          final ss = _formatGNF(val);
                          if (_prixCtrl.text != ss) {
                            _prixCtrl.value = TextEditingValue(
                              text: ss,
                              selection: TextSelection.collapsed(offset: ss.length),
                            );
                          }
                        }
                      },
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
                                child: Image.network(
                                  _existingImageUrls[i],
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
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
                            child: const Icon(Icons.add_a_photo, size: 30, color: kRestoPrimary),
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
                        backgroundColor: kRestoPrimary,
                        foregroundColor: kOnPrimary,
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
