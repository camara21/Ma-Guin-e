import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class InscriptionCliniquePage extends StatefulWidget {
  final Map<String, dynamic>? clinique;

  const InscriptionCliniquePage({super.key, this.clinique});

  @override
  State<InscriptionCliniquePage> createState() => _InscriptionCliniquePageState();
}

class _InscriptionCliniquePageState extends State<InscriptionCliniquePage> {
  final _formKey = GlobalKey<FormState>();

  String nom = '';
  String adresse = '';
  String ville = '';
  String tel = '';
  String description = '';
  String specialites = '';
  String horaires = '';
  String? latitude;
  String? longitude;

  XFile? _pickedImage;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  final String _bucket = 'clinique-photos';

  @override
  void initState() {
    super.initState();
    _initialiserFormulaire();
  }

  void _initialiserFormulaire() {
    final c = widget.clinique ?? {};
    nom = c['nom'] ?? '';
    adresse = c['adresse'] ?? '';
    ville = c['ville'] ?? '';
    tel = c['tel'] ?? '';
    description = c['description'] ?? '';
    specialites = c['specialites'] ?? '';
    horaires = c['horaires'] ?? '';
    latitude = c['latitude']?.toString();
    longitude = c['longitude']?.toString();
    if (c['images'] is List && c['images'].isNotEmpty) {
      _uploadedImageUrl = c['images'][0];
    }
  }

  Future<void> _recupererPosition() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        latitude = position.latitude.toString();
        longitude = position.longitude.toString();
      });

      // Géocodage inverse
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final adresseComplete = [
          placemark.street,
          placemark.subLocality,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country
        ].where((e) => e != null && e.isNotEmpty).join(", ");

        setState(() {
          adresse = adresseComplete;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Position récupérée. Veuillez vous placer à l’intérieur de l’établissement."),
          ),
        );
      }
    } catch (e) {
      debugPrint("Erreur géolocalisation/géocodage : $e");
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

      return Supabase.instance.client.storage.from(_bucket).getPublicUrl(path);
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

    final data = {
      'nom': nom,
      'adresse': adresse,
      'ville': ville,
      'tel': tel,
      'description': description,
      'specialites': specialites,
      'horaires': horaires,
      'latitude': latitude != null ? double.tryParse(latitude!) : null,
      'longitude': longitude != null ? double.tryParse(longitude!) : null,
      'images': imageUrl != null ? [imageUrl] : [],
      'user_id': userId,
    };

    try {
      if (widget.clinique != null) {
        await Supabase.instance.client
            .from('cliniques')
            .update(data)
            .eq('id', widget.clinique!['id']);
      } else {
        await Supabase.instance.client.from('cliniques').insert(data);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Erreur enregistrement: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de l'enregistrement")),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enEdition = widget.clinique != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(enEdition ? "Modifier la clinique" : "Inscription Clinique"),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Bouton + message + coordonnées
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Placez-vous dans votre établissement pour enregistrer sa position exacte.",
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 4,
                      ),
                      onPressed: _recupererPosition,
                      icon: const Icon(Icons.location_on),
                      label: const Text("Détecter ma position"),
                    ),
                    const SizedBox(height: 12),
                    if (latitude != null && longitude != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Latitude : $latitude", style: const TextStyle(fontSize: 15)),
                          Text("Longitude : $longitude", style: const TextStyle(fontSize: 15)),
                          if (adresse.isNotEmpty)
                            Text("Adresse : $adresse", style: const TextStyle(fontSize: 15)),
                        ],
                      ),
                  ],
                ),
              ),

              // Image profil
              GestureDetector(
                onTap: _choisirImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _pickedImage != null
                      ? (kIsWeb
                          ? NetworkImage(_pickedImage!.path)
                          : FileImage(File(_pickedImage!.path)) as ImageProvider)
                      : (_uploadedImageUrl != null ? NetworkImage(_uploadedImageUrl!) : null),
                  child: _pickedImage == null && _uploadedImageUrl == null
                      ? const Icon(Icons.camera_alt, size: 30)
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // Champs de formulaire
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
                initialValue: specialites,
                decoration: const InputDecoration(labelText: "Spécialités"),
                onChanged: (v) => specialites = v,
              ),
              TextFormField(
                initialValue: horaires,
                decoration: const InputDecoration(labelText: "Horaires d'ouverture"),
                onChanged: (v) => horaires = v,
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
