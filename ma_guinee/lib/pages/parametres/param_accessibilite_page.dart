import 'package:flutter/material.dart';

class ParamAccessibilitePage extends StatefulWidget {
  const ParamAccessibilitePage({super.key});

  @override
  State<ParamAccessibilitePage> createState() => _ParamAccessibilitePageState();
}

class _ParamAccessibilitePageState extends State<ParamAccessibilitePage> {
  double _textScale = 1.0; // 0.8 .. 1.6
  bool _highContrast = false;
  bool _reduceMotion = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accessibilité')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          ListTile(
            title: const Text('Taille du texte'),
            subtitle: Slider(
              min: 0.8,
              max: 1.6,
              divisions: 8,
              value: _textScale,
              label: '${(_textScale * 100).round()} %',
              onChanged: (v) => setState(() => _textScale = v),
            ),
            trailing: Text('${(_textScale * 100).round()} %'),
          ),
          SwitchListTile(
            title: const Text('Contraste élevé'),
            value: _highContrast,
            onChanged: (v) => setState(() => _highContrast = v),
          ),
          SwitchListTile(
            title: const Text('Réduire les animations'),
            value: _reduceMotion,
            onChanged: (v) => setState(() => _reduceMotion = v),
          ),
        ],
      ),
    );
  }
}
