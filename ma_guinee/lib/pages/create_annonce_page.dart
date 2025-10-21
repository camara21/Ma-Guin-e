import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ===== PALETTE FIXE (rouge doux, cohérente avec les autres pages) =====
const Color annoncesPrimary     = Color(0xFFD92D20); // rouge doux (actions)
const Color annoncesSecondary   = Color(0xFFFFF1F1); // fond très léger
const Color annoncesOnPrimary   = Color(0xFFFFFFFF);
const Color annoncesOnSecondary = Color(0xFF1F2937);

// Neutres
const Color _pageBg   = Color(0xFFF5F7FA);
const Color _cardBg   = Color(0xFFFFFFFF);
const Color _stroke   = Color(0xFFE5E7EB);
const Color _text     = Color(0xFF1F2937);
const Color _text2    = Color(0xFF6B7280);

class CreateAnnoncePage extends StatefulWidget {
  const CreateAnnoncePage({super.key});

  @override
  State<CreateAnnoncePage> createState() => _CreateAnnoncePageState();
}

class _CreateAnnoncePageState extends State<CreateAnnoncePage> {
  final _formKey = GlobalKey<FormState>();

  final _titreController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prixController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _villeController = TextEditingController();

  final List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();

  bool _loading = false;
  int? _selectedCategoryId; // <- reste NULL tant que l'utilisateur n'a pas choisi
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final response = await Supabase.instance.client.from('categories').select();
    setState(() {
      _categories = List<Map<String, dynamic>>.from(response);
      // NE PAS pré-remplir : on laisse _selectedCategoryId == null
    });
  }

  // — Icônes de catégories (mêmes pictos que la page principale)
  IconData _iconForCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('immobilier')) return Icons.home_work_outlined;
    if (n.contains('véhicule') || n.contains('vehicule') || n.contains('auto')) return Icons.directions_car;
    if (n.contains('vacance') || n.contains('voyage')) return Icons.beach_access;
    if (n.contains('emploi') || n.contains('job') || n.contains('travail')) return Icons.work_outline;
    if (n.contains('service')) return Icons.handshake;
    if (n.contains('famille')) return Icons.family_restroom;
    if (n.contains('électronique') || n.contains('electronique') || n.contains('tech')) return Icons.devices_other;
    if (n.contains('mode')) return Icons.checkroom;
    if (n.contains('loisir') || n.contains('sport')) return Icons.sports_soccer;
    if (n.contains('animal')) return Icons.pets;
    if (n.contains('maison') || n.contains('jardin')) return Icons.chair_alt;
    if (n.contains('matériel') || n.contains('materiel') || n.contains('pro')) return Icons.build;
    if (n.contains('autre')) return Icons.category;
    return Icons.category_outlined;
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked != null && picked.isNotEmpty) {
      setState(() => _images.addAll(picked));
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  Widget _imagePreview(int index) {
    final file = _images[index];
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: file.readAsBytes(),
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(
              width: 90, height: 90,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.memory(snap.data!, width: 90, height: 90, fit: BoxFit.cover),
          );
        },
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Image.file(File(file.path), width: 90, height: 90, fit: BoxFit.cover),
      );
    }
  }

  Future<List<String>> _uploadImages() async {
    final storage = Supabase.instance.client.storage.from('annonce-photos');
    final List<String> urls = [];
    for (final file in _images) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        await storage.uploadBinary(fileName, bytes);
      } else {
        await storage.upload(fileName, File(file.path));
      }
      urls.add(storage.getPublicUrl(fileName));
    }
    return urls;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ajoutez au moins une photo")),
      );
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Choisissez une catégorie")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final uploadedUrls = await _uploadImages();
      final user = Supabase.instance.client.auth.currentUser;

      final data = {
        'titre': _titreController.text.trim(),
        'description': _descriptionController.text.trim(),
        'prix': int.tryParse(_prixController.text.trim()) ?? 0,
        'telephone': _telephoneController.text.trim(),
        'ville': _villeController.text.trim(),
        'categorie_id': _selectedCategoryId,
        'images': uploadedUrls,
        'user_id': user?.id,
        'date_creation': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client.from('annonces').insert(data);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Annonce publiée avec succès")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _input(String label, {IconData? icon}) {
    // Icône grise; seul l’état "focus" utilise la bordure rouge
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: _text2) : null,
      filled: true,
      fillColor: _cardBg,
      labelStyle: const TextStyle(color: _text2),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: _stroke),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: _stroke),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: annoncesPrimary, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _cardBg,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: annoncesPrimary),
        title: const Text(
          'Déposer une annonce',
          style: TextStyle(
            color: _text, // titre neutre (pas rouge)
            fontWeight: FontWeight.bold,
            fontSize: 21,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // TITRE
                    TextFormField(
                      controller: _titreController,
                      decoration: _input('Titre', icon: Icons.edit_outlined),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Entrez un titre' : null,
                    ),
                    const SizedBox(height: 16),

                    // DESCRIPTION
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: _input('Description', icon: Icons.description),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Entrez une description'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // PRIX
                    TextFormField(
                      controller: _prixController,
                      keyboardType: TextInputType.number,
                      decoration: _input('Prix (GNF)', icon: Icons.price_change),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Indiquez un prix'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // VILLE
                    TextFormField(
                      controller: _villeController,
                      decoration: _input('Ville', icon: Icons.location_on),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Entrez une ville'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // TÉLÉPHONE
                    TextFormField(
                      controller: _telephoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _input('Téléphone', icon: Icons.phone),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Entrez un numéro'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // CATÉGORIE (PAS PRÉ-REMPLIE + icône dans les options)
                    DropdownButtonFormField<int>(
                      value: _selectedCategoryId, // reste null par défaut
                      decoration: _input('Catégorie', icon: Icons.category_outlined),
                      hint: const Text('Choisissez une catégorie', style: TextStyle(color: _text2)),
                      validator: (v) =>
                          (v == null) ? 'Choisissez une catégorie' : null,
                      items: _categories
                          .map((cat) {
                            final nom = (cat['nom'] ?? 'Inconnu').toString();
                            return DropdownMenuItem<int>(
                              value: cat['id'] as int,
                              child: Row(
                                children: [
                                  Icon(_iconForCategory(nom), size: 18, color: _text2),
                                  const SizedBox(width: 8),
                                  Text(nom, style: const TextStyle(color: _text)),
                                ],
                              ),
                            );
                          })
                          .toList(),
                      onChanged: (val) => setState(() => _selectedCategoryId = val),
                    ),
                    const SizedBox(height: 24),

                    // PHOTOS
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Photos",
                          style: TextStyle(fontWeight: FontWeight.bold, color: _text)),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (int i = 0; i < _images.length; i++)
                          Stack(
                            children: [
                              _imagePreview(i),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removeImage(i),
                                  child: const CircleAvatar(
                                    radius: 13,
                                    backgroundColor: annoncesPrimary,
                                    child: Icon(Icons.close,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        // Ajout photo
                        InkWell(
                          onTap: _pickImages,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              border: Border.all(color: annoncesPrimary),
                              borderRadius: BorderRadius.circular(13),
                              color: annoncesSecondary,
                            ),
                            child: const Icon(Icons.add_a_photo,
                                size: 28, color: annoncesPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // BOUTON
                    ElevatedButton.icon(
                      onPressed: _submitForm,
                      icon: const Icon(Icons.send),
                      label: const Text("Publier l'annonce"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: annoncesPrimary,
                        foregroundColor: annoncesOnPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 38, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
