import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../models/utilisateur_model.dart';
import '../../routes.dart';

/// Accueil VTC CHAUFFEUR – adapté au schéma FR (courses.*)
class HomeChauffeurVtcPage extends StatefulWidget {
  final UtilisateurModel currentUser;
  const HomeChauffeurVtcPage({super.key, required this.currentUser});

  @override
  State<HomeChauffeurVtcPage> createState() => _HomeChauffeurVtcPageState();
}

class _HomeChauffeurVtcPageState extends State<HomeChauffeurVtcPage>
    with SingleTickerProviderStateMixin {
  final _sb = Supabase.instance.client;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, dynamic>? _driver; // ligne 'chauffeurs'
  List<Map<String, dynamic>> _compatibles = [];
  List<Map<String, dynamic>> _actives = [];
  bool _loading = true;
  bool _isOnline = false;
  num _todayEarnings = 0;

  RealtimeChannel? _chanCourses;
  RealtimeChannel? _chanMyCourses;

  // Palette
  static const kRed = Color(0xFFE73B2E);
  static const kYellow = Color(0xFFFFD400);
  static const kGreen = Color(0xFF1BAA5C);
  static const kGoIdle = Color(0xFF2979FF);
  static const kGoActive = Color(0xFFE53935);

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  String get _chauffeurId {
    final v = (_driver?['id'] ?? _driver?['user_id']) as String?;
    return v ?? widget.currentUser.id;
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _bootstrap();
  }

  @override
  void dispose() {
    _chanCourses?.unsubscribe();
    _chanMyCourses?.unsubscribe();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      await _loadDriver();
      if (!mounted || _driver == null) return;
      await Future.wait([
        _loadCompatibles(reset: true),
        _loadActives(),
        _loadTodayEarnings(),
      ]);
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
      _driver = Map<String, dynamic>.from(row);
      _isOnline = (_driver?['is_online'] as bool?) ?? false;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur profil chauffeur: $e')));
    }
  }

  // Somme des prix des courses déposées aujourd’hui
  Future<void> _loadTodayEarnings() async {
    try {
      final today = DateTime.now().toUtc();
      final dayStartIso = DateTime.utc(today.year, today.month, today.day).toIso8601String();

      final resp = await _sb
          .from('courses')
          .select('prix_gnf, depose_a, chauffeur_id, statut')
          .eq('chauffeur_id', _chauffeurId)
          .not('depose_a', 'is', null)
          .gte('depose_a', dayStartIso)
          .limit(500);

      num sum = 0;
      for (final e in (resp as List)) {
        final v = e['prix_gnf'];
        if (v is num) sum += v;
        else if (v != null) {
          final n = num.tryParse(v.toString());
          if (n != null) sum += n;
        }
      }
      if (!mounted) return;
      setState(() => _todayEarnings = sum);
    } catch (_) {/* silencieux */}
  }

  Future<void> _toggleOnline(bool v) async {
    if (_driver == null) return;
    try {
      await _sb.from('chauffeurs').update({'is_online': v}).eq('id', _chauffeurId);
      if (!mounted) return;
      setState(() => _isOnline = v);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Échec mise en ligne: $e')));
    }
  }

  // Demandes compatibles = toutes en attente (tu peux ajouter un filtre géographique plus tard)
  Future<void> _loadCompatibles({bool reset = false}) async {
    if (_driver == null) return;
    if (reset) _compatibles = [];
    try {
      final rows = await _sb
          .from('courses')
          .select('id, depart_adresse, arrivee_adresse, depart_point, arrivee_point, distance_metres, prix_gnf, demande_a, statut')
          .eq('statut', 'en_attente')
          .order('demande_a', ascending: false)
          .limit(30);

      if (!mounted) return;
      _compatibles = (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur chargement demandes: $e')));
    }
  }

  // Courses actives du chauffeur = statut non terminé/annulé
  Future<void> _loadActives() async {
    if (_driver == null) return;
    try {
      final me = _chauffeurId;
      final rows = await _sb
          .from('courses')
          .select('id, statut, client_id, depart_adresse, arrivee_adresse, depart_point, arrivee_point, prix_gnf, demande_a, annulee_a, depose_a')
          .eq('chauffeur_id', me)
          .not('statut', 'in', '("terminee","annulee")')
          .order('demande_a', ascending: false);

      if (!mounted) return;
      _actives = (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur chargement courses actives: $e')));
    }
  }

  // Temps réel: nouvelles demandes en attente
  void _subscribeStreams() {
    _chanCourses?.unsubscribe();
    _chanMyCourses?.unsubscribe();

    if (_driver == null) return;

    _chanCourses = _sb.channel('new_courses_en_attente')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'courses',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'statut',
          value: 'en_attente',
        ),
        callback: (payload) {
          final r = Map<String, dynamic>.from(payload.newRecord);
          setState(() => _compatibles.insert(0, r));
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
        callback: (_) {
          _loadActives();
          _loadTodayEarnings();
        },
      )
      ..subscribe();
  }

  // Offre – garde les noms génériques; ajuste si ta table diffère
  Future<void> _proposerOffre(Map<String, dynamic> demande) async {
    final priceCtrl =
        TextEditingController(text: (demande['prix_gnf'] ?? 0).toString());
    final etaCtrl = TextEditingController(text: '8');
    String? vehLabel;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Proposer une offre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Course: ${demande['depart_adresse'] ?? '-'} → ${demande['arrivee_adresse'] ?? '-'}'),
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
              decoration: const InputDecoration(labelText: 'Véhicule (ex: Toyota Corolla)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Envoyer')),
        ],
      ),
    );

    if (ok == true) {
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
          // adapte ces noms de colonnes si ton schéma diffère
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
  }

  Future<void> _refresh() async => _bootstrap();

  void _openSuivi(Map<String, dynamic> c) {
    final id = (c['id'] ?? '').toString();
    if (id.isEmpty) return;
    Navigator.pushNamed(context, AppRoutes.vtcSuivi, arguments: {'courseId': id});
  }

  // ---------- Helpers géométrie / formats ----------
  ll.LatLng? _latLngFromPoint(dynamic point) {
    try {
      if (point is Map && point['type'] == 'Point') {
        final coords = point['coordinates'];
        if (coords is List && coords.length >= 2) {
          final lon = (coords[0] as num).toDouble();
          final lat = (coords[1] as num).toDouble();
          return ll.LatLng(lat, lon);
        }
      }
    } catch (_) {}
    return null;
  }

  String _fmtGNF(num v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final remain = s.length - i - 1;
      buf.write(s[i]);
      if (remain > 0 && remain % 3 == 0) buf.write(' ');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);

    final firstActive = _actives.isNotEmpty ? _actives.first : null;
    final d = _latLngFromPoint(firstActive?['depart_point']);
    final a = _latLngFromPoint(firstActive?['arrivee_point']);
    final center = d ?? a ?? const ll.LatLng(9.6412, -13.5784); // Conakry

    final markers = <Marker>[
      if (d != null)
        Marker(
          point: d,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_pin, size: 32, color: kRed),
        ),
      if (a != null)
        Marker(
          point: a,
          width: 40,
          height: 40,
          child: const Icon(Icons.flag, size: 28, color: kGreen),
        ),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,

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
          // Carte OSM
          Positioned.fill(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 12.0,
                      interactionOptions: const InteractionOptions(
                        flags: ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.ma_guinee.app',
                        retinaMode: true,
                      ),
                      MarkerLayer(markers: markers),
                    ],
                  ),
          ),

          // Top bar: menu + gains
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _glassButton(
                  child: const Icon(Icons.menu),
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const Spacer(),
                _earningsPill(_todayEarnings),
              ],
            ),
          ),

          // Panneau coulissant
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
                        color: Colors.black.withOpacity(.10),
                        blurRadius: 20,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      // poignée néon
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 10),
                        child: Container(
                          width: 82,
                          height: 10,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            gradient: const LinearGradient(
                              colors: [kRed, kYellow, kGreen],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: kGreen.withOpacity(.35),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Statut + switch
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
                            Switch(value: _isOnline, onChanged: (v) => _toggleOnline(v)),
                          ],
                        ),
                      ),
                      const Divider(height: 12),

                      Expanded(
                        child: ListView(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: [
                            if ((_driver?['is_verified'] as bool?) != true)
                              Card(
                                elevation: 0,
                                color: Colors.amber.withOpacity(.15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const ListTile(
                                  leading: Icon(Icons.verified_user_outlined),
                                  title: Text('Vérification en attente'),
                                  subtitle: Text("Votre compte chauffeur sera revu par l'équipe."),
                                ),
                              ),
                            const SizedBox(height: 8),

                            Text('Demandes compatibles',
                                style: th.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            if (_compatibles.isEmpty)
                              const Card(
                                elevation: 0,
                                child: ListTile(title: Text('Aucune demande pour l’instant')),
                              )
                            else
                              ..._compatibles.map((d) {
                                final km = ((d['distance_metres'] ?? 0) as num).toDouble() / 1000.0;
                                final prix = d['prix_gnf'];
                                return _dCard(
                                  title:
                                      '${d['depart_adresse'] ?? '-'} → ${d['arrivee_adresse'] ?? '-'}',
                                  subtitle:
                                      '~${km.toStringAsFixed(2)} km • Estimé: ${prix != null ? _fmtGNF((prix as num)) : '-'} GNF',
                                  actionLabel: 'Proposer',
                                  onAction: () => _proposerOffre(d),
                                );
                              }),

                            const SizedBox(height: 14),
                            Text('Mes courses actives',
                                style: th.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            if (_actives.isEmpty)
                              const Card(
                                elevation: 0,
                                child: ListTile(title: Text('Aucune course active')),
                              )
                            else
                              ..._actives.map((c) => _dCard(
                                    title:
                                        '${c['depart_adresse'] ?? '-'} → ${c['arrivee_adresse'] ?? '-'}',
                                    subtitle: 'Statut: ${c['statut']}',
                                    actionLabel: 'Suivi',
                                    onAction: () => _openSuivi(c),
                                  )),
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

          // Bouton "GO" (toggle en ligne)
          Positioned(
            bottom: 128,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => _toggleOnline(!_isOnline),
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final t = _pulse.value; // 0..1
                    final color = _isOnline ? kGoActive : kGoIdle;
                    final scale = 1.0 + (t * 0.04);
                    final blur = 18 + (t * 14);
                    final spread = 4 + (t * 4);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isOnline
                                ? [kGoActive, Colors.deepOrange]
                                : [kGoIdle, Colors.lightBlueAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(.55),
                              blurRadius: blur,
                              spreadRadius: spread,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'GO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            shadows: [Shadow(color: Colors.white, blurRadius: 18)],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- UI helpers ----------
  Widget _dCard({
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.withOpacity(.15)),
      ),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
      ),
    );
  }

  Widget _earningsPill(num gnf) {
    final text = '${_fmtGNF(gnf)} GNF';
    return _glassCapsule(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _glassButton({required Widget child, required VoidCallback onTap}) {
    return _glassCapsule(
      padding: const EdgeInsets.all(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }

  Widget _glassCapsule({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(.6), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.08),
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
