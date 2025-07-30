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
    jobController = TextEditingController(text: widget.prestataire['job'] ?? widget.prestataire['metier'] ?? '');
    villeController = TextEditingController(text: widget.prestataire['city'] ?? widget.prestataire['ville'] ?? '');
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
      'Beauté & Bien-être': [
        'Coiffeur / Coiffeuse', 'Esthéticienne', 'Maquilleuse',
        'Barbier', 'Masseuse', 'Spa thérapeute', 'Onglerie / Prothésiste ongulaire',
      ],
      'Couture & Mode': [
        'Couturier / Couturière', 'Styliste / Modéliste', 'Brodeur / Brodeuse',
        'Teinturier', 'Designer textile',
      ],
      'Alimentation': [
        'Cuisinier', 'Traiteur', 'Boulanger', 'Pâtissier',
        'Vendeur de fruits/légumes', 'Marchand de poisson', 'Restaurateur',
      ],
      'Transport & Livraison': [
        'Chauffeur particulier', 'Taxi-moto', 'Taxi-brousse',
        'Livreur', 'Transporteur',
      ],
      'Services domestiques': [
        'Femme de ménage', 'Nounou', 'Agent d’entretien',
        'Gardiennage', 'Blanchisserie',
      ],
      'Services professionnels': [
        'Secrétaire', 'Traducteur', 'Comptable',
        'Consultant', 'Notaire',
      ],
      'Éducation & formation': [
        'Enseignant', 'Tuteur', 'Formateur',
        'Professeur particulier', 'Coach scolaire',
      ],
      'Santé & Bien-être': [
        'Infirmier', 'Docteur', 'Kinésithérapeute',
        'Psychologue', 'Pharmacien', 'Médecine traditionnelle',
      ],
      'Technologies & Digital': [
        'Développeur / Développeuse', 'Ingénieur logiciel', 'Data Scientist',
        'Développeur mobile', 'Designer UI/UX', 'Administrateur systèmes',
        'Chef de projet IT', 'Technicien réseau', 'Analyste sécurité',
        'Community Manager', 'Growth Hacker', 'Webmaster', 'DevOps Engineer',
      ],
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
      final fileExt = picked.path.split('.').last.toLowerCase();
      final prestataireId = widget.prestataire['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      final fileName = 'presta_$prestataireId.$fileExt';
      final filePath = 'prestataires/$fileName';

      final bytes = await picked.readAsBytes();

      await supabase.storage.from('prestataires').uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );

      final publicUrl = supabase.storage.from('prestataires').getPublicUrl(filePath);

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
    final job = jobController.text.trim();

    try {
      await supabase.from('prestataires').update({
        'job': job,
        'category': _categoryForJob(job), // 💡 ajout ici
        'city': villeController.text.trim(),
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
