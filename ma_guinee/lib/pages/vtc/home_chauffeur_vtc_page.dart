// lib/pages/vtc/home_chauffeur_vtc_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../models/utilisateur_model.dart';
import '../../routes.dart';

/// Accueil VTC côté CHAUFFEUR (style Uber)
/// - Carte OSM gratuite (flutter_map)
/// - Panneau coulissant avec poignée « trois traits »
/// - Gros bouton Passer en ligne / Hors ligne en bas
/// - Raccourcis déplacés dans le menu hamburger (drawer)
class HomeChauffeurVtcPage extends StatefulWidget {
  final UtilisateurModel currentUser;
  const HomeChauffeurVtcPage({super.key, required this.currentUser});

  @override
  State<HomeChauffeurVtcPage> createState() => _HomeChauffeurVtcPageState();
}

class _HomeChauffeurVtcPageState extends State<HomeChauffeurVtcPage> {
  final _sb = Supabase.instance.client;

  final _scaffoldKey = GlobalKey<ScaffoldState>(); // <- pour ouvrir le drawer

  Map<String, dynamic>? _driver; // row chauffeurs
  List<Map<String, dynamic>> _compatibles = [];
  List<Map<String, dynamic>> _actives = [];
  bool _loading = true;
  bool _isOnline = false;

  RealtimeChannel? _chanCourses;
  RealtimeChannel? _chanMyCourses;

  String get _chauffeurId {
    final v = (_driver?['id'] ?? _driver?['user_id']) as String?;
    return v ?? widget.currentUser.id;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _chanCourses?.unsubscribe();
    _chanMyCourses?.unsubscribe();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      await _loadDriver();
      if (!mounted || _driver == null) return;
      await Future.wait([_loadCompatibles(reset: true), _loadActives()]);
      _subscribeStreams();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDriver() async {
    try {
      final row = await _sb
          .from('chauffeurs')
          .select('id, user_id, city, vehicle_pref, is_online, is_verified')
          .or('id.eq.${widget.currentUser.id},user_id.eq.${widget.currentUser.id}')
          .maybeSingle();

      if (!mounted) return;
      if (row == null) {
        Navigator.pushReplacementNamed(context, AppRoutes.vtcInscriptionChauffeur);
        return;
      }
      _driver = row;
      _isOnline = (row['is_online'] as bool?) ?? false;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur profil chauffeur: $e')),
      );
    }
  }

  Future<void> _toggleOnline(bool v) async {
    if (_driver == null) return;
    try {
      await _sb.from('chauffeurs').update({'is_online': v}).eq('id', _chauffeurId);
      if (!mounted) return;
      setState(() => _isOnline = v);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec mise en ligne: $e')),
      );
    }
  }

  Future<void> _loadCompatibles({bool reset = false}) async {
    if (_driver == null) return;
    if (reset) _compatibles = [];
    try {
      final String? city = _driver!['city'] as String?;
      final String vpref = (_driver!['vehicle_pref'] as String?) ?? 'car';
      if (city == null || city.isEmpty) {
        setState(() => _compatibles = []);
        return;
      }

      final rows = await _sb
          .from('courses')
          .select(
              'id, city, vehicle, depart_label, arrivee_label, depart_lat, depart_lng, arrivee_lat, arrivee_lng, distance_km, price_estimated, created_at')
          .eq('status', 'pending')
          .eq('city', city)
          .eq('vehicle', vpref)
          .order('created_at', ascending: false)
          .limit(30);

      if (!mounted) return;
      _compatibles = (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement demandes: $e')),
      );
    }
  }

  Future<void> _loadActives() async {
    if (_driver == null) return;
    try {
      final me = _chauffeurId;
      final rows = await _sb
          .from('courses')
          .select(
              'id, status, client_id, depart_label, arrivee_label, depart_lat, depart_lng, arrivee_lat, arrivee_lng, price_final, created_at')
          .eq('chauffeur_id', me)
          .inFilter('status', ['accepted', 'en_route'])
          .order('created_at', ascending: false);

      if (!mounted) return;
      _actives = (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement courses actives: $e')),
      );
    }
  }

  void _subscribeStreams() {
    _chanCourses?.unsubscribe();
    _chanMyCourses?.unsubscribe();

    if (_driver == null) return;
    final String? city = _driver!['city'] as String?;
    final String vpref = (_driver!['vehicle_pref'] as String?) ?? 'car';
    if (city == null || city.isEmpty) return;

    _chanCourses = _sb.channel('new_courses_${city}_$vpref')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'courses',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'status',
          value: 'pending',
        ),
        callback: (payload) {
          final r = Map<String, dynamic>.from(payload.newRecord);
          if (r['city'] == city && r['vehicle'] == vpref) {
            setState(() => _compatibles.insert(0, r));
          }
        },
      )
      ..subscribe();

    _chanMyCourses = _sb.channel('my_courses_$_chauffeurId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'courses',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'chauffeur_id',
          value: _chauffeurId,
        ),
        callback: (_) => _loadActives(),
      )
      ..subscribe();
  }

  Future<void> _proposerOffre(Map<String, dynamic> demande) async {
    final priceCtrl =
        TextEditingController(text: (demande['price_estimated'] ?? 0).toString());
    final etaCtrl = TextEditingController(text: '8');
    String? vehLabel;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Proposer une offre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Course: ${demande['depart_label'] ?? '-'} → ${demande['arrivee_label'] ?? '-'}'),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Prix proposé (GNF)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: etaCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Arrivée estimée (min)'),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => vehLabel = v,
              decoration:
                  const InputDecoration(labelText: 'Véhicule (ex: Toyota Corolla)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Envoyer')),
        ],
      ),
    );

    if (ok != true) return;

    final price = num.tryParse(priceCtrl.text.trim());
    final eta = int.tryParse(etaCtrl.text.trim());
    if (price == null || price <= 0 || eta == null || eta <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Valeurs invalides')));
      return;
    }

    try {
      await _sb.from('offres_course').insert({
        'course_id': demande['id'],
        'chauffeur_id': _chauffeurId,
        'price': price,
        'eta_min': eta,
        'vehicle_label': vehLabel,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Offre envoyée.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Échec envoi offre: $e')));
    }
  }

  Future<void> _refresh() async => _bootstrap();

  void _openSuivi(Map<String, dynamic> c) {
    final id = (c['id'] ?? '').toString();
    if (id.isEmpty) return;
    Navigator.pushNamed(context, AppRoutes.vtcSuivi, arguments: {'courseId': id});
  }

  // --- Helpers cartes ---
  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  ll.LatLng? _latLngFrom(dynamic lat, dynamic lng) {
    final la = _toDouble(lat);
    final lo = _toDouble(lng);
    if (la == null || lo == null) return null;
    return ll.LatLng(la, lo);
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);

    // Marqueurs sur carte (si une course active existe)
    final firstActive = _actives.isNotEmpty ? _actives.first : null;
    final d = _latLngFrom(firstActive?['depart_lat'], firstActive?['depart_lng']);
    final a = _latLngFrom(firstActive?['arrivee_lat'], firstActive?['arrivee_lng']);
    final center = d ?? a ?? const ll.LatLng(9.6412, -13.5784); // Conakry

    final markers = <Marker>[
      if (d != null)
        Marker(
          point: d,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_pin, size: 32, color: Colors.red),
        ),
      if (a != null)
        Marker(
          point: a,
          width: 40,
          height: 40,
          child: const Icon(Icons.flag, size: 28, color: Colors.green),
        ),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,

      // — Drawer: toutes les actions sont ici —
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(widget.currentUser.prenom ?? 'Chauffeur'),
                subtitle: const Text('Espace chauffeur'),
              ),
              const Divider(),
              SwitchListTile(
                secondary: const Icon(Icons.power_settings_new),
                title: Text(_isOnline ? 'En ligne' : 'Hors ligne'),
                value: _isOnline,
                onChanged: (v) => _toggleOnline(v),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Mes créneaux'),
                onTap: () => Navigator.pushNamed(context, AppRoutes.vtcCreneaux),
              ),
              ListTile(
                leading: const Icon(Icons.directions_car_filled),
                title: const Text('Mes véhicules'),
                onTap: () => Navigator.pushNamed(context, AppRoutes.vtcVehicules),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text('Portefeuille'),
                onTap: () => Navigator.pushNamed(context, AppRoutes.vtcPortefeuille),
              ),
              ListTile(
                leading: const Icon(Icons.payments),
                title: const Text('Paiements'),
                onTap: () => Navigator.pushNamed(context, AppRoutes.vtcPaiements),
              ),
              ListTile(
                leading: const Icon(Icons.price_change),
                title: const Text('Règles tarifaires'),
                onTap: () => Navigator.pushNamed(context, AppRoutes.vtcReglesTarifaires),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Se déconnecter'),
                onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
              ),
            ],
          ),
        ),
      ),

      body: Stack(
        children: [
          // --- Carte OSM plein écran ---
          Positioned.fill(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 13,
                      interactionOptions: const InteractionOptions(
                        flags: ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.example.ma_guinee',
                      ),
                      MarkerLayer(markers: markers),
                    ],
                  ),
          ),

          // --- Bouton menu (hamburger) ---
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              elevation: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.menu),
                ),
              ),
            ),
          ),

          // --- Statut en haut à droite ---
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _isOnline ? Colors.green.shade600 : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.1), blurRadius: 10)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_isOnline ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(_isOnline ? 'En ligne' : 'Hors ligne',
                      style:
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),

          // --- Panneau coulissant façon Uber ---
          DraggableScrollableSheet(
            initialChildSize: 0.18,
            minChildSize: 0.14,
            maxChildSize: 0.88,
            snap: true,
            builder: (context, controller) {
              return SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 20,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      // poignée « trois traits »
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 6),
                        child: Column(
                          children: [
                            _barHandle(),
                            const SizedBox(height: 3),
                            _barHandle(width: 36),
                            const SizedBox(height: 3),
                            _barHandle(width: 26),
                          ],
                        ),
                      ),
                      // Statut + switch compact
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.directions_car_filled, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isOnline
                                    ? 'Vous êtes en ligne — recevez des demandes'
                                    : 'Vous êtes hors ligne',
                                style: th.textTheme.bodyMedium,
                              ),
                            ),
                            Switch(
                              value: _isOnline,
                              onChanged: (v) => _toggleOnline(v),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 12),

                      // Liste scrollable
                      Expanded(
                        child: ListView(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: [
                            if ((_driver?['is_verified'] as bool?) != true)
                              Card(
                                color: Colors.amber.withOpacity(.15),
                                elevation: 0,
                                child: const ListTile(
                                  leading: Icon(Icons.verified_user_outlined),
                                  title: Text('Vérification en attente'),
                                  subtitle:
                                      Text("Votre compte chauffeur sera revu par l'équipe."),
                                ),
                              ),
                            const SizedBox(height: 8),

                            Text('Demandes compatibles',
                                style: th.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),

                            if (_compatibles.isEmpty)
                              const Card(
                                  child:
                                      ListTile(title: Text('Aucune demande pour l’instant')))
                            else
                              ..._compatibles.map(
                                (d) => Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                        color: th.dividerColor.withOpacity(.15)),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                        '${d['depart_label'] ?? '-'} → ${d['arrivee_label'] ?? '-'}'),
                                    subtitle: Text(
                                        '~${(d['distance_km'] ?? 0)} km • Estimé: ${d['price_estimated'] ?? '-'} GNF'),
                                    trailing: ElevatedButton(
                                      onPressed: () => _proposerOffre(d),
                                      child: const Text('Proposer'),
                                    ),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 14),
                            Text('Mes courses actives',
                                style: th.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),

                            if (_actives.isEmpty)
                              const Card(child: ListTile(title: Text('Aucune course active')))
                            else
                              ..._actives.map(
                                (c) => Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                        color: th.dividerColor.withOpacity(.15)),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                        '${c['depart_label'] ?? '-'} → ${c['arrivee_label'] ?? '-'}'),
                                    subtitle: Text('Statut: ${c['status']}'),
                                    trailing: ElevatedButton(
                                      onPressed: () => _openSuivi(c),
                                      child: const Text('Suivi'),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.center,
                              child: OutlinedButton.icon(
                                onPressed: _refresh,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Actualiser'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // --- Gros bouton Passer en ligne / Hors ligne ---
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: _isOnline ? Colors.redAccent : Colors.green.shade600,
                ),
                onPressed: () => _toggleOnline(!_isOnline),
                child: Text(
                  _isOnline ? 'Passer hors ligne' : 'Passer en ligne',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barHandle({double width = 48}) {
    return Container(
      width: width,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
