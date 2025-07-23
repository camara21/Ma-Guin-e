import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class EditCliniquePage extends StatefulWidget {
  final Map<String, dynamic> clinique;
  const EditCliniquePage({super.key, required this.clinique});

  @override
  State<EditCliniquePage> createState() => _EditCliniquePageState();
}

class _EditCliniquePageState extends State<EditCliniquePage> {
  late TextEditingController nomController;
  late TextEditingController villeController;
  late TextEditingController descriptionController;
  late TextEditingController telephoneController;
  late TextEditingController whatsappController;
  List<File> newFiles = [];
  List<String> imagesUrls = [];

  bool loading = false;

  @override
  void initState() {
    super.initState();
    nomController = TextEditingController(text: widget.clinique['nom'] ?? '');
    villeController = TextEditingController(text: widget.clinique['ville'] ?? '');
    descriptionController = TextEditingController(text: widget.clinique['description'] ?? '');
    telephoneController = TextEditingController(text: widget.clinique['tel'] ?? '');
    whatsappController = TextEditingController(text: widget.clinique['whatsapp'] ?? '');
    imagesUrls = (widget.clinique['images'] as List?)?.cast<String>() ?? [];
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 75);
    if (pickedFiles.isNotEmpty) {
      setState(() {
        newFiles.addAll(pickedFiles.map((x) => File(x.path)));
      });
    }
  }

  Future<List<String>> _uploadImages() async {
    final storage = Supabase.instance.client.storage.from('clinique-photos');
    List<String> urls = [];
    for (var file in newFiles) {
      final filename = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      await storage.upload(filename, file);
      urls.add(storage.getPublicUrl(filename));
    }
    return urls;
  }

  Future<void> _save() async {
    setState(() => loading = true);

    // Upload new files, keep the existing urls
    final uploaded = await _uploadImages();
    final allImages = [...imagesUrls, ...uploaded];

    final data = {
      'nom': nomController.text,
      'ville': villeController.text,
      'description': descriptionController.text,
      'tel': telephoneController.text,
      'whatsapp': whatsappController.text,
      'images': allImages,
    };

    await Supabase.instance.client
        .from('cliniques')
        .update(data)
        .eq('id', widget.clinique['id']);

    setState(() => loading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Clinique modifiée !")),
      );
      Navigator.pop(context, {...widget.clinique, ...data});
    }
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer cette clinique ?"),
        content: const Text("Cette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Supabase.instance.client
                  .from('cliniques')
                  .delete()
                  .eq('id', widget.clinique['id']);
              if (mounted) {
                Navigator.pop(context, null);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Clinique supprimée.")),
                );
              }
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      imagesUrls.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Modifier ma clinique"),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.teal),
        actions: [
          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _delete),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Multi-photo existantes
                const Text("Photos actuelles :", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < imagesUrls.length; i++)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(imagesUrls[i], width: 70, height: 70, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 2, right: 2,
                            child: GestureDetector(
                              onTap: () => _removeImage(i),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.8),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    for (var file in newFiles)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(file, width: 70, height: 70, fit: BoxFit.cover),
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
                        child: const Icon(Icons.add_a_photo, size: 30, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(labelText: "Nom de la clinique", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: villeController,
                  decoration: const InputDecoration(labelText: "Ville", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: telephoneController,
                  decoration: const InputDecoration(labelText: "Téléphone", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: whatsappController,
                  decoration: const InputDecoration(labelText: "WhatsApp", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text("Enregistrer"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                ),
              ],
            ),
    );
  }
}
