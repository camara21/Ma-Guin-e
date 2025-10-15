import 'dart:math' show min, max;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // graphiques
  String currentTable = 'logements';
  int days = 30;
  List<_Point> series = [];
  List<_TopCity> topCities = [];
  List<_OnlineUser> onlineUsers = [];
  List<_ActiveChat> activeChats = [];

  // compteurs fiables pour reports
  int reportsTotal = 0;
  int reportsToday = 0;

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
    await _loadMetrics();
    await _loadCharts();
    await _loadTopCities();
    await _loadOnline();
    await _loadActiveChats();
    await _loadReportsCounters(); // ← important pour la tuile Signalements
  }

  // ───────── metrics globales (RPC si dispo)
  Future<void> _loadMetrics() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await SB.i.rpc('rpc_metrics_overview');
      if (res is Map<String, dynamic>) {
        metrics = res;
      } else if (res is List && res.isNotEmpty && res.first is Map) {
        metrics = Map<String, dynamic>.from(res.first as Map);
      } else {
        metrics = {};
      }
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ───────── graphe J-N
  Future<void> _loadCharts() async {
    try {
      final data = await SB.i
          .rpc('rpc_daily_content', params: {'_table': currentTable, '_days': days});
      final list = (data is List) ? data : <dynamic>[];
      series = list.map<_Point>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _Point(DateTime.parse(m['d'] as String), (m['total'] as num? ?? 0).toInt());
      }).toList()
        ..sort((a, b) => a.d.compareTo(b.d));
      setState(() {});
    } catch (_) {
      series = [];
      setState(() {});
    }
  }

  // ───────── top villes
  Future<void> _loadTopCities() async {
    try {
      final data = await SB.i
          .rpc('rpc_top_cities', params: {'_table': currentTable, '_limit': 8});
      final list = (data is List) ? data : <dynamic>[];
      topCities = list.map<_TopCity>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _TopCity((m['ville'] ?? '-') as String, (m['total'] as num? ?? 0).toInt());
      }).toList();
      setState(() {});
    } catch (_) {
      topCities = [];
      setState(() {});
    }
  }

  // ───────── online
  Future<void> _loadOnline() async {
    try {
      final data = await SB.i.rpc('rpc_online_users');
      final list = (data is List) ? data : <dynamic>[];
      onlineUsers = list.map<_OnlineUser>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _OnlineUser(
          (m['user_id'] ?? '').toString(),
          DateTime.parse(m['last_seen'] as String),
          (m['device'] ?? '-') as String,
          (m['ip'] ?? '') as String,
        );
      }).toList();
      setState(() {});
    } catch (_) {
      onlineUsers = [];
      setState(() {});
    }
  }

  // ───────── active chats
  Future<void> _loadActiveChats() async {
    try {
      final data =
          await SB.i.rpc('rpc_active_chats', params: {'_minutes': 60, '_limit': 10});
      final list = (data is List) ? data : <dynamic>[];
      activeChats = list.map<_ActiveChat>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _ActiveChat(
          (m['context_type'] ?? '-') as String,
          (m['context_id'] ?? '').toString(),
          (m['messages'] as num? ?? 0).toInt(),
        );
      }).toList();
      setState(() {});
    } catch (_) {
      activeChats = [];
      setState(() {});
    }
  }

  // ───────── compteurs “reports” fiables (total + today)
  Future<void> _loadReportsCounters() async {
    try {
      // total
      final totalRes = await SB.i.from('reports').select('id');
      final total = (totalRes as List).length;

      // aujourd’hui (UTC)
      final now = DateTime.now().toUtc();
      final start = DateTime.utc(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      final todayRes = await SB.i
          .from('reports')
          .select('id')
          .gte('created_at', start.toIso8601String())
          .lt('created_at', end.toIso8601String());
      final today = (todayRes as List).length;

      // patch dans metrics au besoin
      metrics ??= {};
      final m = Map<String, dynamic>.from(metrics!);
      m['reports'] = {'total': total, 'today': today};
      setState(() {
        metrics = m;
        reportsTotal = total;
        reportsToday = today;
      });
    } catch (_) {
      // on ignore si erreur réseau
    }
  }

  Future<void> _refreshAll() async {
    await _loadMetrics();
    await _loadCharts();
    await _loadTopCities();
    await _loadOnline();
    await _loadActiveChats();
    await _loadReportsCounters();
  }

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
            onPressed: () async {
              await SB.i.auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.splash,
                (route) => false,
              );
            },
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
                        ];
                        if (c.maxWidth > 900) {
                          return Row(
                            children: cards.map((w) => Expanded(child: w)).toList(),
                          );
                        }
                        return Column(children: cards);
                      }),

                      const SizedBox(height: 16),

                      // Filtres graphe
                      Row(children: [
                        DropdownButton<String>(
                          value: currentTable,
                          items: services
                              .map((s) =>
                                  DropdownMenuItem(value: s.table, child: Text(s.name)))
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

                      // Grille services
                      _gridServices(context, m),
                    ],
                  ),
                ),
    );
  }

  // ───────── UI helpers

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
            const Text('Utilisateurs en ligne (≤ 5 min)',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
                        child: Text(
                          '${c.contextType} ${c.contextId.substring(0, min(6, c.contextId.length))}…',
                        ),
                      ),
                      Text('${c.messages} msg'),
                    ]),
                  )),
          ],
        ),
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

        // valeurs de la RPC
        final obj = (metricsMap[s.table] ?? {}) as Map? ?? {};
        int total = (obj['total'] as num?)?.toInt() ?? 0;
        int today = (obj['today'] as num?)?.toInt() ?? 0;

        // override fiable pour Signalements
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
                Text('Aujourd’hui: $today'),
              ],
            ),
          ),
        );

        // petit badge “today” pour les signalements
        final withBadge = s.table == 'reports' && reportsToday > 0
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  card,
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$reportsToday',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : card;

        return InkWell(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  ContentAdvancedPage(title: s.name, table: s.table),
            ));
          },
          child: withBadge,
        );
      },
    );
  }

  // helpers
  _Service _serviceByTable(String t) =>
      services.firstWhere((s) => s.table == t, orElse: () => services.first);
  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ───────── models/UI

class _Service {
  final String name;
  final IconData icon;
  final String table;
  const _Service(this.name, this.icon, this.table);
}

class _Point {
  final DateTime d;
  final int v;
  _Point(this.d, this.v);
}

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
    final area =
        Rect.fromLTWH(margin, margin, size.width - 2 * margin, size.height - 2 * margin);

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
    final path = Path();
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
