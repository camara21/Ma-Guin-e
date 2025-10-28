// lib/pages/admin/admin_dashboard.dart
import 'dart:math' show min, max;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Carte
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Ouvrir les URLs des pièces
import 'package:url_launcher/url_launcher.dart';

import '../supabase_client.dart';
import '../routes.dart';
import 'content_advanced_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? metrics;
  bool loading = true;
  String? error;

  // Graphiques
  String currentTable = 'logements';
  int days = 30;
  List<_Point> series = [];
  List<_TopCity> topCities = [];
  List<_OnlineUser> onlineUsers = [];
  List<_ActiveChat> activeChats = [];

  // Reports
  int reportsTotal = 0;
  int reportsToday = 0;

  // Utilisateurs
  int usersTotal = 0;
  int usersWithLocation = 0;

  // Carte
  List<_UserLoc> userLocs = [];
  final MapController _mapController = MapController();

  // Vérification organisateurs
  static const _kEventPrimary = Color(0xFF7B2CBF);
  List<_Organizer> _pendingOrgs = [];
  bool _loadingOrgs = true;

  final services = <_Service>[
    _Service('Annonces', Icons.campaign, 'annonces'),
    _Service('Prestataires', Icons.handyman, 'prestataires'),
    _Service('Restaurants', Icons.restaurant, 'restaurants'),
    _Service('Lieux (Culte / Divertissement / Tourisme)', Icons.place, 'lieux'),
    _Service('Santé (Cliniques)', Icons.local_hospital, 'cliniques'),
    _Service('Hôtels', Icons.hotel, 'hotels'),
    _Service('Logements', Icons.apartment, 'logements'),
    _Service('Wali fen (Emplois)', Icons.work, 'emplois'),
    _Service('Billetterie (Events)', Icons.confirmation_number, 'events'),
    _Service('Signalements', Icons.report, 'reports'),
  ];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await Future.wait([
        _loadMetrics(),
        _loadCharts(),
        _loadTopCities(),
        _loadOnline(),
        _loadActiveChats(),
        _loadReportsCounters(),
        _loadUsersCounters(),
        _loadUserLocations(),
        _loadPendingOrganizers(),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e');
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  // === Data loads ===
  Future<void> _loadMetrics() async {
    try {
      final res = await SB.i.rpc('rpc_metrics_overview');
      Map<String, dynamic> m;
      if (res is Map<String, dynamic>) {
        m = res;
      } else if (res is List && res.isNotEmpty && res.first is Map) {
        m = Map<String, dynamic>.from(res.first as Map);
      } else {
        m = {};
      }
      if (!mounted) return;
      setState(() => metrics = m);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e');
    }
  }

  Future<void> _loadCharts() async {
    try {
      final data = await SB.i.rpc(
        'rpc_daily_content',
        params: {'_table': currentTable, '_days': days},
      );
      final list = (data is List) ? data : const <dynamic>[];
      final s = list.map<_Point>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _Point(
          DateTime.parse(m['d'] as String),
          (m['total'] as num? ?? 0).toInt(),
        );
      }).toList()
        ..sort((a, b) => a.d.compareTo(b.d));
      if (!mounted) return;
      setState(() => series = s);
    } catch (_) {
      if (!mounted) return;
      setState(() => series = []);
    }
  }

  Future<void> _loadTopCities() async {
    try {
      final data = await SB.i.rpc(
        'rpc_top_cities',
        params: {'_table': currentTable, '_limit': 8},
      );
      final list = (data is List) ? data : const <dynamic>[];
      final cities = list.map<_TopCity>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _TopCity(
          (m['ville'] ?? '-') as String,
          (m['total'] as num? ?? 0).toInt(),
        );
      }).toList();
      if (!mounted) return;
      setState(() => topCities = cities);
    } catch (_) {
      if (!mounted) return;
      setState(() => topCities = []);
    }
  }

  Future<void> _loadOnline() async {
    try {
      final data = await SB.i.rpc('rpc_online_users');
      final list = (data is List) ? data : const <dynamic>[];
      final users = list.map<_OnlineUser>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _OnlineUser(
          (m['user_id'] ?? '').toString(),
          DateTime.parse(m['last_seen'] as String),
          (m['device'] ?? '-') as String,
          (m['ip'] ?? '') as String,
        );
      }).toList();
      if (!mounted) return;
      setState(() => onlineUsers = users);
    } catch (_) {
      if (!mounted) return;
      setState(() => onlineUsers = []);
    }
  }

  Future<void> _loadActiveChats() async {
    try {
      final data = await SB.i.rpc(
        'rpc_active_chats',
        params: {'_minutes': 60, '_limit': 10},
      );
      final list = (data is List) ? data : const <dynamic>[];
      final chats = list.map<_ActiveChat>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _ActiveChat(
          (m['context_type'] ?? '-') as String,
          (m['context_id'] ?? '').toString(),
          (m['messages'] as num? ?? 0).toInt(),
        );
      }).toList();
      if (!mounted) return;
      setState(() => activeChats = chats);
    } catch (_) {
      if (!mounted) return;
      setState(() => activeChats = []);
    }
  }

  Future<void> _loadReportsCounters() async {
    try {
      final totalRes = await SB.i.from('reports').select('id');
      final total = (totalRes as List).length;

      final now = DateTime.now().toUtc();
      final start = DateTime.utc(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      final todayRes = await SB.i
          .from('reports')
          .select('id')
          .gte('created_at', start.toIso8601String())
          .lt('created_at', end.toIso8601String());
      final today = (todayRes as List).length;

      if (!mounted) return;
      metrics ??= {};
      final m = Map<String, dynamic>.from(metrics!);
      m['reports'] = {'total': total, 'today': today};
      setState(() {
        metrics = m;
        reportsTotal = total;
        reportsToday = today;
      });
    } catch (_) {/* ignore */}
  }

  Future<void> _loadUsersCounters() async {
    try {
      final all = await SB.i.from('utilisateurs').select('id');
      final withLoc = await SB.i
          .from('utilisateurs')
          .select('id')
          .not('last_lat', 'is', null)
          .not('last_lon', 'is', null);
      if (!mounted) return;
      setState(() {
        usersTotal = (all as List).length;
        usersWithLocation = (withLoc as List).length;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        usersTotal = 0;
        usersWithLocation = 0;
      });
    }
  }

  Future<void> _loadUserLocations({int limit = 1000}) async {
    try {
      final res = await SB.i.rpc('rpc_user_locations', params: {'_limit': limit});
      final list = (res is List) ? res : const <dynamic>[];
      final pts = list.map<_UserLoc>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _UserLoc(
          (m['id'] ?? '').toString(),
          (m['lat'] as num).toDouble(),
          (m['lon'] as num).toDouble(),
          (m['ville'] ?? '').toString(),
        );
      }).toList();
      if (!mounted) return;
      setState(() => userLocs = pts);
      _fitBoundsToUsers();
    } catch (_) {
      if (!mounted) return;
      setState(() => userLocs = []);
    }
  }

  void _fitBoundsToUsers() {
    if (userLocs.isEmpty) return;
    double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
    for (final u in userLocs) {
      minLat = min<double>(minLat, u.lat);
      maxLat = max<double>(maxLat, u.lat);
      minLon = min<double>(minLon, u.lon);
      maxLon = max<double>(maxLon, u.lon);
    }
    final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
    _mapController.move(center, 3.5);
  }

  Future<void> _loadPendingOrganizers() async {
    setState(() => _loadingOrgs = true);
    try {
      final res = await SB.i
          .from('organisateurs')
          .select('id, user_id, nom_structure, telephone, email_pro, ville, description, nif, rccm, verifie, documents_urls')
          .eq('verifie', false)
          .order('created_at', ascending: true);
      final list = (res as List).cast<Map<String, dynamic>>();
      final mapped = list.map((m) => _Organizer.fromMap(m)).toList();
      if (!mounted) return;
      setState(() => _pendingOrgs = mapped);
    } catch (e) {
      debugPrint('Erreur load pending organizers: $e');
    } finally {
      if (mounted) setState(() => _loadingOrgs = false);
    }
  }

  Future<void> _approveOrganizer(_Organizer org, {String? note}) async {
    try {
      await SB.i.from('organisateurs').update({'verifie': true}).eq('id', org.id);
      try {
        await SB.i.from('organisateurs').update({'verification_note': note}).eq('id', org.id);
      } catch (_) {}
      await _loadPendingOrganizers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Validé: ${org.nomStructure}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur validation: $e')),
      );
    }
  }

  Future<void> _rejectOrganizer(_Organizer org, {required String reason}) async {
    try {
      try {
        await SB.i.from('organisateurs').update({'verification_note': 'REFUS: $reason'}).eq('id', org.id);
      } catch (_) {}
      await _loadPendingOrganizers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refus enregistré pour ${org.nomStructure}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur refus: $e')),
      );
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadMetrics(),
      _loadCharts(),
      _loadTopCities(),
      _loadOnline(),
      _loadActiveChats(),
      _loadReportsCounters(),
      _loadUsersCounters(),
      _loadUserLocations(),
      _loadPendingOrganizers(),
    ]);
  }

  // === UI ===
  @override
  Widget build(BuildContext context) {
    final m = metrics ?? {};
    int totalAll = 0;
    for (final k in m.keys) {
      if (k == 'active_24h') continue;
      final obj = m[k];
      if (obj is Map && obj['total'] != null) {
        totalAll += (obj['total'] as num).toInt();
      }
    }
    final active = ((m['active_24h'] as num?) ?? 0).toInt().toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Centre d'administration"),
        actions: [
          IconButton(onPressed: _refreshAll, icon: const Icon(Icons.refresh)),
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () async => SB.i.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text('Erreur: $error'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      // KPI
                      LayoutBuilder(builder: (context, c) {
                        final cards = [
                          _kpiCard('Utilisateurs actifs 24h', active, Icons.flash_on),
                          _kpiCard('Contenus (total)', '$totalAll', Icons.storage),
                          _kpiCard('Inscrits (total)', '$usersTotal', Icons.people),
                          _kpiCard('Avec localisation', '$usersWithLocation', Icons.location_on),
                        ];
                        if (c.maxWidth > 900) {
                          return Row(children: cards.map((w) => Expanded(child: w)).toList());
                        }
                        return Column(children: cards);
                      }),

                      const SizedBox(height: 16),

                      // Bloc Validation organisateurs
                      _organizersVerificationCard(),

                      const SizedBox(height: 16),

                      // Filtres graphe
                      Row(children: [
                        DropdownButton<String>(
                          value: currentTable,
                          items: services
                              .map((s) => DropdownMenuItem(value: s.table, child: Text(s.name)))
                              .toList(),
                          onChanged: (v) async {
                            if (v == null) return;
                            setState(() => currentTable = v);
                            await _loadCharts();
                            await _loadTopCities();
                          },
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: days,
                          items: const [7, 14, 30, 60, 90]
                              .map((d) => DropdownMenuItem(value: d, child: Text('J-$d')))
                              .toList(),
                          onChanged: (v) async {
                            if (v == null) return;
                            setState(() => days = v);
                            await _loadCharts();
                          },
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ContentAdvancedPage(
                                title: _serviceByTable(currentTable).name,
                                table: currentTable,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Ouvrir la gestion'),
                        ),
                      ]),

                      const SizedBox(height: 8),

                      // Graphe + Top villes
                      LayoutBuilder(builder: (context, c) {
                        final left = Expanded(child: _chartCard());
                        final right = Expanded(child: _topCitiesCard());
                        if (c.maxWidth > 900) {
                          return Row(children: [left, const SizedBox(width: 12), right]);
                        }
                        return Column(children: [left, const SizedBox(height: 12), right]);
                      }),

                      const SizedBox(height: 16),

                      // Online + Chats
                      LayoutBuilder(builder: (context, c) {
                        final left = Expanded(child: _onlineCard());
                        final right = Expanded(child: _activeChatsCard());
                        if (c.maxWidth > 900) {
                          return Row(children: [left, const SizedBox(width: 12), right]);
                        }
                        return Column(children: [left, const SizedBox(height: 12), right]);
                      }),

                      const SizedBox(height: 16),

                      // Carte utilisateurs
                      _usersMapCard(),

                      const SizedBox(height: 16),

                      // Grille services
                      _gridServices(context, m),
                    ],
                  ),
                ),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(icon, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(fontSize: 18)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ------- Bloc Vérification Organisateurs -------
  Widget _organizersVerificationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              const Text('Organisateurs à vérifier', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kEventPrimary.withOpacity(.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_pendingOrgs.length}',
                  style: const TextStyle(color: _kEventPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Rafraîchir',
                onPressed: _loadPendingOrganizers,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingOrgs)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            )
          else if (_pendingOrgs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Aucun dossier en attente.'),
            )
          else
            Column(
              children: _pendingOrgs.map((o) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withOpacity(.06)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.nomStructure, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('${o.ville ?? '-'} • ${o.telephone ?? '-'}'),
                            if (o.emailPro != null && o.emailPro!.isNotEmpty)
                              Text(o.emailPro!),
                            if (o.nif != null && o.nif!.isNotEmpty)
                              Text('NIF: ${o.nif}'),
                            if (o.rccm != null && o.rccm!.isNotEmpty)
                              Text('RCCM: ${o.rccm}'),
                            if (o.description != null && o.description!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(o.description!, maxLines: 3, overflow: TextOverflow.ellipsis),
                            ],
                            if (o.docs.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: o.docs.map((u) {
                                  return InkWell(
                                    onTap: () async {
                                      final uri = Uri.parse(u);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(u, width: 80, height: 80, fit: BoxFit.cover),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _openReviewDialog(o),
                            icon: const Icon(Icons.search),
                            label: const Text('Voir'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kEventPrimary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ]),
      ),
    );
  }

  Future<void> _openReviewDialog(_Organizer org) async {
    final res = await showDialog<_ReviewAction>(
      context: context,
      builder: (_) => _OrganizerReviewDialog(org: org),
    );
    if (res == null) return;
    if (res.action == 'approve') {
      await _approveOrganizer(org, note: res.note);
    } else if (res.action == 'reject') {
      await _rejectOrganizer(org, reason: res.note ?? 'Sans motif');
    }
  }

  Widget _chartCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 240,
          child: series.isEmpty
              ? const Center(child: Text('Pas de données de série pour cette table.'))
              : _LineChart(points: series),
        ),
      ),
    );
  }

  Widget _topCitiesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top villes', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (topCities.isEmpty)
              const Text('Aucune donnée (colonne "ville" absente).')
            else
              ...topCities.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(child: Text(c.ville)),
                      Text('${c.total}'),
                    ]),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _onlineCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Utilisateurs en ligne (≤ 5 min)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (onlineUsers.isEmpty)
              const Text('Aucun utilisateur en ligne.')
            else
              ...onlineUsers.take(10).map((u) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(child: Text(u.userId)),
                      Text(u.device),
                      const SizedBox(width: 8),
                      Text(_fmtTime(u.lastSeen)),
                    ]),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _activeChatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chats actifs (60 min)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (activeChats.isEmpty)
              const Text('Aucune activité de chat.')
            else
              ...activeChats.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(
                        child: Text('${c.contextType} ${c.contextId.substring(0, min(6, c.contextId.length))}…'),
                      ),
                      Text('${c.messages} msg'),
                    ]),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _usersMapCard() {
    final markers = userLocs
        .map((u) => Marker(
              point: LatLng(u.lat, u.lon),
              width: 24,
              height: 24,
              child: const Icon(Icons.location_on, color: Colors.redAccent, size: 22),
            ))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              const Text('Répartition des utilisateurs', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                tooltip: 'Rafraîchir',
                icon: const Icon(Icons.refresh),
                onPressed: _loadUserLocations,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(0, 0),
                initialZoom: 1.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.admin',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('${userLocs.length} utilisateurs géolocalisés affichés'),
        ]),
      ),
    );
  }

  Widget _gridServices(BuildContext context, Map<String, dynamic> metricsMap) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: services.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemBuilder: (context, i) {
        final s = services[i];

        final obj = (metricsMap[s.table] ?? {}) as Map? ?? {};
        int total = (obj['total'] as num?)?.toInt() ?? 0;
        int today = (obj['today'] as num?)?.toInt() ?? 0;

        if (s.table == 'reports') {
          total = reportsTotal;
          today = reportsToday;
        }

        final card = Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(s.icon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
                const Spacer(),
                Text('Total: $total'),
                Text('Aujourd\'hui: $today'),
              ],
            ),
          ),
        );

        final withBadge = s.table == 'reports' && reportsToday > 0
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  card,
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$reportsToday',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              )
            : card;

        return InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ContentAdvancedPage(title: s.name, table: s.table),
            ),
          ),
          child: withBadge,
        );
      },
    );
  }

  _Service _serviceByTable(String t) =>
      services.firstWhere((s) => s.table == t, orElse: () => services.first);
  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ======= Modèles & Dialogues de validation =======
class _Organizer {
  final String id;
  final String? userId;
  final String nomStructure;
  final String? telephone;
  final String? emailPro;
  final String? ville;
  final String? description;
  final String? nif;
  final String? rccm;
  final bool verifie;
  final List<String> docs;

  _Organizer({
    required this.id,
    required this.userId,
    required this.nomStructure,
    required this.telephone,
    required this.emailPro,
    required this.ville,
    required this.description,
    required this.nif,
    required this.rccm,
    required this.verifie,
    required this.docs,
  });

  factory _Organizer.fromMap(Map<String, dynamic> m) => _Organizer(
        id: (m['id'] ?? '').toString(),
        userId: (m['user_id']?.toString()),
        nomStructure: (m['nom_structure'] ?? '').toString(),
        telephone: (m['telephone'] as String?),
        emailPro: (m['email_pro'] as String?),
        ville: (m['ville'] as String?),
        description: (m['description'] as String?),
        nif: (m['nif'] as String?),
        rccm: (m['rccm'] as String?),
        verifie: (m['verifie'] == true),
        docs: (m['documents_urls'] is List)
            ? List<String>.from(m['documents_urls'] as List)
            : const <String>[],
      );
}

class _ReviewAction {
  final String action; // 'approve' | 'reject'
  final String? note;
  const _ReviewAction({required this.action, this.note});
}

class _OrganizerReviewDialog extends StatefulWidget {
  final _Organizer org;
  const _OrganizerReviewDialog({required this.org});

  @override
  State<_OrganizerReviewDialog> createState() => _OrganizerReviewDialogState();
}

class _OrganizerReviewDialogState extends State<_OrganizerReviewDialog> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.org;

    return AlertDialog(
      title: const Text('Vérification organisateur'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(o.nomStructure, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            if (o.ville != null && o.ville!.isNotEmpty) Text('Ville : ${o.ville}'),
            if (o.telephone != null && o.telephone!.isNotEmpty) Text('Téléphone : ${o.telephone}'),
            if (o.emailPro != null && o.emailPro!.isNotEmpty) Text('Email : ${o.emailPro}'),
            if (o.nif != null && o.nif!.isNotEmpty) Text('NIF : ${o.nif}'),
            if (o.rccm != null && o.rccm!.isNotEmpty) Text('RCCM : ${o.rccm}'),
            if (o.description != null && o.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(o.description!),
            ],
            const SizedBox(height: 12),
            if (o.docs.isNotEmpty) ...[
              const Text('Pièces justificatives', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: o.docs.map((u) {
                  return GestureDetector(
                    onTap: () => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(u, width: 90, height: 90, fit: BoxFit.cover),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note interne (optionnel)',
                hintText: 'Commentaire de vérification…',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        TextButton(
          onPressed: () {
            final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
            Navigator.pop(context, _ReviewAction(action: 'reject', note: note ?? 'Dossier incomplet'));
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Refuser'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
            Navigator.pop(context, _ReviewAction(action: 'approve', note: note));
          },
          icon: const Icon(Icons.check),
          label: const Text('Valider'),
        ),
      ],
    );
  }
}

// ======= Chart =======
class _Point {
  final DateTime d;
  final int v;
  _Point(this.d, this.v);
}

class _LineChart extends StatelessWidget {
  final List<_Point> points;
  const _LineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(points),
      child: const SizedBox.expand(),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_Point> pts;
  _LineChartPainter(this.pts);

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.isEmpty) return;

    const margin = 24.0;
    final area = Rect.fromLTWH(
      margin, margin, size.width - 2 * margin, size.height - 2 * margin);

    final axis = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(area.left, area.bottom), Offset(area.right, area.bottom), axis);
    canvas.drawLine(Offset(area.left, area.top), Offset(area.left, area.bottom), axis);

    final minX = pts.first.d.millisecondsSinceEpoch.toDouble();
    final maxX = pts.last.d.millisecondsSinceEpoch.toDouble();
    final spanX = (maxX - minX).abs() < 1 ? 1 : (maxX - minX);
    final maxV = pts.map((e) => e.v).fold<int>(0, max).toDouble().clamp(1, double.infinity);

    final line = Paint()
      ..color = const Color(0xFF246BFD)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = ui.Path();
    for (int i = 0; i < pts.length; i++) {
      final t = (pts[i].d.millisecondsSinceEpoch - minX) / spanX;
      final x = area.left + t * area.width;
      final y = area.bottom - (pts[i].v / maxV) * area.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, line);

    final dot = Paint()..color = const Color(0xFF246BFD);
    for (final p in pts) {
      final t = (p.d.millisecondsSinceEpoch - minX) / spanX;
      final x = area.left + t * area.width;
      final y = area.bottom - (p.v / maxV) * area.height;
      canvas.drawCircle(Offset(x, y), 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) => old.pts != pts;
}

// ======= Autres modèles =======
class _TopCity {
  final String ville;
  final int total;
  _TopCity(this.ville, this.total);
}

class _OnlineUser {
  final String userId;
  final DateTime lastSeen;
  final String device;
  final String ip;
  _OnlineUser(this.userId, this.lastSeen, this.device, this.ip);
}

class _ActiveChat {
  final String contextType;
  final String contextId;
  final int messages;
  _ActiveChat(this.contextType, this.contextId, this.messages);
}

class _UserLoc {
  final String id;
  final double lat;
  final double lon;
  final String ville;
  _UserLoc(this.id, this.lat, this.lon, this.ville);
}

class _Service {
  final String name;
  final IconData icon;
  final String table;
  const _Service(this.name, this.icon, this.table);
}
