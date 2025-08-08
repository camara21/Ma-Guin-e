import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

class EditCliniquePage extends StatefulWidget {
  final Map<String, dynamic>? clinique;
  const EditCliniquePage({super.key, this.clinique});

  @override
  State<EditCliniquePage> createState() => _EditCliniquePageState();
}

class _EditCliniquePageState extends State<EditCliniquePage> {
  late TextEditingController nomController;
  late TextEditingController villeController;
  late TextEditingController adresseController;
  late TextEditingController telephoneController;
  late TextEditingController descriptionController;
  late TextEditingController specialitesController;
  late TextEditingController horairesController;
  late TextEditingController latitudeController;
  late TextEditingController longitudeController;

  List<XFile> newFiles = [];
  List<String> imagesUrls = [];
  bool loading = false;
  final String _bucket = 'clinique-photos';

  @override
  void initState() {
    super.initState();
    final c = widget.clinique ?? {};
    nomController = TextEditingController(text: c['nom'] ?? '');
    villeController = TextEditingController(text: c['ville'] ?? '');
    adresseController = TextEditingController(text: c['adresse'] ?? '');
    telephoneController = TextEditingController(text: c['tel'] ?? '');
    descriptionController = TextEditingController(text: c['description'] ?? '');
    specialitesController = TextEditingController(text: c['specialites'] ?? '');
    horairesController = TextEditingController(text: c['horaires'] ?? '');
    latitudeController = TextEditingController(text: c['latitude']?.toString() ?? '');
    longitudeController = TextEditingController(text: c['longitude']?.toString() ?? '');
    imagesUrls = (c['images'] as List?)?.cast<String>() ?? [];

    Future.delayed(Duration.zero, () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("📍 Placez-vous à l’intérieur de la clinique pour une meilleure géolocalisation."),
          duration: Duration(seconds: 4),
        ),
      );
    });
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 75);
    if (picked.isNotEmpty) {
      setState(() => newFiles.addAll(picked));
    }
  }

  String? _storagePathFromPublicUrl(String url) {
    final marker = '/storage/v1/object/public/$_bucket/';
    final idx = url.indexOf(marker);
    if (idx != -1) {
      return url.substring(idx + marker.length);
    }
    final alt = '$_bucket/';
    final idx2 = url.indexOf(alt);
    if (idx2 != -1) {
      return url.substring(idx2 + alt.length);
    }
    return null;
  }

  Future<List<String>> _uploadImages() async {
    final storage = Supabase.instance.client.storage.from(_bucket);
    List<String> urls = [];
    for (var file in newFiles) {
      final filename = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      try {
        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          await storage.uploadBinary('cliniques/$filename', bytes, fileOptions: const FileOptions(upsert: true));
        } else {
          await storage.upload('cliniques/$filename', File(file.path), fileOptions: const FileOptions(upsert: true));
        }
        urls.add(storage.getPublicUrl('cliniques/$filename'));
      } catch (e) {
        debugPrint("Erreur upload image : $e");
      }
    }
    return urls;
  }

  Future<void> _removeImage(int index) async {
    // suppression d'une image déjà en base
    if (index < imagesUrls.length) {
      final imageUrl = imagesUrls[index];
      final pathInStorage = _storagePathFromPublicUrl(imageUrl);
      if (pathInStorage != null) {
        try {
          await Supabase.instance.client.storage.from(_bucket).remove([pathInStorage]);
        } catch (e) {
          debugPrint("Erreur suppression storage : $e");
        }
      }
      final updated = List<String>.from(imagesUrls)..removeAt(index);
      imagesUrls = updated;
      if (widget.clinique?['id'] != null) {
        try {
          await Supabase.instance.client.from('cliniques').update({'images': updated}).eq('id', widget.clinique!['id']);
        } catch (e) {
          debugPrint("Erreur update DB : $e");
        }
      }
    } else {
      // suppression locale pour les nouvelles images
      final newIndex = index - imagesUrls.length;
      if (newIndex >= 0 && newIndex < newFiles.length) {
        setState(() => newFiles.removeAt(newIndex));
      }
    }
    setState(() {});
  }

  Future<void> _save() async {
    setState(() => loading = true);
    final newUrls = await _uploadImages();
    final allImages = [...imagesUrls, ...newUrls];

    final data = {
      'nom': nomController.text.trim(),
      'ville': villeController.text.trim(),
      'adresse': adresseController.text.trim(),
      'tel': telephoneController.text.trim(),
      'description': descriptionController.text.trim(),
      'specialites': specialitesController.text.trim(),
      'horaires': horairesController.text.trim(),
      'latitude': double.tryParse(latitudeController.text.trim()),
      'longitude': double.tryParse(longitudeController.text.trim()),
      'images': allImages,
    };

    final id = widget.clinique?['id'];

    try {
      if (id != null) {
        await Supabase.instance.client.from('cliniques').update(data).eq('id', id);
      } else {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await Supabase.instance.client.from('cliniques').insert({...data, 'user_id': userId});
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Clinique enregistrée avec succès !")),
        );
        Navigator.pop(context, {...?widget.clinique, ...data});
      }
    } catch (e) {
      debugPrint("Erreur enregistrement : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'enregistrement : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Supprimer cette clinique ?"),
            content: const Text("Cette action est irréversible."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Supprimer", style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;

    if (confirm && widget.clinique?['id'] != null) {
      try {
        await Supabase.instance.client.from('cliniques').delete().eq('id', widget.clinique!['id']);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Clinique supprimée.")),
          );
        }
      } catch (e) {
        debugPrint("Erreur de suppression : $e");
      }
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
        title: const Text("Modifier la clinique", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: bleuMaGuinee),
        actions: [
          if (widget.clinique != null)
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _delete),
        ],
        elevation: 1,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text("Photos de la clinique :", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...imagesUrls.asMap().entries.map((entry) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(entry.value, width: 70, height: 70, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _removeImage(entry.key),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.85),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 19),
                                ),
                              ),
                            ),
                          ],
                        )),
                    ...newFiles.asMap().entries.map((entry) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb
                                  ? Image.network(entry.value.path, width: 70, height: 70, fit: BoxFit.cover)
                                  : Image.file(File(entry.value.path), width: 70, height: 70, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _removeImage(entry.key + imagesUrls.length),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.85),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 19),
                                ),
                              ),
                            ),
                          ],
                        )),
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
                const SizedBox(height: 16),
                _buildTextField(nomController, "Nom de la clinique *", bleuMaGuinee),
                _buildTextField(villeController, "Ville *", bleuMaGuinee),
                _buildTextField(adresseController, "Adresse *", bleuMaGuinee),
                _buildTextField(telephoneController, "Téléphone *", bleuMaGuinee),
                _buildTextField(descriptionController, "Description", bleuMaGuinee, maxLines: 3),
                _buildTextField(specialitesController, "Spécialités", bleuMaGuinee),
                _buildTextField(horairesController, "Horaires", bleuMaGuinee),
                _buildTextField(latitudeController, "Latitude", bleuMaGuinee),
                _buildTextField(longitudeController, "Longitude", bleuMaGuinee),
                const SizedBox(height: 20),
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
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, Color color,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          labelStyle: TextStyle(color: color),
        ),
      ),
    );
  }
}
