import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class EditHotelPage extends StatefulWidget {
  final int hotelId;
  const EditHotelPage({super.key, required this.hotelId});

  @override
  State<EditHotelPage> createState() => _EditHotelPageState();
}

class _EditHotelPageState extends State<EditHotelPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  bool loading = true;
  bool saving = false;

  // Champs hôtel
  String nom = '';
  String adresse = '';
  String ville = '';
  String telephone = '';
  String description = '';
  String prix = '';
  int etoiles = 1;
  double? latitude;
  double? longitude;

  // Images
  List<File> files = []; // Nouvelles à uploader
  List<String> imageUrls = []; // Déjà sur Supabase (ou uploadées)
  Set<int> _imagesToRemove = {}; // Index des images à supprimer

  @override
  void initState() {
    super.initState();
    _loadHotel();
  }

  Future<void> _loadHotel() async {
    setState(() => loading = true);
    final data = await Supabase.instance.client
        .from('hotels')
        .select()
        .eq('id', widget.hotelId)
        .maybeSingle();

    if (data != null) {
      nom = data['nom'] ?? '';
      adresse = data['adresse'] ?? '';
      ville = data['ville'] ?? '';
      telephone = data['tel'] ?? '';
      description = data['description'] ?? '';
      prix = data['prix'] ?? '';
      etoiles = data['etoiles'] ?? 1;
      latitude = data['latitude'];
      longitude = data['longitude'];
      imageUrls = (data['images'] as List?)?.cast<String>() ?? [];
    }
    setState(() => loading = false);
  }

  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage(imageQuality: 80);
    if (pickedFiles.isNotEmpty) {
      setState(() {
        files.addAll(pickedFiles.map((x) => File(x.path)));
      });
    }
  }

  // Uploads images locales vers Storage, retourne les URLs publiques
  Future<List<String>> _uploadImages() async {
    final storage = Supabase.instance.client.storage.from('hotel-photos');
    List<String> urls = [];
    for (var file in files) {
      final filename = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      await storage.upload(filename, file);
      final url = storage.getPublicUrl(filename);
      urls.add(url);
    }
    return urls;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);
    _formKey.currentState!.save();

    // On garde seulement les images non supprimées
    List<String> updatedImages = [
      for (var i = 0; i < imageUrls.length; i++) if (!_imagesToRemove.contains(i)) imageUrls[i]
    ];

    // Upload des nouvelles
    if (files.isNotEmpty) {
      final newUploaded = await _uploadImages();
      updatedImages.addAll(newUploaded);
    }

    final data = {
      'nom': nom,
      'adresse': adresse,
      'ville': ville,
      'tel': telephone,
      'description': description,
      'prix': prix,
      'etoiles': etoiles,
      'latitude': latitude,
      'longitude': longitude,
      'images': updatedImages,
    };

    try {
      await Supabase.instance.client.from('hotels').update(data).eq('id', widget.hotelId);
      setState(() => saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Hôtel modifié avec succès !")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la sauvegarde : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bleuMaGuinee = const Color(0xFF113CFC);
    final jauneMaGuinee = const Color(0xFFFCD116);
    final vert = const Color(0xFF009460);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Modifier l'hôtel", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: bleuMaGuinee),
        elevation: 1,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : saving
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        TextFormField(
                          initialValue: nom,
                          decoration: InputDecoration(
                            labelText: "Nom de l'hôtel *",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            labelStyle: TextStyle(color: bleuMaGuinee),
                          ),
                          validator: (v) => v!.isEmpty ? "Ce champ est requis" : null,
                          onSaved: (v) => nom = v ?? "",
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          initialValue: ville,
                          decoration: InputDecoration(
                            labelText: "Ville *",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            labelStyle: TextStyle(color: bleuMaGuinee),
                          ),
                          validator: (v) => v!.isEmpty ? "Ce champ est requis" : null,
                          onSaved: (v) => ville = v ?? "",
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          initialValue: telephone,
                          decoration: InputDecoration(
                            labelText: "Téléphone *",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            labelStyle: TextStyle(color: bleuMaGuinee),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (v) => v!.isEmpty ? "Ce champ est requis" : null,
                          onSaved: (v) => telephone = v ?? "",
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          initialValue: description,
                          decoration: InputDecoration(
                            labelText: "Description",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            labelStyle: TextStyle(color: bleuMaGuinee),
                          ),
                          maxLines: 3,
                          onSaved: (v) => description = v ?? "",
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          initialValue: prix,
                          decoration: InputDecoration(
                            labelText: "Prix moyen (ex: 500 000 GNF)",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            labelStyle: TextStyle(color: bleuMaGuinee),
                          ),
                          onSaved: (v) => prix = v ?? "",
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text("Nombre d'étoiles :", style: TextStyle(fontWeight: FontWeight.bold, color: bleuMaGuinee)),
                            const SizedBox(width: 10),
                            DropdownButton<int>(
                              value: etoiles,
                              onChanged: (val) => setState(() => etoiles = val!),
                              items: [1, 2, 3, 4, 5]
                                  .map((e) => DropdownMenuItem(
                                        value: e,
                                        child: Text("$e ⭐", style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text("Photos de l'hôtel :", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...List.generate(imageUrls.length, (i) {
                              if (_imagesToRemove.contains(i)) return const SizedBox();
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(imageUrls[i], width: 70, height: 70, fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _imagesToRemove.add(i)),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.8),
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(8),
                                            bottomLeft: Radius.circular(8),
                                          ),
                                        ),
                                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                            ...files
                                .map((file) => ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(file, width: 70, height: 70, fit: BoxFit.cover),
                                    ))
                                .toList(),
                            InkWell(
                              onTap: _pickImages,
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: jauneMaGuinee,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Icon(Icons.add_a_photo, size: 30, color: bleuMaGuinee),
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
                            backgroundColor: vert,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
