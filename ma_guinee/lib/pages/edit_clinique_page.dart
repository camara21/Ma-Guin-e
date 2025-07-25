import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class EditCliniquePage extends StatefulWidget {
  final Map<String, dynamic>? clinique;
  const EditCliniquePage({super.key, this.clinique});

  @override
  State<EditCliniquePage> createState() => _EditCliniquePageState();
}

class _EditCliniquePageState extends State<EditCliniquePage> {
  late TextEditingController nomController;
  late TextEditingController villeController;
  late TextEditingController descriptionController;
  late TextEditingController telephoneController;
  late TextEditingController whatsappController;

  List<XFile> newFiles = [];
  List<String> imagesUrls = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    final clinique = widget.clinique ?? {};
    nomController = TextEditingController(text: clinique['nom'] ?? '');
    villeController = TextEditingController(text: clinique['ville'] ?? '');
    descriptionController = TextEditingController(text: clinique['description'] ?? '');
    telephoneController = TextEditingController(text: clinique['tel'] ?? '');
    whatsappController = TextEditingController(text: clinique['whatsapp'] ?? '');
    imagesUrls = (clinique['images'] as List?)?.cast<String>() ?? [];
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 75);
    if (picked.isNotEmpty) {
      setState(() {
        newFiles.addAll(picked);
      });
    }
  }

  Future<List<String>> _uploadImages() async {
    final storage = Supabase.instance.client.storage.from('clinique-photos');
    List<String> urls = [];

    for (var file in newFiles) {
      final filename = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';

      try {
        final fileData = kIsWeb
            ? await file.readAsBytes()
            : File(file.path);

        await storage.upload(
          filename,
          fileData,
          fileOptions: const FileOptions(upsert: true),
        );

        final publicUrl = storage.getPublicUrl(filename);
        urls.add(publicUrl);
      } catch (e) {
        debugPrint("Erreur lors de l'upload de l’image : $e");
      }
    }

    return urls;
  }

  Future<void> _save() async {
    setState(() => loading = true);

    final newUrls = await _uploadImages();
    final allImages = [...imagesUrls, ...newUrls];

    final data = {
      'nom': nomController.text.trim(),
      'ville': villeController.text.trim(),
      'description': descriptionController.text.trim(),
      'tel': telephoneController.text.trim(),
      'whatsapp': whatsappController.text.trim(),
      'images': allImages,
    };

    final id = widget.clinique?['id'];

    try {
      if (id != null) {
        await Supabase.instance.client
            .from('cliniques')
            .update(data)
            .eq('id', id);
      } else {
        await Supabase.instance.client.from('cliniques').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Clinique enregistrée avec succès.")),
        );
        Navigator.pop(context, {...?widget.clinique, ...data});
      }
    } catch (e) {
      debugPrint("Erreur d'enregistrement : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de l'enregistrement.")),
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
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Annuler"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm && widget.clinique?['id'] != null) {
      try {
        await Supabase.instance.client
            .from('cliniques')
            .delete()
            .eq('id', widget.clinique!['id']);

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

  void _removeImage(int index) {
    setState(() => imagesUrls.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Modifier la clinique"),
        actions: [
          if (widget.clinique != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _delete,
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text("Images actuelles"),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...imagesUrls.asMap().entries.map(
                      (entry) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              entry.value,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _removeImage(entry.key),
                              child: const Icon(Icons.cancel, color: Colors.red, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...newFiles.map((x) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb
                              ? Image.network(x.path, width: 70, height: 70, fit: BoxFit.cover)
                              : Image.file(File(x.path), width: 70, height: 70, fit: BoxFit.cover),
                        )),
                    InkWell(
                      onTap: _pickImages,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_a_photo, size: 30),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(labelText: "Nom", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: villeController,
                  decoration: const InputDecoration(labelText: "Ville", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: telephoneController,
                  decoration: const InputDecoration(labelText: "Téléphone", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: whatsappController,
                  decoration: const InputDecoration(labelText: "WhatsApp", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text("Enregistrer"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }
}
