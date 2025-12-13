// lib/pages/edit_clinique_page.dart
import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Compression (même module que annonces)
import 'package:ma_guinee/utils/image_compressor/image_compressor.dart';

class EditCliniquePage extends StatefulWidget {
  final Map<String, dynamic>? clinique;
  final bool autoAskLocation; // déclenche la géoloc à l’ouverture
  const EditCliniquePage({
    super.key,
    this.clinique,
    this.autoAskLocation = false,
  });

  @override
  State<EditCliniquePage> createState() => _EditCliniquePageState();
}

// Palette Santé / Cliniques
const Color santePrimary = Color(0xFF00897B);
const Color santeSecondary = Color(0xFF80CBC4);
const Color santeOnPrimary = Color(0xFFFFFFFF);

class _EditCliniquePageState extends State<EditCliniquePage> {
  // contrôleurs
  late TextEditingController nomController;
  late TextEditingController villeController;
  late TextEditingController adresseController;
  late TextEditingController telephoneController;
  late TextEditingController descriptionController;
  late TextEditingController specialitesController;
  late TextEditingController horairesController;
  late TextEditingController latitudeController;
  late TextEditingController longitudeController;

  // images
  final List<_LocalImg> _local = []; // nouvelles images (bytes)
  List<String> imagesUrls = []; // images déjà en ligne (URLs publiques)

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
    latitudeController =
        TextEditingController(text: c['latitude']?.toString() ?? '');
    longitudeController =
        TextEditingController(text: c['longitude']?.toString() ?? '');
    imagesUrls = (c['images'] as List?)?.cast<String>() ?? [];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Astuce : place-toi dans la clinique pour une meilleure géolocalisation."),
          duration: Duration(seconds: 4),
        ),
      );
      if (widget.autoAskLocation) _recupererPosition();
    });
  }

  @override
  void dispose() {
    nomController.dispose();
    villeController.dispose();
    adresseController.dispose();
    telephoneController.dispose();
    descriptionController.dispose();
    specialitesController.dispose();
    horairesController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    super.dispose();
  }

  // ---------------- Géolocalisation robuste ----------------
  Future<void> _recupererPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        final go = await _ask(
          title: 'Localisation désactivée',
          content: "Active d’abord la localisation (GPS) dans les réglages.",
          ok: 'Ouvrir réglages',
        );
        if (go) await Geolocator.openLocationSettings();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _toast("Autorisation refusée. Saisis l’adresse manuellement.");
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        final go = await _ask(
          title: 'Autorisation bloquée',
          content:
              "La localisation est bloquée pour cette app. Autorise-la dans les réglages.",
          ok: 'Ouvrir réglages',
        );
        if (go) await Geolocator.openAppSettings();
        return;
      }

      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 12),
        );
      } on TimeoutException {
        _toast("Localisation trop longue. Réessaie près d’une fenêtre.");
        return;
      }

      latitudeController.text = pos.latitude.toString();
      longitudeController.text = pos.longitude.toString();

      // Reverse geocoding non bloquant
      try {
        final marks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude)
                .timeout(const Duration(seconds: 8));
        if (marks.isNotEmpty) {
          final p = marks.first;
          final adresse = [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
            p.country
          ].where((e) => (e != null && e!.trim().isNotEmpty)).join(', ');
          adresseController.text = adresse;
          if (villeController.text.trim().isEmpty &&
              (p.locality ?? '').isNotEmpty) {
            villeController.text = p.locality!;
          }
        }
      } catch (_) {
        /* ignore */
      }

      if (mounted) {
        setState(() {});
        _toast("Position détectée !");
      }
    } catch (_) {
      _toast("Localisation indisponible pour le moment.");
    }
  }

  // ---------------- Images ----------------
  Future<void> _pickImages({bool fromCamera = false}) async {
    final picker = ImagePicker();
    try {
      final XFile? one = fromCamera
          ? await picker.pickImage(source: ImageSource.camera, imageQuality: 85)
          : null;
      final List<XFile> many =
          !fromCamera ? await picker.pickMultiImage(imageQuality: 80) : [];

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
    } catch (_) {
      _toast("Impossible d’ouvrir la galerie ou la caméra.");
    }
  }

  void _removeLocalAt(int idx) => setState(() => _local.removeAt(idx));

  Future<void> _removeImageOnline(int idx) async {
    final imageUrl = imagesUrls[idx];
    final pathInStorage = _storagePathFromPublicUrl(imageUrl);
    if (pathInStorage != null) {
      try {
        await Supabase.instance.client.storage
            .from(_bucket)
            .remove([pathInStorage]);
      } catch (_) {
        /* ignore */
      }
    }
    setState(() => imagesUrls.removeAt(idx));
    if (widget.clinique?['id'] != null) {
      try {
        await Supabase.instance.client
            .from('cliniques')
            .update({'images': imagesUrls}).eq('id', widget.clinique!['id']);
      } catch (_) {
        /* ignore */
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
    return null; // ne jamais renvoyer le bucket entier
  }

  // ✅ Upload des nouvelles images avec compression (identique à annonces)
  Future<List<String>> _uploadImagesCompressed() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    final storage = Supabase.instance.client.storage.from(_bucket);
    final urls = <String>[];

    for (int i = 0; i < _local.length; i++) {
      final li = _local[i];

      try {
        // 1) compression prod
        final c = await ImageCompressor.compressBytes(
          li.bytes,
          maxSide: 1600,
          quality: 82,
          maxBytes: 900 * 1024,
          keepPngIfTransparent: true,
        );

        // 2) nom unique + extension sortie
        final ts = DateTime.now().microsecondsSinceEpoch;
        final objectPath = 'u/$userId/${ts}_$i.${c.extension}';

        // 3) upload binaire + contentType sortie
        await storage.uploadBinary(
          objectPath,
          c.bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: c.contentType,
          ),
        );

        urls.add(storage.getPublicUrl(objectPath));
      } catch (_) {
        // on n’interrompt pas tout si une image échoue
      }
    }

    return urls;
  }

  // ---------------- Règle: une seule clinique par compte ----------------
  Future<bool> _dejaUnEtablissement(String userId) async {
    try {
      final rows = await Supabase.instance.client
          .from('cliniques')
          .select('id')
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .limit(1);
      return rows is List && rows.isNotEmpty;
    } catch (_) {
      // en cas d’erreur, on ne bloque pas (la RLS/contrainte côté DB peut refuser)
      return false;
    }
  }

  // ---------------- Enregistrement ----------------
  Future<void> _save() async {
    // validations minimales côté client
    if (nomController.text.trim().isEmpty ||
        villeController.text.trim().isEmpty ||
        adresseController.text.trim().isEmpty ||
        !_isValidPhone(telephoneController.text.trim())) {
      _toast("Complète les champs requis (nom, ville, adresse, téléphone).");
      return;
    }

    loading = true;
    setState(() {});
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      // Bloquer la création si déjà une clinique
      if (widget.clinique == null &&
          userId != null &&
          await _dejaUnEtablissement(userId)) {
        loading = false;
        setState(() {});
        await _ask(
          title: "Création impossible",
          content: "Vous avez déjà une clinique enregistrée avec ce compte.\n\n"
              "Si vous avez d’autres cliniques à ajouter, veuillez contacter le support "
              "pour activer l’option multi-établissements.",
          ok: "OK",
        );
        return;
      }

      // ✅ upload compressé
      final newUrls = await _uploadImagesCompressed();
      final allImgs = [...imagesUrls, ...newUrls];

      final latitude = double.tryParse(latitudeController.text.trim());
      final longitude = double.tryParse(longitudeController.text.trim());

      final data = {
        'nom': nomController.text.trim(),
        'ville': villeController.text.trim(),
        'adresse': adresseController.text.trim(),
        'tel': telephoneController.text.trim(),
        'description': descriptionController.text.trim(),
        'specialites': specialitesController.text.trim(),
        'horaires': horairesController.text.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'images': allImgs, // ✅ pas de photo_url
      };

      final id = widget.clinique?['id'];
      if (id != null) {
        await Supabase.instance.client
            .from('cliniques')
            .update(data)
            .eq('id', id);
      } else {
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
    } catch (_) {
      if (mounted) _toast("Erreur lors de l’enregistrement. Réessaie.");
    } finally {
      _local.clear();
      loading = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _delete() async {
    final confirm = await _ask(
      title: "Supprimer cette clinique ?",
      content: "Cette action est irréversible.",
      ok: "Supprimer",
    );
    if (!confirm || widget.clinique?['id'] == null) return;

    try {
      await Supabase.instance.client
          .from('cliniques')
          .delete()
          .eq('id', widget.clinique!['id']);
      if (mounted) {
        Navigator.pop(context);
        _toast("Clinique supprimée.");
      }
    } catch (_) {
      _toast("Suppression impossible pour le moment.");
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final enEdition = widget.clinique != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          enEdition ? "Modifier la clinique" : "Inscription Clinique",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: santePrimary),
        actions: [
          if (enEdition)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _delete,
            ),
        ],
        elevation: 1,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _recupererPosition,
                    icon: const Icon(Icons.my_location),
                    label: const Text("Détecter ma position"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: santePrimary,
                      foregroundColor: santeOnPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Photos de la clinique :",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    // existantes
                    ...imagesUrls.asMap().entries.map(
                          (e) => _Thumb(
                            child: Image.network(e.value, fit: BoxFit.cover),
                            onRemove: () => _removeImageOnline(e.key),
                          ),
                        ),
                    // nouvelles
                    ..._local.asMap().entries.map(
                          (e) => _Thumb(
                            child:
                                Image.memory(e.value.bytes, fit: BoxFit.cover),
                            onRemove: () => _removeLocalAt(e.key),
                          ),
                        ),
                    _AddThumb(
                      color: santeSecondary,
                      iconColor: santePrimary,
                      onPickMulti: () => _pickImages(),
                      onPickCamera: () => _pickImages(fromCamera: true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _field(nomController, "Nom de la clinique *"),
                _field(villeController, "Ville *"),
                _field(adresseController, "Adresse *"),
                _field(telephoneController, "Téléphone *",
                    keyboardType: TextInputType.phone),
                _field(descriptionController, "Description", maxLines: 3),
                _field(specialitesController, "Spécialités"),
                _field(horairesController, "Horaires d'ouverture"),
                _field(latitudeController, "Latitude"),
                _field(longitudeController, "Longitude"),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text("Enregistrer"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: santePrimary,
                    foregroundColor: santeOnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          labelStyle: const TextStyle(color: santePrimary),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: santePrimary, width: 2),
          ),
        ),
      ),
    );
  }

  // helpers UI
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _ask({
    required String title,
    required String content,
    String ok = 'OK',
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Fermer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(ok),
          ),
        ],
      ),
    );
    return res == true;
  }

  bool _isValidPhone(String s) {
    final cleaned = s.replaceAll(RegExp(r'[^0-9+]'), '');
    return RegExp(r'^\+?[0-9]{8,15}$').hasMatch(cleaned);
  }
}

// ---------------- Widgets vignettes ----------------

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
          style: OutlinedButton.styleFrom(
            foregroundColor: santePrimary,
            side: const BorderSide(color: santePrimary),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
      ],
    );
  }
}
