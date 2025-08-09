import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditCliniquePage extends StatefulWidget {
  final Map<String, dynamic>? clinique;
  final bool autoAskLocation; // ✅ pour déclencher la géoloc auto à l’ouverture
  const EditCliniquePage({super.key, this.clinique, this.autoAskLocation = false});

  @override
  State<EditCliniquePage> createState() => _EditCliniquePageState();
}

class _EditCliniquePageState extends State<EditCliniquePage> {
  late TextEditingController nomController;
  late TextEditingController villeController;
  late TextEditingController adresseController;
  late TextEditingController telephoneController;
  late TextEditingController descriptionController;
  late TextEditingController specialitesController;
  late TextEditingController horairesController;
  late TextEditingController latitudeController;
  late TextEditingController longitudeController;

  // nouvelles images choisies (préviews + fichiers)
  final List<_LocalImg> _local = [];
  // images déjà en ligne (URLs publiques)
  List<String> imagesUrls = [];

  bool loading = false;
  final String _bucket = 'clinique-photos';

  @override
  void initState() {
    super.initState();
    final c = widget.clinique ?? {};
    nomController = TextEditingController(text: c['nom'] ?? '');
    villeController = TextEditingController(text: c['ville'] ?? '');
    adresseController = TextEditingController(text: c['adresse'] ?? '');
    telephoneController = TextEditingController(text: c['tel'] ?? '');
    descriptionController = TextEditingController(text: c['description'] ?? '');
    specialitesController = TextEditingController(text: c['specialites'] ?? '');
    horairesController = TextEditingController(text: c['horaires'] ?? '');
    latitudeController = TextEditingController(text: c['latitude']?.toString() ?? '');
    longitudeController = TextEditingController(text: c['longitude']?.toString() ?? '');
    imagesUrls = (c['images'] as List?)?.cast<String>() ?? [];

    // snack astuce + auto-géoloc si demandé
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("📍 Placez-vous dans la clinique pour une meilleure géolocalisation."),
          duration: Duration(seconds: 4),
        ),
      );
      if (widget.autoAskLocation) _recupererPosition();
    });
  }

  // ---------- Géolocalisation ----------
  Future<void> _recupererPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Permission de localisation refusée.")),
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Activez la localisation dans les paramètres.")),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      latitudeController.text = pos.latitude.toString();
      longitudeController.text = pos.longitude.toString();

      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final adresse = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
          p.country
        ].where((e) => e != null && e.isNotEmpty).join(", ");
        adresseController.text = adresse;
        if ((villeController.text).isEmpty && (p.locality ?? '').isNotEmpty) {
          villeController.text = p.locality!;
        }
      }
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Position détectée ✔")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur localisation : $e")),
      );
    }
  }

  // ---------- Images ----------
  Future<void> _pickImages({bool fromCamera = false}) async {
    final picker = ImagePicker();
    final XFile? one = fromCamera ? await picker.pickImage(source: ImageSource.camera, imageQuality: 80) : null;
    final List<XFile> many = !fromCamera ? await picker.pickMultiImage(imageQuality: 80) : [];

    final files = [
      if (one != null) one,
      ...many,
    ];
    if (files.isEmpty) return;

    for (final f in files) {
      final bytes = await f.readAsBytes();
      _local.add(_LocalImg(file: f, bytes: bytes));
    }
    setState(() {});
  }

  void _removeLocalAt(int idx) {
    setState(() => _local.removeAt(idx));
  }

  Future<void> _removeImageOnline(int idx) async {
    final imageUrl = imagesUrls[idx];
    final pathInStorage = _storagePathFromPublicUrl(imageUrl);
    if (pathInStorage != null) {
      try {
        await Supabase.instance.client.storage.from(_bucket).remove([pathInStorage]);
      } catch (e) {
        debugPrint("Erreur suppression storage : $e");
      }
    }
    setState(() => imagesUrls.removeAt(idx));
    if (widget.clinique?['id'] != null) {
      try {
        await Supabase.instance.client
            .from('cliniques')
            .update({'images': imagesUrls})
            .eq('id', widget.clinique!['id']);
      } catch (e) {
        debugPrint("Erreur update DB : $e");
      }
    }
  }

  String? _storagePathFromPublicUrl(String url) {
    final marker = '/storage/v1/object/public/$_bucket/';
    final i = url.indexOf(marker);
    if (i != -1) return url.substring(i + marker.length);
    final alt = '$_bucket/';
    final j = url.indexOf(alt);
    if (j != -1) return url.substring(j + alt.length);
    return null;
    // on n’inclut JAMAIS le nom du bucket dans objectPath à l’upload
  }

  Future<String?> _uploadOne(Uint8List bytes, String userId) async {
    try {
      final mime = lookupMimeType('', headerBytes: bytes) ?? 'application/octet-stream';
      String ext = 'bin';
      if (mime.contains('jpeg')) ext = 'jpg';
      else if (mime.contains('png')) ext = 'png';
      else if (mime.contains('webp')) ext = 'webp';
      else if (mime.contains('gif')) ext = 'gif';

      final ts = DateTime.now().millisecondsSinceEpoch;
      final objectPath = 'u/$userId/$ts.$ext';

      await Supabase.instance.client.storage
          .from(_bucket)
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: mime),
          );

      return Supabase.instance.client.storage.from(_bucket).getPublicUrl(objectPath);
    } catch (e) {
      debugPrint("Erreur upload image : $e");
      return null;
    }
  }

  Future<List<String>> _uploadImages() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    final urls = <String>[];
    for (final li in _local) {
      final url = await _uploadOne(li.bytes, userId);
      if (url != null) urls.add(url);
    }
    return urls;
  }

  // ---------- Enregistrement ----------
  Future<void> _save() async {
    loading = true;
    setState(() {});
    try {
      final newUrls = await _uploadImages();
      final allImages = [...imagesUrls, ...newUrls];

      final data = {
        'nom': nomController.text.trim(),
        'ville': villeController.text.trim(),
        'adresse': adresseController.text.trim(),
        'tel': telephoneController.text.trim(),
        'description': descriptionController.text.trim(),
        'specialites': specialitesController.text.trim(),
        'horaires': horairesController.text.trim(),
        'latitude': double.tryParse(latitudeController.text.trim()),
        'longitude': double.tryParse(longitudeController.text.trim()),
        'images': allImages,
        'photo_url': allImages.isNotEmpty ? allImages.first : null,
      };

      final id = widget.clinique?['id'];
      if (id != null) {
        await Supabase.instance.client.from('cliniques').update(data).eq('id', id);
      } else {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        await Supabase.instance.client.from('cliniques').insert({
          ...data,
          'user_id': userId,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Clinique enregistrée avec succès !")),
      );
      Navigator.pop(context, {...?widget.clinique, ...data});
    } catch (e) {
      debugPrint("Erreur enregistrement : $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'enregistrement : $e")),
        );
      }
    } finally {
      _local.clear();
      loading = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Supprimer cette clinique ?"),
            content: const Text("Cette action est irréversible."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm || widget.clinique?['id'] == null) return;

    try {
      await Supabase.instance.client.from('cliniques').delete().eq('id', widget.clinique!['id']);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Clinique supprimée.")),
        );
      }
    } catch (e) {
      debugPrint("Erreur de suppression : $e");
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final bleuMaGuinee = const Color(0xFF113CFC);
    final jauneMaGuinee = const Color(0xFFFCD116);
    final vert = const Color(0xFF009460);
    final enEdition = widget.clinique != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(enEdition ? "Modifier la clinique" : "Inscription Clinique",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: bleuMaGuinee),
        actions: [
          if (enEdition)
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _delete),
        ],
        elevation: 1,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Détecter la position
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _recupererPosition,
                    icon: const Icon(Icons.my_location),
                    label: const Text("Détecter ma position"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bleuMaGuinee,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Photos (miniatures + ajout)
                const Text("Photos de la clinique :", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    // existantes
                    ...imagesUrls.asMap().entries.map((e) => _Thumb(
                          child: Image.network(e.value, fit: BoxFit.cover),
                          onRemove: () => _removeImageOnline(e.key),
                        )),
                    // nouvelles (préviews mémoire)
                    ..._local.asMap().entries.map((e) => _Thumb(
                          child: Image.memory(e.value.bytes, fit: BoxFit.cover),
                          onRemove: () => _removeLocalAt(e.key),
                        )),
                    // bouton ajout
                    _AddThumb(
                      color: jauneMaGuinee,
                      iconColor: bleuMaGuinee,
                      onPickMulti: () => _pickImages(),
                      onPickCamera: () => _pickImages(fromCamera: true),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                _buildTextField(nomController, "Nom de la clinique *", bleuMaGuinee),
                _buildTextField(villeController, "Ville *", bleuMaGuinee),
                _buildTextField(adresseController, "Adresse *", bleuMaGuinee),
                _buildTextField(telephoneController, "Téléphone *", bleuMaGuinee),
                _buildTextField(descriptionController, "Description", bleuMaGuinee, maxLines: 3),
                _buildTextField(specialitesController, "Spécialités", bleuMaGuinee),
                _buildTextField(horairesController, "Horaires d'ouverture", bleuMaGuinee),
                _buildTextField(latitudeController, "Latitude", bleuMaGuinee),
                _buildTextField(longitudeController, "Longitude", bleuMaGuinee),

                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text("Enregistrer"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: vert,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, Color color,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          labelStyle: TextStyle(color: color),
        ),
      ),
    );
  }
}

// ---------- Helpers UI ----------

class _LocalImg {
  final XFile file;
  final Uint8List bytes;
  _LocalImg({required this.file, required this.bytes});
}

class _Thumb extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  const _Thumb({super.key, required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey[200],
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
        Positioned(
          top: -8,
          right: -8,
          child: IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 20, color: Colors.red),
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ],
    );
  }
}

class _AddThumb extends StatelessWidget {
  final Color color;
  final Color iconColor;
  final VoidCallback onPickMulti;
  final VoidCallback onPickCamera;
  const _AddThumb({
    super.key,
    required this.color,
    required this.iconColor,
    required this.onPickMulti,
    required this.onPickCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onPickMulti,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Icon(Icons.add_a_photo, size: 30, color: iconColor),
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: onPickCamera,
          icon: const Icon(Icons.photo_camera_outlined, size: 18),
          label: const Text("Prendre"),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
        ),
      ],
    );
  }
}
