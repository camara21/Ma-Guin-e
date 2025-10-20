// lib/pages/edit_annonce_page.dart
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/annonce_model.dart';

// ====== Palette Annonces (tes valeurs exactes) ======
const kAnnoncePrimary     = Color(0xFF1E3A8A);
const kAnnonceSecondary   = Color(0xFF60A5FA);
const kAnnonceOnPrimary   = Color(0xFFFFFFFF);
const kAnnonceOnSecondary = Color(0xFF000000);

// Neutres (tu peux ajuster si besoin)
const kAnnonceBg   = Color(0xFFF8F8FB);
const kAnnonceCard = Colors.white;
// ====================================================

class EditAnnoncePage extends StatefulWidget {
  final Map<String, dynamic> annonce; // tu passes déjà un Map dans routes
  const EditAnnoncePage({super.key, required this.annonce});

  @override
  State<EditAnnoncePage> createState() => _EditAnnoncePageState();
}

class _EditAnnoncePageState extends State<EditAnnoncePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titreController;
  late TextEditingController _descriptionController;
  late TextEditingController _prixController;
  late TextEditingController _telephoneController;
  late TextEditingController _villeController;

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _newImages = []; // nouvelles images non uploadées
  List<String> _oldUrls = []; // images déjà en ligne

  bool _loading = false;
  int? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();

    final a = AnnonceModel.fromJson(widget.annonce);
    _titreController = TextEditingController(text: a.titre);
    _descriptionController = TextEditingController(text: a.description);
    _prixController = TextEditingController(text: a.prix.toStringAsFixed(0));
    _telephoneController = TextEditingController(text: a.telephone);
    _villeController = TextEditingController(text: a.ville);

    _oldUrls = List<String>.from(a.images);
    _selectedCategoryId = a.categorieId;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final response =
          await Supabase.instance.client.from('categories').select();
      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
        _selectedCategoryId ??=
            _categories.isNotEmpty ? _categories.first['id'] : null;
      });
    } catch (_) {}
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked != null && picked.isNotEmpty) {
      setState(() => _newImages.addAll(picked));
    }
  }

  void _removeNewImage(int index) {
    setState(() => _newImages.removeAt(index));
  }

  void _removeOldImage(int index) {
    setState(() => _oldUrls.removeAt(index));
  }

  Widget _previewNew(int index) {
    final file = _newImages[index];
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: file.readAsBytes(),
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(
              width: 90,
              height: 90,
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

  Widget _previewOld(int index) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Image.network(
        _oldUrls[index],
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 90,
          height: 90,
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, size: 32),
        ),
      ),
    );
  }

  Future<List<String>> _uploadNewImages() async {
    final storage = Supabase.instance.client.storage.from('annonce-photos');
    final List<String> urls = [];

    for (final file in _newImages) {
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Choisissez une catégorie")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final newUrls = await _uploadNewImages();
      final allUrls = [..._oldUrls, ...newUrls];

      final data = {
        'titre': _titreController.text.trim(),
        'description': _descriptionController.text.trim(),
        'prix': int.tryParse(_prixController.text.trim()) ?? 0,
        'telephone': _telephoneController.text.trim(),
        'ville': _villeController.text.trim(),
        'categorie_id': _selectedCategoryId,
        'images': allUrls,
      };

      await Supabase.instance.client
          .from('annonces')
          .update(data)
          .eq('id', widget.annonce['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Annonce mise à jour.")),
        );
        Navigator.pop(context, data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erreur : $e")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _input(String label, {IconData? icon, Color? iconColor}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon, color: iconColor ?? kAnnoncePrimary),
      filled: true,
      fillColor: kAnnonceCard,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: kAnnoncePrimary, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAnnonceBg,
      appBar: AppBar(
        backgroundColor: kAnnoncePrimary,
        elevation: 1,
        iconTheme: const IconThemeData(color: kAnnonceOnPrimary),
        title: const Text(
          'Modifier l’annonce',
          style: TextStyle(
            color: kAnnonceOnPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            color: kAnnonceOnPrimary,
            onPressed: _loading ? null : _save,
            tooltip: "Enregistrer",
          )
        ],
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
                      validator: (v) => v!.isEmpty ? 'Entrez un titre' : null,
                    ),
                    const SizedBox(height: 16),

                    // DESCRIPTION
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: _input('Description', icon: Icons.description),
                      validator: (v) => v!.isEmpty ? 'Entrez une description' : null,
                    ),
                    const SizedBox(height: 16),

                    // PRIX
                    TextFormField(
                      controller: _prixController,
                      keyboardType: TextInputType.number,
                      decoration: _input(
                        'Prix (GNF)',
                        icon: Icons.price_change,
                        iconColor: kAnnonceSecondary, // accent conforme
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Indiquez un prix' : null,
                    ),
                    const SizedBox(height: 16),

                    // VILLE
                    TextFormField(
                      controller: _villeController,
                      decoration: _input('Ville', icon: Icons.location_on),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Entrez une ville' : null,
                    ),
                    const SizedBox(height: 16),

                    // TÉLÉPHONE
                    TextFormField(
                      controller: _telephoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _input(
                        'Téléphone',
                        icon: Icons.phone,
                        iconColor: kAnnonceSecondary,
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Entrez un numéro' : null,
                    ),
                    const SizedBox(height: 16),

                    // CATÉGORIE
                    DropdownButtonFormField<int>(
                      value: _selectedCategoryId,
                      decoration: _input(
                        'Catégorie',
                        icon: Icons.category_outlined,
                        iconColor: kAnnonceSecondary,
                      ),
                      items: _categories
                          .map((cat) => DropdownMenuItem<int>(
                                value: cat['id'],
                                child: Text(cat['nom'] ?? 'Inconnue'),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedCategoryId = val),
                    ),
                    const SizedBox(height: 24),

                    // PHOTOS EXISTANTES
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Photos existantes",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kAnnoncePrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (int i = 0; i < _oldUrls.length; i++)
                          Stack(
                            children: [
                              _previewOld(i),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removeOldImage(i),
                                  child: const CircleAvatar(
                                    radius: 13,
                                    backgroundColor: kAnnonceSecondary,
                                    child: Icon(Icons.close, size: 16, color: kAnnonceOnSecondary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // AJOUTER DE NOUVELLES PHOTOS
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Ajouter de nouvelles photos",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kAnnoncePrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (int i = 0; i < _newImages.length; i++)
                          Stack(
                            children: [
                              _previewNew(i),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removeNewImage(i),
                                  child: const CircleAvatar(
                                    radius: 13,
                                    backgroundColor: kAnnonceSecondary,
                                    child: Icon(Icons.close, size: 16, color: kAnnonceOnSecondary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        InkWell(
                          onTap: _pickImages,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              border: Border.all(color: kAnnoncePrimary),
                              borderRadius: BorderRadius.circular(13),
                              color: kAnnonceCard,
                            ),
                            child: const Icon(Icons.add_a_photo, size: 28, color: kAnnoncePrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // BOUTON ENREGISTRER
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save, color: kAnnonceOnPrimary),
                      label: const Text("Enregistrer", style: TextStyle(color: kAnnonceOnPrimary)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAnnoncePrimary,
                        foregroundColor: kAnnonceOnPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 16),
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
