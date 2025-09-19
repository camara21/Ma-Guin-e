// lib/pages/jobs/job_home_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'jobs_page.dart';
import 'job_detail_page.dart';
import 'my_applications_page.dart';
import '../cv/cv_maker_page.dart';
import 'employer/mes_offres_page.dart';
import 'employer/devenir_employeur_page.dart';

class JobHomePage extends StatefulWidget {
  const JobHomePage({super.key});
  @override
  State<JobHomePage> createState() => _JobHomePageState();
}

class _JobHomePageState extends State<JobHomePage> {
  // Palette Ma Guinée
  static const kBlue   = Color(0xFF1976D2);
  static const kBg     = Color(0xFFF6F7F9);
  static const kRed    = Color(0xFFCE1126);
  static const kYellow = Color(0xFFFCD116);
  static const kGreen  = Color(0xFF009460);

  late Future<List<Map<String, dynamic>>> _recent;

  @override
  void initState() {
    super.initState();
    _recent = _loadRecent();
  }

  Future<List<Map<String, dynamic>>> _loadRecent() async {
    final sb = Supabase.instance.client;
    try {
      // 1) Offres récentes publiques (actif = true)
      final List rows = await sb
          .from('emplois')
          .select('id, titre, ville, commune, type_contrat, cree_le, employeur_id')
          .eq('actif', true)
          .order('cree_le', ascending: false)
          .limit(8);

      final items = rows.map((e) => Map<String, dynamic>.from(e)).toList();

      // 2) Tenter de récupérer logos via la RPC (si dispo)
      final ids = items
          .map((m) => (m['employeur_id'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> logosById = {};
      if (ids.isNotEmpty) {
        try {
          final res = await sb.rpc('get_employeurs_public', params: {'ids': ids});
          final list = (res as List?) ?? const [];
          for (final e in list) {
            final m = Map<String, dynamic>.from(e);
            final id = (m['id'] ?? '').toString();
            if (id.isNotEmpty) logosById[id] = m;
          }
        } catch (_) {
          // La RPC n'existe pas → on ignore les logos (pas d'erreur UI)
        }
      }

      // 3) Merge logos dans les items
      for (final m in items) {
        final empId = (m['employeur_id'] ?? '').toString();
        if (empId.isNotEmpty && logosById.containsKey(empId)) {
          m['employeur_nom']  = logosById[empId]?['nom'] ?? '';
          m['logo_url']       = logosById[empId]?['logo_url'] ?? '';
        } else {
          m['employeur_nom']  = '';
          m['logo_url']       = '';
        }
      }

      return items;
    } catch (e) {
      // Si la policy SELECT n’est pas ouverte au public, on arrive ici
      debugPrint('load recent jobs error: $e');
      rethrow;
    }
  }

  String _formatVilleType(Map<String, dynamic> m) {
    final ville = (m['ville'] ?? '').toString();
    final type  = (m['type_contrat'] ?? '').toString().toUpperCase();
    if (ville.isEmpty && type.isEmpty) return '';
    if (ville.isEmpty) return type;
    if (type.isEmpty)  return ville;
    return '$ville • $type';
  }

  String _formatDate(Map<String, dynamic> m) {
    final raw = m['cree_le']?.toString();
    if (raw == null || raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
      if (diff.inHours   < 24) return 'il y a ${diff.inHours} h';
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) { return ''; }
  }

  Future<void> _openEmployeur() async {
    final sb  = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;

    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter pour accéder à l’espace employeur.')),
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
          MaterialPageRoute(builder: (_) => MesOffresPage(employeurId: employeurId)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        title: const Text('Emplois'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _HeroJobs(
            titleTop: 'La Guinée recrute',
            titleBottom: 'choisis ton avenir',
            onSearchTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const JobsPage())),
            imageAsset: 'assets/jobs/hero.png',
          ),
          const SizedBox(height: 12),

          // Actions rapides
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _PillAction(
                icon: Icons.picture_as_pdf, label: 'Générer mon CV',
                color: kYellow,
                onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => CvMakerPage())),
              ),
              _PillAction(
                icon: Icons.assignment_turned_in, label: 'Mes candidatures',
                color: kGreen,
                onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const MyApplicationsPage())),
              ),
              _PillAction(
                icon: Icons.business_center, label: 'Espace employeur',
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => CvMakerPage())),
              child: const Text('Créer mon CV'),
            ),
          ),

          const SizedBox(height: 18),

          _SectionTitle('Dernières offres'),
          const SizedBox(height: 8),

          FutureBuilder<List<Map<String, dynamic>>>(
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

              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return const Text('Aucune offre disponible pour l’instant.');
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final m = items[i];
                  final logo = (m['logo_url'] ?? '').toString();
                  final jobId = (m['id'] ?? '').toString();

                  return _JobCard(
                    title: (m['titre'] ?? '').toString(),
                    subtitle: _formatVilleType(m),
                    meta: _formatDate(m),
                    logoUrl: logo,
                    onTap: () {
                      if (jobId.isEmpty) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => JobDetailPage(jobId: jobId)),
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

// ================== HERO ==================
class _HeroJobs extends StatelessWidget {
  const _HeroJobs({
    required this.titleTop,
    required this.titleBottom,
    required this.onSearchTap,
    this.imageAsset = 'assets/jobs/hero.png',
  });

  final String titleTop;
  final String titleBottom;
  final VoidCallback onSearchTap;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width *
        MediaQuery.of(context).devicePixelRatio;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.asset(
              imageAsset,
              fit: BoxFit.cover,
              cacheWidth: w.round(),
              filterQuality: FilterQuality.medium,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withOpacity(0.65),
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.55),
                  ],
                  stops: const [0, .5, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16, right: 16, top: 16,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  children: [
                    TextSpan(text: '$titleTop\n'),
                    const TextSpan(text: 'choisis ton avenir', style: TextStyle(fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12, right: 12, bottom: 12,
            child: Material(
              color: Colors.white,
              elevation: 3,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: onSearchTap,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
                  child: Row(
                    children: const [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Trouver mon job',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            SizedBox(height: 4),
                            Text('Métier, entreprise, compétence…',
                              style: TextStyle(color: Colors.black45, fontSize: 14)),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.black,
                        child: Icon(Icons.search, color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================== UI helpers ==================
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ===== Boutons pilule =====
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

// ===== Carte offre =====
class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.onTap,
    this.logoUrl,
  });

  final String title;
  final String subtitle;
  final String meta;
  final String? logoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasLogo = (logoUrl ?? '').trim().isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            children: [
              if (hasLogo)
                CircleAvatar(radius: 18, backgroundImage: NetworkImage(logoUrl!.trim()))
              else
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: _JobHomePageState.kBlue,
                  child: Icon(Icons.work_outline, color: Colors.white, size: 18),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black54)),
                    ],
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(meta, style: const TextStyle(fontSize: 12, color: Colors.black45)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
