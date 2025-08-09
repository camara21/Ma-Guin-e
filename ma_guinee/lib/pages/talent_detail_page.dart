import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/storage_service.dart';
import '../services/talents_service.dart';

class TalentDetailPage extends StatefulWidget {
  final Map<String, dynamic> talent;
  const TalentDetailPage({super.key, required this.talent});

  @override
  State<TalentDetailPage> createState() => _TalentDetailPageState();
}

class _TalentDetailPageState extends State<TalentDetailPage>
    with WidgetsBindingObserver {
  final _svc = TalentsService();
  final _storage = StorageService();

  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;

  bool _liked = false;
  int _likesCount = 0;
  int _viewsCount = 0;
  bool _viewCounted = false;

  final _commentCtrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loadingComments = true;

  // Thème app
  Color get red => const Color(0xFFCE1126);
  Color get yellow => const Color(0xFFFCD116);
  Color get blue => const Color(0xFF113CFC);

  Future<void> _initPlayer() async {
    final path = (widget.talent['video_url'] ?? '') as String;
    if (path.isEmpty) return;

    try {
      // URL signée (marche même si le bucket est public aujourd’hui)
      final signed = await _storage.signedUrl(
        'talents-videos',
        path,
        expiresInSeconds: 3600,
      );

      final ctrl = VideoPlayerController.networkUrl(Uri.parse(signed));
      await ctrl.initialize();

      if (!mounted) return;
      _videoCtrl = ctrl;
      _chewieCtrl = ChewieController(
        videoPlayerController: ctrl,
        autoPlay: true,
        looping: false,
        showControls: true, // passe à false si tu veux un UI ultra clean
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de lecture vidéo: $e')),
      );
    }
  }

  Future<void> _loadState() async {
    try {
      final id = widget.talent['id']; // Object (int ou String)
      final liked = await _svc.isLiked(id);
      final comments = await _svc.listComments(id);

      _likesCount = (widget.talent['likes_count'] ?? 0) as int;
      _viewsCount = (widget.talent['views_count'] ?? 0) as int;

      if (!mounted) return;
      setState(() {
        _liked = liked;
        _comments = comments;
        _loadingComments = false;
      });

      _incrementViewsOnce(); // +1 vue en arrière-plan, une seule fois
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingComments = false);
    }
  }

  Future<void> _incrementViewsOnce() async {
    if (_viewCounted) return;
    _viewCounted = true;

    final id = widget.talent['id']; // Object
    try {
      await _svc.incrementViews(id);
      if (!mounted) return;
      setState(() => _viewsCount += 1);
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _toggleLike() async {
    final id = widget.talent['id']; // Object

    try {
      if (_liked) {
        await _svc.unlike(id);
        if (!mounted) return;
        setState(() {
          _liked = false;
          _likesCount = (_likesCount - 1).clamp(0, 1 << 30);
        });
      } else {
        await _svc.like(id);
        if (!mounted) return;
        setState(() {
          _liked = true;
          _likesCount += 1;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _postComment() async {
    final txt = _commentCtrl.text.trim();
    if (txt.isEmpty) return;

    final id = widget.talent['id']; // Object

    try {
      final row = await _svc.addComment(id, txt);
      if (!mounted) return;
      setState(() {
        _comments.insert(0, row);
        _commentCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<String?> _thumbUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    return _storage.publicUrl('talents-thumbs', path);
  }

  // Tap pour play/pause
  void _togglePlayPause() {
    final v = _videoCtrl;
    if (v == null || !v.value.isInitialized) return;
    if (v.value.isPlaying) {
      v.pause();
    } else {
      v.play();
    }
    setState(() {});
  }

  // Pause en background / reprise en foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final v = _videoCtrl;
    if (v == null) return;
    if (state == AppLifecycleState.paused) {
      v.pause();
    } else if (state == AppLifecycleState.resumed) {
      // Si tu veux auto-reprendre:
      // v.play();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPlayer();
    _loadState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  String _formatDate(dynamic value) {
    if (value is String) {
      final dt = DateTime.tryParse(value);
      if (dt != null) {
        final local = dt.toLocal();
        return '${local.day.toString().padLeft(2, '0')}/'
            '${local.month.toString().padLeft(2, '0')}/'
            '${local.year} ${local.hour.toString().padLeft(2, '0')}:'
            '${local.minute.toString().padLeft(2, '0')}';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.talent;
    final theme = Theme.of(context);

    final aspect = (_videoCtrl?.value.isInitialized ?? false)
        ? _videoCtrl!.value.aspectRatio
        : (16 / 9);

    return Scaffold(
      appBar: AppBar(
        title: Text((t['titre'] ?? 'Talent').toString()),
        backgroundColor: Colors.white,
        foregroundColor: blue,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Player (tap = play/pause)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: aspect,
              child: GestureDetector(
                onTap: _togglePlayPause,
                behavior: HitTestBehavior.opaque,
                child: (_chewieCtrl != null &&
                        (_videoCtrl?.value.isInitialized ?? false))
                    ? Chewie(controller: _chewieCtrl!)
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Carte titre + stats + mini-thumb
          FutureBuilder<String?>(
            future: _thumbUrl(t['thumbnail_url']),
            builder: (_, snap) {
              final thumb = snap.data;
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MiniThumb(thumbUrl: thumb, accent: red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (t['titre'] ?? '').toString(),
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${t['genre'] ?? ''}'
                              '${(t['genre'] ?? '').toString().isNotEmpty ? ' • ' : ''}'
                              '${t['ville'] ?? ''}',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey[800]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _toggleLike,
                                  icon: Icon(
                                    _liked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: _liked ? red : null,
                                  ),
                                  tooltip:
                                      _liked ? 'Retirer le like' : 'Aimer',
                                ),
                                Text('$_likesCount'),
                                const SizedBox(width: 18),
                                const Icon(Icons.remove_red_eye, size: 18),
                                const SizedBox(width: 4),
                                Text('$_viewsCount vues'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 10),
          if ((t['description'] ?? '').toString().isNotEmpty) ...[
            Text((t['description'] ?? '').toString()),
            const SizedBox(height: 16),
          ],

          // Bandeau commentaires
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [red, yellow],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: const Text(
              "Commentaires",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),

          // Saisie commentaire
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Écrire un commentaire…',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _postComment(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _postComment,
                icon: const Icon(Icons.send),
                label: const Text('Envoyer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_loadingComments)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),

          if (!_loadingComments && _comments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucun commentaire.'),
            ),

          ..._comments.map(
            (c) => ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text((c['contenu'] ?? '').toString()),
              subtitle: Text(_formatDate(c['created_at'])),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- petits widgets ----------
class _MiniThumb extends StatelessWidget {
  final String? thumbUrl;
  final Color accent;
  const _MiniThumb({required this.thumbUrl, required this.accent});

  @override
  Widget build(BuildContext context) {
    final placeholder = Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 86,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [accent.withOpacity(0.15), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Icon(Icons.play_circle_fill_rounded, color: accent, size: 28),
      ],
    );

    if (thumbUrl == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: placeholder,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        thumbUrl!,
        width: 86,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}
