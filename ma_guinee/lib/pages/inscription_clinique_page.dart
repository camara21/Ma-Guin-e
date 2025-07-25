import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InscriptionCliniquePage extends StatefulWidget {
  final Map<String, dynamic>? clinique;

  const InscriptionCliniquePage({super.key, this.clinique});

  @override
  State<InscriptionCliniquePage> createState() =>
      _InscriptionCliniquePageState();
}

class _InscriptionCliniquePageState extends State<InscriptionCliniquePage> {
  final _formKey = GlobalKey<FormState>();

  String nom = '';
  String adresse = '';
  String ville = '';
  String tel = '';
  String whatsapp = '';
  String description = '';
  XFile? _pickedImage;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  final String _bucket = 'clinique-photos';

  @override
  void initState() {
    super.initState();
    if (widget.clinique != null) {
      final c = widget.clinique!;
      nom = c['nom'] ?? '';
      adresse = c['adresse'] ?? '';
      ville = c['ville'] ?? '';
      tel = c['tel'] ?? '';
      whatsapp = c['whatsapp'] ?? '';
      description = c['description'] ?? '';
      if (c['images'] is List && c['images'].isNotEmpty) {
        _uploadedImageUrl = c['images'][0];
      }
    }
  }

  Future<void> _choisirImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _pickedImage = picked);
    }
  }

  Future<String?> _uploadImage(XFile imageFile) async {
    try {
      final ext = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await imageFile.readAsBytes();

      final path = 'cliniques/$fileName';
      await Supabase.instance.client.storage
          .from(_bucket)
          .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));

      final url = Supabase.instance.client.storage
          .from(_bucket)
          .getPublicUrl(path);

      return url;
    } catch (e) {
      debugPrint("Erreur d'upload: $e");
      return null;
    }
  }

  Future<void> _enregistrerClinique() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    String? imageUrl = _uploadedImageUrl;

    if (_pickedImage != null) {
      imageUrl = await _uploadImage(_pickedImage!);
    }

    final cliniqueData = {
      'nom': nom,
      'adresse': adresse,
      'ville': ville,
      'tel': tel,
      'whatsapp': whatsapp,
      'description': description,
      'images': imageUrl != null ? [imageUrl] : [],
      'user_id': userId,
    };

    try {
      if (widget.clinique != null) {
        // Modification
        await Supabase.instance.client
            .from('cliniques')
            .update(cliniqueData)
            .eq('id', widget.clinique!['id']);
      } else {
        // Création
        await Supabase.instance.client.from('cliniques').insert(cliniqueData);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e, st) {
      debugPrint("Erreur lors de l'enregistrement: $e\n$st");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de l'enregistrement")),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool enEdition = widget.clinique != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(enEdition ? "Modifier la clinique" : "Ajouter une clinique"),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _choisirImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _pickedImage != null
                      ? (kIsWeb
                          ? NetworkImage(_pickedImage!.path)
                          : FileImage(File(_pickedImage!.path)) as ImageProvider)
                      : (_uploadedImageUrl != null
                          ? NetworkImage(_uploadedImageUrl!)
                          : null),
                  child: _pickedImage == null && _uploadedImageUrl == null
                      ? const Icon(Icons.camera_alt, size: 30)
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                initialValue: nom,
                decoration: const InputDecoration(labelText: "Nom"),
                onChanged: (v) => nom = v,
                validator: (v) => v == null || v.isEmpty ? "Champ requis" : null,
              ),
              TextFormField(
                initialValue: adresse,
                decoration: const InputDecoration(labelText: "Adresse"),
                onChanged: (v) => adresse = v,
              ),
              TextFormField(
                initialValue: ville,
                decoration: const InputDecoration(labelText: "Ville"),
                onChanged: (v) => ville = v,
              ),
              TextFormField(
                initialValue: tel,
                decoration: const InputDecoration(labelText: "Téléphone"),
                keyboardType: TextInputType.phone,
                onChanged: (v) => tel = v,
              ),
              TextFormField(
                initialValue: whatsapp,
                decoration: const InputDecoration(labelText: "WhatsApp"),
                keyboardType: TextInputType.phone,
                onChanged: (v) => whatsapp = v,
              ),
              TextFormField(
                initialValue: description,
                decoration: const InputDecoration(labelText: "Description"),
                onChanged: (v) => description = v,
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              _isUploading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _enregistrerClinique,
                      icon: const Icon(Icons.save),
                      label: Text(enEdition ? "Mettre à jour" : "Enregistrer"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
