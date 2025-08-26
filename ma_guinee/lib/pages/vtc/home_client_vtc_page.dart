// lib/pages/vtc/home_client_vtc_page.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/utilisateur_model.dart';
import '../../routes.dart';

/// Accueil VTC côté CLIENT — style moderne / futuriste
class HomeClientVtcPage extends StatefulWidget {
  final UtilisateurModel currentUser;
  const HomeClientVtcPage({super.key, required this.currentUser});

  @override
  State<HomeClientVtcPage> createState() => _HomeClientVtcPageState();
}

class _HomeClientVtcPageState extends State<HomeClientVtcPage> {
  final _sb = Supabase.instance.client;

  Map<String, dynamic>? _active; // course active
  final List<Map<String, dynamic>> _recent = []; // historique
  bool _loading = true;
  bool _loadingMore = false;
  String? _lastCreatedAtCursor; // ISO8601 desc cursor
  RealtimeChannel? _chan;

  // UI / Map
  final _map = MapController();
  final ll.LatLng _center = const ll.LatLng(9.6412, -13.5784); // Conakry
  String _vehicle = 'car'; // 'car' | 'moto'

  @override
  void initState() {
    super.initState();
    _loadAll();
    _subscribeActive();
  }

  @override
  void dispose() {
    _chan?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      await Future.wait([_loadActive(), _loadRecent(reset: true)]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadActive() async {
    try {
      final row = await _sb
          .from('courses')
          .select(
              'id, status, price_estimated, price_final, depart_label, arrivee_label, chauffeur_id, created_at')
          .eq('client_id', widget.currentUser.id)
          .inFilter('status', ['pending', 'accepted', 'en_route'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;
      setState(() => _active = row == null ? null : Map<String, dynamic>.from(row));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erreur chargement course active: $e")));
    }
  }

  Future<void> _loadRecent({bool reset = false}) async {
    if (reset) {
      _recent.clear();
      _lastCreatedAtCursor = null;
    }
    setState(() => _loadingMore = true);
    try {
      var q = _sb
          .from('courses')
          .select('id, status, price_final, depart_label, arrivee_label, created_at')
          .eq('client_id', widget.currentUser.id);

      if (_lastCreatedAtCursor != null) {
        q = q.lt('created_at', _lastCreatedAtCursor!);
      }

      final rows = await q.order('created_at', ascending: false).limit(20);
      final list = (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();

      if (list.isNotEmpty) {
        _lastCreatedAtCursor = list.last['created_at']?.toString();
        _recent.addAll(list);
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur historique: $e')));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _subscribeActive() {
    _chan?.unsubscribe();

    _chan = _sb.channel('client_active_${widget.currentUser.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'courses',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'client_id',
          value: widget.currentUser.id,
        ),
        callback: (_) async {
          await _loadActive();
          if (mounted) await _loadRecent(reset: true);
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'courses',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'client_id',
          value: widget.currentUser.id,
        ),
        callback: (_) async {
          await _loadActive();
          if (mounted) await _loadRecent(reset: true);
        },
      )
      ..subscribe();
  }

  void _openActiveAction() {
    final a = _active;
    if (a == null) return;
    final status = (a['status'] as String?) ?? '';
    final id = (a['id'] ?? '').toString();
    if (id.isEmpty) return;

    if (status == 'pending') {
      Navigator.pushNamed(context, AppRoutes.vtcOffres, arguments: {'demandeId': id});
    } else {
      Navigator.pushNamed(context, AppRoutes.vtcSuivi, arguments: {'courseId': id});
    }
  }

  void _newRequest() {
    Navigator.pushNamed(context, AppRoutes.vtcDemande);
  }

  Future<void> _refresh() => _loadAll();

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Soneya — Client'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newRequest,
        icon: const Icon(Icons.timeline),
        label: const Text('Nouvelle course'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                children: [
                  // ---------- MAP CARD (glass) ----------
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: SizedBox(
                          height: 260,
                          child: FlutterMap(
                            mapController: _map,
                            options: MapOptions(
                              initialCenter: _center,
                              initialZoom: 13,
                              interactionOptions:
                                  const InteractionOptions(flags: ~InteractiveFlag.rotate),
                            ),
                            // IMPORTANT: pas de `const` ici
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                subdomains: const ['a', 'b', 'c'],
                                userAgentPackageName: 'com.example.ma_guinee',
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Glow border
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(.06),
                                  blurRadius: 24,
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // ___ Vehicle pills (glass)
                      Positioned(
                        top: 14,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _Glass(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _VehicleChip(
                                    icon: Icons.two_wheeler,
                                    label: 'Moto',
                                    selected: _vehicle == 'moto',
                                    onTap: () => setState(() => _vehicle = 'moto'),
                                  ),
                                  const SizedBox(width: 8),
                                  _VehicleChip(
                                    icon: Icons.directions_car_filled_rounded,
                                    label: 'Voiture',
                                    selected: _vehicle == 'car',
                                    onTap: () => setState(() => _vehicle = 'car'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // ___ Where to? pill (bottom center)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: _Glass(
                          child: InkWell(
                            onTap: _newRequest,
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade600,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.search,
                                        color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      "Où allons-nous ?",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                  ),
                                  Row(
                                    children: const [
                                      Icon(Icons.star_border, size: 18),
                                      SizedBox(width: 8),
                                      Icon(Icons.schedule, size: 18),
                                      SizedBox(width: 4),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ---------- Active ride -----------
                  if (_active != null)
                    _ActiveCourseCard(active: _active!, onOpen: _openActiveAction),

                  if (_active != null) const SizedBox(height: 16),

                  // ---------- History ----------
                  Text(
                    'Historique récent',
                    style: th.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),

                  if (_recent.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('Aucune course récente'),
                        subtitle: Text('Crée ta première demande pour commencer.'),
                      ),
                    )
                  else
                    ..._recent.map(
                      (c) => Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: th.dividerColor.withOpacity(.15)),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade50,
                            child: Icon(
                              c['status'] == 'completed'
                                  ? Icons.done
                                  : Icons.directions_car_filled,
                              color: Colors.green.shade700,
                            ),
                          ),
                          title: Text(
                              '${c['depart_label'] ?? '-'} → ${c['arrivee_label'] ?? '-'}'),
                          subtitle: Text('Statut: ${c['status']}'),
                          trailing: Text('${c['price_final'] ?? '-'} GNF'),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),
                  if (!_loadingMore)
                    OutlinedButton.icon(
                      onPressed: _loadRecent,
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Charger plus'),
                    )
                  else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

// ---------- Glass container (simple) ----------
class _Glass extends StatelessWidget {
  final Widget child;
  const _Glass({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _VehicleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _VehicleChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selColor = selected ? Colors.green.shade700 : Colors.black87;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selColor,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, size: 16, color: Colors.green),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------- Active course card ----------
class _ActiveCourseCard extends StatelessWidget {
  final Map<String, dynamic> active;
  final VoidCallback onOpen;
  const _ActiveCourseCard({required this.active, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final status = (active['status'] as String?) ?? '-';
    final price = active['price_final'] ?? active['price_estimated'] ?? '-';
    return Card(
      elevation: 0,
      color: th.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: th.dividerColor.withOpacity(.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Course en cours',
                style: th.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('${active['depart_label'] ?? '-'} → ${active['arrivee_label'] ?? '-'}'),
            const SizedBox(height: 6),
            Text('Statut: $status • Tarif: $price GNF'),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new),
                label: Text(status == 'pending' ? 'Voir offres' : 'Suivi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
