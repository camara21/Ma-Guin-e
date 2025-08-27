import 'package:flutter/material.dart';

class ParamModeNuitPage extends StatefulWidget {
  const ParamModeNuitPage({super.key});

  @override
  State<ParamModeNuitPage> createState() => _ParamModeNuitPageState();
}

class _ParamModeNuitPageState extends State<ParamModeNuitPage> {
  String _theme = 'system'; // 'system' | 'light' | 'dark'
  bool _autoAtNight = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mode nuit')),
      body: ListView(
        children: [
          RadioListTile<String>(
            title: const Text('Suivre le système'),
            value: 'system',
            groupValue: _theme,
            onChanged: (v) => setState(() => _theme = v!),
          ),
          RadioListTile<String>(
            title: const Text('Toujours clair'),
            value: 'light',
            groupValue: _theme,
            onChanged: (v) => setState(() => _theme = v!),
          ),
          RadioListTile<String>(
            title: const Text('Toujours sombre'),
            value: 'dark',
            groupValue: _theme,
            onChanged: (v) => setState(() => _theme = v!),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Activer automatiquement la nuit'),
            subtitle: const Text('Selon l’heure/localisation'),
            value: _autoAtNight,
            onChanged: (v) => setState(() => _autoAtNight = v),
          ),
        ],
      ),
    );
  }
}
