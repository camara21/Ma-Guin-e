// lib/pages/inscription_clinique_page.dart
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class InscriptionCliniquePage extends StatefulWidget {
  final Map<String, dynamic>? clinique;
  const InscriptionCliniquePage({super.key, this.clinique});

  @override
  State<InscriptionCliniquePage> createState() =>
      _InscriptionCliniquePageState();
}

// Palette Santé
const Color kHealthPrimary = Color(0xFF009460);
const Color kHealthSecondary = Color(0xFFFCD116);
const Color kOnPrimary = Colors.white;

class _InscriptionCliniquePageState extends State<InscriptionCliniquePage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _sb = Supabase.instance.client;

  // Champs
  String nom = '';
  String ville = '';
  String adresse = '';
  String tel = '';
  String description = '';
  String specialites = '';
  String horaires = '';
  double? latitude;
  double? longitude;

  // UI
  bool _locating = false;
  bool _saving = false;

  // Images
  final List<XFile> _pickedImages = [];
  List<String> _onlineImages = [];
  static const String _bucket = 'clinique-photos';

  // Centre par défaut (Conakry)
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
    final c = widget.clinique;
    if (c != null) {
      nom = (c['nom'] ?? '').toString();
      ville = (c['ville'] ?? '').toString();
      adresse = (c['adresse'] ?? '').toString();
      tel = (c['tel'] ?? '').toString();
      description = (c['description'] ?? '').toString();
      specialites = (c['specialites'] ?? '').toString();
      horaires = (c['horaires'] ?? '').toString();
      latitude = (c['latitude'] as num?)?.toDouble();
      longitude = (c['longitude'] as num?)?.toDouble();
      _onlineImages = (c['images'] as List?)?.cast<String>() ?? [];
    }
  }

  // ------------ Localisation ------------
  Future<void> _detectLocation() async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Astuce localisation"),
          content: const Text(
            "Pour plus de précision, placez-vous à l’intérieur de la clinique avant de détecter la position.",
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Le service de localisation est désactivé. Activez le GPS puis réessayez.',
            ),
          ),
        );
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!mounted) return;
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

      // Reverse geocoding (adresse + ville)
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

      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Position récupérée. Touchez la carte pour ajuster le point exact si besoin.",
          ),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur localisation : $e')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _reverseGeocodeFromLatLng() async {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) {
      if (!mounted) return;
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
        final p = placemarks.first;
        setState(() {
          adresse = [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
            p.country
          ].where((e) => (e != null && e!.trim().isNotEmpty)).join(', ');
          ville = p.locality ?? ville;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Adresse mise à jour à partir de la position."),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Aucune adresse trouvée pour ces coordonnées."),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible de déduire l’adresse : $e")),
      );
    }
  }

  // ------------ Images ------------
  Future<void> _pickImages() async {
    final res = await _picker.pickMultiImage(imageQuality: 80);
    if (res.isEmpty) return;
    setState(() => _pickedImages.addAll(res));
  }

  void _removePicked(int i) => setState(() => _pickedImages.removeAt(i));
  void _removeOnline(int i) => setState(() => _onlineImages.removeAt(i));

  Widget _preview(XFile f) {
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

  Future<List<String>> _uploadImages(String uid) async {
    final storage = _sb.storage.from(_bucket);
    final urls = <String>[];
    for (final img in _pickedImages) {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(img.path).replaceAll(' ', '_')}';
      final objectPath = 'u/$uid/$fileName';

      if (kIsWeb) {
        final bytes = await img.readAsBytes();
        await storage.uploadBinary(
          objectPath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
      } else {
        await storage.upload(
          objectPath,
          File(img.path),
          fileOptions: const FileOptions(upsert: true),
        );
      }
      urls.add(storage.getPublicUrl(objectPath));
    }
    return urls;
  }

  // Empêche la création de plusieurs cliniques pour un même user
  Future<Map<String, dynamic>?> _findCliniqueForUser(String uid) async {
    try {
      final rows = await _sb
          .from('cliniques')
          .select('id, nom')
          .eq('user_id', uid)
          .eq('is_deleted', false)
          .limit(1);

      if (rows is List && rows.isNotEmpty) {
        final row = rows.first;
        if (row is Map<String, dynamic>) return row;
        return Map<String, dynamic>.from(row as Map);
      }
    } catch (e) {
      // En cas d’erreur réseau, on laisse passer, les RLS protègent aussi côté base.
    }
    return null;
  }

  // ------------ Enregistrement ------------
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final isMobile = _isMobile;
    final enEdition = widget.clinique != null;

    if (!isMobile && !enEdition) {
      // Sécurité supplémentaire côté logique, en plus du bouton désactivé.
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Inscription sur téléphone requise'),
          content: const Text(
            "Pour garantir une carte fiable et une position précise, "
            "l’inscription de la clinique doit être réalisée avec votre téléphone.",
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

    if (latitude == null || longitude == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Détecte ta position puis ajuste-la sur la carte si besoin.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    _formKey.currentState!.save();

    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) throw 'Utilisateur non connecté';

      // Règle métier : 1 clinique par compte
      if (widget.clinique == null) {
        final existing = await _findCliniqueForUser(uid);
        if (existing != null) {
          final nomExistant = (existing['nom'] ?? '').toString().trim().isEmpty
              ? 'Clinique existante'
              : existing['nom'].toString();

          if (!mounted) return;
          setState(() => _saving = false);
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Clinique déjà enregistrée'),
              content: Text(
                'Vous avez déjà une clinique enregistrée avec ce compte :\n'
                '"$nomExistant".\n\n'
                'Chaque compte peut gérer une seule clinique directement dans l’application.\n\n'
                'Si vous avez plusieurs cliniques à gérer, merci de nous contacter '
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

      // Upload images
      final uploaded = await _uploadImages(uid);
      final allImages = [..._onlineImages, ...uploaded];

      // Données selon colonnes existantes
      final data = {
        'user_id': uid,
        'nom': nom,
        'ville': ville,
        'adresse': adresse,
        'tel': tel,
        'description': description,
        'specialites': specialites,
        'horaires': horaires,
        'latitude': latitude,
        'longitude': longitude,
        'images': allImages,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.clinique == null) {
        data['created_at'] = DateTime.now().toIso8601String();
        await _sb.from('cliniques').insert(data);
        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Succès'),
              content: const Text('Clinique enregistrée avec succès.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        final id = widget.clinique!['id'];
        await _sb.from('cliniques').update(data).eq('id', id);
        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Succès'),
              content: const Text('Clinique mise à jour avec succès.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
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
      if (mounted) setState(() => _saving = false);
    }
  }

  // ------------ UI ------------
  @override
  Widget build(BuildContext context) {
    final enEdition = widget.clinique != null;
    final isMobile = _isMobile;
    final canSave = isMobile || enEdition;
    final showMap = latitude != null && longitude != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        title: Text(enEdition ? 'Modifier Clinique' : 'Inscription Clinique'),
        backgroundColor: Colors.white,
        foregroundColor: kHealthPrimary,
        elevation: 1,
        actions: [
          if (enEdition)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Supprimer ?'),
                        content: const Text('Cette action est irréversible.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Supprimer',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ) ??
                    false;
                if (!ok) return;
                try {
                  await _sb
                      .from('cliniques')
                      .delete()
                      .eq('id', widget.clinique!['id']);
                  if (mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur : $e')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: _saving
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
                              ? "Pour garantir une carte fiable, l’enregistrement initial de cette clinique a été fait avec un téléphone. Vous pouvez modifier les informations ci-dessous, mais la position doit rester cohérente."
                              : "L’inscription d’une clinique doit être réalisée avec votre téléphone pour une géolocalisation précise. Merci d’ouvrir l’application sur mobile et de refaire cette étape.",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],

                    const Text(
                      "Placez-vous dans la clinique pour enregistrer sa position exacte.",
                      style: TextStyle(color: Colors.blueGrey, fontSize: 13.5),
                    ),
                    const SizedBox(height: 9),

                    ElevatedButton.icon(
                      onPressed:
                          (!isMobile || _locating) ? null : _detectLocation,
                      icon: const Icon(Icons.location_on),
                      label: Text(_locating
                          ? 'Recherche en cours…'
                          : 'Détecter ma position'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kHealthPrimary,
                        foregroundColor: kOnPrimary,
                      ),
                    ),

                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Après la détection, vous pourrez déplacer le marqueur sur la carte pour ajuster la position exacte (entrée, accueil, etc.).",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),

                    if (showMap) ...[
                      const SizedBox(height: 10),
                      if (adresse.isNotEmpty)
                        Text(
                          'Adresse : $adresse',
                          style: const TextStyle(fontSize: 13),
                        ),
                      if (latitude != null && longitude != null) ...[
                        Text(
                          'Latitude  : ${latitude!.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Longitude : ${longitude!.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
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
                              // Ajustement manuel direct sur mobile uniquement
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
                                      Text('Position ajustée manuellement.'),
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
                                    width: 40,
                                    height: 40,
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

                    // Form fields
                    TextFormField(
                      initialValue: nom,
                      decoration: const InputDecoration(
                        labelText: 'Nom de la clinique *',
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Champ requis' : null,
                      onSaved: (v) => nom = v!.trim(),
                    ),
                    TextFormField(
                      initialValue: ville,
                      decoration: const InputDecoration(labelText: 'Ville *'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Champ requis' : null,
                      onSaved: (v) => ville = v!.trim(),
                    ),
                    TextFormField(
                      initialValue: adresse,
                      decoration: const InputDecoration(labelText: 'Adresse *'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Champ requis' : null,
                      onSaved: (v) => adresse = v!.trim(),
                    ),
                    TextFormField(
                      initialValue: tel,
                      decoration:
                          const InputDecoration(labelText: 'Téléphone *'),
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Champ requis' : null,
                      onSaved: (v) => tel = v!.trim(),
                    ),
                    TextFormField(
                      initialValue: description,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                      onSaved: (v) => description = (v ?? '').trim(),
                    ),
                    TextFormField(
                      initialValue: specialites,
                      decoration:
                          const InputDecoration(labelText: 'Spécialités'),
                      onSaved: (v) => specialites = (v ?? '').trim(),
                    ),
                    TextFormField(
                      initialValue: horaires,
                      decoration: const InputDecoration(
                        labelText: "Horaires d'ouverture",
                      ),
                      onSaved: (v) => horaires = (v ?? '').trim(),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Photos de la clinique :',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // existantes
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
                        // nouvelles
                        for (int i = 0; i < _pickedImages.length; i++)
                          Stack(
                            children: [
                              _preview(_pickedImages[i]),
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
                        widget.clinique == null
                            ? 'Enregistrer'
                            : 'Mettre à jour',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kHealthPrimary,
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
