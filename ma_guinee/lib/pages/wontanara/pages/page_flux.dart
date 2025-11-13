// lib/wontanara/pages/page_flux.dart
import 'package:flutter/material.dart';
import 'page_publication_form.dart';

const _teal = Color(0xFF0E5A51);
const _tealDark = Color(0xFF0B4740);

enum ActualiteFilter { all, infos, alertes, collecte, votes, verifiee }

class PageFlux extends StatefulWidget {
  const PageFlux({super.key});

  @override
  State<PageFlux> createState() => _PageFluxState();
}

class _PageFluxState extends State<PageFlux> {
  ActualiteFilter _filter = ActualiteFilter.all;

  // 🔹 Données mockées (on branchera Supabase plus tard)
  final List<_Publication> _allPublications = [
    _Publication(
      id: '1',
      auteurNom: 'Info_locale',
      auteurInitiales: 'IL',
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
    // TODO: ouvrir le profil réel Supabase
    debugPrint('Ouvrir profil de ${pub.auteurNom}');
  }

  void _sharePublication(_Publication pub) {
    // TODO: partage système
    debugPrint('Partager publication ${pub.id}');
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
                  // TODO: envoyer le signalement côté Supabase
                  debugPrint('Signalement de la publication ${pub.id}');
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
                        Expanded(
                          child: Text(
                            'Commentaires',
                            style: const TextStyle(
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
                  // 🔹 Liste de commentaires mockée
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
                  // 🔹 Zone de saisie
                  Padding(
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 6,
                      bottom: MediaQuery.of(context).viewInsets.bottom +
                          8, // clavier
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
                          onPressed: () {
                            // TODO: envoyer le commentaire
                          },
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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PagePublicationForm(),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Publier',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _tealDark, width: 1),
                foregroundColor: _tealDark,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F5F7),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Bandeau original "temps réel"
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
                    'Suivez en temps réel ce qui se passe dans votre quartier.',
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
          const SizedBox(height: 16),

          const _SectionTitle('Filtres rapides'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChipLabel(
                'Tout',
                selected: _filter == ActualiteFilter.all,
                onTap: () => setState(() => _filter = ActualiteFilter.all),
              ),
              _FilterChipLabel(
                'Infos locales',
                selected: _filter == ActualiteFilter.infos,
                onTap: () => setState(() => _filter = ActualiteFilter.infos),
              ),
              _FilterChipLabel(
                'Alertes',
                selected: _filter == ActualiteFilter.alertes,
                onTap: () => setState(() => _filter = ActualiteFilter.alertes),
              ),
              _FilterChipLabel(
                'Collecte',
                selected: _filter == ActualiteFilter.collecte,
                onTap: () => setState(() => _filter = ActualiteFilter.collecte),
              ),
              _FilterChipLabel(
                'Votes',
                selected: _filter == ActualiteFilter.votes,
                onTap: () => setState(() => _filter = ActualiteFilter.votes),
              ),
              _FilterChipLabel(
                'Actu vérifiée',
                selected: _filter == ActualiteFilter.verifiee,
                onTap: () => setState(() => _filter = ActualiteFilter.verifiee),
              ),
            ],
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

  // ===== Carte de publication =====
  Widget _buildPublicationCard(BuildContext context, _Publication pub) {
    return InkWell(
      onTap: () {
        // TODO: Détail de la publication
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: _cardBox.copyWith(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- Header : auteur + temps ----------
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

            // ---------- Titre ----------
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

            // ---------- Photos swipables + boutons à droite (style TikTok) ----------
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

            // ---------- Compteurs ----------
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

// ====== Models + widgets ======

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

class _FilterChipLabel extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _FilterChipLabel(
    this.label, {
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? _teal.withOpacity(.08) : Colors.grey[100];
    final border = selected ? _teal.withOpacity(.50) : Colors.grey[300];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border!),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? _tealDark : Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ===== Bande de photos swipable + boutons TikTok =====
class _SwipePhotos extends StatefulWidget {
  final int count; // 1 → n
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

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            PageView.builder(
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
            if (widget.count > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.count,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _index == i ? 16 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _index == i
                            ? Colors.white
                            : Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            // 🔹 Colonne d’actions à droite (style TikTok)
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                    icon: Icons.share_outlined,
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
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }
}

// ===== Delegate de recherche =====
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
