// lib/pages/inscription_prestataire_page.dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/user_provider.dart';

// ✅ Compression (même module que Annonces/Resto/Lieux)
import 'package:ma_guinee/utils/image_compressor/image_compressor.dart';

class InscriptionPrestatairePage extends StatefulWidget {
  const InscriptionPrestatairePage({super.key});

  @override
  State<InscriptionPrestatairePage> createState() =>
      _InscriptionPrestatairePageState();
}

class _InscriptionPrestatairePageState
    extends State<InscriptionPrestatairePage> {
  // ==== Palette Prestataire (teal) ====
  static const Color kTeal = Color(0xFF0EA5A4); // primaire
  static const Color kTealDark = Color(0xFF0B8A89); // gradient start
  static const Color kTealLight = Color(0xFF14B8A6); // gradient end / accents
  static const Color kBgSoft = Color(0xFFF8F8FB);

  final _formKey = GlobalKey<FormState>();

  // Champs
  String? _selectedCategory; // domaine (ex: Technologies & Digital)
  String? _selectedJob; // métier (ex: Ingénieur logiciel)

  // ✅ Controllers (pour conserver les valeurs en modification)
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  // On garde ces variables (compat logique existante)
  String _city = '';
  String _description = '';

  // Téléphone (Guinée uniquement)
  static const String kDialCode = '+224';
  String _nationalNumber = '';
  String _prestatairePhone = '';

  // Image activité
  XFile? _pickedImage;
  bool _isUploading = false;
  bool _isSaving = false;
  bool _hasExisting = false;
  String? _uploadedImageUrl;

  static const String _bucket = 'prestataire-photos';

  final Map<String, List<String>> _categories = {
    'Artisans & BTP': [
      'Maçon',
      'Plombier',
      'Électricien',
      'Soudeur',
      'Charpentier',
      'Couvreur',
      'Peintre en bâtiment',
      'Mécanicien',
      'Menuisier',
      'Vitrier',
      'Tôlier',
      'Carreleur',
      'Poseur de fenêtres/portes',
      'Ferrailleur',
    ],
    'Beauté & Bien-être': [
      'Coiffeur / Coiffeuse',
      'Esthéticienne',
      'Maquilleuse',
      'Barbier',
      'Masseuse',
      'Spa thérapeute',
      'Onglerie / Prothésiste ongulaire',
    ],
    'Couture & Mode': [
      'Couturier / Couturière',
      'Styliste / Modéliste',
      'Brodeur / Brodeuse',
      'Teinturier',
      'Designer textile',
    ],
    'Alimentation': [
      'Cuisinier',
      'Traiteur',
      'Boulanger',
      'Pâtissier',
      'Vendeur de fruits/légumes',
      'Marchand de poisson',
      'Restaurateur',
    ],
    'Transport & Livraison': [
      'Chauffeur particulier',
      'Taxi-moto',
      'Taxi-brousse',
      'Livreur',
      'Transporteur',
    ],
    'Services domestiques': [
      'Femme de ménage',
      'Nounou',
      'Agent d’entretien',
      'Gardiennage',
      'Blanchisserie',
    ],
    'Services professionnels': [
      'Secrétaire',
      'Traducteur',
      'Comptable',
      'Consultant',
      'Notaire',
    ],
    'Éducation & formation': [
      'Enseignant',
      'Tuteur',
      'Formateur',
      'Professeur particulier',
      'Coach scolaire',
    ],
    'Santé & Bien-être': [
      'Infirmier',
      'Docteur',
      'Kinésithérapeute',
      'Psychologue',
      'Pharmacien',
      'Médecine traditionnelle',
    ],
    'Technologies & Digital': [
      'Développeur / Développeuse',
      'Ingénieur logiciel',
      'Data Scientist',
      'Développeur mobile',
      'Designer UI/UX',
      'Administrateur systèmes',
      'Chef de projet IT',
      'Technicien réseau',
      'Analyste sécurité',
      'Community Manager',
      'Growth Hacker',
      'Webmaster',
      'DevOps Engineer',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _categoryForJob(String? job) {
    if (job == null) return '';
    for (final e in _categories.entries) {
      if (e.value.contains(job)) return e.key;
    }
    return '';
  }

  String _cleanFileName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^\w\d\-_\.]'), '_');
  }

  String _stripExtension(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot <= 0) return filename;
    return filename.substring(0, dot);
  }

  // ✅ Normalisation téléphone :
  // - l'utilisateur peut saisir: 6xxxxxxx, 62 xx xx xx, +2246..., 002246...
  // - si pas d'indicatif, on suppose GN et on préfixe +224
  String _normalizePhoneInput(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return '';

    final compact = raw.replaceAll(RegExp(r'[\s\-]'), '');
    if (compact.startsWith('+')) {
      return '+${compact.substring(1).replaceAll(RegExp(r'\D'), '')}';
    }
    if (compact.startsWith('00')) {
      return '+${compact.substring(2).replaceAll(RegExp(r'\D'), '')}';
    }

    final digits = compact.replaceAll(RegExp(r'\D'), '');

    // Si l'utilisateur tape 224xxxx..., on ajoute le +
    if (digits.startsWith('224') && digits.length >= 11) {
      return '+$digits';
    }

    // Sinon, on considère que c'est un numéro national GN
    return '$kDialCode$digits';
  }

  // ✅ affichage sympa en modification : si DB = +224xxxx, on montre sans indicatif
  String _displayPhone(String dbPhone) {
    final p = dbPhone.trim();
    if (p.isEmpty) return '';
    final compact = p.replaceAll(RegExp(r'[\s\-]'), '');
    if (compact.startsWith('+224')) return compact.substring(4);
    if (compact.startsWith('224')) return compact.substring(3);
    if (compact.startsWith('00224')) return compact.substring(5);
    return p;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    // ✅ pas de imageQuality : on compresse nous-mêmes avant l’upload
    final res = await picker.pickImage(source: ImageSource.gallery);
    if (res == null) return;

    setState(() => _pickedImage = res);
    await _uploadImage(res);
  }

  // ✅ Upload avec compression (identique à Annonces/Resto/Lieux)
  Future<void> _uploadImage(XFile file) async {
    setState(() => _isUploading = true);

    try {
      final supa = Supabase.instance.client;
      final uid = context.read<UserProvider>().utilisateur!.id;
      final storage = supa.storage.from(_bucket);

      // 1) bytes originaux
      final Uint8List rawBytes = await file.readAsBytes();

      // 2) compression prod
      final c = await ImageCompressor.compressBytes(
        rawBytes,
        maxSide: 1600,
        quality: 82,
        maxBytes: 900 * 1024,
        keepPngIfTransparent: true,
      );

      // 3) nom safe + extension issue du compresseur
      final clean = _cleanFileName(file.name.isEmpty ? 'photo.png' : file.name);
      final base = _stripExtension(clean).trim().isEmpty
          ? 'photo_activite'
          : _stripExtension(clean);

      final fileName =
          '${DateTime.now().microsecondsSinceEpoch}_$base.${c.extension}';
      final storagePath = '$uid/$fileName';

      // 4) upload binaire + contentType
      await storage.uploadBinary(
        storagePath,
        c.bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: c.contentType,
        ),
      );

      final publicUrl = storage.getPublicUrl(storagePath);

      setState(() => _uploadedImageUrl = publicUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo d’activité téléversée !')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'upload : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _loadExisting() async {
    final supa = Supabase.instance.client;
    final user = context.read<UserProvider>().utilisateur;
    if (user == null) return;

    try {
      final row = await supa
          .from('prestataires')
          .select('metier, category, ville, description, photo_url, phone')
          .eq('utilisateur_id', user.id)
          .maybeSingle();

      if (row != null) {
        final existingCategory = (row['category'] ?? '').toString();
        final existingJob = (row['metier'] ?? '').toString();

        setState(() {
          _hasExisting = true;

          // Domaine
          if (existingCategory.isNotEmpty &&
              _categories.containsKey(existingCategory)) {
            _selectedCategory = existingCategory;
          } else {
            _selectedCategory = null;
          }

          // Métier
          if (_selectedCategory != null &&
              _categories[_selectedCategory]!.contains(existingJob)) {
            _selectedJob = existingJob;
          } else {
            _selectedJob = null;
          }

          _city = (row['ville'] ?? '').toString();
          _description = (row['description'] ?? '').toString();

          // ✅ Controllers gardent toujours les infos en modification
          _cityCtrl.text = _city;
          _descCtrl.text = _description;

          final existingPhone = (row['phone'] ?? '').toString();
          _prestatairePhone = existingPhone;

          // ✅ on affiche sans +224, mais on conserve la valeur DB
          final shown = _displayPhone(existingPhone);
          _phoneCtrl.text = shown;

          _nationalNumber = shown.replaceAll(RegExp(r'\D'), '');

          _uploadedImageUrl = (row['photo_url'] ?? '').toString().isEmpty
              ? null
              : row['photo_url'].toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = context.read<UserProvider>().utilisateur!;
    final supa = Supabase.instance.client;

    // ✅ Prend toujours les valeurs des controllers (pas de perte en update)
    _city = _cityCtrl.text;
    _description = _descCtrl.text;

    final inputPhone = _phoneCtrl.text;
    final normalizedPhone = _normalizePhoneInput(inputPhone);

    // garde aussi la variable existante (compat)
    _nationalNumber = inputPhone;

    final row = {
      'utilisateur_id': user.id,
      'metier': _selectedJob,
      'category': _selectedCategory ?? _categoryForJob(_selectedJob),
      'ville': _city.trim(),
      'description': _description.trim(),
      'phone': normalizedPhone,
      'photo_url': _uploadedImageUrl ?? '',
      'date_ajout': DateTime.now().toIso8601String(),
    };

    setState(() => _isSaving = true);
    try {
      final existing = await supa
          .from('prestataires')
          .select('id')
          .eq('utilisateur_id', user.id)
          .maybeSingle();

      if (existing != null) {
        await supa
            .from('prestataires')
            .update(row)
            .eq('utilisateur_id', user.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vos informations prestataire ont été mises à jour.'),
          ),
        );
        Navigator.pop(context, true);
        return;
      }

      await supa.from('prestataires').insert(row);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inscription prestataire réussie !')),
      );
      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        try {
          await supa
              .from('prestataires')
              .update(row)
              .eq('utilisateur_id', user.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Vos informations prestataire ont été mises à jour.'),
            ),
          );
          Navigator.pop(context, true);
          return;
        } catch (_) {}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().utilisateur;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Connectez-vous pour vous inscrire en tant que prestataire.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBgSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: kTeal),
        title: const Text(
          'Inscription Prestataire',
          style: TextStyle(color: kTeal, fontWeight: FontWeight.bold),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallWidth = constraints.maxWidth < 360;
          final horizontalPadding = isSmallWidth ? 12.0 : 18.0;
          final verticalPadding = constraints.maxHeight < 650 ? 12.0 : 22.0;

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // Bandeau info (gradient teal)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [kTealDark, kTealLight],
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
                          child: Icon(
                            Icons.engineering,
                            color: kTeal,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Prestataire : ${user.prenom} ${user.nom}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.5,
                                ),
                              ),
                              Text(
                                'Tel compte : ${user.telephone}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                user.email,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_hasExisting)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'Déjà inscrit',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Photo activité (teal) - responsive
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _isUploading ? null : _pickImage,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kTeal, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallWidth ? 8 : 10,
                              vertical: 6,
                            ),
                            backgroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.photo_camera, color: kTeal),
                          label: Text(
                            _isUploading ? 'Chargement...' : 'Photo activité',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: kTeal,
                              fontSize: isSmallWidth ? 15 : 18,
                            ),
                          ),
                        ),
                      ),
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

                  // Domaine (catégorie)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedCategory,
                    decoration: _inputDecoration('Sélectionnez un domaine'),
                    items: _categories.keys
                        .map(
                          (cat) => DropdownMenuItem<String>(
                            value: cat,
                            child: Text(cat),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCategory = val;
                        _selectedJob = null; // reset métier
                      });
                    },
                    validator: (v) =>
                        v == null ? 'Veuillez sélectionner un domaine' : null,
                  ),
                  const SizedBox(height: 10),

                  // Métier dans le domaine choisi
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedJob,
                    decoration: _inputDecoration('Sélectionnez un métier'),
                    items: (_selectedCategory == null)
                        ? const <DropdownMenuItem<String>>[]
                        : _categories[_selectedCategory]!
                            .map(
                              (job) => DropdownMenuItem<String>(
                                value: job,
                                child: Text(job),
                              ),
                            )
                            .toList(),
                    onChanged: _selectedCategory == null
                        ? null
                        : (val) => setState(() => _selectedJob = val),
                    validator: (v) {
                      if (_selectedCategory == null) {
                        return 'Sélectionnez d’abord un domaine';
                      }
                      if (v == null) {
                        return 'Veuillez sélectionner un métier';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Ville (✅ controller)
                  TextFormField(
                    controller: _cityCtrl,
                    decoration: _inputDecoration('Ville'),
                    onChanged: (v) => _city = v,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Ville requise' : null,
                  ),
                  const SizedBox(height: 13),

                  // Téléphone prestataire (✅ plus de +224 par défaut)
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9\s\-\+]'),
                      ),
                    ],
                    decoration: _inputDecoration(
                      'Numéro du prestataire (ex: 6x xx xx xx ou +224...)',
                    ),
                    onChanged: (v) => _nationalNumber = v,
                    validator: (v) {
                      final raw = (v ?? '').trim();
                      if (raw.isEmpty) return 'Téléphone requis';

                      // validation simple : minimum 8 chiffres
                      final digits = raw.replaceAll(RegExp(r'\D'), '');
                      if (digits.length < 8) return 'Numéro trop court';
                      return null;
                    },
                  ),
                  const SizedBox(height: 13),

                  // Description (✅ controller)
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration:
                        _inputDecoration('Description de votre activité'),
                    onChanged: (v) => _description = v,
                  ),
                  const SizedBox(height: 22),

                  // Bouton Valider (teal)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_isUploading || _isSaving) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTeal,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallWidth ? 14 : 17,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isSmallWidth ? 18 : 20,
                          ),
                        ),
                        elevation: 2,
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isSaving
                            ? 'Enregistrement…'
                            : (_hasExisting
                                ? 'Mettre à jour mon inscription'
                                : 'Valider mon inscription'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      );
}
