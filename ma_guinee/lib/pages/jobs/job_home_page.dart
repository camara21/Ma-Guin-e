import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'jobs_page.dart';
import 'job_detail_page.dart';

// alias pour éviter les collisions
import 'my_applications_page.dart' as apps;
import 'my_favorite_jobs_page.dart' as favs;

import '../cv/cv_maker_page.dart';
import 'employer/mes_offres_page.dart';
import 'employer/devenir_employeur_page.dart';

import 'package:ma_guinee/services/jobs_service.dart';
import 'package:ma_guinee/models/job_models.dart';

class JobHomePage extends StatefulWidget {
  const JobHomePage({super.key});
  @override
  State<JobHomePage> createState() => _JobHomePageState();
}

class _JobHomePageState extends State<JobHomePage> {
  // Palette
  static const kBlue = Color(0xFF1976D2);
  static const kBg = Color(0xFFF6F7F9);
  static const kRed = Color(0xFFCE1126);
  static const kGreen = Color(0xFF009460);

  final _svc = JobsService();
  late Future<List<EmploiModel>> _recent;

  // état local des favoris (emploi_id)
  Set<String> _favSet = {};

  @override
  void initState() {
    super.initState();
    _recent = _loadRecent();
  }

  bool get _isMobile {
    final w = MediaQuery.maybeOf(context)?.size.width ?? 800;
    return w < 600;
  }

  Future<List<EmploiModel>> _loadRecent() {
    return _svc.chercher(limit: 12, offset: 0);
  }

  // enrichir (nom + logo) si EmploiModel expose employeurId
  Future<Map<String, Map<String, String>>> _loadEmployeursMeta(
    List<EmploiModel> items,
  ) async {
    final sb = Supabase.instance.client;
    try {
      final ids = <String>{};
      for (final e in items) {
        try {
          final dyn = e as dynamic;
          final id = dyn.employeurId?.toString();
          if (id != null && id.isNotEmpty) ids.add(id);
        } catch (_) {}
      }
      if (ids.isEmpty) return {};

      final inList = '(${ids.map((e) => '"$e"').join(',')})';
      final rows = await sb
          .from('employeurs')
          .select('id, nom, logo_url')
          .filter('id', 'in', inList);

      final out = <String, Map<String, String>>{};
      for (final r in (rows as List? ?? const [])) {
        final m = Map<String, dynamic>.from(r);
        final id = (m['id'] ?? '').toString();
        out[id] = {
          'nom': (m['nom'] ?? '').toString(),
          'logo': (m['logo_url'] ?? '').toString(),
        };
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  // charge l’état des favoris (public.emplois_favoris)
  Future<Set<String>> _loadFavSetFor(List<EmploiModel> items) async {
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return {};
    final ids =
        items.map((e) => e.id).where((s) => s.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return {};
    final inList = '(${ids.map((e) => '"$e"').join(',')})';
    final rows = await sb
        .from('emplois_favoris')
        .select('emploi_id')
        .eq('utilisateur_id', uid)
        .filter('emploi_id', 'in', inList);
    final out = <String>{};
    for (final r in (rows as List? ?? const [])) {
      final id = (r['emploi_id'] ?? '').toString();
      if (id.isNotEmpty) out.add(id);
    }
    return out;
  }

  // activer/désactiver favori
  Future<void> _toggleFavorite(String jobId) async {
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Connectez-vous pour ajouter des favoris.')),
      );
      return;
    }
    final isFav = _favSet.contains(jobId);
    try {
      if (isFav) {
        await sb.from('emplois_favoris').delete().match({
          'utilisateur_id': uid,
          'emploi_id': jobId,
        });
        setState(() => _favSet.remove(jobId));
      } else {
        await sb.from('emplois_favoris').insert({
          'utilisateur_id': uid,
          'emploi_id': jobId,
        });
        setState(() => _favSet.add(jobId));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur favoris : $e')),
      );
    }
  }

  Future<void> _openEmployeur() async {
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;

    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Veuillez vous connecter pour accéder à l’espace employeur.'),
        ),
      );
      return;
    }

    try {
      final row = await sb
          .from('employeurs')
          .select('id')
          .eq('proprietaire', uid)
          .maybeSingle();

      if (!mounted) return;
      if (row != null && row['id'] != null) {
        final String employeurId = row['id'] as String;
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => MesOffresPage(employeurId: employeurId)),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DevenirEmployeurPage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d’accès à l’espace employeur : $e')),
      );
    }
  }

  PopupMenuButton<int> _mobileMenu() {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.menu_rounded),
      onSelected: (v) {
        switch (v) {
          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const apps.MyApplicationsPage()),
            );
            break;
          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const favs.MyFavoriteJobsPage()),
            );
            break;
          case 3:
            _openEmployeur();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 1,
          child: ListTile(
            leading: Icon(Icons.assignment_turned_in_outlined),
            title: Text('Mes candidatures'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 2,
          child: ListTile(
            leading: Icon(Icons.favorite_border),
            title: Text('Mes favoris'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 3,
          child: ListTile(
            leading: Icon(Icons.business_center_outlined),
            title: Text('Espace employeur'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  // ------- Helpers date relative -------
  String _formatRelative(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().toLocal().difference(d);
      if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
      if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  String _relativeFromEmploi(EmploiModel e) {
    try {
      final dyn = e as dynamic;
      final iso = (dyn.creeLe ?? dyn.cree_le ?? dyn.createdAt ?? dyn.created_at)
          ?.toString();
      return _formatRelative(iso);
    } catch (_) {
      return '';
    }
  }

  String _formatVilleContrat(EmploiModel e) {
    final parts = <String>[];
    if (e.ville.isNotEmpty) parts.add(e.ville);
    if (e.typeContrat.isNotEmpty) parts.add(e.typeContrat);
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        title: const Text('Emplois'),
        actions: [
          if (isMobile) _mobileMenu(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _HeroJobs(
            titleTop: 'La Guinée recrute',
            titleBottom: 'choisis ton avenir',
            onSearchTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JobsPage()),
            ),
          ),
          const SizedBox(height: 12),

          if (!isMobile)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PillAction(
                  icon: Icons.assignment_turned_in,
                  label: 'Mes candidatures',
                  color: kGreen,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const apps.MyApplicationsPage()),
                  ),
                ),
                _PillAction(
                  icon: Icons.favorite_border,
                  label: 'Mes favoris',
                  color: kRed,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const favs.MyFavoriteJobsPage()),
                  ),
                ),
                _PillAction(
                  icon: Icons.business_center,
                  label: 'Espace employeur',
                  color: kRed,
                  onTap: _openEmployeur,
                ),
              ],
            ),

          const SizedBox(height: 16),

          // Bloc CV
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            padding: const EdgeInsets.all(14),
            child: const Row(
              children: [
                Icon(Icons.file_present, color: kBlue, size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pas de CV ? Créez-le en 2 minutes et postulez tout de suite.',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: kBlue,
                side: const BorderSide(color: kBlue),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CvMakerPage()),
              ),
              child: const Text('Créer mon CV'),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'Dernières offres',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          // ====== LISTE VITRINE ======
          FutureBuilder<List<EmploiModel>>(
            future: _recent,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return const Text('Impossible de charger les offres.');
              }

              final items = snap.data ?? const <EmploiModel>[];
              if (items.isEmpty) {
                return const Text('Aucune offre disponible pour l’instant.');
              }

              return FutureBuilder<Map<String, Map<String, String>>>(
                future: _loadEmployeursMeta(items),
                builder: (context, metaSnap) {
                  final meta = metaSnap.data ?? {};

                  return FutureBuilder<Set<String>>(
                    future: _loadFavSetFor(items),
                    builder: (context, favSnap) {
                      if (favSnap.hasData) {
                        _favSet = favSnap.data!;
                      }
                      final useFav = favSnap.data ?? _favSet;

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final e = items[i];
                          String empId = '';
                          try {
                            empId =
                                ((e as dynamic).employeurId ?? '').toString();
                          } catch (_) {}
                          final company = meta[empId]?['nom'] ?? '';
                          final logo = meta[empId]?['logo'] ?? '';
                          final isFav = useFav.contains(e.id);

                          return _JobCardVitrine(
                            title: e.titre,
                            company: company,
                            subtitle: _formatVilleContrat(e),
                            meta: _relativeFromEmploi(e),
                            logoUrl: logo,
                            bannerUrl: null,
                            favorite: isFav,
                            onFavoriteTap: () => _toggleFavorite(e.id),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JobDetailPage(jobId: e.id),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ================== HERO AVEC CARROUSEL (fluide) ==================
class _HeroJobs extends StatefulWidget {
  const _HeroJobs({
    required this.titleTop,
    required this.titleBottom,
    required this.onSearchTap,
  });

  final String titleTop;
  final String titleBottom;
  final VoidCallback onSearchTap;

  @override
  State<_HeroJobs> createState() => _HeroJobsState();
}

class _HeroJobsState extends State<_HeroJobs> {
  final PageController _ctrl = PageController();
  int _index = 0;
  Timer? _timer;

  bool _precached = false;
  bool _autoStarted = false;

  // mêmes images que ton ancien hero
  final List<String> _images = const [
    'https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/wali-images/v3.png',
    'https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/wali-images/v1.png',
    'https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/wali-images/v10.png',
    'https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/wali-images/v8.png',
    'https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/wali-images/v12.png',
    'https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/wali-images/v7.png',
    'https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/wali-images/v14.png',
    'https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/wali-images/v13.png',
    'https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/wali-images/v6.png',
    'https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/wali-images/v11.png',
    'https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/wali-images/v15.png',
    'https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/wali-images/v18.png',
    'https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/wali-images/v2.png',
    'https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/wali-images/v20.png',
    'https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/wali-images/v4.png',
    'https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/wali-images/c13.png',
    'https://zykbcgqgkdsguirjvwxg.supabase.co/storage/v1/object/public/wali-images/v9.png',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      _precacheAll();
    }
  }

  Future<void> _precacheAll() async {
    // on précharge toutes les images pour éviter les écrans blancs entre deux
    for (final url in _images) {
      try {
        await precacheImage(CachedNetworkImageProvider(url), context);
      } catch (_) {}
    }
    if (!mounted) return;
    _startAuto();
  }

  void _startAuto() {
    if (_autoStarted || _images.length <= 1 || !_ctrl.hasClients) return;
    _autoStarted = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_ctrl.hasClients) return;
      _index = (_index + 1) % _images.length;
      _ctrl.animateToPage(
        _index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 190,
        child: Stack(
          children: [
            // ---------- Carrousel d’images ----------
            PageView.builder(
              controller: _ctrl,
              itemCount: _images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final url = _images[i];
                return CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: Colors.black12), // pas de blanc
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported,
                        color: Colors.black45),
                  ),
                  fadeInDuration: const Duration(milliseconds: 250),
                  fadeOutDuration: Duration.zero,
                );
              },
            ),

            // léger dégradé pour la lisibilité
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withOpacity(0.25),
                      Colors.transparent,
                      Colors.black.withOpacity(0.18),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // ---------- Texte haut ----------
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      shadows: const [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    children: [
                      TextSpan(text: '${widget.titleTop}\n'),
                      TextSpan(
                        text: widget.titleBottom,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ---------- CTA recherche ----------
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Material(
                color: Colors.white,
                elevation: 3,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: widget.onSearchTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
                    child: Row(
                      children: const [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trouver mon job',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Métier, entreprise, compétence…',
                                style: TextStyle(
                                    color: Colors.black45, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.black,
                          child: Icon(
                            Icons.search,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ---------- Dots ----------
            if (_images.length > 1)
              Positioned(
                bottom: 6,
                right: 16,
                child: Row(
                  children: List.generate(_images.length, (i) {
                    final active = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 6,
                      width: active ? 18 : 6,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ================== UI helpers ==================
class _PillAction extends StatelessWidget {
  const _PillAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: StadiumBorder(side: BorderSide(color: color.withOpacity(.45))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Carte "vitrine" =====================
class _JobCardVitrine extends StatelessWidget {
  const _JobCardVitrine({
    required this.title,
    required this.company,
    required this.subtitle,
    required this.meta,
    required this.onTap,
    required this.favorite,
    required this.onFavoriteTap,
    this.logoUrl,
    this.bannerUrl,
  });

  final String title;
  final String company;
  final String subtitle;
  final String meta;
  final String? logoUrl;
  final String? bannerUrl;
  final bool favorite;
  final VoidCallback onFavoriteTap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasLogo = (logoUrl ?? '').trim().isNotEmpty;
    final hasBanner = (bannerUrl ?? '').trim().isNotEmpty;

    final bool useLogoAsBanner = !hasBanner && hasLogo;

    final isMobile = MediaQuery.of(context).size.width < 600;
    final double bannerHeight = isMobile ? 110 : 140;
    final double badgeSize = isMobile ? 36 : 42;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: bannerHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasBanner)
                    Image.network(
                      bannerUrl!.trim(),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    )
                  else if (useLogoAsBanner)
                    Container(
                      color: Colors.white,
                      child: Image.network(
                        logoUrl!.trim(),
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.work_outline,
                          size: 40,
                          color: Colors.black45,
                        ),
                      ),
                    )
                  else
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF4F6F9), Color(0xFFE9EDF3)],
                        ),
                      ),
                    ),
                  if (!useLogoAsBanner && hasLogo)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(blurRadius: 8, color: Colors.black12)
                          ],
                        ),
                        child: SizedBox(
                          width: badgeSize,
                          height: badgeSize,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              logoUrl!.trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.work_outline, size: 22),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IconButton(
                      onPressed: onFavoriteTap,
                      icon: Icon(
                        favorite ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                      ),
                      color: favorite ? Colors.red : Colors.black87,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (company.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(company,
                        style: const TextStyle(color: Colors.black54)),
                  ],
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(color: Colors.black54)),
                  ],
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      meta,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: onTap,
                      child: const Text('Voir l’offre'),
                    ),
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
