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
  List<String> imageUrls = []; // Celles déjà sur Supabase (et nouvelles après upload)
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

  // Enregistrer la modif
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);
    _formKey.currentState!.save();

    // Supprime images retirées
    List<String> updatedImages = [
      for (var i = 0; i < imageUrls.length; i++) if (!_imagesToRemove.contains(i)) imageUrls[i]
    ];

    // Upload des nouvelles
    if (files.isNotEmpty) {
      final newUploaded = await _uploadImages();
      updatedImages.addAll(newUploaded);
    }

    // Mise à jour en base
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
      // Pas besoin de changer created_at ici
    };

    await Supabase.instance.client.from('hotels').update(data).eq('id', widget.hotelId);

    setState(() => saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hôtel modifié avec succès !")),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Modifier l'hôtel")),
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
                          decoration: const InputDecoration(labelText: "Nom de l'hôtel"),
                          validator: (v) => v!.isEmpty ? "Champ requis" : null,
                          onSaved: (v) => nom = v ?? "",
                        ),
                        TextFormField(
                          initialValue: ville,
                          decoration: const InputDecoration(labelText: "Ville"),
                          validator: (v) => v!.isEmpty ? "Champ requis" : null,
                          onSaved: (v) => ville = v ?? "",
                        ),
                        TextFormField(
                          initialValue: telephone,
                          decoration: const InputDecoration(labelText: "Téléphone"),
                          keyboardType: TextInputType.phone,
                          validator: (v) => v!.isEmpty ? "Champ requis" : null,
                          onSaved: (v) => telephone = v ?? "",
                        ),
                        TextFormField(
                          initialValue: description,
                          decoration: const InputDecoration(labelText: "Description"),
                          maxLines: 3,
                          onSaved: (v) => description = v ?? "",
                        ),
                        TextFormField(
                          initialValue: prix,
                          decoration: const InputDecoration(labelText: "Prix moyen (ex: 500 000 GNF)"),
                          onSaved: (v) => prix = v ?? "",
                        ),
                        Row(
                          children: [
                            const Text("Nombre d'étoiles :"),
                            const SizedBox(width: 12),
                            DropdownButton<int>(
                              value: etoiles,
                              onChanged: (val) => setState(() => etoiles = val!),
                              items: [1, 2, 3, 4, 5]
                                  .map((e) => DropdownMenuItem(value: e, child: Text("$e ⭐")))
                                  .toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text("Photos de l'hôtel :", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        // Images existantes avec suppression
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
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: const Icon(Icons.add_a_photo, size: 30, color: Colors.purple),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        ElevatedButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save),
                          label: const Text("Enregistrer"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
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
