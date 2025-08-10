// lib/pages/posts_reels_page.dart
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

// services & pages
import '../services/post_service.dart';
import 'post_detail_page.dart';
import 'post_create_page.dart' show PostCreatePage, PickedMedia;
import 'live_page.dart';
import 'main_navigation_page.dart';

class PostsReelsPage extends StatefulWidget {
  const PostsReelsPage({super.key, this.startPostId});
  final String? startPostId;

  @override
  State<PostsReelsPage> createState() => _PostsReelsPageState();
}

class _PostsReelsPageState extends State<PostsReelsPage> with TickerProviderStateMixin {
  final _svc = PostService();
  final PageController _pageCtrl = PageController();

  final List<Map<String, dynamic>> _items = [];
  final Map<int, VideoPlayerController> _controllers = {};
  final Set<String> _liked = {};

  bool _loading = false;
  bool _end = false;
  int _offset = 0;
  final int _limit = 6;
  int _current = 0;
  bool _muted = true;

  Color get _red => const Color(0xFFCE1126);
  Color get _yellow => const Color(0xFFFCD116);
  Color get _green => const Color(0xFF009460);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _load(reset: true).then((_) {
      if (!mounted) return;
      if (widget.startPostId != null) {
        final i = _items.indexWhere((e) => e['id'] == widget.startPostId);
        if (i >= 0) { _current = i; _pageCtrl.jumpToPage(i); }
      }
      _playIndex(_current);
    });
    _pageCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    _pageCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ---------- NAV ----------
  void _goHomeOnExistingNav() {
    bool found = false;
    Navigator.of(context).popUntil((route) {
      if (route.settings.name == '/main') { found = true; return true; }
      return false;
    });
    if (!found) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationPage()),
        (r) => false,
      );
    }
  }

  void _openSearch() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('Recherche (bientôt)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Filtrer par texte, auteur…', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- DATA / SCROLL ----------
  void _onScroll() {
    final p = _pageCtrl.page ?? 0;
    final idx = p.round();
    if (idx != _current) {
      _pauseIndex(_current);
      _current = idx;
      _playIndex(_current);
      if (_current >= _items.length - 2 && !_loading && !_end) _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);

    if (reset) {
      _end = false; _offset = 0;
      for (final c in _controllers.values) c.dispose();
      _controllers.clear(); _items.clear();
    }

    final rows = await _svc.fetchFeed(limit: _limit, offset: _offset);
    if (rows.length < _limit) _end = true;
    _items.addAll(rows);
    _offset += rows.length;

    _ensureController(_current);
    _ensureController(_current + 1);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _ensureController(int index) async {
    if (index < 0 || index >= _items.length) return;
    if (_controllers[index] != null) return;

    final row = _items[index];
    final media = (row['post_media'] as List?) ?? [];
    final first = media.isNotEmpty ? media.first as Map<String, dynamic> : null;
    final isVideo = (first?['type'] ?? '') == 'video';
    final url = first?['url'] as String?;

    if (url == null || url.isEmpty || !isVideo) return;

    try {
      final signed = await _svc.getSignedUrl(url);
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(signed));
      await ctrl.initialize();
      ctrl..setLooping(true)..setVolume(_muted ? 0 : 1);
      _controllers[index] = ctrl;
      if (mounted) setState((){});
    } catch (_) {}
  }

  void _playIndex(int index) async {
    final c = _controllers[index];
    if (c == null) { await _ensureController(index); _controllers[index]?.play(); }
    else { if (c.value.isInitialized) c.play(); }

    // incrément local + fire-and-forget côté serveur
    if (index >= 0 && index < _items.length) {
      final id = _items[index]['id'] as String;
      final v = (_items[index]['views_count'] ?? 0) as int;
      _items[index]['views_count'] = v + 1;
      _svc.incrementView(id);
    }

    _pauseIndex(index - 1);
    _pauseIndex(index + 1);
    _ensureController(index + 1);
    if (mounted) setState((){});
  }

  void _pauseIndex(int index) {
    final c = _controllers[index];
    if (c != null && c.value.isInitialized) c.pause();
  }

  // ---------- ACTIONS ----------
  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _controllers[_current]?.setVolume(_muted ? 0 : 1);
    });
  }

  Future<void> _toggleLike(String postId, int index) async {
    try {
      final res = await _svc.toggleLike(postId);
      final isLiked = (res['is_liked'] as bool?) ?? false;
      final likes = (res['likes_count'] as int?) ?? 0;
      _items[index]['likes_count'] = likes;
      if (isLiked) _liked.add(postId); else _liked.remove(postId);
      if (mounted) setState((){});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur like: $e')));
    }
  }

  Future<void> _openComments(Map<String,dynamic> p, int index) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _CommentsSheet(
        postId: p['id'] as String,
        svc: _svc,
        onAdded: (delta) {
          final cur = (_items[index]['comments_count'] ?? 0) as int;
          _items[index]['comments_count'] = cur + delta;
          if (mounted) setState((){});
        },
      ),
    );
  }

  Future<void> _sharePost(Map<String,dynamic> p, int index) async {
    try { await _svc.incrementShare(p['id'] as String); } catch (_) {}
    final cur = (_items[index]['shares_count'] ?? 0) as int;
    _items[index]['shares_count'] = cur + 1;
    if (mounted) setState((){});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Partage effectué.')));
  }

  void _openGiftSheet(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.95),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16,16,16,28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Envoyer un cadeau', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _GiftChip(label: '1 000 GNF', colors: [_yellow,_green], onTap: ()=>_sendGift(p,1000)),
              _GiftChip(label: '5 000 GNF', colors: [_red,_yellow], onTap: ()=>_sendGift(p,5000)),
              _GiftChip(label: '10 000 GNF', colors: [_green,_yellow], onTap: ()=>_sendGift(p,10000)),
              _GiftChip(label: '25 000 GNF', colors: [_yellow,_green], onTap: ()=>_sendGift(p,25000)),
            ]),
            const SizedBox(height: 10),
            TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.white70))),
          ]),
        ),
      ),
    );
  }

  void _sendGift(Map<String, dynamic> p, int amount) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cadeau ${amount.toString()} GNF envoyé (démo).')),
    );
  }

  void _openMore(Map<String, dynamic> p) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.flag, color: Colors.white),
            title: const Text('Signaler', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signalement envoyé. Merci !')));
            },
          ),
        ]),
      ),
    );
  }

  // ---------- PUBLISH ----------
  Future<void> _openPublish() async {
    try {
      Uint8List? bytes; String? filename; String? mime; String? localPath;

      if (kIsWeb) {
        final res = await FilePicker.platform.pickFiles(allowMultiple: false, type: FileType.media, withData: true);
        if (res == null || res.files.isEmpty) return;
        final f = res.files.first; bytes = f.bytes!; filename = f.name;
        final header = (f.bytes!=null && f.bytes!.isNotEmpty) ? f.bytes!.sublist(0, f.bytes!.length<32? f.bytes!.length:32) : null;
        mime = lookupMimeType(f.name, headerBytes: header) ?? 'application/octet-stream';
      } else {
        final choice = await showModalBottomSheet<String>(
          context: context,
          builder: (_) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(leading: const Icon(Icons.photo), title: const Text('Photo'), onTap: ()=>Navigator.pop(context,'image')),
              ListTile(leading: const Icon(Icons.videocam), title: const Text('Vidéo'), onTap: ()=>Navigator.pop(context,'video')),
            ]),
          ),
        );
        if (choice == null) return;

        if (choice == 'image') {
          final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2160);
          if (x == null) return;
          bytes = await x.readAsBytes(); filename = x.name; mime = lookupMimeType(x.name) ?? 'image/*'; localPath = x.path;
        } else {
          final x = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 5));
          if (x == null) return;
          bytes = await x.readAsBytes(); filename = x.name; mime = lookupMimeType(x.name) ?? 'video/*'; localPath = x.path;
        }
      }

      final media = PickedMedia(bytes: bytes!, filename: filename!, mimeType: mime!, localPath: localPath);
      final created = await Navigator.push<Map<String, dynamic>?>(
        context, MaterialPageRoute(builder: (_) => PostCreatePage(media: media)),
      );

      if (created != null) {
        await _load(reset: true);
        final i = _items.indexWhere((e) => e['id'] == created['id']);
        if (i >= 0) { _current = i; _pageCtrl.jumpToPage(i); _playIndex(i); }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sélection média: $e')));
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final padTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(children: [
        if (_items.isEmpty && _loading)
          const Center(child: CircularProgressIndicator(color: Colors.white))
        else if (_items.isEmpty)
          const Center(child: Text('Aucun post pour le moment', style: TextStyle(color: Colors.white70)))
        else
          PageView.builder(
            controller: _pageCtrl,
            scrollDirection: Axis.vertical,
            itemCount: _items.length,
            itemBuilder: (_, i) {
              final data = _items[i];
              final postId = data['id'] as String;
              final media = (data['post_media'] as List?) ?? [];
              final first = media.isNotEmpty ? media.first as Map<String,dynamic> : null;
              final isVideo = (first?['type'] ?? '') == 'video';
              final isLiked = _liked.contains(postId);

              return _ReelItem(
                data: data,
                controller: _controllers[i],
                isVideo: isVideo,
                brandRed: _red, brandYellow: _yellow, brandGreen: _green,
                muted: _muted, isLiked: isLiked,
                onTapVideo: () { final c = _controllers[i]; if (c==null) return; c.value.isPlaying ? c.pause() : c.play(); setState((){}); },
                onOpenDetail: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailPage(post: data))),
                onToggleLike: () => _toggleLike(postId, i),
                onOpenComments: () => _openComments(data, i),
                onShare: () => _sharePost(data, i),
                onGift: () => _openGiftSheet(data),
                onMore: () => _openMore(data),
              );
            },
          ),

        // top bar : recherche, Live, logo, mute
        Positioned(
          left: 12, right: 12, top: padTop + 8,
          child: Row(children: [
            GestureDetector(
              onTap: _openSearch,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.30), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                child: const Icon(Icons.search, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LivePage())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white24)),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.wifi_tethering, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('Live', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                ]),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _goHomeOnExistingNav,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.30), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                child: Image.asset('assets/logo_guinee.png', height: 18),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _toggleMute,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.30), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                child: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ]),

      // bottom nav (Neo Dock)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: _NeoDock(
            current: 0,
            onHome: () {}, onFriends: () {}, onAdd: _openPublish, onMessages: () {}, onProfile: () {},
            brandRed: _red, brandYellow: _yellow, brandGreen: _green,
          ),
        ),
      ),
    );
  }
}

/// =======================
/// ITEM REEL
/// =======================
class _ReelItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final VideoPlayerController? controller;
  final bool isVideo;
  final bool muted;
  final bool isLiked;
  final VoidCallback onTapVideo, onOpenDetail, onToggleLike, onOpenComments, onShare, onGift, onMore;
  final Color brandRed, brandYellow, brandGreen;

  const _ReelItem({
    required this.data,
    required this.controller,
    required this.isVideo,
    required this.muted,
    required this.isLiked,
    required this.onTapVideo,
    required this.onOpenDetail,
    required this.onToggleLike,
    required this.onOpenComments,
    required this.onShare,
    required this.onGift,
    required this.onMore,
    required this.brandRed,
    required this.brandYellow,
    required this.brandGreen,
  });

  Widget _buildMediaLayer() {
    if (isVideo) {
      if (controller == null || !controller!.value.isInitialized) {
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      }
      final size = controller!.value.size;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTapVideo,
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(controller!)),
          ),
        ),
      );
    } else {
      final media = (data['post_media'] as List?) ?? [];
      final first = media.isNotEmpty ? media.first as Map<String, dynamic> : null;
      final url = (first?['url'] ?? first?['public_url'] ?? '') as String;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTapVideo,
        child: Image.network(url, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = (data['text_content'] ?? '').toString();
    final likes = (data['likes_count'] ?? 0) as int;
    final views = (data['views_count'] ?? 0) as int;
    final comments = (data['comments_count'] ?? 0) as int;
    final shares = (data['shares_count'] ?? 0) as int;

    final mediaLayer = _buildMediaLayer();

    return Stack(fit: StackFit.expand, children: [
      mediaLayer,

      // avatar auteur en haut-gauche
      Positioned(
        left: 12, top: MediaQuery.of(context).padding.top + 54,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {/* TODO: profil */},
          child: const CircleAvatar(
            radius: 18, backgroundColor: Colors.black45,
            child: Icon(Icons.person, color: Colors.white),
          ),
        ),
      ),

      // texte / auteur
      Positioned(
        left: 14, right: 110, bottom: 22,
        child: Text(
          text,
          maxLines: 3, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, height: 1.2),
        ),
      ),

      // actions alignées en bas : Like → Com → Vues → Partage → Cadeau → Plus
      Positioned(
        right: 14, bottom: 12,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _ActionIcon(
            bgGradient: [brandRed, brandYellow],
            child: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: Colors.white, size: 22),
            onTap: onToggleLike,
            counter: likes,
          ),
          const SizedBox(height: 10),
          _ActionIcon(
            bgGradient: [brandYellow, brandGreen],
            child: const _CommentBubbleLinesIcon(size: 22, stroke: 2),
            onTap: onOpenComments,
            counter: comments,
          ),
          const SizedBox(height: 10),
          _ActionIcon(
            bgGradient: const [Colors.white24, Colors.white24],
            child: const Icon(Icons.remove_red_eye, color: Colors.white, size: 22),
            counter: views,
          ),
          const SizedBox(height: 10),
          _ActionIcon(
            bgGradient: [brandRed, brandYellow],
            child: const _ShareTrayArrowIcon(size: 22, stroke: 2),
            onTap: onShare,
            counter: shares,
          ),
          const SizedBox(height: 10),
          _ActionIcon(
            bgGradient: const [Colors.white24, Colors.white24],
            child: const Icon(Icons.card_giftcard, color: Colors.white, size: 22),
            onTap: onGift,
          ),
          const SizedBox(height: 10),
          _ActionIcon(
            bgGradient: const [Colors.white24, Colors.white24],
            child: const Icon(Icons.more_horiz, color: Colors.white, size: 22),
            onTap: onMore,
          ),
        ]),
      ),
    ]);
  }
}

/// bouton rond + compteur sous l’icône
class _ActionIcon extends StatelessWidget {
  final List<Color> bgGradient;
  final Widget child;
  final VoidCallback? onTap;
  final int? counter;
  const _ActionIcon({required this.bgGradient, required this.child, this.onTap, this.counter});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Tooltip(
          message: counter != null ? '$counter' : '',
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(color: Colors.white),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: bgGradient),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              child: child,
            ),
          ),
        ),
        const SizedBox(height: 3),
        if (counter != null)
          Text('$counter', style: const TextStyle(color: Colors.white, fontSize: 11)),
      ],
    );
  }
}

/// ===== Icône COMMENTAIRE (bulle + 3 lignes)
class _CommentBubbleLinesIcon extends StatelessWidget {
  final double size; final double stroke;
  const _CommentBubbleLinesIcon({this.size = 24, this.stroke = 2});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _CommentLinesPainter(stroke));
}

class _CommentLinesPainter extends CustomPainter {
  final double stroke; _CommentLinesPainter(this.stroke);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final r = RRect.fromRectAndRadius(Rect.fromLTWH(3, 4, s.width - 6, s.height - 12), const Radius.circular(10));
    canvas.drawRRect(r, p);
    final tail = Path()
      ..moveTo(s.width/2 - 4, s.height - 8)
      ..lineTo(s.width/2, s.height - 2)
      ..lineTo(s.width/2 + 4, s.height - 8);
    canvas.drawPath(tail, p);

    // 3 lignes intérieures
    double left = r.left + 6, right = r.right - 6;
    final y1 = r.top + 6, y2 = y1 + 6, y3 = y2 + 6;
    canvas.drawLine(Offset(left, y1), Offset(right, y1), p);
    canvas.drawLine(Offset(left, y2), Offset(right, y2), p);
    canvas.drawLine(Offset(left, y3), Offset(right, y3), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ===== Icône PARTAGE (flèche courbe sortant d’un plateau)
class _ShareTrayArrowIcon extends StatelessWidget {
  final double size; final double stroke;
  const _ShareTrayArrowIcon({this.size = 24, this.stroke = 2});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _ShareTrayArrowPainter(stroke));
}

class _ShareTrayArrowPainter extends CustomPainter {
  final double stroke; _ShareTrayArrowPainter(this.stroke);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // plateau
    canvas.drawLine(Offset(3, s.height - 5), Offset(s.width - 3, s.height - 5), p);

    // flèche courbe
    final path = Path()
      ..moveTo(s.width*0.30, s.height*0.70)
      ..cubicTo(s.width*0.45, s.height*0.35, s.width*0.62, s.height*0.32, s.width*0.72, s.height*0.32)
      ..lineTo(s.width*0.72, s.height*0.18)
      ..moveTo(s.width*0.72, s.height*0.32)
      ..lineTo(s.width*0.58, s.height*0.32);
    // tête flèche
    final arrow = Path()
      ..moveTo(s.width*0.72, s.height*0.18)
      ..lineTo(s.width*0.82, s.height*0.28)
      ..moveTo(s.width*0.72, s.height*0.18)
      ..lineTo(s.width*0.62, s.height*0.28);
    canvas.drawPath(path, p);
    canvas.drawPath(arrow, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ===== Chip "cadeau"
class _GiftChip extends StatelessWidget {
  final String label; final List<Color> colors; final VoidCallback onTap;
  const _GiftChip({required this.label, required this.colors, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(100),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(100),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    ),
  );
}

/// ================
/// Commentaires
/// ================
class _CommentsSheet extends StatefulWidget {
  final String postId; final PostService svc;
  final ValueChanged<int>? onAdded; // informe le parent pour MAJ compteur
  const _CommentsSheet({required this.postId, required this.svc, this.onAdded});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final rows = await widget.svc.listComments(widget.postId);
      if (!mounted) return;
      setState(() { _items = rows; _loading = false; });
    } catch (_) {
      if (!mounted) return; setState(() => _loading = false);
    }
  }

  Future<void> _post() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    try {
      final row = await widget.svc.addComment(widget.postId, txt);
      if (!mounted) return;
      setState(() { _items.insert(0, row); _ctrl.clear(); });
      widget.onAdded?.call(1); // +1 pour le compteur parent
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 12, right: 12, top: 8,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 46, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 12),
          const Text('Commentaires', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white))
          else
            Flexible(
              child: _items.isEmpty
                  ? const Padding(padding: EdgeInsets.all(20), child: Text('Aucun commentaire', style: TextStyle(color: Colors.white70)))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                      itemBuilder: (_, i) {
                        final c = _items[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text((c['content'] ?? '').toString(), style: const TextStyle(color: Colors.white)),
                          subtitle: Text((c['created_at'] ?? '').toString(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        );
                      },
                    ),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Écrire un commentaire…',
                  hintStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                ),
                onSubmitted: (_) => _post(),
              ),
            ),
            IconButton(onPressed: _post, icon: const Icon(Icons.send, color: Colors.white)),
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

/// =======================
/// Neo Dock (barre réinventée)
/// =======================
class _NeoDock extends StatefulWidget {
  final int current;
  final VoidCallback onHome, onFriends, onAdd, onMessages, onProfile;
  final Color brandRed, brandYellow, brandGreen;
  const _NeoDock({
    required this.current,
    required this.onHome,
    required this.onFriends,
    required this.onAdd,
    required this.onMessages,
    required this.onProfile,
    required this.brandRed,
    required this.brandYellow,
    required this.brandGreen,
  });

  @override
  State<_NeoDock> createState() => _NeoDockState();
}

class _NeoDockState extends State<_NeoDock> with SingleTickerProviderStateMixin {
  late int _current = widget.current;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }
  void _set(int i) => setState(() => _current = i);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    const dockHeight = 64.0;

    return SizedBox(
      height: dockHeight + 18,
      child: Stack(alignment: Alignment.bottomCenter, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: dockHeight, width: w,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 6))],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _NeoDockItem(icon: Icons.home_rounded, active: _current == 0, onTap: (){ _set(0); widget.onHome(); }),
                _NeoDockItem(icon: Icons.group_rounded, active: _current == 1, onTap: (){ _set(1); widget.onFriends(); }),
                const SizedBox(width: 64),
                _NeoDockItem(icon: Icons.chat_bubble_rounded, active: _current == 3, onTap: (){ _set(3); widget.onMessages(); }),
                _NeoDockItem(icon: Icons.person_rounded, active: _current == 4, onTap: (){ _set(4); widget.onProfile(); }),
              ]),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: _indicatorLeftForIndex(_current, w),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 32, height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(colors: [widget.brandRed, widget.brandYellow, widget.brandGreen]),
            ),
          ),
        ),
        Positioned(
          bottom: dockHeight - 36,
          child: GestureDetector(
            onTap: () { _set(2); widget.onAdd(); },
            child: Stack(alignment: Alignment.center, children: [
              ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.08).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                child: Container(width: 66, height: 66, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.white24, Colors.transparent]))),
              ),
              Container(
                width: 58, height: 58,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(colors: [Color(0xFFCE1126), Color(0xFFFCD116), Color(0xFF009460), Color(0xFFCE1126)]),
                ),
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.90)),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  double _indicatorLeftForIndex(int i, double width) {
    const gapForCenter = 64.0, padding = 16.0;
    final usable = width - padding*2 - gapForCenter;
    final slot = usable / 4; final center = (slot - 32) / 2;
    final map = {
      0: padding + slot*0 + center,
      1: padding + slot*1 + center,
      3: padding + slot*2 + gapForCenter + center,
      4: padding + slot*3 + gapForCenter + center,
    };
    return map[i] ?? (width/2 - 16);
  }
}

class _NeoDockItem extends StatelessWidget {
  final IconData icon; final bool active; final VoidCallback onTap;
  const _NeoDockItem({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14), onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: active ? Colors.white.withOpacity(0.10) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, color: active ? Colors.white : Colors.white70),
    ),
  );
}
