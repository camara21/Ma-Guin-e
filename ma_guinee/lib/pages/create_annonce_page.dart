import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Compression (module qu’on vient de faire)
import 'package:ma_guinee/utils/image_compressor/image_compressor.dart';

// ===== PALETTE FIXE (rouge doux, cohérente avec les autres pages) =====
const Color annoncesPrimary = Color(0xFFD92D20); // rouge doux (actions)
const Color annoncesSecondary = Color(0xFFFFF1F1); // fond très léger
const Color annoncesOnPrimary = Color(0xFFFFFFFF);
const Color annoncesOnSecondary = Color(0xFF1F2937);

// Neutres
const Color _pageBg = Color(0xFFF5F7FA);
const Color _cardBg = Color(0xFFFFFFFF);
const Color _stroke = Color(0xFFE5E7EB);
const Color _text = Color(0xFF1F2937);
const Color _text2 = Color(0xFF6B7280);

// ===== Lieux Guinée (préfectures / communes / quartiers / secteurs) =====
// ✅ Triée A→Z, noms indépendants, sans doublons.
const List<String> _guineaCities = [
  'Almamya',
  'Aéroport Gbéssia',
  'Bambéto',
  'Bantounka',
  'Bellevue',
  'Beyla',
  'Boffa',
  'Boké',
  'Bonfi',
  'Boulbinet',
  'Camayenne',
  'Conakry',
  'Coronthie',
  'Cosa',
  'Coyah',
  'Dabola',
  'Dabondy',
  'Dalaba',
  'Dinguiraye',
  'Dixinn',
  'Dubréka',
  'Enta',
  'Faranah',
  'Forécariah',
  'Fria',
  'Gaoual',
  'Gbéssia',
  'Guéckédou',
  'Hafia',
  'Hamdallaye',
  'Kagbelen',
  'Kaloum',
  'Kamsar',
  'Kankan',
  'Kaporo-Rails',
  'Kassonyah',
  'Kérouané',
  'Kindia',
  'Kintinian',
  'Kipé',
  'Kissidougou',
  'Kobaya',
  'Kolaboui',
  'Koloma',
  'Koubia',
  'Koundara',
  'Kouroussa',
  'Kountia',
  'Labé',
  'Lambanyi',
  'Lélouma',
  'Lola',
  'Macenta',
  'Madina',
  'Mali',
  'Mamou',
  'Mandiana',
  'Manéah',
  'Matam',
  'Matoto',
  'Moribayah',
  'Nongo',
  'Nzérékoré',
  'Pita',
  'Ratoma',
  'Sangarédi',
  'Sangoyah',
  'Sanoyah',
  'Siguiri',
  'Simbaya',
  'Sonfonia',
  'Tannerie',
  'Taouyah',
  'Télimélé',
  'Tombo',
  'Tombolia',
  'Tougué',
  'Wanindara',
  'Yattaya',
  'Yomou',
];

String _normalizePlace(String s) {
  var x = s.trim().toLowerCase();
  x = x
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ô', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ç', 'c');
  x = x.replaceAll(RegExp(r'\s+'), ' ');
  return x;
}

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

  String _ville = '';

  final List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();

  bool _loading = false;
  int? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _prixController.addListener(_onPrixChanged);
    _loadCategories();
  }

  @override
  void dispose() {
    _prixController.removeListener(_onPrixChanged);
    _titreController.dispose();
    _descriptionController.dispose();
    _prixController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  void _onPrixChanged() {
    final text = _prixController.text;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      if (text.isEmpty) return;
      _prixController.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      return;
    }

    final value = int.tryParse(digits);
    if (value == null) return;

    final formatted =
        NumberFormat('#,##0', 'en_US').format(value).replaceAll(',', '.');

    if (formatted == text) return;

    _prixController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _loadCategories() async {
    final response = await Supabase.instance.client.from('categories').select();
    setState(() {
      _categories = List<Map<String, dynamic>>.from(response);
    });
  }

  IconData _iconForCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('immobilier')) return Icons.home_work_outlined;
    if (n.contains('véhicule') ||
        n.contains('vehicule') ||
        n.contains('auto')) {
      return Icons.directions_car;
    }
    if (n.contains('vacance') || n.contains('voyage'))
      return Icons.beach_access;
    if (n.contains('emploi') || n.contains('job') || n.contains('travail')) {
      return Icons.work_outline;
    }
    if (n.contains('service')) return Icons.handshake;
    if (n.contains('famille')) return Icons.family_restroom;
    if (n.contains('électronique') ||
        n.contains('electronique') ||
        n.contains('tech')) {
      return Icons.devices_other;
    }
    if (n.contains('mode')) return Icons.checkroom;
    if (n.contains('loisir') || n.contains('sport')) return Icons.sports_soccer;
    if (n.contains('animal')) return Icons.pets;
    if (n.contains('maison') || n.contains('jardin')) return Icons.chair_alt;
    if (n.contains('matériel') || n.contains('materiel') || n.contains('pro')) {
      return Icons.build;
    }
    if (n.contains('autre')) return Icons.category;
    return Icons.category_outlined;
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
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

  // ✅ Upload + compression (mobile + web + desktop via ton module)
  Future<List<String>> _uploadImages() async {
    final storage = Supabase.instance.client.storage.from('annonce-photos');

    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    final List<String> urls = [];

    for (int i = 0; i < _images.length; i++) {
      final file = _images[i];

      // bytes originaux
      final rawBytes = await file.readAsBytes();

      // ✅ compression prod
      final c = await ImageCompressor.compressBytes(
        rawBytes,
        maxSide: 1600,
        quality: 82,
        maxBytes: 900 * 1024,
        keepPngIfTransparent: true,
      );

      final nameBase = DateTime.now().microsecondsSinceEpoch;
      final objectPath = 'annonces/$userId/${nameBase}_$i.${c.extension}';

      await storage.uploadBinary(
        objectPath,
        c.bytes,
        fileOptions: FileOptions(
          contentType: c.contentType,
          upsert: true,
        ),
      );

      urls.add(storage.getPublicUrl(objectPath));
    }

    return urls;
  }

  String? _normalizeGuineaPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    String d = digits;
    if (d.startsWith('00224')) {
      d = d.substring(5);
    } else if (d.startsWith('224')) {
      d = d.substring(3);
    }

    if (d.length != 9) return null;
    return '+224$d';
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

    final normalizedPhone =
        _normalizeGuineaPhone(_telephoneController.text.trim());
    if (normalizedPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Numéro guinéen invalide")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final uploadedUrls = await _uploadImages();
      final user = Supabase.instance.client.auth.currentUser;

      final prixStr = _prixController.text.replaceAll('.', '').trim();
      final prix = int.tryParse(prixStr) ?? 0;

      final data = {
        'titre': _titreController.text.trim(),
        'description': _descriptionController.text.trim(),
        'prix': prix,
        'telephone': normalizedPhone,
        'ville': _ville.trim(),
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
            color: _text,
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
                    TextFormField(
                      controller: _titreController,
                      decoration: _input('Titre', icon: Icons.edit_outlined),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Entrez un titre'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration:
                          _input('Description', icon: Icons.description),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Entrez une description'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _prixController,
                      keyboardType: TextInputType.number,
                      decoration: _input('Prix (GNF)'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Indiquez un prix'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue value) {
                        final typed = value.text.trim();
                        final q = _normalizePlace(typed);

                        // Si vide, propose quelques suggestions (évite une liste énorme)
                        if (q.isEmpty) return _guineaCities.take(18);

                        final matches = _guineaCities
                            .where((p) => _normalizePlace(p).contains(q))
                            .take(18)
                            .toList(growable: false);

                        // ✅ Option “Utiliser ce que j’ai tapé” si pas déjà dans la liste
                        final alreadyExists = _guineaCities.any(
                          (p) => _normalizePlace(p) == _normalizePlace(typed),
                        );

                        if (typed.isNotEmpty && !alreadyExists) {
                          return <String>[typed, ...matches];
                        }
                        return matches;
                      },
                      onSelected: (String selection) {
                        _ville = selection; // ✅ garde la valeur sélectionnée
                      },
                      fieldViewBuilder: (context, textController, focusNode,
                          onFieldSubmitted) {
                        return TextFormField(
                          controller: textController,
                          focusNode: focusNode,
                          decoration: _input('Ville / quartier / secteur',
                              icon: Icons.location_on),
                          textInputAction: TextInputAction.next,

                          // ✅ autorise la saisie libre
                          onChanged: (value) => _ville = value,

                          // ✅ si l’utilisateur valide au clavier sans choisir une suggestion
                          onFieldSubmitted: (value) {
                            _ville = value;
                            onFieldSubmitted();
                          },

                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Entrez une ville / quartier / secteur'
                              : null,
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 6,
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxHeight: 240, maxWidth: 600),
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: options.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1, color: _stroke),
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);

                                  // 👇 si c’est la valeur tapée (non présente dans la liste), on l’indique
                                  final isTypedValue = !_guineaCities.any(
                                    (p) =>
                                        _normalizePlace(p) ==
                                        _normalizePlace(option),
                                  );

                                  return ListTile(
                                    dense: true,
                                    title: Text(option,
                                        style: const TextStyle(color: _text)),
                                    subtitle: isTypedValue
                                        ? const Text('Utiliser cette valeur',
                                            style: TextStyle(
                                                color: _text2, fontSize: 12))
                                        : null,
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: annoncesSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: annoncesPrimary.withOpacity(0.15)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.info_outline,
                              size: 18, color: annoncesPrimary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Ce numéro permet à vos clients de vous joindre "
                              "directement et de recevoir des appels même lorsque "
                              "vous n’êtes pas connecté(e) à Soneya. Utilisez un "
                              "numéro guinéen actif que vous consultez régulièrement.",
                              style: TextStyle(
                                  color: _text2, fontSize: 12.5, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextFormField(
                      controller: _telephoneController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration:
                          _input('Téléphone (Guinée)', icon: Icons.phone),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Entrez un numéro';
                        return _normalizeGuineaPhone(v) == null
                            ? 'Entrez un numéro guinéen valide'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedCategoryId,
                      decoration:
                          _input('Catégorie', icon: Icons.category_outlined),
                      hint: const Text('Choisissez une catégorie',
                          style: TextStyle(color: _text2)),
                      validator: (v) =>
                          (v == null) ? 'Choisissez une catégorie' : null,
                      items: _categories.map((cat) {
                        final nom = (cat['nom'] ?? 'Inconnu').toString();
                        return DropdownMenuItem<int>(
                          value: cat['id'] as int,
                          child: Row(
                            children: [
                              Icon(_iconForCategory(nom),
                                  size: 18, color: _text2),
                              const SizedBox(width: 8),
                              Text(nom, style: const TextStyle(color: _text)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCategoryId = val),
                    ),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Photos",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: _text),
                      ),
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
                            borderRadius: BorderRadius.circular(17)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
