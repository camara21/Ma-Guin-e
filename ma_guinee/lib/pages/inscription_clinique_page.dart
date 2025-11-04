// lib/pages/inscription_clinique_page.dart
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

class InscriptionCliniquePage extends StatefulWidget {
  final Map<String, dynamic>? clinique;
  const InscriptionCliniquePage({super.key, this.clinique});

  @override
  State<InscriptionCliniquePage> createState() => _InscriptionCliniquePageState();
}

// Palette Santé
const Color kHealthPrimary   = Color(0xFF009460);
const Color kHealthSecondary = Color(0xFFFCD116);
const Color kOnPrimary       = Colors.white;

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

  @override
  void initState() {
    super.initState();
    final c = widget.clinique;
    if (c != null) {
      nom          = (c['nom'] ?? '').toString();
      ville        = (c['ville'] ?? '').toString();
      adresse      = (c['adresse'] ?? '').toString();
      tel          = (c['tel'] ?? '').toString();
      description  = (c['description'] ?? '').toString();
      specialites  = (c['specialites'] ?? '').toString();
      horaires     = (c['horaires'] ?? '').toString();
      latitude     = (c['latitude'] as num?)?.toDouble();
      longitude    = (c['longitude'] as num?)?.toDouble();
      _onlineImages = (c['images'] as List?)?.cast<String>() ?? [];
    }
  }

  // ------------ Localisation (même logique que l'hôtel) ------------
  Future<void> _detectLocation() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Astuce : placez-vous à l’intérieur de la clinique pour enregistrer sa position exacte."),
        duration: Duration(seconds: 2),
      ),
    );

    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Service de localisation désactivé';
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'Permission refusée';
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      latitude  = pos.latitude;
      longitude = pos.longitude;

      // Reverse geocoding (adresse + ville)
      try {
        final placemarks = await placemarkFromCoordinates(latitude!, longitude!);
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
          content: Text("Position récupérée. Touchez la carte pour ajuster si besoin."),
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

  // ------------ Images ------------
  Future<void> _pickImages() async {
    final res = await _picker.pickMultiImage(imageQuality: 80);
    if (res.isEmpty) return;
    setState(() => _pickedImages.addAll(res));
  }

  void _removePicked(int i) => setState(() => _pickedImages.removeAt(i));
  void _removeOnline(int i)   => setState(() => _onlineImages.removeAt(i));

  Widget _preview(XFile f) {
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: f.readAsBytes(),
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(width: 70, height: 70, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
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
    final storage = _sb.storage.from(_bucket);
    final urls = <String>[];
    for (final img in _pickedImages) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(img.path).replaceAll(' ', '_')}';
      final objectPath = 'u/$uid/$fileName';

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

  // Empêche la création s’il existe déjà une clinique pour ce user
  Future<bool> _hasClinic(String uid) async {
    try {
      final rows = await _sb
          .from('cliniques')
          .select('id')
          .eq('user_id', uid)
          .eq('is_deleted', false)
          .limit(1);
      return rows is List && rows.isNotEmpty;
    } catch (_) {
      // En cas d’erreur réseau, on laisse la création tenter (les RLS peuvent aussi protéger)
      return false;
    }
  }

  // ------------ Enregistrement ------------
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Détecte ta position ou ajuste-la sur la carte.')),
      );
      return;
    }

    setState(() => _saving = true);
    _formKey.currentState!.save();

    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) throw 'Utilisateur non connecté';

      // Bloquer la création si déjà une clinique
      if (widget.clinique == null && await _hasClinic(uid)) {
        if (!mounted) return;
        setState(() => _saving = false);
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Création impossible'),
            content: const Text(
              "Vous avez déjà une clinique enregistrée avec ce compte.\n\n"
              "Si vous avez d’autres cliniques à ajouter, veuillez contacter le support pour activer la multi-gestion."
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
        return;
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
        'updated_at': DateTime.now().toIso8601String(), // OK si colonne existe, sinon ignorée par PostgREST
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
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
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
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ------------ UI ------------
  @override
  Widget build(BuildContext context) {
    final enEdition = widget.clinique != null;

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
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ) ??
                    false;
                if (!ok) return;
                try {
                  await _sb.from('cliniques').delete().eq('id', widget.clinique!['id']);
                  if (mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
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
                    const Text(
                      "Placez-vous dans la clinique pour enregistrer sa position exacte.",
                      style: TextStyle(color: Colors.blueGrey, fontSize: 13.5),
                    ),
                    const SizedBox(height: 9),
                    ElevatedButton.icon(
                      onPressed: _locating ? null : _detectLocation,
                      icon: const Icon(Icons.location_on),
                      label: Text(_locating ? 'Recherche en cours…' : 'Détecter ma position'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kHealthPrimary,
                        foregroundColor: kOnPrimary,
                      ),
                    ),

                    if (latitude != null && longitude != null) ...[
                      const SizedBox(height: 6),
                      Text('Latitude : $latitude'),
                      Text('Longitude : $longitude'),
                      if (adresse.isNotEmpty) Text('Adresse : $adresse'),
                      const SizedBox(height: 12),
                      const Text('Position sur la carte :', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 220,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(latitude!, longitude!),
                            initialZoom: 16.0,
                            onTap: (tapPosition, point) {
                              setState(() {
                                latitude  = point.latitude;
                                longitude = point.longitude;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Position ajustée manuellement.'),
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
                                  width: 40, height: 40,
                                  point: LatLng(latitude!, longitude!),
                                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Form fields
                    TextFormField(
                      initialValue: nom,
                      decoration: const InputDecoration(labelText: 'Nom de la clinique *'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
                      onSaved: (v) => nom = v!.trim(),
                    ),
                    TextFormField(
                      initialValue: ville,
                      decoration: const InputDecoration(labelText: 'Ville *'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
                      onSaved: (v) => ville = v!.trim(),
                    ),
                    TextFormField(
                      initialValue: adresse,
                      decoration: const InputDecoration(labelText: 'Adresse *'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
                      onSaved: (v) => adresse = v!.trim(),
                    ),
                    TextFormField(
                      initialValue: tel,
                      decoration: const InputDecoration(labelText: 'Téléphone *'),
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
                      onSaved: (v) => tel = v!.trim(),
                    ),
                    TextFormField(
                      initialValue: description,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                      onSaved: (v) => description = (v ?? '').trim(),
                    ),
                    TextFormField(
                      initialValue: specialites,
                      decoration: const InputDecoration(labelText: 'Spécialités'),
                      onSaved: (v) => specialites = (v ?? '').trim(),
                    ),
                    TextFormField(
                      initialValue: horaires,
                      decoration: const InputDecoration(labelText: "Horaires d'ouverture"),
                      onSaved: (v) => horaires = (v ?? '').trim(),
                    ),

                    const SizedBox(height: 16),
                    const Text('Photos de la clinique :', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // existantes (aperçu simple + suppression locale)
                        for (int i = 0; i < _onlineImages.length; i++)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(_onlineImages[i], width: 70, height: 70, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removeOnline(i),
                                  child: const CircleAvatar(
                                    radius: 11,
                                    backgroundColor: Colors.red,
                                    child: Icon(Icons.close, size: 14, color: Colors.white),
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
                                    child: Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        InkWell(
                          onTap: _pickImages,
                          child: Container(
                            width: 70, height: 70,
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
                      label: Text(widget.clinique == null ? 'Enregistrer' : 'Mettre à jour'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kHealthPrimary,
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
