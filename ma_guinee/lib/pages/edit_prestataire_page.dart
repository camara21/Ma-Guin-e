import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Compression (même module que annonces)
import 'package:ma_guinee/utils/image_compressor/image_compressor.dart';

// --- Palette Prestataires ---
const Color prestatairePrimary = Color(0xFF113CFC);
const Color prestataireSecondary = Color(0xFFFCD116);
const Color prestataireOnPrimary = Color(0xFFFFFFFF);
const Color prestataireOnSecondary = Color(0xFF000000);

class EditPrestatairePage extends StatefulWidget {
  final Map<String, dynamic> prestataire;
  const EditPrestatairePage({super.key, required this.prestataire});

  @override
  State<EditPrestatairePage> createState() => _EditPrestatairePageState();
}

class _EditPrestatairePageState extends State<EditPrestatairePage> {
  static const String _bucket = 'prestataire-photos';

  late TextEditingController jobController;
  late TextEditingController villeController;
  late TextEditingController descriptionController;
  late TextEditingController phoneController;

  File? _photoFile;
  bool _isUploading = false;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    jobController = TextEditingController(
      text: widget.prestataire['metier'] ?? widget.prestataire['job'] ?? '',
    );
    villeController = TextEditingController(
      text: widget.prestataire['ville'] ?? widget.prestataire['city'] ?? '',
    );
    phoneController =
        TextEditingController(text: widget.prestataire['phone'] ?? '');
    descriptionController =
        TextEditingController(text: widget.prestataire['description'] ?? '');

    _imageUrl =
        widget.prestataire['image'] ?? widget.prestataire['photo_url'] ?? '';
  }

  @override
  void dispose() {
    jobController.dispose();
    villeController.dispose();
    phoneController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  String _categoryForJob(String? job) {
    if (job == null) return '';
    final Map<String, List<String>> categories = {
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
      // ... (autres catégories inchangées)
    };
    for (final e in categories.entries) {
      if (e.value.contains(job)) return e.key;
    }
    return '';
  }

  // -----------------------------
  // ✅ Extraire objectPath depuis une URL publique Supabase
  // -----------------------------
  String? _storagePathFromPublicUrl(String url) {
    try {
      if (url.trim().isEmpty) return null;

      final marker = '/storage/v1/object/public/$_bucket/';
      final i = url.indexOf(marker);
      if (i != -1) {
        final p = url.substring(i + marker.length);
        final decoded = Uri.decodeComponent(p);
        if (decoded.trim().isEmpty) return null;
        if (decoded.trim() == _bucket) return null;
        if (decoded.endsWith('/')) return null;
        return decoded;
      }

      final uri = Uri.parse(url);
      final seg = uri.pathSegments;
      final idx = seg.indexOf(_bucket);
      if (idx == -1 || idx + 1 >= seg.length) return null;

      final p = seg.sublist(idx + 1).join('/');
      final decoded = Uri.decodeComponent(p);
      if (decoded.trim().isEmpty) return null;
      if (decoded.trim() == _bucket) return null;
      if (decoded.endsWith('/')) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteOldImageIfAny(String? oldUrl) async {
    if (oldUrl == null || oldUrl.trim().isEmpty) return;

    final objectPath = _storagePathFromPublicUrl(oldUrl);
    if (objectPath == null) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase.storage.from(_bucket).remove([objectPath]);
    } catch (_) {
      // On n'échoue pas l'UX si la suppression échoue (policy, fichier déjà supprimé, etc.)
    }
  }

  Future<void> _pickImageAndUpload() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (picked == null) return;

    // snapshot ancienne URL (à supprimer après succès)
    final oldUrl = _imageUrl;

    setState(() {
      _isUploading = true;
      _photoFile = File(picked.path); // preview instant
    });

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw "Utilisateur non connecté.";

      final prestataireId = widget.prestataire['id'] ??
          DateTime.now().millisecondsSinceEpoch.toString();

      // 1) bytes originaux
      final Uint8List rawBytes = await picked.readAsBytes();

      // 2) ✅ compression prod (mêmes réglages que annonces)
      final c = await ImageCompressor.compressBytes(
        rawBytes,
        maxSide: 1600,
        quality: 82,
        maxBytes: 900 * 1024,
        keepPngIfTransparent: true,
      );

      // 3) Nouveau chemin unique
      final fileName =
          'presta_${prestataireId}_${DateTime.now().microsecondsSinceEpoch}.${c.extension}';
      final filePath = '$userId/$fileName';

      // 4) upload binaire
      await supabase.storage.from(_bucket).uploadBinary(
            filePath,
            c.bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: c.contentType,
              metadata: {'owner': userId},
            ),
          );

      final publicUrl = supabase.storage.from(_bucket).getPublicUrl(filePath);

      // 5) update DB
      await supabase
          .from('prestataires')
          .update({'image': publicUrl}).eq('id', prestataireId);

      // 6) ✅ suppression de l'ancienne image (après succès DB)
      //    - si l’ancienne URL est bien dans le même bucket
      if (oldUrl != null &&
          oldUrl.trim().isNotEmpty &&
          oldUrl.trim() != publicUrl.trim()) {
        await _deleteOldImageIfAny(oldUrl);
      }

      setState(() {
        _imageUrl = publicUrl;
        _photoFile = null;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Photo de profil mise à jour (ancienne supprimée)."),
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'upload : $e")),
        );
      }
    }
  }

  Future<void> _save() async {
    final supabase = Supabase.instance.client;
    final prestataireId = widget.prestataire['id'];
    final metier = jobController.text.trim();

    if (metier.isEmpty ||
        villeController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tous les champs obligatoires doivent être remplis."),
        ),
      );
      return;
    }

    try {
      await supabase.from('prestataires').update({
        'metier': metier,
        'category': _categoryForJob(metier),
        'ville': villeController.text.trim(),
        'phone': phoneController.text.trim(),
        'description': descriptionController.text.trim(),
        'image': _imageUrl ?? widget.prestataire['image'] ?? '',
      }).eq('id', prestataireId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil prestataire mis à jour !")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la sauvegarde : $e")),
        );
      }
    }
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer ce profil prestataire ?"),
        content: const Text("Cette action est irréversible."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final supabase = Supabase.instance.client;
              final prestataireId = widget.prestataire['id'];

              try {
                // Optionnel: supprimer aussi la photo storage actuelle
                final url = _imageUrl;
                await supabase
                    .from('prestataires')
                    .delete()
                    .eq('id', prestataireId);
                await _deleteOldImageIfAny(url);

                if (mounted) {
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Prestataire supprimé.")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erreur suppression : $e")),
                  );
                }
              }
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Modifier mon espace prestataire",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: prestatairePrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _delete,
          ),
        ],
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundImage: _photoFile != null
                      ? FileImage(_photoFile!)
                      : (_imageUrl != null && _imageUrl!.isNotEmpty)
                          ? NetworkImage(_imageUrl!)
                          : const AssetImage('assets/avatar.png')
                              as ImageProvider,
                  backgroundColor: Colors.grey[200],
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: InkWell(
                    onTap: _isUploading ? null : _pickImageAndUpload,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.edit,
                              color: prestatairePrimary,
                              size: 22,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 23),
          TextField(
            controller: jobController,
            decoration: InputDecoration(
              labelText: "Métier *",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              labelStyle: const TextStyle(color: prestatairePrimary),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: prestatairePrimary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: villeController,
            decoration: InputDecoration(
              labelText: "Ville *",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              labelStyle: const TextStyle(color: prestatairePrimary),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: prestatairePrimary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: phoneController,
            decoration: InputDecoration(
              labelText: "Téléphone *",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              labelStyle: const TextStyle(color: prestatairePrimary),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: prestatairePrimary, width: 2),
              ),
              prefixIcon: const Icon(Icons.phone, color: prestataireSecondary),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 15),
          TextField(
            controller: descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: "Description",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              labelStyle: const TextStyle(color: prestatairePrimary),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: prestatairePrimary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text("Enregistrer les modifications"),
            style: ElevatedButton.styleFrom(
              backgroundColor: prestatairePrimary,
              foregroundColor: prestataireOnPrimary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
