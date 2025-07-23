import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class EditRestoPage extends StatefulWidget {
  final Map<String, dynamic> resto; // contient toutes les infos actuelles
  const EditRestoPage({super.key, required this.resto});

  @override
  State<EditRestoPage> createState() => _EditRestoPageState();
}

class _EditRestoPageState extends State<EditRestoPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late TextEditingController nomController;
  late TextEditingController villeController;
  late TextEditingController descriptionController;
  late TextEditingController telController;

  double? latitude;
  double? longitude;
  String adresse = '';
  bool _gettingLocation = false;
  bool loading = false;

  List<File> files = [];
  List<String> urls = []; // URLs existantes déjà sur Supabase

  @override
  void initState() {
    super.initState();
    nomController = TextEditingController(text: widget.resto['nom'] ?? '');
    villeController = TextEditingController(text: widget.resto['ville'] ?? '');
    descriptionController = TextEditingController(text: widget.resto['description'] ?? '');
    telController = TextEditingController(text: widget.resto['tel'] ?? '');
    latitude = widget.resto['latitude'];
    longitude = widget.resto['longitude'];
    adresse = widget.resto['adresse'] ?? '';
    urls = ((widget.resto['images'] ?? []) as List).map((e) => e.toString()).toList();
  }

  Future<void> _detectLocation() async {
    setState(() => _gettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _gettingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission de localisation refusée.')),
          );
          return;
        }
      }
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      latitude = pos.latitude;
      longitude = pos.longitude;

      List<Placemark> placemarks = await placemarkFromCoordinates(latitude!, longitude!);
      final place = placemarks.first;
      adresse = "${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}";
      setState(() {});
    } catch (e) {
      setState(() => _gettingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur localisation : $e')),
      );
    }
    setState(() => _gettingLocation = false);
  }

  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage(imageQuality: 75);
    if (pickedFiles.isNotEmpty) {
      setState(() {
        files.addAll(pickedFiles.map((x) => File(x.path)));
      });
    }
  }

  // Supprimer une photo existante de la liste et éventuellement du Storage
  void _removeImage(int idx, {bool isNetwork = false}) {
    setState(() {
      if (isNetwork) {
        urls.removeAt(idx);
      } else {
        files.removeAt(idx);
      }
    });
  }

  Future<List<String>> _uploadImages() async {
    final storage = Supabase.instance.client.storage.from('restaurant_photos');
    List<String> newUrls = [];
    for (var file in files) {
      final filename = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      await storage.upload(filename, file);
      final url = storage.getPublicUrl(filename);
      newUrls.add(url);
    }
    return newUrls;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Merci de cliquer sur \"Détecter ma position\"")),
      );
      return;
    }
    setState(() => loading = true);

    // Upload nouvelles images
    final uploadedUrls = await _uploadImages();
    final allUrls = [...urls, ...uploadedUrls];

    // Update la ligne en base
    await Supabase.instance.client
        .from('restaurants')
        .update({
          'nom': nomController.text,
          'ville': villeController.text,
          'tel': telController.text,
          'description': descriptionController.text,
          'latitude': latitude,
          'longitude': longitude,
          'adresse': adresse,
          'images': allUrls,
        })
        .eq('id', widget.resto['id']);

    setState(() => loading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Restaurant modifié avec succès !")),
      );
      Navigator.pop(context, {
        ...widget.resto,
        'nom': nomController.text,
        'ville': villeController.text,
        'tel': telController.text,
        'description': descriptionController.text,
        'latitude': latitude,
        'longitude': longitude,
        'adresse': adresse,
        'images': allUrls,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Modifier Restaurant")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(18.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Text(
                      "Si l'adresse est fausse, place-toi dans ton restaurant puis détecte la position :",
                      style: TextStyle(color: Colors.blueGrey, fontSize: 14),
                    ),
                    const SizedBox(height: 9),
                    ElevatedButton.icon(
                      onPressed: _gettingLocation ? null : _detectLocation,
                      icon: const Icon(Icons.location_on),
                      label: _gettingLocation
                          ? const Text("Recherche en cours…")
                          : const Text("Détecter ma position"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (latitude != null && longitude != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Latitude : $latitude"),
                            Text("Longitude : $longitude"),
                            Text("Adresse : $adresse"),
                          ],
                        ),
                      ),
                    TextFormField(
                      controller: nomController,
                      decoration: const InputDecoration(labelText: "Nom du restaurant"),
                      validator: (v) => v!.isEmpty ? "Champ requis" : null,
                    ),
                    TextFormField(
                      controller: villeController,
                      decoration: const InputDecoration(labelText: "Ville"),
                      validator: (v) => v!.isEmpty ? "Champ requis" : null,
                    ),
                    TextFormField(
                      controller: telController,
                      decoration: const InputDecoration(labelText: "Téléphone"),
                      keyboardType: TextInputType.phone,
                      validator: (v) => v!.isEmpty ? "Champ requis" : null,
                    ),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: "Description"),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // IMAGES gestion
                    const Text("Photos du restaurant :", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Images existantes (Supabase)
                        ...List.generate(urls.length, (idx) {
                          final url = urls[idx];
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(url, width: 70, height: 70, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: () => _removeImage(idx, isNetwork: true),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 17),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        // Nouvelles images locales (non encore uploadées)
                        ...List.generate(files.length, (idx) {
                          final file = files[idx];
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(file, width: 70, height: 70, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: () => _removeImage(idx),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 17),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        // Ajout
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
                            child: const Icon(Icons.add_a_photo, size: 30, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text("Enregistrer"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
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
