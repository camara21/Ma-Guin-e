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
    jobController = TextEditingController(text: widget.prestataire['metier'] ?? widget.prestataire['job'] ?? '');
    villeController = TextEditingController(text: widget.prestataire['ville'] ?? widget.prestataire['city'] ?? '');
    phoneController = TextEditingController(text: widget.prestataire['phone'] ?? '');
    descriptionController = TextEditingController(text: widget.prestataire['description'] ?? '');
    _imageUrl = widget.prestataire['image'] ?? widget.prestataire['photo_url'] ?? '';
  }

  @override
  void dispose() {
    jobController.dispose();
    villeController.dispose();
    phoneController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  String _categoryForJob(String? job) {
    if (job == null) return '';
    final Map<String, List<String>> categories = {
      'Artisans & BTP': [
        'Maçon', 'Plombier', 'Électricien', 'Soudeur', 'Charpentier',
        'Couvreur', 'Peintre en bâtiment', 'Mécanicien', 'Menuisier',
        'Vitrier', 'Tôlier', 'Carreleur', 'Poseur de fenêtres/portes', 'Ferrailleur',
      ],
      // ... (autres catégories inchangées)
    };
    for (final e in categories.entries) {
      if (e.value.contains(job)) return e.key;
    }
    return '';
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
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw "Utilisateur non connecté.";
      final fileExt = picked.path.split('.').last.toLowerCase();
      final prestataireId = widget.prestataire['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      final fileName = 'presta_$prestataireId.$fileExt';
      // *** CHEMIN DOIT COMMENCER PAR L’ID UTILISATEUR ! ***
      final filePath = '$userId/$fileName';

      final bytes = await picked.readAsBytes();

      await supabase.storage.from('prestataire-photos').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          metadata: {'owner': userId}, // bonus, pas obligatoire
        ),
      );

      final publicUrl = supabase.storage.from('prestataire-photos').getPublicUrl(filePath);

      await supabase
          .from('prestataires')
          .update({'image': publicUrl})
          .eq('id', prestataireId);

      setState(() {
        _imageUrl = publicUrl;
        _photoFile = null; // ← CORRECTION ICI pour forcer l'affichage direct de l'image réseau
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Photo de profil mise à jour avec succès !")),
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
    final metier = jobController.text.trim();

    if (metier.isEmpty || villeController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tous les champs obligatoires doivent être remplis.")),
      );
      return;
    }

    try {
      await supabase.from('prestataires').update({
        'metier': metier,
        'category': _categoryForJob(metier),
        'ville': villeController.text.trim(),
        'phone': phoneController.text.trim(),
        'description': descriptionController.text.trim(),
        'image': _imageUrl ?? widget.prestataire['image'] ?? '',
      }).eq('id', prestataireId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil prestataire mis à jour avec succès !")),
      );
      Navigator.pop(context, true);
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
                Navigator.pop(context, true);
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
    final Color bleuMaGuinee = const Color(0xFF113CFC);
    final Color vert = const Color(0xFF009460);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Modifier mon espace prestataire", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: bleuMaGuinee),
        actions: [
          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _delete),
        ],
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 46,
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
                          : Icon(Icons.edit, color: bleuMaGuinee, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 23),
          TextField(
            controller: jobController,
            decoration: InputDecoration(
              labelText: "Métier *",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              labelStyle: TextStyle(color: bleuMaGuinee),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: villeController,
            decoration: InputDecoration(
              labelText: "Ville *",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              labelStyle: TextStyle(color: bleuMaGuinee),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: phoneController,
            decoration: InputDecoration(
              labelText: "Téléphone *",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              labelStyle: TextStyle(color: bleuMaGuinee),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 15),
          TextField(
            controller: descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: "Description",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              labelStyle: TextStyle(color: bleuMaGuinee),
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text("Enregistrer les modifications"),
            style: ElevatedButton.styleFrom(
              backgroundColor: vert,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
