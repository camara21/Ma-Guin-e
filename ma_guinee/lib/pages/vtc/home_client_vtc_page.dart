import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/utilisateur_model.dart';

// --- enums au top-level ---
enum TargetField { depart, arrivee }
enum _BottomTab { profil, historique, paiement }

class HomeClientVtcPage extends StatefulWidget {
  final UtilisateurModel currentUser;
  const HomeClientVtcPage({super.key, required this.currentUser});

  @override
  State<HomeClientVtcPage> createState() => _HomeClientVtcPageState();
}

class _HomeClientVtcPageState extends State<HomeClientVtcPage>
    with SingleTickerProviderStateMixin {
  final _sb = Supabase.instance.client;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // --- Map ---
  final MapController _map = MapController();
  ll.LatLng _center = const ll.LatLng(9.6412, -13.5784); // Conakry
  double _zoom = 14;

  // --- Points & libellés ---
  ll.LatLng? _depart;
  String? _departLabel;
  ll.LatLng? _arrivee;
  String? _arriveeLabel;

  // Champ actif
  TargetField _target = TargetField.depart;

  // saisie
  final _departCtrl = TextEditingController();
  final _arriveeCtrl = TextEditingController();

  // style
  static const kRed = Color(0xFFE73B2E);
  static const kYellow = Color(0xFFFFD400);
  static const kGreen = Color(0xFF1BAA5C);
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  bool _loading = false;

  // --- Données profil / paiements ---
  late UtilisateurModel _user; // copie locale
  List<Map<String, dynamic>> _lastPayments = [];
  bool _loadingPayments = false;

  // --- Historique (dock) ---
  List<Map<String, dynamic>> _recent = [];
  bool _loadingRecent = false;

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _center = const ll.LatLng(9.6412, -13.5784);
    _zoom = 13;

    _loadRecent();
    _refreshUserFromSupabase();
    _loadLastPayments();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _departCtrl.dispose();
    _arriveeCtrl.dispose();
    super.dispose();
  }

  // ---------- Profil (récup depuis Supabase) ----------
  Future<void> _refreshUserFromSupabase() async {
    try {
      Map<String, dynamic>? row;

      // profiles si dispo
      try {
        final r = await _sb
            .from('profiles')
            .select('id, nom, prenom, email, telephone, photo_url, pays, genre')
            .eq('id', widget.currentUser.id)
            .maybeSingle();
        if (r != null) row = Map<String, dynamic>.from(r);
      } catch (_) {}

      // fallback: utilisateurs
      if (row == null) {
        final r = await _sb
            .from('utilisateurs')
            .select('id, nom, prenom, email, telephone, photo_url, pays, genre')
            .eq('id', widget.currentUser.id)
            .maybeSingle();
        if (r != null) row = Map<String, dynamic>.from(r);
      }

      if (!mounted || row == null) return;

      final m = Map<String, dynamic>.from(row);

      setState(() {
        _user = UtilisateurModel(
          id: (m['id']?.toString() ?? widget.currentUser.id),
          nom: (m['nom']?.toString() ?? ''),
          prenom: (m['prenom']?.toString() ?? ''),
          email: (m['email']?.toString() ?? ''),
          telephone: (m['telephone']?.toString() ?? ''),
          photoUrl: m['photo_url']?.toString(),
          pays: (m['pays']?.toString() ?? widget.currentUser.pays ?? 'GN'),
          genre: (m['genre']?.toString() ?? 'autre'),
        );
      });
    } catch (_) {/* silencieux */}
  }

  // ---------- Paiements (derniers paiements de l’utilisateur) ----------
  Future<void> _loadLastPayments() async {
    setState(() => _loadingPayments = true);
    try {
      // 5 derniers paiements liés à des courses de ce client
      final rows = await _sb
          .from('paiements')
          .select(
              'id, amount_gnf, moyen, statut, created_at, ride_id, courses!inner(client_id)')
          .eq('courses.client_id', widget.currentUser.id)
          .order('created_at', ascending: false)
          .limit(5);

      _lastPayments =
          (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      _lastPayments = [];
    } finally {
      if (mounted) setState(() => _loadingPayments = false);
    }
  }

  // ---------- Historique ----------
  Future<void> _loadRecent() async {
    setState(() => _loadingRecent = true);
    try {
      final rows = await _sb
          .from('courses')
          .select(
              'id,statut,prix_gnf,depart_adresse,arrivee_adresse,demande_a')
          .eq('client_id', widget.currentUser.id)
          .order('demande_a', ascending: false)
          .limit(10);
      _recent =
          (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      // silencieux
    } finally {
      if (mounted) setState(() => _loadingRecent = false);
    }
  }

  // ---------- Recherche lieux ----------
  Future<List<_Lieu>> _searchLieux(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final rows = await _sb
          .from('lieux')
          .select('id, name, type, city, commune, lat, lng')
          .ilike('name', '%$q%')
          .limit(15);
      return (rows as List)
          .map((e) => _Lieu.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<_Lieu>> _smartSuggestions(String query) async {
    final out = <_Lieu>[];
    out.addAll(await _searchLieux(query));
    if (out.length < 6 && query.length >= 2) {
      try {
        final more = await _sb
            .from('lieux')
            .select('id, name, type, city, commune, lat, lng')
            .or('type.eq.ville,type.eq.commune')
            .ilike('name', '%$query%')
            .limit(10);
        out.addAll((more as List)
            .map((e) => _Lieu.fromMap(Map<String, dynamic>.from(e))));
      } catch (_) {}
    }
    final seen = <String>{};
    return out
        .where((e) => seen.add('${e.name}-${e.lat}-${e.lng}-${e.type}'))
        .toList();
  }

  // ---------- Actions ----------
  Future<void> _myLocation() async {
    try {
      final ok = await Geolocator.requestPermission();
      if (ok == LocationPermission.deniedForever ||
          ok == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Active la localisation dans les réglages.')),
        );
        return;
      }
      final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
      final me = ll.LatLng(p.latitude, p.longitude);
      setState(() {
        _center = me;
        _zoom = 16;
        if (_target == TargetField.depart) {
          _depart = me;
          _departLabel ??= 'Ma position';
          _departCtrl.text = _departLabel!;
        } else {
          _arrivee = me;
          _arriveeLabel ??= 'Ma position';
          _arriveeCtrl.text = _arriveeLabel!;
        }
      });
      _map.move(me, _zoom);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Position indisponible: $e')),
      );
    }
  }

  void _swap() {
    setState(() {
      final tPoint = _depart;
      final tLabel = _departLabel;
      _depart = _arrivee;
      _departLabel = _arriveeLabel;
      _arrivee = tPoint;
      _arriveeLabel = tLabel;

      final tText = _departCtrl.text;
      _departCtrl.text = _arriveeCtrl.text;
      _arriveeCtrl.text = tText;
    });
  }

  void _confirm() {
    if (_depart == null || _arrivee == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis le départ et l’arrivée.')),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      '/vtc/demande', // adapte si ta route diffère
      arguments: {
        'vehicle': 'car',
        'depart_lat': _depart!.latitude,
        'depart_lng': _depart!.longitude,
        'arrivee_lat': _arrivee!.latitude,
        'arrivee_lng': _arrivee!.longitude,
        'depart_adresse': _departLabel ?? _departCtrl.text,
        'arrivee_adresse': _arriveeLabel ?? _arriveeCtrl.text,
      },
    );
  }

  void _commitCenterAsTarget() {
    setState(() {
      if (_target == TargetField.depart) {
        _depart = _center;
        _departLabel ??= 'Point de départ';
      } else {
        _arrivee = _center;
        _arriveeLabel ??= 'Point d’arrivée';
      }
    });
  }

  // ---------- Dock (sheet) ----------
  void _openDock(_BottomTab tab) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DockSheet(
        tab: tab,
        user: _user,
        recent: _recent,
        loadingRecent: _loadingRecent,
        loadingPayments: _loadingPayments,
        paymentMethods: _lastPayments,
        onRefreshProfile: _refreshUserFromSupabase,
        onRefreshHistory: _loadRecent,
        onRefreshPayments: _loadLastPayments,
        onEditProfile: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Brancher la page Profil ici.')),
          );
        },
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final padTop = MediaQuery.of(context).padding.top;
    final padBot = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Carte
          Positioned.fill(
            child: Listener(
              onPointerUp: (_) => _commitCenterAsTarget(),
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: _zoom,
                  interactionOptions: const InteractionOptions(
                    flags: ~InteractiveFlag.rotate,
                  ),
                  onPositionChanged: (pos, _) {
                    if (pos.center != null) {
                      _center = pos.center!;
                      _zoom = pos.zoom ?? _zoom;
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    retinaMode: true,
                    userAgentPackageName: 'com.ma_guinee.app',
                  ),
                  MarkerLayer(
                    markers: [
                      if (_depart != null)
                        Marker(
                          point: _depart!,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_pin,
                              color: kRed, size: 34),
                        ),
                      if (_arrivee != null)
                        Marker(
                          point: _arrivee!,
                          width: 40,
                          height: 40,
                          child:
                              const Icon(Icons.flag, color: kGreen, size: 30),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Épingle fantôme au centre
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, -6 + (_pulse.value * -2)),
                    child: Icon(
                      _target == TargetField.depart
                          ? Icons.place
                          : Icons.flag,
                      size: 34,
                      color: _target == TargetField.depart
                          ? kRed.withOpacity(.85)
                          : kGreen.withOpacity(.85),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Pills Départ / Arrivée
          Positioned(
            top: padTop + 10,
            left: 12,
            right: 12,
            child: Column(
              children: [
                _searchPill(
                  label: 'Départ',
                  controller: _departCtrl,
                  selected: _target == TargetField.depart,
                  onTap: () => setState(() => _target = TargetField.depart),
                  onSelected: (l) {
                    setState(() {
                      _depart = ll.LatLng(l.lat, l.lng);
                      _departLabel = l.fullLabel;
                      _departCtrl.text = l.fullLabel;
                    });
                    _map.move(_depart!, 16);
                  },
                ),
                const SizedBox(height: 8),
                _searchPill(
                  label: 'Arrivée',
                  controller: _arriveeCtrl,
                  selected: _target == TargetField.arrivee,
                  onTap: () => setState(() => _target = TargetField.arrivee),
                  onSelected: (l) {
                    setState(() {
                      _arrivee = ll.LatLng(l.lat, l.lng);
                      _arriveeLabel = l.fullLabel;
                      _arriveeCtrl.text = l.fullLabel;
                    });
                    _map.move(_arrivee!, 16);
                  },
                ),
              ],
            ),
          ),

          // Boutons flottants
          Positioned(
            right: 12,
            bottom: 170 + padBot,
            child: Column(
              children: [
                _roundGlass(icon: Icons.my_location, onTap: _myLocation),
                const SizedBox(height: 10),
                _roundGlass(icon: Icons.swap_vert_rounded, onTap: _swap),
              ],
            ),
          ),

          // Gros bouton CONFIRMER
          Positioned(
            left: 16,
            right: 16,
            bottom: 98 + padBot,
            child: SafeArea(
              top: false,
              child: GestureDetector(
                onTap: _loading ? null : _confirm,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0BA360), Color(0xFF3CBA92)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.15),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Text(
                    'CONFIRMER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Dock
          Positioned(
            left: 12,
            right: 12,
            bottom: 14 + padBot,
            child: _Glass(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _DockButton(
                      icon: Icons.person,
                      label: 'Moi',
                      onTap: () => _openDock(_BottomTab.profil),
                    ),
                    _DockDivider(),
                    _DockButton(
                      icon: Icons.history,
                      label: 'Historique',
                      onTap: () => _openDock(_BottomTab.historique),
                    ),
                    _DockDivider(),
                    _DockButton(
                      icon: Icons.account_balance_wallet,
                      label: 'Paiements',
                      onTap: () => _openDock(_BottomTab.paiement),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Menu
          Positioned(
            top: padTop + 12,
            left: 12,
            child: _roundGlass(
              icon: Icons.menu,
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Widgets ----------
  Widget _searchPill({
    required String label,
    required TextEditingController controller,
    required bool selected,
    required VoidCallback onTap,
    required void Function(_Lieu) onSelected,
  }) {
    return _Glass(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [kRed, kYellow, kGreen],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Icon(
                label == 'Départ' ? Icons.place : Icons.flag,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: onTap,
                child: TypeAheadField<_Lieu>(
                  hideOnEmpty: true,
                  hideOnUnfocus: true,
                  debounceDuration: const Duration(milliseconds: 220),
                  controller: controller,
                  suggestionsCallback: _smartSuggestions,
                  builder: (context, ctrl, focus) {
                    return TextField(
                      controller: ctrl,
                      focusNode: focus,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '… (quartier, carrefour, commune, ville)',
                        hintStyle: TextStyle(color: Colors.black54),
                      ),
                      onTap: onTap,
                      onChanged: (_) => onTap(),
                    );
                  },
                  itemBuilder: (context, _Lieu l) {
                    return ListTile(
                      title: Text(l.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(l.meta),
                    );
                  },
                  onSelected: onSelected,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: selected ? Colors.black : Colors.black26,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundGlass({required IconData icon, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withOpacity(.75),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Glass container ----------
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
            border:
                Border.all(color: Colors.white.withOpacity(0.5), width: 0.8),
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

// ---------- Dock widgets ----------
class _DockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DockButton(
      {required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _DockDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 26, color: Colors.black12);
  }
}

class _DockSheet extends StatelessWidget {
  final _BottomTab tab;
  final UtilisateurModel user;
  final List<Map<String, dynamic>> recent;
  final bool loadingRecent;

  final bool loadingPayments;
  final List<Map<String, dynamic>> paymentMethods; // ici = derniers paiements

  final Future<void> Function() onRefreshProfile;
  final Future<void> Function() onRefreshHistory;
  final Future<void> Function() onRefreshPayments;
  final VoidCallback onEditProfile;

  const _DockSheet({
    required this.tab,
    required this.user,
    required this.recent,
    required this.loadingRecent,
    required this.loadingPayments,
    required this.paymentMethods,
    required this.onRefreshProfile,
    required this.onRefreshHistory,
    required this.onRefreshPayments,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    final radius = const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    );
    return Material(
      shape: radius,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          color: Colors.white,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: _content(context),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    switch (tab) {
      case _BottomTab.profil:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text('Mon profil',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: 'Rafraîchir',
                  onPressed: onRefreshProfile,
                  icon: const Icon(Icons.refresh),
                )
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade100,
                child: const Icon(Icons.person, color: Colors.black87),
              ),
              title: Text(
                ('${user.prenom ?? ''} ${user.nom ?? ''}').trim().isEmpty
                    ? 'Client'
                    : '${user.prenom ?? ''} ${user.nom ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(user.email ?? user.telephone ?? '—'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.phone_iphone),
              title: const Text('Téléphone'),
              subtitle: Text(user.telephone ?? '—'),
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: Text(user.email ?? '—'),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Modifier mon profil'),
                onPressed: onEditProfile,
              ),
            ),
          ],
        );

      case _BottomTab.historique:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text('Historique récent',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  onPressed: onRefreshHistory,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualiser',
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (loadingRecent)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (recent.isEmpty)
              const Card(
                  child: ListTile(title: Text('Aucune course récente')))
            else
              ...recent.map((c) {
                final prix = c['prix_gnf'];
                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.local_taxi)),
                    title: Text(
                        '${c['depart_adresse'] ?? '-'} → ${c['arrivee_adresse'] ?? '-'}'),
                    subtitle: Text('Statut: ${c['statut']}'),
                    trailing: Text(prix != null ? '$prix GNF' : '—'),
                  ),
                );
              }),
          ],
        );

      case _BottomTab.paiement:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text('Paiements',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: 'Rafraîchir',
                  onPressed: onRefreshPayments,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (loadingPayments)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (paymentMethods.isEmpty)
              Card(
                elevation: 0,
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet),
                  title: const Text('Aucun paiement trouvé'),
                  subtitle: Text(
                    (user.telephone != null && user.telephone!.isNotEmpty)
                        ? 'Mobile Money suggéré • ${user.telephone}'
                        : 'Ajoute un moyen de paiement dans ton profil',
                  ),
                  trailing: const Text('—'),
                ),
              )
            else
              ...paymentMethods.map((m) {
                final moyen = (m['moyen'] ?? '').toString();
                final statut = (m['statut'] ?? '').toString();
                final amount = m['amount_gnf'];
                final createdAt = (m['created_at'] ?? '').toString();
                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text('${amount ?? '—'} GNF'),
                    subtitle: Text('$moyen • $statut\n$createdAt'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              }),
            const SizedBox(height: 8),
            const Text(
              'Astuce : lie Orange Money / MTN / Free pour payer plus vite.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        );
    }
  }

  Widget _sheetHandle() => Center(
        child: Container(
          width: 44,
          height: 5,
          margin: const EdgeInsets.only(top: 6, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
}

// ---------- Modèle lieu ----------
class _Lieu {
  final String id;
  final String name;
  final String type; // quartier / carrefour / commune / ville / lieu
  final String? city;
  final String? commune;
  final double lat;
  final double lng;

  _Lieu({
    required this.id,
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
    this.city,
    this.commune,
  });

  String get meta {
    final parts = <String>[];
    if (type.isNotEmpty) parts.add(type);
    if (commune != null && commune!.isNotEmpty) parts.add(commune!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    return parts.join(' • ');
  }

  String get fullLabel {
    final parts = <String>[name];
    if (commune != null && commune!.isNotEmpty) parts.add(commune!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    return parts.join(', ');
  }

  factory _Lieu.fromMap(Map<String, dynamic> m) => _Lieu(
        id: m['id'].toString(),
        name: m['name']?.toString() ?? '-',
        type: m['type']?.toString() ?? '',
        city: m['city']?.toString(),
        commune: m['commune']?.toString(),
        lat: (m['lat'] is num)
            ? (m['lat'] as num).toDouble()
            : double.parse(m['lat'].toString()),
        lng: (m['lng'] is num)
            ? (m['lng'] as num).toDouble()
            : double.parse(m['lng'].toString()),
      );
}
