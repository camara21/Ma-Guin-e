// lib/pages/inscription_resto_page.dart
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, debugPrint;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ✅ Compression (même module que Annonces)
import 'package:ma_guinee/utils/image_compressor/image_compressor.dart';

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

  // Centre par défaut (Conakry) si jamais
  static const LatLng _defaultCenter = LatLng(9.6412, -13.5784);

  // ---- Mobile / Desktop ----
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

  // ---------- Helpers filename ----------
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

  // ---------- IMAGES ----------
  Future<void> _pickImages() async {
    // ✅ pas de imageQuality ici : on compresse nous-mêmes juste avant upload
    final res = await _picker.pickMultiImage();
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
          if (snap.connectionState != ConnectionState.done ||
              snap.data == null) {
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
    } else {
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
  }

  // ✅ Upload + compression (identique Annonces/Lieux)
  Future<List<String>> _uploadImages(String uid) async {
    final storage = Supabase.instance.client.storage.from(_bucket);
    final List<String> urls = [];

    for (int i = 0; i < _pickedImages.length; i++) {
      final img = _pickedImages[i];

      // Nom de base (utile si tu veux un nom “humain”)
      final original = kIsWeb ? img.name : p.basename(img.path);
      final base = _slugify(p.basenameWithoutExtension(original));
      final safeBase = (base.trim().isEmpty) ? 'image' : base.trim();

      // Bytes source
      final rawBytes = await img.readAsBytes();

      // ✅ compression prod (mêmes paramètres que Annonces)
      final c = await ImageCompressor.compressBytes(
        rawBytes,
        maxSide: 1600,
        quality: 82,
        maxBytes: 900 * 1024,
        keepPngIfTransparent: true,
      );

      final ts = DateTime.now().microsecondsSinceEpoch;
      final filename = '${ts}_${safeBase}_$i.${c.extension}';
      final objectPath = 'users/$uid/$filename';

      await storage.uploadBinary(
        objectPath,
        c.bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: c.contentType,
        ),
      );

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

  // ---------- LOCALISATION ----------
  Future<void> _detectLocation() async {
    if (_gettingLocation) return;
    setState(() => _gettingLocation = true);

    try {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Astuce localisation"),
          content: const Text(
            "Pour plus de précision, placez-vous à l’intérieur du restaurant avant de détecter la position.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );

      if (!await Geolocator.isLocationServiceEnabled()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Le service de localisation est désactivé. Activez le GPS puis réessayez.',
            ),
          ),
        );
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permission de localisation refusée. Autorisez-la dans les paramètres pour continuer.',
            ),
          ),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      latitude = pos.latitude;
      longitude = pos.longitude;

      try {
        final placemarks =
            await placemarkFromCoordinates(latitude!, longitude!);
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          adresse = [
            pm.street,
            pm.subLocality,
            pm.locality,
            pm.administrativeArea,
            pm.country,
          ].where((e) => (e != null && e.trim().isNotEmpty)).join(', ');
          ville = pm.locality ?? ville;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Position récupérée. Touchez la carte pour ajuster le point exact si besoin.",
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur localisation : $e')),
      );
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _reverseGeocodeFromLatLng() async {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Détectez d’abord la position puis ajustez le marqueur sur la carte.",
          ),
        ),
      );
      return;
    }
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        setState(() {
          adresse = [
            pm.street,
            pm.subLocality,
            pm.locality,
            pm.administrativeArea,
            pm.country,
          ].where((e) => (e != null && e.trim().isNotEmpty)).join(', ');
          ville = pm.locality ?? ville;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Adresse mise à jour à partir de la position."),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Aucune adresse trouvée pour ces coordonnées."),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible de déduire l’adresse : $e")),
      );
    }
  }

  // ---------- Vérification : 1 restaurant par compte ----------
  Future<Map<String, dynamic>?> _findRestaurantForUser(String uid) async {
    try {
      final res = await Supabase.instance.client
          .from('restaurants')
          .select('id, nom')
          .eq('user_id', uid)
          .limit(1);

      if (res is List && res.isNotEmpty) {
        final row = res.first;
        if (row is Map<String, dynamic>) return row;
        return Map<String, dynamic>.from(row as Map);
      }
    } catch (e) {
      debugPrint('Erreur vérification restaurant pour utilisateur: $e');
    }
    return null;
  }

  // ---------- ENREGISTREMENT ----------
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Clique d’abord sur “Détecter ma position” pour localiser le restaurant.',
          ),
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

      // Règle métier : 1 restaurant par compte
      if (widget.restaurant == null) {
        final existing = await _findRestaurantForUser(uid);
        if (existing != null) {
          final nomExistant = (existing['nom'] ?? '').toString().trim().isEmpty
              ? 'Restaurant existant'
              : existing['nom'].toString();

          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Restaurant déjà enregistré'),
              content: Text(
                'Vous avez déjà un restaurant enregistré avec ce compte :\n'
                '"$nomExistant".\n\n'
                'Chaque compte peut gérer un seul restaurant directement dans l’application.\n\n'
                'Si vous avez plusieurs restaurants à gérer, merci de nous contacter '
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
      }

      if (_imagesToDelete.isNotEmpty) {
        await _deleteImagesFromStorage(_imagesToDelete);
      }

      // ✅ upload compressé
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
        await supa
            .from('restaurants')
            .update(data)
            .eq('id', widget.restaurant!['id']);
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
    final enEdition = widget.restaurant != null;
    final isMobile = _isMobile;

    // Inscription initiale obligatoire sur mobile
    final canSave = isMobile || enEdition;

    // Carte seulement après géoloc (ou si déjà en base)
    final showMap = latitude != null && longitude != null;

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
                              ? "Pour garantir une géolocalisation fiable, l’enregistrement initial de ce restaurant a été fait avec un téléphone. Vous pouvez modifier les informations ci-dessous, mais la position doit rester cohérente."
                              : "L’inscription d’un restaurant doit être réalisée avec votre téléphone pour une géolocalisation précise. Merci d’ouvrir l’application sur mobile et de refaire cette étape.",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],

                    const Text(
                      "Placez-vous dans votre établissement pour enregistrer sa position exacte.",
                      style: TextStyle(color: Colors.blueGrey, fontSize: 13.5),
                    ),
                    const SizedBox(height: 9),

                    ElevatedButton.icon(
                      onPressed: (!isMobile || _gettingLocation)
                          ? null
                          : _detectLocation,
                      icon: const Icon(Icons.location_on),
                      label: Text(_gettingLocation
                          ? 'Recherche en cours…'
                          : 'Détecter ma position'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kRestoPrimary,
                        foregroundColor: kOnPrimary,
                      ),
                    ),

                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Après la détection, vous pourrez déplacer le marqueur sur la carte pour ajuster la position exacte (entrée, accueil, parking…).",
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade800),
                      ),
                    ),

                    if (showMap) ...[
                      const SizedBox(height: 10),
                      if (adresse.isNotEmpty)
                        Text("Adresse : $adresse",
                            style: TextStyle(color: dark)),
                      if (latitude != null && longitude != null) ...[
                        Text("Latitude  : ${latitude!.toStringAsFixed(6)}",
                            style: TextStyle(color: dark, fontSize: 12)),
                        Text("Longitude : ${longitude!.toStringAsFixed(6)}",
                            style: TextStyle(color: dark, fontSize: 12)),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 220,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              latitude ?? _defaultCenter.latitude,
                              longitude ?? _defaultCenter.longitude,
                            ),
                            initialZoom: 16,
                            onTap: (tapPos, point) {
                              // Ajustement manuel direct sur mobile uniquement
                              if (!isMobile) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "L’ajustement précis de la position se fait depuis l’application mobile."),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              if (latitude == null || longitude == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "Clique d’abord sur “Détecter ma position”."),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              setState(() {
                                latitude = point.latitude;
                                longitude = point.longitude;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text("Position modifiée manuellement."),
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
                            if (latitude != null && longitude != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(latitude!, longitude!),
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 12),
                    ],

                    TextFormField(
                      initialValue: nom,
                      decoration: const InputDecoration(
                        labelText: 'Nom du restaurant',
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Champ requis' : null,
                      onSaved: (v) => nom = v ?? '',
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
                      decoration: const InputDecoration(labelText: 'Téléphone'),
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Champ requis' : null,
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
                              selection:
                                  TextSelection.collapsed(offset: ss.length),
                            );
                          }
                        }
                      },
                    ),

                    TextFormField(
                      initialValue: description,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                      onSaved: (v) => description = v ?? '',
                    ),
                    TextFormField(
                      initialValue: specialites,
                      decoration:
                          const InputDecoration(labelText: 'Spécialités'),
                      onSaved: (v) => specialites = v ?? '',
                    ),
                    TextFormField(
                      initialValue: horaires,
                      decoration: const InputDecoration(
                          labelText: 'Horaires d’ouverture'),
                      onSaved: (v) => horaires = v ?? '',
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Photos du restaurant',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                              _imagePreview(_pickedImages[i]),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removeImage(i),
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
                              color: kRestoPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      onPressed: canSave ? _save : null,
                      icon: const Icon(Icons.save),
                      label: Text(enEdition ? 'Mettre à jour' : 'Enregistrer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kRestoPrimary,
                        foregroundColor: kOnPrimary,
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
