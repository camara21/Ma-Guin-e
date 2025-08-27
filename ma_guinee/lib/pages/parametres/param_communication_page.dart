import 'package:flutter/material.dart';

class ParamCommunicationPage extends StatefulWidget {
  const ParamCommunicationPage({super.key});

  @override
  State<ParamCommunicationPage> createState() => _ParamCommunicationPageState();
}

class _ParamCommunicationPageState extends State<ParamCommunicationPage> {
  bool _push = true;
  bool _promos = false;
  bool _calls = true;
  String _lang = 'fr'; // fr, en, ar, ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Communication')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Notifications push'),
            value: _push,
            onChanged: (v) => setState(() => _push = v),
          ),
          SwitchListTile(
            title: const Text('Promotions et offres'),
            value: _promos,
            onChanged: (v) => setState(() => _promos = v),
          ),
          SwitchListTile(
            title: const Text('Appels clients (dans l’app)'),
            value: _calls,
            onChanged: (v) => setState(() => _calls = v),
          ),
          const Divider(),
          ListTile(
            title: const Text('Langue'),
            trailing: DropdownButton<String>(
              value: _lang,
              items: const [
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'ar', child: Text('العربية')),
              ],
              onChanged: (v) => setState(() => _lang = v!),
            ),
          ),
        ],
      ),
    );
  }
}
