// lib/pages/post_create_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/post_service.dart';

class PickedMedia {
  final Uint8List bytes;
  final String filename;
  final String mimeType;
  final String? localPath; // optionnel (mobile)

  bool get isVideo => mimeType.startsWith('video/');
  bool get isImage => mimeType.startsWith('image/');

  PickedMedia({
    required this.bytes,
    required this.filename,
    required this.mimeType,
    this.localPath,
  });
}

class PostCreatePage extends StatefulWidget {
  const PostCreatePage({super.key, required this.media});
  final PickedMedia media;

  @override
  State<PostCreatePage> createState() => _PostCreatePageState();
}

class _PostCreatePageState extends State<PostCreatePage> {
  final _svc = PostService();
  final _txt = TextEditingController();
  VideoPlayerController? _videoCtrl;
  bool _publishing = false;

  @override
  void dispose() {
    _videoCtrl?.dispose();
    _txt.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_publishing) return;
    setState(() => _publishing = true);
    try {
      final post = await _svc.createPostWithMedia(
        bytes: widget.media.bytes,
        filename: widget.media.filename,
        mimeType: widget.media.mimeType,
        textContent: _txt.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop<Map<String, dynamic>>(context, post);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur publication: $e')));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.media;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle publication')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: Center(
                child: m.isImage
                    ? Image.memory(m.bytes, fit: BoxFit.contain)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam, color: Colors.white, size: 48),
                          const SizedBox(height: 8),
                          Text(m.filename, style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          const Text('Aperçu vidéo simplifié', style: TextStyle(color: Colors.white38)),
                        ],
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              children: [
                TextField(
                  controller: _txt,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Ajouter une légende…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _publishing ? null : _publish,
                    icon: const Icon(Icons.cloud_upload),
                    label: Text(_publishing ? 'Publication…' : 'Publier'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
