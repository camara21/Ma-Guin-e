import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/utilisateur_model.dart';

class ModifierProfilPage extends StatefulWidget {
  final UtilisateurModel user;

  const ModifierProfilPage({super.key, required this.user});

  @override
  State<ModifierProfilPage> createState() => _ModifierProfilPageState();
}

class _ModifierProfilPageState extends State<ModifierProfilPage> {
  final _formKey = GlobalKey<FormState>();
  late String prenom;
  late String nom;
  late String email;
  late String telephone;
  late String pays;
  late String genre;
  File? _photoFile;
  bool _isUploading = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    prenom = widget.user.prenom;
    nom = widget.user.nom;
    email = widget.user.email;
    telephone = widget.user.telephone;
    pays = widget.user.pays;
    genre = widget.user.genre.toLowerCase(); // ✅ correction ici
    _photoUrl = widget.user.photoUrl;
  }

  Future<void> _pickImageAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;

    setState(() {
      _isUploading = true;
      _photoFile = File(picked.path);
    });

    try {
      final supabase = Supabase.instance.client;
      final userId = widget.user.id;
      final fileExt = picked.path.split('.').last;
      final fileName = 'avatar_$userId.$fileExt';
      final filePath = 'profile-photos/$fileName';
      final bytes = await picked.readAsBytes();

      await supabase.storage.from('profile-photos').uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );

      final publicUrl = supabase.storage.from('profile-photos').getPublicUrl(filePath);

      setState(() {
        _photoUrl = publicUrl;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Photo de profil mise à jour !")),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'upload : $e")),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      await Supabase.instance.client.from('utilisateurs').update({
        'prenom': prenom,
        'nom': nom,
        'email': email,
        'telephone': telephone,
        'pays': pays,
        'genre': genre,
        if (_photoUrl != null && _photoUrl!.isNotEmpty) 'photo_url': _photoUrl,
      }).eq('id', widget.user.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil mis à jour !')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la sauvegarde : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Modifier mon profil", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0.8,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: _photoFile != null
                          ? FileImage(_photoFile!)
                          : (_photoUrl?.isNotEmpty ?? false)
                              ? NetworkImage(_photoUrl!)
                              : const AssetImage('assets/avatar.png') as ImageProvider,
                      backgroundColor: Colors.grey[200],
                    ),
                    Positioned(
                      bottom: 0,
                      right: 2,
                      child: GestureDetector(
                        onTap: _isUploading ? null : _pickImageAndUpload,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                          ),
                          child: _isUploading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.edit, size: 17, color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                initialValue: prenom,
                decoration: const InputDecoration(labelText: "Prénom"),
                validator: (v) => v!.trim().isEmpty ? "Champ requis" : null,
                onSaved: (v) => prenom = v!.trim(),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: nom,
                decoration: const InputDecoration(labelText: "Nom"),
                validator: (v) => v!.trim().isEmpty ? "Champ requis" : null,
                onSaved: (v) => nom = v!.trim(),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: email,
                decoration: const InputDecoration(labelText: "Email"),
                validator: (v) => v!.isEmpty ? "Champ requis" : null,
                onSaved: (v) => email = v!,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: telephone,
                decoration: const InputDecoration(labelText: "Téléphone"),
                onSaved: (v) => telephone = v!,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: pays,
                decoration: const InputDecoration(labelText: "Pays"),
                onSaved: (v) => pays = v!,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: ['homme', 'femme', 'autre'].contains(genre) ? genre : null,
                decoration: const InputDecoration(labelText: "Genre"),
                items: const [
                  DropdownMenuItem(value: "homme", child: Text("Homme")),
                  DropdownMenuItem(value: "femme", child: Text("Femme")),
                  DropdownMenuItem(value: "autre", child: Text("Autre")),
                ],
                onChanged: (v) => setState(() => genre = v ?? ""),
                onSaved: (v) => genre = v ?? "",
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _save,
                  icon: const Icon(Icons.check, size: 20),
                  label: const Text("Enregistrer"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
