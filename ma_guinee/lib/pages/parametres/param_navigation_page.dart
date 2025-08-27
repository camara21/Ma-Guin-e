import 'package:flutter/material.dart';

class ParamNavigationPage extends StatefulWidget {
  const ParamNavigationPage({super.key});

  @override
  State<ParamNavigationPage> createState() => _ParamNavigationPageState();
}

class _ParamNavigationPageState extends State<ParamNavigationPage> {
  String _appNav = 'osm'; // 'osm' | 'gmap' (d’autres plus tard)
  bool _avoidTolls = false;
  bool _avoidHighways = false;
  String _distanceUnit = 'km'; // 'km' | 'mi'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navigation')),
      body: ListView(
        children: [
          const _GroupHeader('Application de navigation'),
          RadioListTile<String>(
            title: const Text('Carte intégrée (OpenStreetMap)'),
            value: 'osm',
            groupValue: _appNav,
            onChanged: (v) => setState(() => _appNav = v!),
          ),
          RadioListTile<String>(
            title: const Text('Google Maps (ouvrir l’app)'),
            value: 'gmap',
            groupValue: _appNav,
            onChanged: (v) => setState(() => _appNav = v!),
          ),
          const Divider(height: 24),
          const _GroupHeader('Préférences d’itinéraire'),
          SwitchListTile(
            title: const Text('Éviter les péages'),
            value: _avoidTolls,
            onChanged: (v) => setState(() => _avoidTolls = v),
          ),
          SwitchListTile(
            title: const Text('Éviter les autoroutes'),
            value: _avoidHighways,
            onChanged: (v) => setState(() => _avoidHighways = v),
          ),
          const Divider(height: 24),
          const _GroupHeader('Unités'),
          ListTile(
            title: const Text('Unité de distance'),
            trailing: DropdownButton<String>(
              value: _distanceUnit,
              items: const [
                DropdownMenuItem(value: 'km', child: Text('Kilomètres (km)')),
                DropdownMenuItem(value: 'mi', child: Text('Miles (mi)')),
              ],
              onChanged: (v) => setState(() => _distanceUnit = v!),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String text;
  const _GroupHeader(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Colors.black54, letterSpacing: .2)),
      );
}
