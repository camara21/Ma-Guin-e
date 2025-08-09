import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/talents_service.dart';

class TalentUploadPage extends StatefulWidget {
  const TalentUploadPage({super.key});

  @override
  State<TalentUploadPage> createState() => _TalentUploadPageState();
}

class _TalentUploadPageState extends State<TalentUploadPage> {
  final _titre = TextEditingController();
  final _genre = TextEditingController();
  final _ville = TextEditingController();
  final _description = TextEditingController();

  final _svc = TalentsService();
  PlatformFile? _video;
  PlatformFile? _thumb;
  bool _submitting = false;

  // Couleurs thème
  Color get red => const Color(0xFFCE1126);
  Color get yellow => const Color(0xFFFCD116);
  Color get green => const Color(0xFF009460);
  Color get blue => const Color(0xFF113CFC);

  // -------- Pickers ----------
  Future<void> _pickVideo() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: true,
    );
    if (!mounted) return;
    if (res != null && res.files.isNotEmpty) {
      setState(() => _video = res.files.single);
    }
  }

  Future<void> _pickThumb() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (!mounted) return;
    if (res != null && res.files.isNotEmpty) {
      setState(() => _thumb = res.files.single);
    }
  }

  // -------- Upload direct Supabase ----------
  Future<String> _uploadToBucket({
    required String bucket,
    required String filename,
    required Uint8List bytes,
  }) async {
    final supa = Supabase.instance.client;
    final userId = supa.auth.currentUser?.id;
    if (userId == null) throw 'Utilisateur non connecté';

    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'bin';
    final objectPath = 'u/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await supa.storage
        .from(bucket)
        .uploadBinary(objectPath, bytes, fileOptions: const FileOptions(upsert: true));

    // On renvoie le chemin (stocké en DB). La lecture se fera via URL signée.
    return objectPath;
  }

  Future<void> _submit() async {
    if (_video == null || _video!.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionne une vidéo.')),
      );
      return;
    }
    if (_titre.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le titre est obligatoire.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      // 1) Upload vidéo
      final videoPath = await _uploadToBucket(
        bucket: 'talents-videos',
        filename: _video!.name,
        bytes: _video!.bytes!,
      );

      // 2) Upload miniature (optionnel)
      String? thumbPath;
      if (_thumb != null && _thumb!.bytes != null) {
        thumbPath = await _uploadToBucket(
          bucket: 'talents-thumbs',
          filename: _thumb!.name,
          bytes: _thumb!.bytes!,
        );
      }

      // 3) Enregistrer en base et RENVoyer l’élément créé
      // ⚠️ Assure-toi que createTalent RETOURNE la ligne créée (Map avec 'id')
      final created = await _svc.createTalent(
        titre: _titre.text.trim(),
        genre: _genre.text.trim().isEmpty ? null : _genre.text.trim(),
        ville: _ville.text.trim().isEmpty ? null : _ville.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        videoPath: videoPath,
        thumbnailPath: thumbPath,
      ); // <-- doit renvoyer p.ex. { id: 123, ... }

      if (!mounted) return;

      // 4) Succès + retour de la ligne au caller (Reels)
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Publié ✅'),
          content: const Text("Ta démo a été publiée. Merci de partager ton talent !"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );

      // On renvoie l’élément créé pour que TalentsReelsPage se positionne dessus
      Navigator.pop<Map<String, dynamic>>(context, created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publier une démo'),
        backgroundColor: Colors.white,
        foregroundColor: blue,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Bannière
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [red, yellow],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.music_video_rounded, color: Colors.white, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Découvre et fais découvrir les talents de Guinée.\n"
                      "Publie ta meilleure vidéo et fais-toi repérer !",
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Champs
            TextField(controller: _titre, decoration: const InputDecoration(labelText: 'Titre *')),
            const SizedBox(height: 12),
            TextField(controller: _genre, decoration: const InputDecoration(labelText: 'Genre (rap, afro, slam…)')),
            const SizedBox(height: 12),
            TextField(controller: _ville, decoration: const InputDecoration(labelText: 'Ville')),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Sélecteurs fichiers
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickVideo,
                    icon: Icon(Icons.video_file, color: blue),
                    label: Text(
                      _video == null ? 'Choisir une vidéo *' : _video!.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickThumb,
                    icon: Icon(Icons.image, color: green),
                    label: Text(
                      _thumb == null ? "Image d'aperçu (optionnel)" : _thumb!.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            if (_thumb?.bytes != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(_thumb!.bytes!, height: 120, fit: BoxFit.cover),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.cloud_upload),
                label: _submitting ? const Text('Envoi...') : const Text('Soumettre'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Formats vidéo acceptés (mp4, mov…). Le temps d’envoi dépend de ta connexion.",
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
