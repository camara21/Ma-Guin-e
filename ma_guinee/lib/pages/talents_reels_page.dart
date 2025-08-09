import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
// (optionnel) partage natif -> ajoute share_plus au pubspec et décommente :
// import 'package:share_plus/share_plus.dart';

import '../services/talents_service.dart';
import '../services/storage_service.dart';
import 'talent_detail_page.dart';
import 'talent_upload_page.dart';

/// Page Reels plein écran — version prod, sans page feed.
/// Ouvre directement ce flux depuis ton menu "Talents guinéens".
class TalentsReelsPage extends StatefulWidget {
  const TalentsReelsPage({
    super.key,
    this.genre,
    this.ville,
    this.startTalentId,
  });

  final String? genre;
  final String? ville;
  final int? startTalentId; // pour ouvrir sur une vidéo précise après publication

  @override
  State<TalentsReelsPage> createState() => _TalentsReelsPageState();
}

class _TalentsReelsPageState extends State<TalentsReelsPage> {
  final _svc = TalentsService();
  final _storage = StorageService();
  final PageController _pageCtrl = PageController();

  final List<Map<String, dynamic>> _items = [];
  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _likedIds = {}; // likes togglés localement (optimiste)

  bool _loading = false;
  bool _end = false;
  int _offset = 0;
  final int _limit = 6;
  int _current = 0;
  bool _muted = true;

  // Couleurs "Ma Guinée"
  Color get _red => const Color(0xFFCE1126);
  Color get _yellow => const Color(0xFFFCD116);
  Color get _green => const Color(0xFF009460);

  @override
  void initState() {
    super.initState();
    // Immersif (cache barre de statut)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _load(reset: true).then((_) {
      if (!mounted) return;
      if (widget.startTalentId != null) {
        final i = _items.indexWhere((e) => e['id'] == widget.startTalentId);
        if (i >= 0) {
          _current = i;
          _pageCtrl.jumpToPage(i);
        }
      }
      _playIndex(_current); // auto-play au démarrage
    });

    _pageCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _pageCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); // restaure UI
    super.dispose();
  }

  // ----------------- DATA & VIDEO -----------------

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
      _end = false;
      _offset = 0;
      for (final c in _controllers.values) c.dispose();
      _controllers.clear();
      _items.clear();
    }

    final rows = await _svc.fetchTalents(
      genre: widget.genre,
      ville: widget.ville,
      limit: _limit,
      offset: _offset,
      onlyApproved: true,
    );

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
    final storagePath = (row['video_url'] ?? '') as String;
    if (storagePath.isEmpty) return;

    try {
      final signed = await _storage.signedUrl('talents-videos', storagePath, expiresInSeconds: 3600);
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(signed));
      await ctrl.initialize();
      ctrl
        ..setLooping(true)
        ..setVolume(_muted ? 0 : 1);
      _controllers[index] = ctrl;
      if (mounted) setState(() {});
    } catch (_) {/* ignore */}
  }

  void _playIndex(int index) async {
    final c = _controllers[index];
    if (c == null) {
      await _ensureController(index);
      _controllers[index]?.play();
    } else {
      if (c.value.isInitialized) c.play();
    }
    _pauseIndex(index - 1);
    _pauseIndex(index + 1);
    _ensureController(index + 1);

    if (index >= 0 && index < _items.length) {
      _svc.incrementViews(_items[index]['id']); // fire-and-forget
    }
  }

  void _pauseIndex(int index) {
    final c = _controllers[index];
    if (c != null && c.value.isInitialized) c.pause();
  }

  // ----------------- ACTIONS -----------------

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      final c = _controllers[_current];
      if (c != null) c.setVolume(_muted ? 0 : 1);
    });
  }

  Future<void> _toggleLike(int id, int index) async {
    try {
      if (_likedIds.contains(id)) {
        await _svc.unlike(id);
        _likedIds.remove(id);
        _items[index]['likes_count'] = (_items[index]['likes_count'] ?? 1) - 1;
      } else {
        await _svc.like(id);
        _likedIds.add(id);
        _items[index]['likes_count'] = (_items[index]['likes_count'] ?? 0) + 1;
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _openComments(Map<String, dynamic> t) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CommentsSheet(talentId: t['id'], svc: _svc),
    );
  }

  void _shareTalent(Map<String, dynamic> t) async {
    final titre = (t['titre'] ?? 'Talent').toString();
    final id = t['id'];
    final text = 'Découvre ce talent: $titre (id:$id)';
    try {
      // await Share.share(text);
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lien copié dans le presse-papiers')),
      );
    } catch (_) {}
  }

  Future<void> _supportArtist(Map<String, dynamic> t) async {
    final amount = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SupportSheet(red: _red, yellow: _yellow, green: _green),
    );
    if (amount != null) {
      try {
        await _svc.support(t['id'], amount);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Merci pour le soutien (+$amount)')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _openPublish() async {
    final created = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(builder: (_) => const TalentUploadPage()),
    );
    // Si on a publié, recharger et se positionner sur le nouveau talent
    await _load(reset: true);
    if (!mounted) return;
    if (created != null && created['id'] != null) {
      final i = _items.indexWhere((e) => e['id'] == created['id']);
      if (i >= 0) {
        _current = i;
        _pageCtrl.jumpToPage(i);
        _playIndex(i);
      }
    }
  }

  // ----------------- UI -----------------

  @override
  Widget build(BuildContext context) {
    final padTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Flux Reels
          if (_items.isEmpty && _loading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_items.isEmpty)
            const Center(child: Text('Aucun talent pour le moment', style: TextStyle(color: Colors.white70)))
          else
            PageView.builder(
              controller: _pageCtrl,
              scrollDirection: Axis.vertical,
              itemCount: _items.length,
              itemBuilder: (_, i) => _ReelItem(
                data: _items[i],
                controller: _controllers[i],
                brandRed: _red,
                brandYellow: _yellow,
                brandGreen: _green,
                muted: _muted,
                isLiked: _likedIds.contains(_items[i]['id']),
                onTapVideo: () {
                  final c = _controllers[i];
                  if (c == null) return;
                  c.value.isPlaying ? c.pause() : c.play();
                  setState(() {});
                },
                onOpenDetail: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TalentDetailPage(talent: _items[i])),
                  );
                },
                onToggleLike: () => _toggleLike(_items[i]['id'], i),
                onOpenComments: () => _openComments(_items[i]),
                onShare: () => _shareTalent(_items[i]),
                onSupport: () => _supportArtist(_items[i]),
                fetchAuthor: () => _svc.getUserPublic(_items[i]['user_id']),
              ),
            ),

          // Bouton mute (haut droit)
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
                child: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
              ),
            ),
          ),

          // Bouton Publier (haut droit, à gauche du mute)
          Positioned(
            right: 66,
            top: padTop + 10,
            child: ElevatedButton.icon(
              onPressed: _openPublish,
              icon: const Icon(Icons.add),
              label: const Text('Publier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF113CFC),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),

          if (_loading && !_end)
            const Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}

/// ---------- ITEM PLEIN ÉCRAN ----------
class _ReelItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final VideoPlayerController? controller;
  final bool muted;
  final bool isLiked;
  final VoidCallback onTapVideo;
  final VoidCallback onOpenDetail;
  final VoidCallback onToggleLike;
  final VoidCallback onOpenComments;
  final VoidCallback onShare;
  final VoidCallback onSupport;
  final Future<Map<String, dynamic>?> Function() fetchAuthor;
  final Color brandRed, brandYellow, brandGreen;

  const _ReelItem({
    required this.data,
    required this.controller,
    required this.muted,
    required this.isLiked,
    required this.onTapVideo,
    required this.onOpenDetail,
    required this.onToggleLike,
    required this.onOpenComments,
    required this.onShare,
    required this.onSupport,
    required this.fetchAuthor,
    required this.brandRed,
    required this.brandYellow,
    required this.brandGreen,
  });

  bool _isNewTalent(Map<String, dynamic> d) {
    final created = DateTime.tryParse((d['created_at'] ?? '').toString());
    if (created == null) return false;
    return DateTime.now().difference(created).inDays <= 7;
    // ajuste le seuil à ta convenance
  }

  bool _isTrending(Map<String, dynamic> d) {
    final v = (d['views_count'] ?? 0) as int;
    return v >= 100; // seuil simple pour "Tendance"
  }

  @override
  Widget build(BuildContext context) {
    // Couche vidéo (cover)
    Widget videoLayer;
    if (controller != null && controller!.value.isInitialized) {
      final size = controller!.value.size;
      videoLayer = Center(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(controller!)),
        ),
      );
    } else {
      videoLayer = const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final titre = (data['titre'] ?? '').toString();
    final genre = (data['genre'] ?? '').toString();
    final ville = (data['ville'] ?? '').toString();
    final vues  = (data['views_count'] ?? 0).toString();
    final likes = (data['likes_count'] ?? 0).toString();

    // Badge
    String? badge;
    if (_isNewTalent(data)) {
      badge = 'Nouveau talent';
    } else if (_isTrending(data)) {
      badge = 'Tendance';
    }

    return GestureDetector(
      onTap: onTapVideo, // tap = pause/reprise
      child: Stack(
        fit: StackFit.expand,
        children: [
          // vidéo + léger filtre d’uniformisation
          ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.06), BlendMode.darken),
            child: videoLayer,
          ),

          // halos arrondis 🇬🇳
          Positioned.fill(
            child: IgnorePointer(
              child: Column(
                children: [
                  Container(
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                      gradient: LinearGradient(
                        colors: [brandRed.withOpacity(0.32), Colors.transparent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 110,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      gradient: LinearGradient(
                        colors: [Colors.transparent, brandGreen.withOpacity(0.32)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Badge (haut gauche)
          if (badge != null)
            Positioned(
              left: 14,
              top: MediaQuery.of(context).padding.top + 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: badge == 'Nouveau talent' ? brandRed : brandGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

          // Profil auteur (haut gauche, sous le badge)
          Positioned(
            left: 14,
            top: MediaQuery.of(context).padding.top + 45,
            right: 120,
            child: FutureBuilder<Map<String, dynamic>?>(
              future: fetchAuthor(),
              builder: (_, snap) {
                final author = snap.data;
                final photo = (author?['photo_url'] ?? '').toString();
                final nomComplet = [
                  (author?['prenom'] ?? '').toString(),
                  (author?['nom'] ?? '').toString()
                ].where((e) => e.isNotEmpty).join(' ');
                final rate = (author?['rating_avg'] ?? 0).toString();

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white24,
                      backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                      child: photo.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nomComplet.isEmpty ? 'Artiste' : nomComplet,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.place, size: 14, color: Colors.white70),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(ville,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white70)),
                              ),
                              if (rate != '0') ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.star, size: 14, color: Colors.amber),
                                Text(rate, style: const TextStyle(color: Colors.white)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Infos + actions (bas)
          Positioned(
            left: 14,
            right: 14,
            bottom: 26,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Carte info
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 230),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.45), Colors.black.withOpacity(0.15)],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (titre.isNotEmpty)
                          Text(
                            titre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${genre.isNotEmpty ? '$genre • ' : ''}$ville',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Actions
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Action(
                      icon: isLiked ? Icons.favorite : Icons.favorite_border,
                      label: likes,
                      gradient: [brandRed, brandYellow],
                      active: isLiked,
                      onTap: onToggleLike,
                    ),
                    const SizedBox(height: 12),
                    _Action(
                      icon: Icons.chat_bubble_outline,
                      label: 'Com',
                      gradient: [brandYellow, brandGreen],
                      onTap: onOpenComments,
                    ),
                    const SizedBox(height: 12),
                    _Action(
                      icon: Icons.share,
                      label: 'Share',
                      gradient: [brandGreen, brandRed],
                      onTap: onShare,
                    ),
                    const SizedBox(height: 12),
                    _Action(
                      icon: Icons.monetization_on_outlined,
                      label: 'Support',
                      gradient: [brandRed, brandGreen],
                      onTap: onSupport,
                    ),
                    const SizedBox(height: 12),
                    _Action(icon: Icons.remove_red_eye, label: vues, gradient: [Colors.white24, Colors.white24]),
                    const SizedBox(height: 12),
                    _Action(
                      icon: Icons.more_horiz,
                      label: 'Plus',
                      gradient: [Colors.white24, Colors.white24],
                      onTap: onOpenDetail,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final List<Color> gradient;
  final VoidCallback? onTap;
  const _Action({
    required this.icon,
    required this.label,
    required this.gradient,
    this.onTap,
    this.active = false,
  });
  @override
  Widget build(BuildContext context) {
    final iconColor = active ? Colors.redAccent : Colors.white;
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}

/// ---------- BottomSheet commentaires ----------
class _CommentsSheet extends StatefulWidget {
  final int talentId;
  final TalentsService svc;
  const _CommentsSheet({required this.talentId, required this.svc});

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
      final rows = await widget.svc.listComments(widget.talentId);
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
      final row = await widget.svc.addComment(widget.talentId, txt);
      if (!mounted) return;
      setState(() {
        _items.insert(0, row);
        _ctrl.clear();
      });
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
          left: 12,
          right: 12,
          top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 46, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 12),
            const Text('Commentaires', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                        child: Text('Aucun commentaire', style: TextStyle(color: Colors.white70)),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                        itemBuilder: (_, i) {
                          final c = _items[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text((c['contenu'] ?? '').toString(), style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              (c['created_at'] ?? '').toString(),
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
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
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                    ),
                    onSubmitted: (_) => _post(),
                  ),
                ),
                IconButton(onPressed: _post, icon: const Icon(Icons.send, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// ---------- BottomSheet soutien ----------
class _SupportSheet extends StatelessWidget {
  final Color red, yellow, green;
  const _SupportSheet({required this.red, required this.yellow, required this.green});

  @override
  Widget build(BuildContext context) {
    final choices = [1000, 5000, 10000, 25000]; // GNF
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 46, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 12),
            const Text('Soutenir l’artiste', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: choices.map((v) {
                final g = [red, yellow, green];
                return GestureDetector(
                  onTap: () => Navigator.pop<int>(context, v),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [g[v % 3], g[(v + 1) % 3]]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$v GNF', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
