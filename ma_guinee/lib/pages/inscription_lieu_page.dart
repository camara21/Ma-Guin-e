import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class InscriptionLieuPage extends StatefulWidget {
  final Map<String, dynamic>? lieu;

  const InscriptionLieuPage({super.key, this.lieu});

  @override
  State<InscriptionLieuPage> createState() => _InscriptionLieuPageState();
}

class _InscriptionLieuPageState extends State<InscriptionLieuPage> {
  final _formKey = GlobalKey<FormState>();

  String nom = '';
  String adresse = '';
  String ville = '';
  String? type;
  String sousCategorie = '';
  String description = '';
  String contact = '';
  double? latitude;
  double? longitude;

  List<XFile> _pickedImages = [];
  List<String> _uploadedImages = [];
  bool _isUploading = false;
  final String _bucket = 'lieux-photos';

  final List<String> _typesLieu = ['divertissement', 'culte', 'tourisme'];
  final Map<String, List<String>> sousCategoriesParType = {
    'divertissement': [
      'Boîte de nuit', 'Bar', 'Salle de jeux', 'Cinéma', 'Parc d’attraction', 'Club', 'Plage privée'
    ],
    'culte': [
      'Mosquée', 'Église', 'Temple', 'Sanctuaire', 'Chapelle'
    ],
    'tourisme': [
      'Monument', 'Musée', 'Plage', 'Cascade', 'Parc naturel', 'Site historique', 'Montagne'
    ],
  };

  @override
  void initState() {
    super.initState();
    final l = widget.lieu ?? {};
    nom = l['nom'] ?? '';
    adresse = l['adresse'] ?? '';
    ville = l['ville'] ?? '';
    type = l['type'];
    sousCategorie = l['sous_categorie'] ?? '';
    description = l['description'] ?? '';
    contact = l['contact'] ?? '';
    latitude = l['latitude'] != null ? double.tryParse('${l['latitude']}') : null;
    longitude = l['longitude'] != null ? double.tryParse('${l['longitude']}') : null;
    if (l['images'] is List && l['images'].isNotEmpty) {
      _uploadedImages = List<String>.from(l['images']);
    }
  }

  Color get mainColor => const Color(0xFF1E3FCF);
  Color get red => const Color(0xFFCE1126);
  Color get yellow => const Color(0xFFFFCB05);
  Color get green => const Color(0xFF009460);

  Future<void> _recupererPosition() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
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
        ].where((e) => e != null && e.isNotEmpty).join(", ");
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

  Future<void> _choisirImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      final newPicked = picked.where((img) =>
        !_pickedImages.any((x) => x.path == img.path)
        && !_uploadedImages.contains(img.path)).toList();
      setState(() => _pickedImages.addAll(newPicked));
    }
  }

  void _removePickedImage(XFile img) {
    setState(() {
      _pickedImages.remove(img);
    });
  }

  void _removeUploadedImage(String url) {
    setState(() {
      _uploadedImages.remove(url);
    });
  }

  /// *** CORRECTION POUR LE CHEMIN D’UPLOAD ***
  Future<List<String>> _uploadImages(List<XFile> images) async {
    final urls = <String>[];
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Utilisateur non authentifié.")));
      return [];
    }
    for (var imageFile in images) {
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.name.replaceAll(RegExp(r'[^\w\-_\.]'), '')}';
        final path = '$userId/$fileName'; // ← OBLIGATOIRE pour les policies Storage Supabase !
        final bytes = await imageFile.readAsBytes();

        await Supabase.instance.client.storage
            .from(_bucket)
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(upsert: true),
            );

        final publicUrl = Supabase.instance.client.storage.from(_bucket).getPublicUrl(path);
        urls.add(publicUrl);

        print('Upload OK: $publicUrl');
      } catch (e) {
        debugPrint("Erreur upload image : $e");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur upload : $e")));
      }
    }
    return urls;
  }

  Future<void> _enregistrerLieu() async {
    if (!_formKey.currentState!.validate()) return;
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez définir la position géographique.")),
      );
      return;
    }
    if (type == null || type!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez choisir le type de lieu.")),
      );
      return;
    }
    if (sousCategorie.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez choisir la sous-catégorie.")),
      );
      return;
    }

    setState(() => _isUploading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    List<String> images = List<String>.from(_uploadedImages);

    if (_pickedImages.isNotEmpty) {
      final uploaded = await _uploadImages(_pickedImages);
      images = [...images, ...uploaded];
      setState(() {
        _pickedImages.clear();
        _uploadedImages = images;
      });
    }

    final data = {
      'nom': nom,
      'adresse': adresse,
      'ville': ville,
      'categorie': type,
      'sous_categorie': sousCategorie,
      'type': type,
      'description': description,
      'contact': contact,
      'latitude': latitude,
      'longitude': longitude,
      'images': images,
      'photo_url': images.isNotEmpty ? images[0] : null,
      'user_id': userId,
    };

    try {
      if (widget.lieu != null) {
        await Supabase.instance.client.from('lieux').update(data).eq('id', widget.lieu!['id']);
      } else {
        await Supabase.instance.client.from('lieux').insert(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Erreur enregistrement : $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur enregistrement.")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _supprimerLieu() async {
    if (widget.lieu == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirmer la suppression"),
        content: const Text("Voulez-vous vraiment supprimer ce lieu ? Cette action est irréversible."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await Supabase.instance.client.from('lieux').delete().eq('id', widget.lieu!['id']);
        if (mounted) {
          Navigator.pop(context, "deleted");
        }
      } catch (e) {
        debugPrint("Erreur suppression : $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de la suppression.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enEdition = widget.lieu != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(enEdition ? "Modifier le lieu" : "Inscription Lieu"),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
        actions: [
          if (enEdition)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              tooltip: "Supprimer ce lieu",
              onPressed: _supprimerLieu,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: _recupererPosition,
                icon: Icon(Icons.my_location, color: green),
                label: const Text("Détecter ma position"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  foregroundColor: Colors.white,
                ),
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
                      center: LatLng(latitude!, longitude!),
                      zoom: 16,
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
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 40,
                            height: 40,
                            point: LatLng(latitude!, longitude!),
                            child: Icon(Icons.location_on, color: red, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: _choisirImages,
                icon: Icon(Icons.photo_library, color: yellow),
                label: const Text("Ajouter des photos (max 10)"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: mainColor,
                  side: BorderSide(color: mainColor, width: 2),
                ),
              ),
              const SizedBox(height: 5),
              if (_uploadedImages.isNotEmpty || _pickedImages.isNotEmpty)
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ..._uploadedImages.map(
                        (url) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removeUploadedImage(url),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.65),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ..._pickedImages.map(
                        (img) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              kIsWeb
                                  ? Image.network(img.path, width: 80, height: 80, fit: BoxFit.cover)
                                  : Image.file(File(img.path), width: 80, height: 80, fit: BoxFit.cover),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removePickedImage(img),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.65),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              TextFormField(
                initialValue: nom,
                decoration: InputDecoration(labelText: "Nom du lieu", labelStyle: TextStyle(color: mainColor)),
                onChanged: (v) => nom = v,
                validator: (v) => v == null || v.isEmpty ? "Champ requis" : null,
              ),
              DropdownButtonFormField<String>(
                value: type,
                decoration: InputDecoration(
                  labelText: "Type de lieu *",
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(color: mainColor),
                ),
                items: _typesLieu
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t[0].toUpperCase() + t.substring(1)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  type = v;
                  sousCategorie = '';
                }),
                validator: (v) => v == null || v.isEmpty ? "Choisissez un type" : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: sousCategorie.isNotEmpty ? sousCategorie : null,
                decoration: InputDecoration(
                  labelText: "Sous-catégorie *",
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(color: mainColor),
                ),
                items: type != null
                    ? (sousCategoriesParType[type!] ?? [])
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat),
                            ))
                        .toList()
                    : [],
                onChanged: (v) => setState(() => sousCategorie = v ?? ''),
                validator: (v) => v == null || v.isEmpty ? "Choisissez une sous-catégorie" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: adresse,
                decoration: InputDecoration(labelText: "Adresse", labelStyle: TextStyle(color: mainColor)),
                onChanged: (v) => adresse = v,
              ),
              TextFormField(
                initialValue: ville,
                decoration: InputDecoration(labelText: "Ville", labelStyle: TextStyle(color: mainColor)),
                onChanged: (v) => ville = v,
              ),
              TextFormField(
                initialValue: contact,
                decoration: InputDecoration(labelText: "Contact (téléphone/email)", labelStyle: TextStyle(color: mainColor)),
                onChanged: (v) => contact = v,
              ),
              TextFormField(
                initialValue: description,
                decoration: InputDecoration(labelText: "Description", labelStyle: TextStyle(color: mainColor)),
                maxLines: 3,
                onChanged: (v) => description = v,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (enEdition)
                    ElevatedButton.icon(
                      onPressed: _supprimerLieu,
                      icon: const Icon(Icons.delete),
                      label: const Text("Supprimer"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  Expanded(
                    child: _isUploading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            onPressed: _enregistrerLieu,
                            icon: const Icon(Icons.save),
                            label: Text(enEdition ? "Mettre à jour" : "Enregistrer"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mainColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
