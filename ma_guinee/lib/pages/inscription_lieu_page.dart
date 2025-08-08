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
      'Boîte de nuit', 'Bar', 'Salle de jeux', 'Cinéma',
      'Parc d’attraction', 'Club', 'Plage privée'
    ],
    'culte': ['Mosquée', 'Église', 'Temple', 'Sanctuaire', 'Chapelle'],
    'tourisme': [
      'Monument', 'Musée', 'Plage', 'Cascade',
      'Parc naturel', 'Site historique', 'Montagne'
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
      // Message avant détection
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Astuce localisation"),
          content: const Text(
              "Pour plus de précision, placez-vous à l’intérieur de l’établissement avant de détecter la position."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Permission de localisation refusée.")));
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Activez la localisation dans les paramètres.")));
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      latitude = position.latitude;
      longitude = position.longitude;

      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        adresse = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
          p.country
        ].where((e) => e != null && e.isNotEmpty).join(", ");
        ville = p.locality ?? ville;
      }

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Position détectée avec succès.")));
    } catch (e) {
      debugPrint("Erreur géolocalisation : $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur localisation : $e")));
    }
  }

  Future<void> _choisirImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      final newPicked = picked
          .where((img) =>
              !_pickedImages.any((x) => x.path == img.path) &&
              !_uploadedImages.contains(img.path))
          .toList();
      setState(() => _pickedImages.addAll(newPicked));
    }
  }

  void _removePickedImage(XFile img) =>
      setState(() => _pickedImages.remove(img));

  void _removeUploadedImage(String url) =>
      setState(() => _uploadedImages.remove(url));

  Future<List<String>> _uploadImages(List<XFile> images) async {
    final urls = <String>[];
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    for (var img in images) {
      try {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${img.name.replaceAll(RegExp(r'[^\w\-_\.]'), '')}';
        final path = '$userId/$fileName';
        final bytes = await img.readAsBytes();
        await Supabase.instance.client.storage
            .from(_bucket)
            .uploadBinary(path, bytes, fileOptions: FileOptions(upsert: true));
        urls.add(Supabase.instance.client.storage.from(_bucket).getPublicUrl(path));
      } catch (e) {
        debugPrint("Erreur upload image : $e");
      }
    }
    return urls;
  }

  Future<void> _enregistrerLieu() async {
    if (!_formKey.currentState!.validate()) return;
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Veuillez détecter la position.")));
      return;
    }
    if (type == null || type!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Veuillez choisir un type de lieu.")));
      return;
    }
    if (sousCategorie.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Veuillez choisir une sous-catégorie.")));
      return;
    }

    setState(() => _isUploading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    List<String> images = List.from(_uploadedImages);
    if (_pickedImages.isNotEmpty) {
      final uploaded = await _uploadImages(_pickedImages);
      images = [...images, ...uploaded];
      _pickedImages.clear();
      _uploadedImages = images;
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
        await Supabase.instance.client
            .from('lieux')
            .update(data)
            .eq('id', widget.lieu!['id']);
      } else {
        await Supabase.instance.client.from('lieux').insert(data);
      }

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Succès"),
          content: Text(widget.lieu != null
              ? "Lieu mis à jour avec succès ✅"
              : "Lieu enregistré avec succès ✅"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Erreur enregistrement : $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erreur : $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enEdition = widget.lieu != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(enEdition ? "Modifier le lieu" : "Inscription Lieu"),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: _recupererPosition,
                icon: const Icon(Icons.my_location),
                label: const Text("Détecter ma position"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  foregroundColor: Colors.white,
                ),
              ),
              if (latitude != null && longitude != null) ...[
                const SizedBox(height: 10),
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
                            const SnackBar(content: Text("Position modifiée")));
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
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _choisirImages,
                icon: const Icon(Icons.photo_library),
                label: const Text("Ajouter des photos"),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: nom,
                decoration: const InputDecoration(labelText: "Nom du lieu"),
                validator: (v) => v == null || v.isEmpty ? "Champ requis" : null,
                onChanged: (v) => nom = v,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: "Type de lieu"),
                items: _typesLieu
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() {
                  type = v;
                  sousCategorie = '';
                }),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: sousCategorie.isNotEmpty ? sousCategorie : null,
                decoration: const InputDecoration(labelText: "Sous-catégorie"),
                items: type != null
                    ? (sousCategoriesParType[type!] ?? [])
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList()
                    : [],
                onChanged: (v) => setState(() => sousCategorie = v ?? ''),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: adresse,
                decoration: const InputDecoration(labelText: "Adresse"),
                onChanged: (v) => adresse = v,
              ),
              TextFormField(
                initialValue: ville,
                decoration: const InputDecoration(labelText: "Ville"),
                onChanged: (v) => ville = v,
              ),
              TextFormField(
                initialValue: contact,
                decoration: const InputDecoration(labelText: "Contact"),
                onChanged: (v) => contact = v,
              ),
              TextFormField(
                initialValue: description,
                decoration: const InputDecoration(labelText: "Description"),
                maxLines: 3,
                onChanged: (v) => description = v,
              ),
              const SizedBox(height: 20),
              _isUploading
                  ? const CircularProgressIndicator()
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
            ],
          ),
        ),
      ),
    );
  }
}
