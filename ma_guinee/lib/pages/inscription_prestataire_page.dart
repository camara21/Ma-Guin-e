import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/user_provider.dart';

class InscriptionPrestatairePage extends StatefulWidget {
  const InscriptionPrestatairePage({super.key});

  @override
  State<InscriptionPrestatairePage> createState() => _InscriptionPrestatairePageState();
}

class _InscriptionPrestatairePageState extends State<InscriptionPrestatairePage> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedJob;
  String _city = '';
  String _description = '';
  XFile? _pickedImage;
  bool _isUploading = false;
  String? _uploadedImageUrl;

  static const String _bucket = 'prestataire-photos';

  final Map<String, List<String>> _categories = {
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

  String _categoryForJob(String? job) {
    if (job == null) return '';
    for (final e in _categories.entries) {
      if (e.value.contains(job)) return e.key;
    }
    return '';
  }

  /// Nettoie le nom du fichier pour Supabase Storage (pas d’espace, accent, etc)
  String _cleanFileName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\d\-_\.]'), '_'); // autorise . - _ et alphanum
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final res = await picker.pickImage(source: ImageSource.gallery, imageQuality: 72);
    if (res == null) return;
    setState(() => _pickedImage = res);
    await _uploadImage(res);
  }

  Future<void> _uploadImage(XFile file) async {
    setState(() => _isUploading = true);
    try {
      final supa = Supabase.instance.client;
      final uid = context.read<UserProvider>().utilisateur!.id;

      // Nettoyage du nom de fichier et chemin dossier
      final cleanFileName = _cleanFileName(file.name);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$cleanFileName';
      final storagePath = '$uid/$fileName';

      final storage = supa.storage.from(_bucket);
      if (kIsWeb) {
        await storage.uploadBinary(
          storagePath,
          await file.readAsBytes(),
          fileOptions: const FileOptions(upsert: true),
        );
      } else {
        await storage.upload(
          storagePath,
          File(file.path),
          fileOptions: const FileOptions(upsert: true),
        );
      }

      final publicUrl = storage.getPublicUrl(storagePath);

      setState(() {
        _uploadedImageUrl = publicUrl;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo d’activité téléchargée !')),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'upload : $e")),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = context.read<UserProvider>().utilisateur!;
    final supa = Supabase.instance.client;

    final row = {
      'utilisateur_id': user.id,
      'metier': _selectedJob,
      'category': _categoryForJob(_selectedJob), // 💡 Auto-catégorisation ici
      'ville': _city.trim(),
      'description': _description.trim(),
      'photo_url': _uploadedImageUrl ?? '',
      'date_ajout': DateTime.now().toIso8601String(),
    };

    try {
      final existing = await supa
          .from('prestataires')
          .select('id')
          .eq('utilisateur_id', user.id)
          .maybeSingle();

      if (existing != null) {
        await supa.from('prestataires').update(row).eq('utilisateur_id', user.id);
      } else {
        await supa.from('prestataires').insert(row);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inscription prestataire réussie !')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().utilisateur;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Connectez-vous pour vous inscrire en tant que prestataire.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFFCE1126)),
        title: const Text(
          'Inscription Prestataire',
          style: TextStyle(color: Color(0xFFCE1126), fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Header prestataire
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFCE1126), Color(0xFFFCD116)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.09),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.engineering, color: Color(0xFFCE1126), size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Prestataire : ${user.prenom} ${user.nom}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.5)),
                          Text('Tel : ${user.telephone}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
                          Text(user.email,
                              style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Photo
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickImage,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF009460), width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.photo_camera, color: Color(0xFF009460)),
                    label: Text(
                      _isUploading ? 'Chargement...' : 'Photo activité',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF009460),
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_uploadedImageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.network(
                        _uploadedImageUrl!,
                        width: 63,
                        height: 63,
                        fit: BoxFit.cover,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              // Métier
              DropdownButtonFormField<String>(
                value: _selectedJob,
                decoration: _inputDecoration('Sélectionnez un métier'),
                items: _categories.entries
                    .expand((entry) => entry.value.map(
                          (job) => DropdownMenuItem<String>(
                            value: job,
                            child: Text('${entry.key} → $job'),
                          ),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedJob = val),
                validator: (v) => v == null ? 'Veuillez sélectionner un métier' : null,
              ),
              if (_selectedJob != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 12),
                  child: Text(
                    'Catégorie détectée : ${_categoryForJob(_selectedJob)}',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ),

              // Ville
              TextFormField(
                decoration: _inputDecoration('Ville'),
                onChanged: (v) => _city = v,
                validator: (v) => v == null || v.isEmpty ? 'Ville requise' : null,
              ),
              const SizedBox(height: 13),

              // Téléphone (readonly)
              TextFormField(
                initialValue: user.telephone,
                readOnly: true,
                decoration: _inputDecoration('Numéro de téléphone').copyWith(
                  fillColor: const Color(0xFFF3F4F6),
                ),
              ),
              const SizedBox(height: 13),

              // Description
              TextFormField(
                maxLines: 3,
                decoration: _inputDecoration('Description de votre activité'),
                onChanged: (v) => _description = v,
              ),
              const SizedBox(height: 22),

              // Bouton Valider
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009460),
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: const Text('Valider mon inscription',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFFBBBBBB)),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      );
}
