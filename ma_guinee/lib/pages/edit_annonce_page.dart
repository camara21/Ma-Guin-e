// lib/pages/edit_annonce_page.dart
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/annonce_model.dart';

// ✅ Compression (même module que CreateAnnoncePage)
import 'package:ma_guinee/utils/image_compressor/image_compressor.dart';

// ====== PALETTE FIXE (rouge doux cohérente) ======
const kAnnoncePrimary = Color(0xFFD92D20); // rouge doux (actions)
const kAnnoncePrimaryDark = Color(0xFFB42318); // variante pressée
const kAnnonceSecondary = Color(0xFFFFF1F1); // fond très léger
const kAnnonceOnPrimary = Color(0xFFFFFFFF);
const kAnnonceOnSecondary = Color(0xFF1F2937);

// Neutres
const kAnnonceBg = Color(0xFFF5F7FA);
const kAnnonceCard = Color(0xFFFFFFFF);
const kStroke = Color(0xFFE5E7EB);
const kText = Color(0xFF1F2937);
const kText2 = Color(0xFF6B7280);
// ========================================

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

  // ✅ Pour supprimer de Supabase Storage les anciennes images retirées (optionnel mais recommandé)
  final List<String> _oldUrlsToDelete = [];

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

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    _prixController.dispose();
    _telephoneController.dispose();
    _villeController.dispose();
    super.dispose();
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
    if (picked.isNotEmpty) {
      setState(() => _newImages.addAll(picked));
    }
  }

  void _removeNewImage(int index) {
    setState(() => _newImages.removeAt(index));
  }

  void _removeOldImage(int index) {
    final removed = _oldUrls.removeAt(index);
    _oldUrlsToDelete.add(removed); // ✅ marquer pour suppression storage
    setState(() {});
  }

  Widget _previewNew(int index) {
    final file = _newImages[index];
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: file.readAsBytes(),
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done ||
              snap.data == null) {
            return const SizedBox(
              width: 90,
              height: 90,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.memory(
              snap.data!,
              width: 90,
              height: 90,
              fit: BoxFit.cover,
            ),
          );
        },
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Image.file(
          File(file.path),
          width: 90,
          height: 90,
          fit: BoxFit.cover,
        ),
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

  // ✅ Upload des nouvelles images avec compression (identique à CreateAnnoncePage)
  Future<List<String>> _uploadNewImages() async {
    if (_newImages.isEmpty) return [];

    final storage = Supabase.instance.client.storage.from('annonce-photos');
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'anon';

    final List<String> urls = [];

    for (int i = 0; i < _newImages.length; i++) {
      final file = _newImages[i];

      // 1) bytes originaux
      final rawBytes = await file.readAsBytes();

      // 2) compression prod
      final c = await ImageCompressor.compressBytes(
        rawBytes,
        maxSide: 1600,
        quality: 82,
        maxBytes: 900 * 1024,
        keepPngIfTransparent: true,
      );

      // 3) chemin cohérent avec CreateAnnoncePage
      final nameBase = DateTime.now().microsecondsSinceEpoch;
      final objectPath = 'annonces/$userId/${nameBase}_$i.${c.extension}';

      // 4) upload binaire + contentType
      await storage.uploadBinary(
        objectPath,
        c.bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: c.contentType,
        ),
      );

      urls.add(storage.getPublicUrl(objectPath));
    }

    return urls;
  }

  // ✅ (Optionnel mais recommandé) supprimer dans Supabase Storage les images anciennes retirées
  Future<void> _deleteOldImagesFromStorage(List<String> urls) async {
    if (urls.isEmpty) return;
    final storage = Supabase.instance.client.storage.from('annonce-photos');

    for (final url in urls) {
      try {
        final uri = Uri.parse(url);
        final seg = List<String>.from(uri.pathSegments);

        // URL publique typique:
        // /storage/v1/object/public/annonce-photos/<objectPath...>
        final idx = seg.indexOf('annonce-photos');
        if (idx == -1 || idx + 1 >= seg.length) continue;

        final objectPath = seg.sublist(idx + 1).join('/');
        await storage.remove([objectPath]);
      } catch (_) {
        // silencieux (ne bloque pas l'update)
      }
    }
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

      // ✅ Après update DB, on nettoie le storage des anciennes images supprimées
      if (_oldUrlsToDelete.isNotEmpty) {
        await _deleteOldImagesFromStorage(_oldUrlsToDelete);
        _oldUrlsToDelete.clear();
      }

      // reset nouvelles images
      _newImages.clear();

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
    // Icônes NEUTRES; la bordure passe au rouge uniquement au focus
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: kText2),
      prefixIcon: icon == null ? null : Icon(icon, color: iconColor ?? kText2),
      filled: true,
      fillColor: kAnnonceCard,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: kStroke),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: kStroke),
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
        backgroundColor: kAnnonceCard,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: kAnnoncePrimary),
        title: const Text(
          'Modifier l’annonce',
          style: TextStyle(
            color: kText, // titre neutre (pas rouge)
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: kAnnoncePrimary),
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
                    TextFormField(
                      controller: _titreController,
                      decoration: _input('Titre', icon: Icons.edit_outlined),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Entrez un titre' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration:
                          _input('Description', icon: Icons.description),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Entrez une description'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _prixController,
                      keyboardType: TextInputType.number,
                      decoration:
                          _input('Prix (GNF)', icon: Icons.price_change),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Indiquez un prix'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _villeController,
                      decoration: _input('Ville', icon: Icons.location_on),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Entrez une ville'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _telephoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _input('Téléphone', icon: Icons.phone),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Entrez un numéro'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedCategoryId,
                      decoration:
                          _input('Catégorie', icon: Icons.category_outlined),
                      items: _categories
                          .map((cat) => DropdownMenuItem<int>(
                                value: cat['id'],
                                child: Text(
                                  cat['nom'] ?? 'Inconnue',
                                  style: const TextStyle(color: kText),
                                ),
                              ))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCategoryId = val),
                    ),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Photos existantes",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kText,
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
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: kAnnonceOnSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Ajouter de nouvelles photos",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kText,
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
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: kAnnonceOnSecondary,
                                    ),
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
                            child: const Icon(
                              Icons.add_a_photo,
                              size: 28,
                              color: kAnnoncePrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _save,
                      icon: const Icon(Icons.save),
                      label: const Text("Enregistrer"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAnnoncePrimary,
                        foregroundColor: kAnnonceOnPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 38,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ).copyWith(
                        overlayColor: MaterialStateProperty.resolveWith(
                          (s) => s.contains(MaterialState.pressed)
                              ? kAnnoncePrimaryDark.withOpacity(.12)
                              : null,
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
