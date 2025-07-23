import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditPrestatairePage extends StatefulWidget {
  final Map<String, dynamic> prestataire;
  const EditPrestatairePage({super.key, required this.prestataire});

  @override
  State<EditPrestatairePage> createState() => _EditPrestatairePageState();
}

class _EditPrestatairePageState extends State<EditPrestatairePage> {
  late TextEditingController jobController;
  late TextEditingController villeController;
  late TextEditingController descriptionController;
  late TextEditingController phoneController;
  File? _photoFile;
  bool _isUploading = false;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    jobController = TextEditingController(text: widget.prestataire['job'] ?? '');
    villeController = TextEditingController(text: widget.prestataire['city'] ?? '');
    phoneController = TextEditingController(text: widget.prestataire['phone'] ?? '');
    descriptionController = TextEditingController(text: widget.prestataire['description'] ?? '');
    _imageUrl = widget.prestataire['image'] ?? '';
  }

  @override
  void dispose() {
    jobController.dispose();
    villeController.dispose();
    phoneController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImageAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    setState(() {
      _isUploading = true;
      _photoFile = File(picked.path);
    });

    try {
      final supabase = Supabase.instance.client;
      final fileExt = picked.path.split('.').last.toLowerCase();
      final prestataireId = widget.prestataire['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      final fileName = 'presta_$prestataireId.$fileExt';
      final filePath = 'prestataires/$fileName';

      final bytes = await picked.readAsBytes();

      // Supabase v2 : uploadBinary renvoie l'URL ou lève une exception
      await supabase.storage.from('prestataires').uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );

      final publicUrl = supabase.storage.from('prestataires').getPublicUrl(filePath);

      // Met à jour la photo dans la base de données prestataire
      await supabase
          .from('prestataires')
          .update({'image': publicUrl})
          .eq('id', prestataireId);

      setState(() {
        _imageUrl = publicUrl;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Photo mise à jour avec succès !")),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'upload : $e")),
      );
    }
  }

  Future<void> _save() async {
    final supabase = Supabase.instance.client;
    final prestataireId = widget.prestataire['id'];

    try {
      await supabase.from('prestataires').update({
        'job': jobController.text.trim(),
        'city': villeController.text.trim(),
        'phone': phoneController.text.trim(),
        'description': descriptionController.text.trim(),
        'image': _imageUrl ?? widget.prestataire['image'] ?? '',
      }).eq('id', prestataireId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil prestataire mis à jour avec succès !")),
      );
      Navigator.pop(context, true); // Retourne true pour signaler succès
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la sauvegarde : $e")),
      );
    }
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer ce profil prestataire ?"),
        content: const Text("Cette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final supabase = Supabase.instance.client;
              final prestataireId = widget.prestataire['id'];
              try {
                await supabase.from('prestataires').delete().eq('id', prestataireId);
                Navigator.pop(context, true); // Retour succès suppression
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Prestataire supprimé.")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Erreur lors de la suppression : $e")),
                );
              }
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Modifier mon espace prestataire"),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
        actions: [
          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundImage: _photoFile != null
                      ? FileImage(_photoFile!)
                      : (_imageUrl != null && _imageUrl!.isNotEmpty)
                          ? NetworkImage(_imageUrl!)
                          : const AssetImage('assets/avatar.png') as ImageProvider,
                  backgroundColor: Colors.grey[200],
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: InkWell(
                    onTap: _isUploading ? null : _pickImageAndUpload,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      child: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit, color: Color(0xFF113CFC), size: 21),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: jobController,
            decoration: const InputDecoration(labelText: "Métier", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: villeController,
            decoration: const InputDecoration(labelText: "Ville", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: phoneController,
            decoration: const InputDecoration(labelText: "Téléphone", border: OutlineInputBorder()),
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
            label: const Text("Enregistrer les modifications"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF009460),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
