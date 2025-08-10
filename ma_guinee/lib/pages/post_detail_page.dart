// lib/pages/post_detail_page.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/post_service.dart';
import 'post_create_page.dart' show PostCreatePage, PickedMedia;
import 'main_navigation_page.dart';

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.post});
  final Map<String, dynamic> post;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _svc = PostService();

  late Map<String, dynamic> _post;
  List<_MediaItem> _media = [];
  final List<VideoPlayerController?> _controllers = [];
  bool _loading = true;
  bool _muted = true;
  int _currentIndex = 0;

  int _likes = 0;
  int _comments = 0;
  int _views = 0;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _post = Map<String, dynamic>.from(widget.post);
    _likes = (_post['likes_count'] ?? 0) as int;
    _comments = (_post['comments_count'] ?? 0) as int;
    _views = (_post['views_count'] ?? 0) as int;
    _bootstrap();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c?.dispose();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      // 1) charger les médias
      List<Map<String, dynamic>> raw = [];
      if (_post['post_media'] is List && (_post['post_media'] as List).isNotEmpty) {
        raw = (_post['post_media'] as List)
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        final rows = await Supabase.instance.client
            .from('post_media')
            .select('url, type, position, width, height, duration_ms')
            .eq('post_id', _post['id'])
            .order('position', ascending: true);
        raw = (rows as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      // 2) signer + préparer les contrôleurs vidéo
      _media.clear();
      _controllers.clear();
      for (final m in raw) {
        final path = (m['url'] ?? '').toString();
        final type = (m['type'] ?? '').toString();
        final signed = path.isEmpty ? '' : await _svc.getSignedUrl(path);

        if (type == 'video' && signed.isNotEmpty) {
          final ctrl = VideoPlayerController.networkUrl(Uri.parse(signed));
          await ctrl.initialize();
          ctrl
            ..setLooping(true)
            ..setVolume(_muted ? 0 : 1);
          _controllers.add(ctrl);
          _media.add(_MediaItem(type: _MediaType.video, signedUrl: signed));
        } else {
          _controllers.add(null);
          _media.add(_MediaItem(type: _MediaType.image, signedUrl: signed));
        }
      }

      // 3) vue unique
      await _svc.incrementView(_post['id'] as String);
      _views += 1;

      // 4) autoplay premier média vidéo
      if (_controllers.isNotEmpty &&
          _controllers.first != null &&
          _controllers.first!.value.isInitialized) {
        _controllers.first!.play();
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onPageChanged(int i) {
    final prev = _controllers[_currentIndex];
    prev?.pause();
    final next = _controllers[i];
    if (next != null && next.value.isInitialized) {
      next.play();
    }
    setState(() => _currentIndex = i);
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      final c = _controllers[_currentIndex];
      c?.setVolume(_muted ? 0 : 1);
    });
  }

  Future<void> _toggleLike() async {
    try {
      final res = await _svc.toggleLike(_post['id'] as String);
      _isLiked = (res['is_liked'] as bool?) ?? false;
      _likes = (res['likes_count'] as int?) ?? _likes;
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur like: $e')));
    }
  }

  Future<void> _openCommentsSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CommentsSheet(
        postId: _post['id'] as String,
        svc: _svc,
        onNewComment: () => setState(() => _comments += 1),
      ),
    );
  }

  /// Ouvre directement le sélecteur média (web/mobile/desktop) puis la page composer
  Future<void> _pickAndOpenComposer() async {
    try {
      Uint8List? bytes;
      String? filename;
      String? mime;
      String? localPath;

      if (kIsWeb) {
        final res = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.media,
          withData: true,
        );
        if (res == null || res.files.isEmpty) return;
        final f = res.files.first;

        bytes = f.bytes!;
        filename = f.name;

        // Pas de f.mimeType fiable sur toutes plateformes → on détecte
        final header = (f.bytes != null && f.bytes!.isNotEmpty)
            ? f.bytes!.sublist(0, f.bytes!.length < 32 ? f.bytes!.length : 32)
            : null;
        mime = lookupMimeType(f.name, headerBytes: header) ??
            'application/octet-stream';
      } else {
        final choice = await showModalBottomSheet<String>(
          context: context,
          builder: (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo),
                  title: const Text('Photo'),
                  onTap: () => Navigator.pop(context, 'image'),
                ),
                ListTile(
                  leading: const Icon(Icons.videocam),
                  title: const Text('Vidéo'),
                  onTap: () => Navigator.pop(context, 'video'),
                ),
              ],
            ),
          ),
        );
        if (choice == null) return;

        if (choice == 'image') {
          final x = await ImagePicker()
              .pickImage(source: ImageSource.gallery, maxWidth: 2160);
          if (x == null) return;
          bytes = await x.readAsBytes();
          filename = x.name;
          mime = lookupMimeType(x.name) ?? 'image/*';
          localPath = x.path;
        } else {
          final x = await ImagePicker()
              .pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 5));
          if (x == null) return;
          bytes = await x.readAsBytes();
          filename = x.name;
          mime = lookupMimeType(x.name) ?? 'video/*';
          localPath = x.path;
        }
      }

      final media = PickedMedia(
        bytes: bytes!,
        filename: filename!,
        mimeType: mime!,
        localPath: localPath,
      );

      final created = await Navigator.push<Map<String, dynamic>?>(
        context,
        MaterialPageRoute(builder: (_) => PostCreatePage(media: media)),
      );

      if (created != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publication réussie')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sélection média: $e')));
    }
  }

  /// Clic sur le logo : revient à la navigation principale si déjà ouverte,
  /// sinon la rouvre.
  void _goHomeOnExistingNav() {
    bool found = false;
    Navigator.of(context).popUntil((route) {
      if (route.settings.name == '/main') {
        found = true;
        return true;
      }
      return false;
    });
    if (!found) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationPage()),
        (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final padTop = MediaQuery.of(context).padding.top;
    final text = (_post['text_content'] ?? '').toString();

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 54,
        leading: Padding(
          padding: EdgeInsets.only(top: padTop > 0 ? 0 : 6, left: 8),
          child: GestureDetector(
            onTap: _goHomeOnExistingNav,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 1),
              ),
              child: Image.asset('assets/logo_guinee.png', height: 22),
            ),
          ),
        ),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                if (_media.isEmpty)
                  const Center(
                    child: Text('Aucun média',
                        style: TextStyle(color: Colors.white70)),
                  )
                else
                  PageView.builder(
                    itemCount: _media.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (_, i) {
                      final m = _media[i];
                      if (m.type == _MediaType.video) {
                        final c = _controllers[i];
                        if (c == null || !c.value.isInitialized) {
                          return const Center(
                              child:
                                  CircularProgressIndicator(color: Colors.white));
                        }
                        final size = c.value.size;
                        return GestureDetector(
                          onTap: () =>
                              c.value.isPlaying ? c.pause() : c.play(),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: size.width,
                                height: size.height,
                                child: VideoPlayer(c),
                              ),
                            ),
                          ),
                        );
                      } else {
                        return m.signedUrl.isEmpty
                            ? const SizedBox.shrink()
                            : Image.network(
                                m.signedUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              );
                      }
                    },
                  ),

                // Mute
                Positioned(
                  right: 16,
                  top: padTop + 12,
                  child: GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.38),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Icon(
                        _muted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                // Texte + compteurs
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (text.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            text,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _Chip(icon: Icons.favorite, label: '$_likes'),
                          const SizedBox(width: 8),
                          _Chip(
                              icon: Icons.mode_comment_outlined,
                              label: '$_comments'),
                          const SizedBox(width: 8),
                          _Chip(icon: Icons.remove_red_eye, label: '$_views'),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                Positioned(
                  right: 16,
                  bottom: 120,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FabAction(
                        icon: _isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        onTap: _toggleLike,
                      ),
                      const SizedBox(height: 12),
                      _FabAction(
                        icon: Icons.chat_bubble_outline,
                        onTap: _openCommentsSheet,
                      ),
                      const SizedBox(height: 12),
                      _FabAction(
                        icon: Icons.more_horiz,
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (_) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.share),
                                    title: const Text('Partager'),
                                    onTap: () => Navigator.pop(context),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.flag_outlined),
                                    title: const Text('Signaler'),
                                    onTap: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

      // Barre du bas
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomBtn(
                  icon: Icons.person_outline,
                  label: 'Profil',
                  onTap: () {},
                ),
                _BottomBtn(
                  icon: Icons.add_box_outlined,
                  label: 'Ajouter',
                  onTap: _pickAndOpenComposer,
                ),
                _BottomBtn(
                  icon: Icons.chat_bubble_outline,
                  label: 'Messages',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ====== UI utils ======

class _FabAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _FabAction({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _BottomBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BottomBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ====== Modèle interne ======

enum _MediaType { image, video }

class _MediaItem {
  final _MediaType type;
  final String signedUrl;
  _MediaItem({required this.type, required this.signedUrl});
}

// ====== Commentaires ======

class _CommentsSheet extends StatefulWidget {
  final String postId;
  final PostService svc;
  final VoidCallback onNewComment;
  const _CommentsSheet({
    required this.postId,
    required this.svc,
    required this.onNewComment,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.svc.listComments(widget.postId);
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _post() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    try {
      final row = await widget.svc.addComment(widget.postId, txt);
      if (!mounted) return;
      setState(() {
        _items.insert(0, row);
        _ctrl.clear();
      });
      widget.onNewComment();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 12,
          right: 12,
          top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Commentaires',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: Colors.white),
              )
            else
              Flexible(
                child: _items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Aucun commentaire',
                            style: TextStyle(color: Colors.white70)),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _items.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white10),
                        itemBuilder: (_, i) {
                          final c = _items[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text((c['content'] ?? '').toString(),
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              (c['created_at'] ?? '').toString(),
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                          );
                        },
                      ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Écrire un commentaire…',
                      hintStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                    ),
                    onSubmitted: (_) => _post(),
                  ),
                ),
                IconButton(
                  onPressed: _post,
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
