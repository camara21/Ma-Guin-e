import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/user_provider.dart';

class InscriptionPrestatairePage extends StatefulWidget {
  const InscriptionPrestatairePage({super.key});

  @override
  State<InscriptionPrestatairePage> createState() =>
      _InscriptionPrestatairePageState();
}

class _InscriptionPrestatairePageState
    extends State<InscriptionPrestatairePage> {
  // ==== Palette Prestataire (teal) ====
  static const Color kTeal       = Color(0xFF0EA5A4); // primaire
  static const Color kTealDark   = Color(0xFF0B8A89); // gradient start
  static const Color kTealLight  = Color(0xFF14B8A6); // gradient end / accents
  static const Color kBgSoft     = Color(0xFFF8F8FB);

  final _formKey = GlobalKey<FormState>();

  // Champs
  String? _selectedJob;
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final res =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 72);
    if (res == null) return;
    setState(() => _pickedImage = res);
    await _uploadImage(res);
  }

  Future<void> _uploadImage(XFile file) async {
    setState(() => _isUploading = true);
    try {
      final supa = Supabase.instance.client;
      final uid = context.read<UserProvider>().utilisateur!.id;

      final cleanFileName = _cleanFileName(file.name);
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$cleanFileName';
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
          const SnackBar(content: Text('Photo d’activité téléversée !')),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'upload : $e")),
      );
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
        setState(() {
          _hasExisting = true;
          _selectedJob = (row['metier'] ?? '') as String?;
          _city = (row['ville'] ?? '').toString();
          _description = (row['description'] ?? '').toString();

          final existingPhone = (row['phone'] ?? '').toString();
          _prestatairePhone = existingPhone;

          if (existingPhone.startsWith(kDialCode)) {
            _nationalNumber =
                existingPhone.substring(kDialCode.length).replaceAll(RegExp(r'\D'), '');
          } else {
            _nationalNumber = existingPhone.replaceAll(RegExp(r'\D'), '');
          }

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

    final digits = _nationalNumber.replaceAll(RegExp(r'\D'), '');
    final normalizedPhone = '$kDialCode$digits';

    final row = {
      'utilisateur_id': user.id,
      'metier': _selectedJob,
      'category': _categoryForJob(_selectedJob),
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
        await supa.from('prestataires').update(row).eq('utilisateur_id', user.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vos informations prestataire ont été mises à jour.')),
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
          await supa.from('prestataires').update(row).eq('utilisateur_id', user.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vos informations prestataire ont été mises à jour.')),
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
        body: Center(child: Text('Connectez-vous pour vous inscrire en tant que prestataire.')),
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
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
                      child: Icon(Icons.engineering, color: kTeal, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Prestataire : ${user.prenom} ${user.nom}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.5)),
                          Text('Tel compte : ${user.telephone}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13.5)),
                          Text(user.email,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13.5)),
                        ],
                      ),
                    ),
                    if (_hasExisting)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text('Déjà inscrit',
                            style: TextStyle(color: Colors.white)),
                      ),
                  ],
                ),
              ),

              // Photo activité (teal)
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickImage,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kTeal, width: 2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      backgroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.photo_camera, color: kTeal),
                    label: Text(
                      _isUploading ? 'Chargement...' : 'Photo activité',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: kTeal,
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
                            child: Text('${entry.key} • $job'),
                          ),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedJob = val),
                validator: (v) =>
                    v == null ? 'Veuillez sélectionner un métier' : null,
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
                initialValue: _city.isEmpty ? null : _city,
                decoration: _inputDecoration('Ville'),
                onChanged: (v) => _city = v,
                validator: (v) => v == null || v.isEmpty ? 'Ville requise' : null,
              ),
              const SizedBox(height: 13),

              // Téléphone prestataire (+224 fixe)
              TextFormField(
                initialValue: _nationalNumber.isEmpty ? null : _nationalNumber,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\s\-]')),
                ],
                decoration: _inputDecoration('Numéro du prestataire (ex: 6x xx xx xx)')
                    .copyWith(
                  prefixText: '$kDialCode ',
                  prefixStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onChanged: (v) => _nationalNumber = v,
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  if (digits.isEmpty) return 'Téléphone requis';
                  if (digits.length < 8) return 'Numéro trop court';
                  return null;
                },
              ),
              const SizedBox(height: 13),

              // Description
              TextFormField(
                initialValue: _description.isEmpty ? null : _description,
                maxLines: 3,
                decoration: _inputDecoration('Description de votre activité'),
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
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    elevation: 2,
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline,
                          color: Colors.white),
                  label: Text(
                    _isSaving
                        ? 'Enregistrement…'
                        : (_hasExisting
                            ? 'Mettre à jour mon inscription'
                            : 'Valider mon inscription'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 17),
                  ),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      );
}
