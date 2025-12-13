// lib/pages/edit_resto_page.dart
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

// ✅ Compression (même module que tes annonces)
import 'package:ma_guinee/utils/image_compressor/image_compressor.dart';

/// Palette Restaurants
const Color restoPrimary = Color(0xFFE76F51);
const Color restoSecondary = Color(0xFFF4A261);
const Color restoOnPrimary = Color(0xFFFFFFFF);

class EditRestoPage extends StatefulWidget {
  final Map<String, dynamic> resto;
  const EditRestoPage({super.key, required this.resto});

  @override
  State<EditRestoPage> createState() => _EditRestoPageState();
}

class _EditRestoPageState extends State<EditRestoPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late TextEditingController nomController;
  late TextEditingController villeController;
  late TextEditingController telController;
  late TextEditingController descriptionController;

  // Champs additionnels
  final TextEditingController _prixCtrl = TextEditingController();
  int? prix; // parsé localement
  int? etoiles; // parsé localement

  double? latitude;
  double? longitude;
  String adresse = '';

  bool _gettingLocation = false;
  bool _loading = false;

  // Images
  final List<XFile> _pickedImages = [];
  List<String> _existingImageUrls = [];
  final List<String> _imagesToDelete = [];

  static const String _bucket = 'restaurant-photos';

  // ---------- Helpers: parse robustes ----------
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
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  String _formatGNF(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final remaining = s.length - i - 1;
      buf.write(s[i]);
      if (remaining > 0 && remaining % 3 == 0)
        buf.write('\u202F'); // espace fine
    }
    return buf.toString();
  }

  int? _parseGNF(String input) {
    final digits = input.replaceAll(RegExp(r'[^\d\-]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  // ---------- Helpers: filename safe ----------
  String _toAscii(String input) {
    const withD = 'ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖØòóôõöøÙÚÛÜùúûüÇçÑñŸÿŠšŽž';
    const noD = 'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOOooooooUUUUuuuuCcNnYySsZz';
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

  String _safeFilenameFor(String original, String extNoDot) {
    final baseName = kIsWeb ? original : p.basename(original);
    final name = _slugify(baseName);
    final dot = name.lastIndexOf('.');
    final base = (dot > 0) ? name.substring(0, dot) : name;

    final ts = DateTime.now().microsecondsSinceEpoch;
    final ext = extNoDot.replaceAll('.', '').toLowerCase();
    return '${ts}_$base.$ext';
  }

  // ---------- Payload unique (même que l’inscription) ----------
  Map<String, dynamic> _buildPayload({
    required String uid,
    required List<String> images,
  }) {
    // Prix: si ta colonne est TEXT -> on envoie une chaîne "50000" (ou null)
    final prixStr = _prixCtrl.text.trim().isEmpty
        ? null
        : _parseGNF(_prixCtrl.text)?.toString();

    return {
      'nom': nomController.text.trim(),
      'ville': villeController.text.trim(),
      'tel': telController.text.trim(), // colonne existante
      'telephone': telController.text.trim(), // si les 2 coexistent
      'description': descriptionController.text.trim(),
      'specialites': widget.resto['specialites'] ?? '',
      'horaires': widget.resto['horaires'] ?? '',
      'latitude': latitude,
      'longitude': longitude,
      'adresse': adresse,
      'prix': prixStr, // TEXT (ou int si colonne int, adapte si besoin)
      'etoiles': etoiles, // INT
      'images': images, // text[]
      'user_id': uid, // identique à l’inscription
    };
  }

  @override
  void initState() {
    super.initState();

    nomController = TextEditingController(text: widget.resto['nom'] ?? '');
    villeController = TextEditingController(text: widget.resto['ville'] ?? '');
    telController = TextEditingController(
      text: (widget.resto['tel'] ?? widget.resto['telephone'] ?? '').toString(),
    );
    descriptionController =
        TextEditingController(text: widget.resto['description'] ?? '');

    latitude = _asDouble(widget.resto['latitude']);
    longitude = _asDouble(widget.resto['longitude']);
    adresse = (widget.resto['adresse'] ?? '').toString();

    prix = _asInt(widget.resto['prix']);
    etoiles = _asInt(widget.resto['etoiles']);
    if (prix != null) _prixCtrl.text = _formatGNF(prix!);

    final imgs = widget.resto['images'];
    if (imgs is List) {
      _existingImageUrls = imgs.map((e) => e.toString()).toList();
    } else if (imgs is String && imgs.trim().isNotEmpty) {
      _existingImageUrls = [imgs];
    }
  }

  @override
  void dispose() {
    nomController.dispose();
    villeController.dispose();
    telController.dispose();
    descriptionController.dispose();
    _prixCtrl.dispose();
    super.dispose();
  }

  // ---------- Localisation ----------
  Future<void> _detectLocation() async {
    setState(() => _gettingLocation = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission de localisation refusée.')),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      latitude = pos.latitude;
      longitude = pos.longitude;

      try {
        final places = await placemarkFromCoordinates(latitude!, longitude!);
        if (places.isNotEmpty) {
          final p = places.first;
          adresse = [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
            p.country
          ].where((e) => (e != null && e.trim().isNotEmpty)).join(', ');
        }
      } catch (_) {}

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Position détectée avec succès !")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la localisation : $e')),
      );
    } finally {
      setState(() => _gettingLocation = false);
    }
  }

  // ---------- Images ----------
  Future<void> _pickImages() async {
    // imageQuality ici ne suffit pas (différences devices), on compresse à l’upload.
    final res = await _picker.pickMultiImage(imageQuality: 100);
    if (res.isNotEmpty) setState(() => _pickedImages.addAll(res));
  }

  void _removeExistingImage(int i) {
    final removed = _existingImageUrls.removeAt(i);
    _imagesToDelete.add(removed); // ✅ sera supprimée du storage au Save
    setState(() {});
  }

  void _removePicked(int i) => setState(() => _pickedImages.removeAt(i));

  Widget _previewPicked(XFile file) {
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: file.readAsBytes(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const SizedBox(
              width: 70,
              height: 70,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              snap.data!,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
            ),
          );
        },
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(file.path),
        width: 70,
        height: 70,
        fit: BoxFit.cover,
      ),
    );
  }

  // ✅ extraction robuste objectPath depuis URL publique
  String? _storagePathFromPublicUrl(String url) {
    try {
      if (url.trim().isEmpty) return null;

      final marker = '/storage/v1/object/public/$_bucket/';
      final i = url.indexOf(marker);
      if (i != -1) {
        final pth = Uri.decodeComponent(url.substring(i + marker.length));
        if (pth.trim().isEmpty) return null;
        if (pth.trim() == _bucket) return null;
        if (pth.endsWith('/')) return null;
        return pth;
      }

      final uri = Uri.parse(url);
      final seg = uri.pathSegments;
      final idx = seg.indexOf(_bucket);
      if (idx == -1 || idx + 1 >= seg.length) return null;

      final pth = Uri.decodeComponent(seg.sublist(idx + 1).join('/'));
      if (pth.trim().isEmpty) return null;
      if (pth.trim() == _bucket) return null;
      if (pth.endsWith('/')) return null;
      return pth;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteImagesFromStorage(List<String> urls) async {
    final storage = Supabase.instance.client.storage.from(_bucket);
    for (final url in urls) {
      final objectPath = _storagePathFromPublicUrl(url);
      if (objectPath == null) continue;
      try {
        await storage.remove([objectPath]);
      } catch (_) {
        // ignore : policy, déjà supprimé, etc.
      }
    }
  }

  Future<List<String>> _uploadImages(String uid) async {
    final storage = Supabase.instance.client.storage.from(_bucket);
    final List<String> urls = [];

    for (final img in _pickedImages) {
      final original = kIsWeb ? img.name : p.basename(img.path);

      // 1) lire bytes
      final rawBytes = await img.readAsBytes();

      // 2) ✅ compression prod (cohérent avec annonces)
      final c = await ImageCompressor.compressBytes(
        rawBytes,
        maxSide: 1600,
        quality: 82,
        maxBytes: 900 * 1024,
        keepPngIfTransparent: true,
      );

      // 3) nom/chemin safe (ext = extension réelle post-compression)
      final safeName = _safeFilenameFor(original, c.extension);
      final objectPath = 'users/$uid/$safeName';

      // 4) upload binaire avec contentType
      await storage.uploadBinary(
        objectPath,
        c.bytes,
        fileOptions: FileOptions(
          upsert: false,
          contentType: c.contentType,
        ),
      );

      urls.add(storage.getPublicUrl(objectPath));
    }

    return urls;
  }

  // ---------- SAVE (UPDATE) ----------
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clique d’abord sur “Détecter ma position”.'),
        ),
      );
      return;
    }

    prix = _parseGNF(_prixCtrl.text);

    setState(() => _loading = true);
    try {
      final supa = Supabase.instance.client;
      final uid = supa.auth.currentUser?.id;
      if (uid == null) throw 'Utilisateur non connecté';

      // 1) ✅ supprimer du storage les images retirées (donc “ancien” supprimé vraiment)
      if (_imagesToDelete.isNotEmpty) {
        await _deleteImagesFromStorage(_imagesToDelete);
      }

      // 2) upload nouvelles images
      final newUrls = await _uploadImages(uid);
      final allUrls = [..._existingImageUrls, ...newUrls];

      // 3) payload aligné inscription
      final payload = _buildPayload(uid: uid, images: allUrls);

      // 4) update
      await supa
          .from('restaurants')
          .update(payload)
          .eq('id', widget.resto['id']);

      // 5) nettoyage local
      _imagesToDelete.clear();
      _pickedImages.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restaurant modifié avec succès !')),
      );
      Navigator.pop(context, {
        ...widget.resto,
        ...payload,
        'id': widget.resto['id'],
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur Supabase : ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Modifier le restaurant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: restoPrimary),
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
                    ElevatedButton.icon(
                      onPressed: _gettingLocation ? null : _detectLocation,
                      icon: const Icon(Icons.location_on),
                      label: Text(
                        _gettingLocation
                            ? 'Recherche en cours…'
                            : 'Détecter ma position',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: restoPrimary,
                        foregroundColor: restoOnPrimary,
                      ),
                    ),
                    if (latitude != null && longitude != null) ...[
                      const SizedBox(height: 8),
                      Text('Latitude : ${latitude!.toStringAsFixed(6)}'),
                      Text('Longitude : ${longitude!.toStringAsFixed(6)}'),
                      if (adresse.isNotEmpty) Text('Adresse : $adresse'),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nomController,
                      decoration:
                          const InputDecoration(labelText: 'Nom du restaurant'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: villeController,
                      decoration: const InputDecoration(labelText: 'Ville'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: telController,
                      decoration: const InputDecoration(labelText: 'Téléphone'),
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _prixCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Prix moyen (GNF)',
                        helperText: 'Ex: 80000',
                      ),
                      onChanged: (v) {
                        final val = _parseGNF(v);
                        if (val != null) {
                          final ss = _formatGNF(val);
                          if (_prixCtrl.text != ss) {
                            _prixCtrl.value = TextEditingValue(
                              text: ss,
                              selection:
                                  TextSelection.collapsed(offset: ss.length),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Photos du restaurant',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
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
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        for (int i = 0; i < _pickedImages.length; i++)
                          Stack(
                            children: [
                              _previewPicked(_pickedImages[i]),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removePicked(i),
                                  child: const CircleAvatar(
                                    radius: 11,
                                    backgroundColor: Colors.red,
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
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
                            child: const Icon(
                              Icons.add_a_photo,
                              size: 30,
                              color: restoPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('Enregistrer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: restoPrimary,
                        foregroundColor: restoOnPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
