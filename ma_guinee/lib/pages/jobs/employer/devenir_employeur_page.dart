// lib/pages/jobs/employer/devenir_employeur_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mes_offres_page.dart';
import 'package:ma_guinee/services/employeur_service.dart';

class DevenirEmployeurPage extends StatefulWidget {
  const DevenirEmployeurPage({super.key});

  @override
  State<DevenirEmployeurPage> createState() => _DevenirEmployeurPageState();
}

class _DevenirEmployeurPageState extends State<DevenirEmployeurPage> {
  // Palette Home Jobs
  static const kBlue = Color(0xFF1976D2);
  static const kBg = Color(0xFFF6F7F9);
  static const kRed = Color(0xFFCE1126);
  static const kYellow = Color(0xFFFCD116);
  static const kGreen = Color(0xFF009460);

  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _villeCtrl = TextEditingController();
  final _communeCtrl = TextEditingController();
  final _secteurCtrl = TextEditingController();
  bool _loading = false;

  final _svc = EmployeurService();

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _villeCtrl.dispose();
    _communeCtrl.dispose();
    _secteurCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: kBlue),
      border: const OutlineInputBorder(),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: kBlue, width: 2),
      ),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black12, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // Crée ou récupère l’employeur et retourne son ID
      final id = await _svc.ensureEmployeurId(
        nom: _nomCtrl.text.trim(),
        telephone: _telCtrl.text.trim(),
        ville: _villeCtrl.text.trim(),
        commune: _communeCtrl.text.trim(),
        secteur: _secteurCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Espace employeur prêt !')),
      );

      // Redirection en fournissant l’employeurId
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => MesOffresPage(employeurId: id)),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Création impossible : $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: .5,
        title: const Text('Devenir employeur'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Petite carte intro
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.business_center, color: kBlue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Créez votre espace pour publier des offres et gérer les candidatures.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Formulaire
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nomCtrl,
                    decoration:
                        _dec('Nom de l’entreprise', Icons.apartment),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telCtrl,
                    decoration: _dec('Téléphone', Icons.phone),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _villeCtrl,
                    decoration: _dec('Ville', Icons.location_city),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _communeCtrl,
                    decoration: _dec('Commune', Icons.location_on),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _secteurCtrl,
                    decoration: _dec('Secteur', Icons.category),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: kBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Créer mon espace'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Astuce : vous pourrez compléter (logo, adresse, site web) plus tard.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _HelpChip(
                    icon: Icons.verified,
                    text: 'Publication rapide',
                    color: kGreen),
                _HelpChip(
                    icon: Icons.visibility,
                    text: 'Visibilité locale',
                    color: kYellow),
                _HelpChip(
                    icon: Icons.security,
                    text: 'Accès sécurisé',
                    color: kRed),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpChip extends StatelessWidget {
  const _HelpChip(
      {required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: StadiumBorder(side: BorderSide(color: color.withOpacity(.35))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(text),
          ],
        ),
      ),
    );
  }
}
