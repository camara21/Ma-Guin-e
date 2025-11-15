// lib/wontanara/pages/page_flux.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

const _teal = Color(0xFF0E5A51);
const _tealDark = Color(0xFF0B4740);

enum ActualiteFilter { all, infos, alertes, collecte, votes, verifiee }

enum PublicationType { infos, alerte }

class PageFlux extends StatefulWidget {
  const PageFlux({super.key});

  @override
  State<PageFlux> createState() => _PageFluxState();
}

class _PageFluxState extends State<PageFlux> {
  ActualiteFilter _filter = ActualiteFilter.all;

  final List<_Publication> _allPublications = [
    _Publication(
      id: '1',
      auteurNom: 'Info_quartier',
      auteurInitiales: 'IQ',
      titre: 'Coupure d’eau programmée demain matin',
      sousTitre: 'Quartier Kipé',
      timeAgo: 'il y a 18 min',
      type: ActualiteFilter.infos,
      photosCount: 1,
    ),
    _Publication(
      id: '2',
      auteurNom: 'Signalement citoyen',
      auteurInitiales: 'SC',
      titre: 'Alerte : panne de courant sur la corniche',
      sousTitre: 'Corniche nord',
      timeAgo: 'il y a 47 min',
      type: ActualiteFilter.alertes,
      photosCount: 3,
    ),
    _Publication(
      id: '3',
      auteurNom: 'Commune de Ratoma',
      auteurInitiales: 'CR',
      titre: 'Opération de nettoyage samedi 16 mars',
      sousTitre: 'Place des Martyrs',
      timeAgo: 'dans 3 j',
      type: ActualiteFilter.collecte,
      photosCount: 5,
    ),
  ];

  void _openProfile(_Publication pub) {
    debugPrint('Profil de ${pub.auteurNom}');
  }

  Future<void> _sharePublication(_Publication pub) async {
    final text = pub.titre.isNotEmpty
        ? '${pub.titre}\n${pub.sousTitre} • ${pub.timeAgo}'
        : '${pub.sousTitre} • ${pub.timeAgo}';

    await Share.share(
      text,
      subject: 'Actualité Wontanara',
    );

    setState(() {
      pub.shares++;
    });
  }

  void _showPostMenu(_Publication pub) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading:
                    const Icon(Icons.flag_outlined, color: Colors.redAccent),
                title: const Text('Signaler cette actualité'),
                subtitle: const Text('Ne respecte pas la charte Soneya'),
                onTap: () {
                  Navigator.pop(context);
                  debugPrint('Signalement publication ${pub.id}');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _openComments(_Publication pub) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Commentaires',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: 6,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: _teal.withOpacity(.12),
                            child: const Text(
                              'U',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _tealDark,
                              ),
                            ),
                          ),
                          title: Text(
                            'Utilisateur ${index + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: const Text(
                            'Très bonne initiative pour le quartier 👌',
                          ),
                          trailing: const Text(
                            'il y a 2 h',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 6,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: _teal,
                          child: Text(
                            'MC',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Ajouter un commentaire…',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: const Color(0xFFF5F5F7),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: _teal),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pubs = _allPublications.where((p) {
      switch (_filter) {
        case ActualiteFilter.all:
          return true;
        case ActualiteFilter.infos:
          return p.type == ActualiteFilter.infos;
        case ActualiteFilter.alertes:
          return p.type == ActualiteFilter.alertes;
        case ActualiteFilter.collecte:
          return p.type == ActualiteFilter.collecte;
        case ActualiteFilter.votes:
          return p.type == ActualiteFilter.votes;
        case ActualiteFilter.verifiee:
          return p.type == ActualiteFilter.verifiee;
      }
    }).toList();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'Actualités',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.black87),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _PublicationSearchDelegate(_allPublications),
              );
            },
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PagePublierActualite(),
                ),
              );
            },
            icon: const Icon(Icons.add_rounded, size: 20, color: _tealDark),
            label: const Text(
              'Publier',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: _tealDark,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: _tealDark,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: const Color(0xFFF5F5F7),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFFD6F2EC), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: const [
                Icon(Icons.radar_rounded, color: _tealDark),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Suivez en temps réel ce qui se passe en Guinée.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _tealDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Près de vous'),
          const SizedBox(height: 8),
          for (int i = 0; i < pubs.length; i++) ...[
            _buildPublicationCard(context, pubs[i]),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildPublicationCard(BuildContext context, _Publication pub) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: _cardBox.copyWith(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _openProfile(pub),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: _teal.withOpacity(.12),
                      child: Text(
                        pub.auteurInitiales,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _tealDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openProfile(pub),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pub.auteurNom,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${pub.sousTitre} • ${pub.timeAgo}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.more_horiz,
                      size: 20,
                      color: Colors.black54,
                    ),
                    onPressed: () => _showPostMenu(pub),
                  ),
                ],
              ),
            ),
            if (pub.titre.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  pub.titre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (pub.photosCount > 0)
              Padding(
                padding: EdgeInsets.zero,
                child: _SwipePhotos(
                  count: pub.photosCount,
                  isLiked: pub.isLiked,
                  onLike: () {
                    setState(() {
                      pub.isLiked = !pub.isLiked;
                      if (pub.isLiked) {
                        pub.likes++;
                      } else {
                        pub.likes = (pub.likes - 1).clamp(0, 999999);
                      }
                    });
                  },
                  onComment: () => _openComments(pub),
                  onShare: () => _sharePublication(pub),
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.thumb_up_alt_rounded,
                    size: 16,
                    color: pub.isLiked ? _teal : Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    pub.likes.toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const Spacer(),
                  Text(
                    '${pub.comments} commentaires',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${pub.shares} partages',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/* ========= MODELS & WIDGETS ========= */

class _Publication {
  final String id;
  final String auteurNom;
  final String auteurInitiales;
  final ActualiteFilter type;
  final String titre;
  final String sousTitre;
  final String timeAgo;
  final int photosCount;

  int likes;
  int comments;
  int shares;
  bool isLiked;

  _Publication({
    required this.id,
    required this.auteurNom,
    required this.auteurInitiales,
    required this.type,
    required this.titre,
    required this.sousTitre,
    required this.timeAgo,
    this.photosCount = 0,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.isLiked = false,
  });
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: _tealDark,
      ),
    );
  }
}

final _cardBox = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ],
  border: Border.all(color: Colors.black12, width: 0.4),
);

class RoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const RoundedField({
    super.key,
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _tealDark, width: 1.3),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const TypeChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFE6F4F0) : const Color(0xFFF3F4F6);
    final border = selected ? _tealDark : const Color(0xFFE5E7EB);
    final txtColor = selected ? _tealDark : const Color(0xFF111827);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: txtColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: txtColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* === Swipe photos + actions TikTok === */

class _SwipePhotos extends StatefulWidget {
  final int count;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final bool isLiked;

  const _SwipePhotos({
    required this.count,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.isLiked,
  });

  @override
  State<_SwipePhotos> createState() => _SwipePhotosState();
}

class _SwipePhotosState extends State<_SwipePhotos> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFullscreen() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (_) {
        final fullController = PageController(initialPage: _index);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Stack(
            children: [
              PageView.builder(
                controller: fullController,
                itemCount: widget.count,
                itemBuilder: (_, i) {
                  return Center(
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Container(
                        color: Colors.grey[900],
                        child: const Icon(
                          Icons.image_rounded,
                          size: 120,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            GestureDetector(
              onTap: _openFullscreen,
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.count,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.image_rounded,
                        size: 60,
                        color: _tealDark,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.count > 1)
              Positioned(
                bottom: 10,
                left: 12,
                child: Row(
                  children: List.generate(
                    widget.count,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 4),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _index == i
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 10,
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoundIconButton(
                    icon: widget.isLiked
                        ? Icons.favorite
                        : Icons.favorite_border_rounded,
                    active: widget.isLiked,
                    onTap: widget.onLike,
                  ),
                  const SizedBox(height: 14),
                  _RoundIconButton(
                    icon: Icons.mode_comment_outlined,
                    onTap: widget.onComment,
                  ),
                  const SizedBox(height: 14),
                  _RoundIconButton(
                    icon: Icons.reply_rounded,
                    onTap: widget.onShare,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _RoundIconButton({
    required this.icon,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? _teal : Colors.white.withOpacity(0.95);
    final iconColor = active ? Colors.white : _tealDark;

    Widget iconWidget = Icon(icon, size: 20, color: iconColor);

    if (icon == Icons.reply_rounded) {
      iconWidget = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scale(-1.0, 1.0)
          ..rotateZ(0.7),
        child: Icon(icon, size: 20, color: iconColor),
      );
    }

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: iconWidget,
      ),
    );
  }
}

/* === Recherche === */

class _PublicationSearchDelegate extends SearchDelegate<_Publication?> {
  final List<_Publication> publications;

  _PublicationSearchDelegate(this.publications);

  @override
  String get searchFieldLabel => 'Rechercher une actualité';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  List<_Publication> _filtered() {
    final q = query.toLowerCase();
    return publications.where((p) {
      return p.titre.toLowerCase().contains(q) ||
          p.sousTitre.toLowerCase().contains(q) ||
          p.auteurNom.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final results = _filtered();

    if (results.isEmpty) {
      return const Center(
        child: Text('Aucun résultat'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final pub = results[index];
        return Container(
          decoration: _cardBox.copyWith(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: _teal.withOpacity(.12),
              child: Text(
                pub.auteurInitiales,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _tealDark,
                ),
              ),
            ),
            title: Text(
              pub.titre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${pub.auteurNom} • ${pub.sousTitre}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}

/* === Page Publier avec PHOTOS === */

class PagePublierActualite extends StatefulWidget {
  const PagePublierActualite({super.key});

  @override
  State<PagePublierActualite> createState() => _PagePublierActualiteState();
}

class _PagePublierActualiteState extends State<PagePublierActualite> {
  final _formKey = GlobalKey<FormState>();

  PublicationType _type = PublicationType.infos;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _zoneCtrl = TextEditingController();

  bool _sending = false;
  double? _lat;
  double? _lng;

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _zoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;
    setState(() {
      _images.addAll(picked);
    });
  }

  Future<void> _pickLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Active la localisation sur ton téléphone.'),
        ),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Autorise la localisation pour signaler une alerte.'),
          ),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('La localisation est bloquée dans les paramètres système.'),
        ),
      );
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _lat = pos.latitude;
      _lng = pos.longitude;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_type == PublicationType.alerte && (_lat == null || _lng == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pour une alerte, utilise le bouton localisation.'),
        ),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _type == PublicationType.alerte
                ? 'Alerte envoyée à votre quartier.'
                : 'Info publiée.',
          ),
        ),
      );

      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _buildPhotosPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photos',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _tealDark,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 82,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  width: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                    color: const Color(0xFFF3F4F6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.photo_camera_outlined, color: _tealDark),
                      SizedBox(height: 4),
                      Text(
                        'Ajouter',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              for (final img in _images)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(img.path),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _images.remove(img));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAlerte = _type == PublicationType.alerte;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Publier',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: _tealDark,
                            child: Text(
                              'MC',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Publier une actualité dans mon quartier',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Type de publication',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _tealDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          TypeChip(
                            label: 'Infos',
                            icon: Icons.info_outline,
                            selected: _type == PublicationType.infos,
                            onTap: () =>
                                setState(() => _type = PublicationType.infos),
                          ),
                          TypeChip(
                            label: 'Alerte',
                            icon: Icons.warning_amber_rounded,
                            selected: _type == PublicationType.alerte,
                            onTap: () =>
                                setState(() => _type = PublicationType.alerte),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Contenu',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _tealDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      RoundedField(
                        controller: _titleCtrl,
                        hintText: 'Titre',
                        maxLines: 1,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Le titre est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      RoundedField(
                        controller: _descCtrl,
                        hintText: 'Description',
                        maxLines: 4,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Merci de décrire l’actualité';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _buildPhotosPicker(),
                      const SizedBox(height: 22),
                      if (isAlerte) ...[
                        const Text(
                          'Zone',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _tealDark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        RoundedField(
                          controller: _zoneCtrl,
                          hintText: 'Région / Préfecture / Quartier',
                          maxLines: 1,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'La zone est obligatoire pour une alerte';
                            }
                            return null;
                          },
                          suffixIcon: const Icon(
                            Icons.location_on_outlined,
                            color: _tealDark,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickLocation,
                                icon: const Icon(Icons.my_location_rounded),
                                label: const Text('Utiliser ma localisation'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _tealDark,
                                  side: const BorderSide(color: _tealDark),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_lat != null && _lng != null)
                          Text(
                            'Position enregistrée (${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)})',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          )
                        else
                          const Text(
                            'Pour une alerte, enregistre ta position pour l’afficher sur la carte.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _sending ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _tealDark,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: _sending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Publier',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
