// lib/wontanara/pages/page_carte.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:ionicons/ionicons.dart';
import 'package:latlong2/latlong.dart';

import '../theme_wontanara.dart';

// Types d'éléments sur la carte
enum CarteType { info, alerte, entraide, collecte, vote }

class PageCarte extends StatefulWidget {
  const PageCarte({super.key});

  @override
  State<PageCarte> createState() => _PageCarteState();
}

class _PageCarteState extends State<PageCarte> {
  // Vue carte
  bool _satellite = false;

  // Filtres zone
  String? _region = 'Guinée entière';
  String? _prefecture;
  String? _quartier;

  // 🔹 Maquette : quelques points sur la Guinée
  final List<_CarteItem> _items = [
    _CarteItem(
      id: 'A1',
      type: CarteType.alerte,
      titre: 'Panne de courant',
      description: 'Quartier Kipé • coupure depuis 2 h',
      position: LatLng(9.565, -13.673), // Conakry
    ),
    _CarteItem(
      id: 'A2',
      type: CarteType.alerte,
      titre: 'Inondation sur la route',
      description: 'Route Le Prince • circulation difficile',
      position: LatLng(9.63, -13.58),
    ),
    _CarteItem(
      id: 'E1',
      type: CarteType.entraide,
      titre: 'Besoin de bénévoles pour nettoyage',
      description: 'Plage de Rogbane • samedi 9h',
      position: LatLng(9.65, -13.57),
    ),
    _CarteItem(
      id: 'E2',
      type: CarteType.entraide,
      titre: 'Aide alimentaire',
      description: 'Quartier Nongo • famille en difficulté',
      position: LatLng(9.64, -13.63),
    ),
  ];

  // Exemple de listes pour maquette des filtres
  final List<String> _regions = [
    'Guinée entière',
    'Conakry',
    'Kindia',
    'Labé',
  ];

  final Map<String, List<String>> _prefecturesParRegion = {
    'Conakry': ['Toutes les préfectures', 'Dixinn', 'Ratoma', 'Kaloum'],
    'Kindia': ['Toutes les préfectures', 'Kindia-centre', 'Télimélé'],
    'Labé': ['Toutes les préfectures', 'Labé-ville', 'Mali'],
  };

  // Pour l’instant on ne filtre pas les points par zone (maquette),
  // mais on pourra le faire quand on aura les vraies données Supabase.
  List<_CarteItem> get _visibleItems => _items;

  void _openItemDetails(_CarteItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _typeIcon(item.type, big: true),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.titre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: ThemeWontanara.vertPetrole,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ThemeWontanara.texte2,
                  ),
                ),
                const SizedBox(height: 16),
                if (item.type == CarteType.entraide) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO : ouvrir mini-chat / contact
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.volunteer_activism_rounded),
                      label: const Text('Proposer mon aide'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeWontanara.vertPetrole,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO : suivre l’alerte / recevoir des notifs
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Suivre cette alerte'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ThemeWontanara.vertPetrole,
                        side: const BorderSide(
                            color: ThemeWontanara.vertPetrole, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openZoneFilterSheet() {
    String? region = _region;
    String? prefecture = _prefecture;
    String? quartier = _quartier;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setModalState) {
            final prefs = (region != null &&
                    region != 'Guinée entière' &&
                    _prefecturesParRegion[region] != null)
                ? _prefecturesParRegion[region]!
                : <String>['Toutes les préfectures'];

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Filtrer la zone',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: ThemeWontanara.vertPetrole,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: region,
                      decoration: _dropdownDecoration('Région'),
                      items: _regions
                          .map(
                              (r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (val) {
                        setModalState(() {
                          region = val;
                          prefecture = null;
                          quartier = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: prefecture,
                      decoration: _dropdownDecoration('Préfecture'),
                      items: prefs
                          .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (val) {
                        setModalState(() {
                          prefecture = val;
                          quartier = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: _dropdownDecoration('Quartier').copyWith(
                        hintText: 'Ex : Kipé, Nongo…',
                      ),
                      onChanged: (val) {
                        quartier = val.isEmpty ? null : val;
                      },
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _region = region;
                            _prefecture = prefecture;
                            _quartier = quartier;
                          });
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeWontanara.vertPetrole,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Appliquer',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Centre approximatif de la Guinée
    const centerGuinee = LatLng(10.8, -10.8);

    final viewLabel = _satellite ? 'Satellite' : 'Plan';

    String zoneLabel = _region ?? 'Guinée entière';
    if (_prefecture != null && _prefecture!.isNotEmpty) {
      zoneLabel += ' • $_prefecture';
    }
    if (_quartier != null && _quartier!.isNotEmpty) {
      zoneLabel += ' • $_quartier';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: ThemeWontanara.texte,
        title: const Text(
          'Carte communautaire',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: ThemeWontanara.menthe,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: FlutterMap(
                        options: const MapOptions(
                          initialCenter: centerGuinee,
                          initialZoom: 6.0,
                          minZoom: 5.0,
                          maxZoom: 16.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: _satellite
                                // 💡 Pour la prod : vérifier les CGU de ce fournisseur
                                ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                                : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: _satellite
                                ? const <String>[]
                                : const ['a', 'b', 'c'],
                            userAgentPackageName: 'com.soneya.ma_guinee',
                          ),
                          MarkerLayer(
                            markers: _visibleItems
                                .map(
                                  (item) => Marker(
                                    point: item.position,
                                    width: 60,
                                    height: 60,
                                    alignment: Alignment.center,
                                    child: GestureDetector(
                                      onTap: () => _openItemDetails(item),
                                      child: _MapMarker(type: item.type),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),

                    // ------- Filtre zone (dans la carte) -------
                    Positioned(
                      left: 12,
                      right: 80,
                      top: 12,
                      child: GestureDetector(
                        onTap: _openZoneFilterSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color: ThemeWontanara.vertPetrole,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  zoneLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: ThemeWontanara.texte,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: ThemeWontanara.texte2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ------- Bouton vue plan / satellite -------
                    Positioned(
                      right: 12,
                      top: 12,
                      child: InkWell(
                        onTap: () {
                          setState(() => _satellite = !_satellite);
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _satellite
                                    ? Icons.satellite_alt_outlined
                                    : Icons.map_outlined,
                                size: 18,
                                color: ThemeWontanara.vertPetrole,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                viewLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: ThemeWontanara.vertPetrole,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// Modèle interne pour les points de carte
// =====================================================

class _CarteItem {
  final String id;
  final CarteType type;
  final String titre;
  final String description;
  final LatLng position;

  _CarteItem({
    required this.id,
    required this.type,
    required this.titre,
    required this.description,
    required this.position,
  });
}

// Petit widget utilitaire pour l’icône selon le type
Widget _typeIcon(CarteType type, {bool big = false}) {
  IconData icon;
  Color color;
  switch (type) {
    case CarteType.alerte:
      icon = Ionicons.warning_outline;
      color = Colors.orange;
      break;
    case CarteType.entraide:
      icon = Ionicons.heart_outline;
      color = Colors.pinkAccent;
      break;
    case CarteType.collecte:
      icon = Ionicons.refresh_outline;
      color = Colors.green;
      break;
    case CarteType.vote:
      icon = Icons.how_to_vote;
      color = ThemeWontanara.vertPetrole;
      break;
    case CarteType.info:
    default:
      icon = Ionicons.information_circle_outline;
      color = ThemeWontanara.vertPetrole;
  }

  return CircleAvatar(
    radius: big ? 20 : 16,
    backgroundColor: color.withOpacity(.1),
    child: Icon(icon, size: big ? 20 : 18, color: color),
  );
}

// Marqueur visuel sur la carte
class _MapMarker extends StatelessWidget {
  final CarteType type;

  const _MapMarker({required this.type});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _typeIcon(type),
        const SizedBox(height: 2),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

InputDecoration _dropdownDecoration(String label) {
  return InputDecoration(
    labelText: label,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}
