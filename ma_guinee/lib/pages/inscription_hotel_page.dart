// lib/pages/inscription_hotel_page.dart
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, debugPrint;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Compression (ton module)
import 'package:ma_guinee/utils/image_compressor/image_compressor.dart';

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
  static const Color hotelsPrimary = Color(0xFF264653);
  static const Color hotelsSecondary = Color(0xFF2A9D8F);
  static const Color onPrimary = Colors.white;

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

  // Images
  final List<XFile> _pickedImages = [];
  List<String> _onlineImages = []; // ✅ images existantes en édition
  static const String _bucket = 'hotel-photos';

  // Centre par défaut (Conakry) si jamais
  static const LatLng _defaultCenter = LatLng(9.6412, -13.5784);

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

      // ✅ récupérer photos existantes si présentes
      _onlineImages = (h['images'] as List?)?.cast<String>() ?? [];
    }
  }

  // -------------------- Localisation --------------------
  Future<void> _detectLocation() async {
    if (_gettingLocation) return;
    setState(() => _gettingLocation = true);

    try {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Astuce localisation"),
          content: const Text(
            "Pour plus de précision, placez-vous à l’intérieur de l’hôtel avant de détecter la position.",
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

      // Geocoding : adresse + ville
      try {
        final placemarks =
            await placemarkFromCoordinates(latitude!, longitude!);
        if (placemarks.isNotEmpty) {
          final pmark = placemarks.first;
          adresse = [
            pmark.street,
            pmark.subLocality,
            pmark.locality,
            pmark.administrativeArea,
            pmark.country
          ].where((e) => (e != null && e!.trim().isNotEmpty)).join(', ');
          ville = pmark.locality ?? ville;
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
        final pmark = placemarks.first;
        setState(() {
          adresse = [
            pmark.street,
            pmark.subLocality,
            pmark.locality,
            pmark.administrativeArea,
            pmark.country
          ].where((e) => (e != null && e!.trim().isNotEmpty)).join(', ');
          ville = pmark.locality ?? ville;
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

  // -------------------- Images --------------------
  Future<void> _pickImages() async {
    final res = await _picker.pickMultiImage(imageQuality: 80);
    if (res.isEmpty) return;
    setState(() => _pickedImages.addAll(res));
  }

  void _removePicked(int i) => setState(() => _pickedImages.removeAt(i));
  void _removeOnline(int i) => setState(() => _onlineImages.removeAt(i));

  Widget _imagePreview(XFile f) {
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: f.readAsBytes(),
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done ||
              snap.data == null) {
            return const SizedBox(
              width: 70,
              height: 70,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
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
        File(f.path),
        width: 70,
        height: 70,
        fit: BoxFit.cover,
      ),
    );
  }

  // ✅ Upload + compression (web + mobile + desktop) + contentType
  Future<List<String>> _uploadImages(String uid) async {
    final storage = Supabase.instance.client.storage.from(_bucket);
    final urls = <String>[];

    for (int i = 0; i < _pickedImages.length; i++) {
      final img = _pickedImages[i];

      final raw = await img.readAsBytes();

      final c = await ImageCompressor.compressBytes(
        raw,
        maxSide: 1600,
        quality: 82,
        maxBytes: 900 * 1024,
        keepPngIfTransparent: true,
      );

      final safeBase =
          p.basename(img.path).replaceAll(' ', '_').replaceAll('.', '_');
      final ts = DateTime.now().microsecondsSinceEpoch;

      // ✅ important : cohérent avec tes policies (u/<uid>/...)
      final objectPath = 'u/$uid/${ts}_${i}_$safeBase.${c.extension}';

      try {
        debugPrint(
            '[hotel] upload: raw=${raw.length}B -> cmp=${c.bytes.length}B type=${c.contentType}');
      } catch (_) {}

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

  // ---------- Vérification : un seul hôtel par compte ----------
  Future<Map<String, dynamic>?> _findHotelForUser(String uid) async {
    try {
      final res = Supabase.instance.client
          .from('hotels')
          .select('id, nom')
          .eq('user_id', uid)
          .limit(1);

      final out = await res;
      if (out is List && out.isNotEmpty) {
        final row = out.first;
        if (row is Map<String, dynamic>) return row;
        return Map<String, dynamic>.from(row as Map);
      }
    } catch (e) {
      debugPrint('Erreur vérification hôtel pour utilisateur: $e');
    }
    return null;
  }

  // -------------------- Enregistrement --------------------
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cliquez sur "Détecter ma position" puis ajustez sur la carte si besoin.',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    _formKey.currentState!.save();

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) throw 'Utilisateur non connecté';

      // Règle métier : 1 hôtel par compte
      if (widget.hotel == null) {
        final existingHotel = await _findHotelForUser(uid);
        if (existingHotel != null) {
          final nomExistant =
              (existingHotel['nom'] ?? '').toString().trim().isEmpty
                  ? 'Hôtel existant'
                  : existingHotel['nom'].toString();

          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Hôtel déjà enregistré'),
              content: Text(
                'Vous avez déjà un hôtel enregistré avec ce compte :\n'
                '"$nomExistant".\n\n'
                'Chaque compte peut gérer un seul hôtel directement dans l’application.\n\n'
                'Si vous avez plusieurs hôtels à gérer, merci de nous contacter '
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

      // ✅ upload compressé
      final uploaded = await _uploadImages(uid);

      // ✅ important : en édition, on garde les anciennes + nouvelles
      final allImages = [..._onlineImages, ...uploaded];

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
        'images': allImages,
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
                  child: const Text("OK"),
                ),
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
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
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

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    final enEdition = widget.hotel != null;
    final isMobile = _isMobile;

    // Inscription initiale obligatoire sur mobile
    final canSave = isMobile || enEdition;

    // Carte visible uniquement si lat/lng existent (géoloc ou édition)
    final showMap = latitude != null && longitude != null;

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
                              ? "Pour garantir une géolocalisation fiable, l’enregistrement initial de cet hôtel a été fait avec un téléphone. Vous pouvez modifier les informations ci-dessous, mais la position doit rester cohérente."
                              : "L’inscription d’un hôtel doit être réalisée avec votre téléphone pour une géolocalisation précise. Merci d’ouvrir l’application sur mobile et de refaire cette étape.",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                    const Text(
                      "Placez-vous dans l’hôtel pour enregistrer sa position exacte.",
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
                        backgroundColor: hotelsPrimary,
                        foregroundColor: onPrimary,
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
                        Text('Adresse : $adresse',
                            style: const TextStyle(fontSize: 13)),
                      if (latitude != null && longitude != null) ...[
                        Text(
                          'Latitude  : ${latitude!.toStringAsFixed(6)}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black87),
                        ),
                        Text(
                          'Longitude : ${longitude!.toStringAsFixed(6)}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black87),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 220,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              latitude ?? _defaultCenter.latitude,
                              longitude ?? _defaultCenter.longitude,
                            ),
                            initialZoom: 16.0,
                            onTap: (tapPosition, point) {
                              if (!isMobile) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "L’ajustement précis de la position se fait depuis l’application mobile.",
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              if (latitude == null || longitude == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Cliquez d’abord sur “Détecter ma position”.",
                                    ),
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
                                      Text("Position ajustée manuellement."),
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
                                    width: 40.0,
                                    height: 40.0,
                                    point: LatLng(latitude!, longitude!),
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
                      decoration: const InputDecoration(labelText: 'Téléphone'),
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
                        labelText: 'Prix moyen (ex: 500 000 GNF)',
                      ),
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
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text('$e ★'),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Photos de l’hôtel :',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // ✅ existantes
                        for (int i = 0; i < _onlineImages.length; i++)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _onlineImages[i],
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removeOnline(i),
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
                        // ✅ nouvelles
                        for (int i = 0; i < _pickedImages.length; i++)
                          Stack(
                            children: [
                              _imagePreview(_pickedImages[i]),
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
                            child: const Icon(Icons.add_a_photo, size: 30),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: canSave ? _save : null,
                      icon: const Icon(Icons.save),
                      label: Text(
                        widget.hotel == null ? 'Enregistrer' : 'Mettre à jour',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hotelsPrimary,
                        foregroundColor: onPrimary,
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
