import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
  double? latitude;
  double? longitude;

  XFile? _pickedImage;
  String? _uploadedImageUrl;
  bool _isUploading = false;
  final String _bucket = 'clinique-photos';

  @override
  void initState() {
    super.initState();
    final c = widget.clinique ?? {};
    nom = c['nom'] ?? '';
    adresse = c['adresse'] ?? '';
    ville = c['ville'] ?? '';
    tel = c['tel'] ?? '';
    description = c['description'] ?? '';
    specialites = c['specialites'] ?? '';
    horaires = c['horaires'] ?? '';
    latitude = c['latitude'] != null ? double.tryParse('${c['latitude']}') : null;
    longitude = c['longitude'] != null ? double.tryParse('${c['longitude']}') : null;
    if (c['images'] is List && c['images'].isNotEmpty) {
      _uploadedImageUrl = c['images'][0];
    }
  }

  Future<void> _recupererPosition() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });

      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        adresse = [
          placemark.street,
          placemark.subLocality,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country
        ].where((e) => e != null && e.isNotEmpty).join(", ");
        ville = placemark.locality ?? ville;
        setState(() {});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Position récupérée. Placez-vous à l’intérieur de l’établissement.")),
        );
      }
    } catch (e) {
      debugPrint("Erreur géolocalisation : $e");
    }
  }

  Future<void> _choisirImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _pickedImage = picked);
    }
  }

  Future<String?> _uploadImage(XFile imageFile) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.${imageFile.path.split('.').last}';
      final path = 'cliniques/$fileName';
      final bytes = await imageFile.readAsBytes();

      await Supabase.instance.client.storage
          .from(_bucket)
          .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));

      return Supabase.instance.client.storage.from(_bucket).getPublicUrl(path);
    } catch (e) {
      debugPrint("Erreur d'upload : $e");
      return null;
    }
  }

  Future<void> _enregistrerClinique() async {
    if (!_formKey.currentState!.validate()) return;
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez définir la position géographique.")),
      );
      return;
    }

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
      'latitude': latitude,
      'longitude': longitude,
      'images': imageUrl != null ? [imageUrl] : [],
      'user_id': userId,
    };

    try {
      if (widget.clinique != null) {
        await Supabase.instance.client.from('cliniques').update(data).eq('id', widget.clinique!['id']);
      } else {
        await Supabase.instance.client.from('cliniques').insert(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Erreur enregistrement : $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur enregistrement.")));
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
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: _recupererPosition,
                icon: const Icon(Icons.my_location),
                label: const Text("Détecter ma position"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              if (latitude != null && longitude != null) ...[
                Text("Latitude : $latitude"),
                Text("Longitude : $longitude"),
                if (adresse.isNotEmpty) Text("Adresse : $adresse"),
                const SizedBox(height: 10),
                SizedBox(
                  height: 200,
                  child: FlutterMap(
                    options: MapOptions(
                      center: LatLng(latitude!, longitude!),
                      zoom: 16,
                      onTap: (tapPosition, point) {
                        setState(() {
                          latitude = point.latitude;
                          longitude = point.longitude;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Position modifiée manuellement")),
                        );
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 40,
                            height: 40,
                            point: LatLng(latitude!, longitude!),
                            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
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
                maxLines: 3,
                onChanged: (v) => description = v,
              ),
              const SizedBox(height: 20),
              _isUploading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _enregistrerClinique,
                      icon: const Icon(Icons.save),
                      label: Text(enEdition ? "Mettre à jour" : "Enregistrer"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
