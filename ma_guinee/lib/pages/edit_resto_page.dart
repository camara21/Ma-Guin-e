import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

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
  late TextEditingController descriptionController;
  late TextEditingController telController;

  double? latitude;
  double? longitude;
  String adresse = '';
  bool _gettingLocation = false;
  bool loading = false;

  List<File> files = [];
  List<String> urls = [];

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Position détectée avec succès !")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la localisation : $e')),
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

  /// Suppression locale + Supabase Storage
  void _removeImage(int idx, {bool isNetwork = false}) async {
    final storage = Supabase.instance.client.storage.from('restaurant_photos');

    if (isNetwork) {
      final imageUrl = urls[idx];
      try {
        // Récupération du nom du fichier depuis l'URL publique
        final fileName = imageUrl.split('/').last.split('?').first;

        // Suppression dans Supabase Storage
        await storage.remove([fileName]);

        setState(() {
          urls.removeAt(idx);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Image supprimée du serveur.")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la suppression : $e")),
        );
      }
    } else {
      setState(() {
        files.removeAt(idx);
      });
    }
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
        const SnackBar(content: Text("Merci de cliquer sur « Détecter ma position ».")),
      );
      return;
    }
    setState(() => loading = true);

    final uploadedUrls = await _uploadImages();
    final allUrls = [...urls, ...uploadedUrls];

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
        const SnackBar(content: Text("Restaurant modifié avec succès !")),
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
    final Color bleuMaGuinee = const Color(0xFF113CFC);
    final Color orange = const Color(0xFFF39C12);
    final Color rouge = const Color(0xFFCE1126);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Modifier le restaurant", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: bleuMaGuinee),
        elevation: 1,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(18.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Text(
                      "Pour plus de précision, placez-vous à l'intérieur du restaurant puis cliquez sur « Détecter ma position ». ",
                      style: TextStyle(color: Colors.blueGrey, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 9),
                    ElevatedButton.icon(
                      onPressed: _gettingLocation ? null : _detectLocation,
                      icon: const Icon(Icons.location_on),
                      label: _gettingLocation
                          ? const Text("Recherche de la position…")
                          : const Text("Détecter ma position"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: orange,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    if (latitude != null && longitude != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Latitude : $latitude"),
                            Text("Longitude : $longitude"),
                            Text("Adresse détectée : $adresse"),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nomController,
                      decoration: InputDecoration(
                        labelText: "Nom du restaurant",
                        labelStyle: TextStyle(color: bleuMaGuinee),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
                    ),
                    const SizedBox(height: 13),
                    TextFormField(
                      controller: villeController,
                      decoration: InputDecoration(
                        labelText: "Ville",
                        labelStyle: TextStyle(color: bleuMaGuinee),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
                    ),
                    const SizedBox(height: 13),
                    TextFormField(
                      controller: telController,
                      decoration: InputDecoration(
                        labelText: "Téléphone",
                        labelStyle: TextStyle(color: bleuMaGuinee),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
                    ),
                    const SizedBox(height: 13),
                    TextFormField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: "Description",
                        labelStyle: TextStyle(color: bleuMaGuinee),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 18),
                    const Text("Photos du restaurant :", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
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
                                      color: rouge,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 17),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
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
                                      color: rouge,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 17),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        InkWell(
                          onTap: _pickImages,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: bleuMaGuinee),
                            ),
                            child: Icon(Icons.add_a_photo, size: 32, color: orange),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text("Enregistrer les modifications"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: bleuMaGuinee,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
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
