import 'package:flutter/material.dart';

class ParamSonVoixPage extends StatefulWidget {
  const ParamSonVoixPage({super.key});

  @override
  State<ParamSonVoixPage> createState() => _ParamSonVoixPageState();
}

class _ParamSonVoixPageState extends State<ParamSonVoixPage> {
  bool _voiceGuidance = true;
  bool _beepNewRide = true;
  bool _vibrate = true;
  double _volume = 0.8; // 0..1

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Son & voix')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Instructions vocales'),
            value: _voiceGuidance,
            onChanged: (v) => setState(() => _voiceGuidance = v),
          ),
          SwitchListTile(
            title: const Text('Bip nouvelle demande'),
            value: _beepNewRide,
            onChanged: (v) => setState(() => _beepNewRide = v),
          ),
          SwitchListTile(
            title: const Text('Vibration'),
            value: _vibrate,
            onChanged: (v) => setState(() => _vibrate = v),
          ),
          ListTile(
            title: const Text('Volume'),
            subtitle: Slider(
              value: _volume,
              onChanged: (v) => setState(() => _volume = v),
            ),
            trailing: Text('${(_volume * 100).round()} %'),
          ),
        ],
      ),
    );
  }
}
