import 'package:flutter/material.dart';

class ParamAProposPage extends StatelessWidget {
  const ParamAProposPage({super.key});

  @override
  Widget build(BuildContext context) {
    const appName = 'Soneya Driver';
    const version = '1.0.0';
    const buildNumber = '100';

    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.apps_rounded),
            title: Text(appName),
            subtitle: Text('Version $version ($buildNumber)'),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.description_rounded),
            title: Text("Conditions d’utilisation"),
            subtitle: Text('Lire les conditions'),
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip_rounded),
            title: Text('Politique de confidentialité'),
            subtitle: Text('Comment nous protégeons vos données'),
          ),
          ListTile(
            leading: Icon(Icons.support_agent_rounded),
            title: Text('Contacter le support'),
            subtitle: Text('support@soneya.app'),
          ),
        ],
      ),
    );
  }
}
