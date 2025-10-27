// lib/pages/billetterie/pro_inscription_organisateur_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProInscriptionOrganisateurPage extends StatefulWidget {
  const ProInscriptionOrganisateurPage({super.key});

  @override
  State<ProInscriptionOrganisateurPage> createState() => _ProInscriptionOrganisateurPageState();
}

class _ProInscriptionOrganisateurPageState extends State<ProInscriptionOrganisateurPage> {
  final _sb = Supabase.instance.client;
  final _form = GlobalKey<FormState>();

  final _nomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _emailProCtrl = TextEditingController();
  final _villeCtrl = TextEditingController(text: 'Conakry');
  final _descCtrl = TextEditingController();

  bool _sending = false;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _emailProCtrl.dispose();
    _villeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    final user = _sb.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await _sb.from('organisateurs').insert({
        'user_id': user.id,
        'nom_structure': _nomCtrl.text.trim(),
        'telephone': _telCtrl.text.trim(),
        'email_pro': _emailProCtrl.text.trim().isEmpty ? null : _emailProCtrl.text.trim(),
        'ville': _villeCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'verifie': false, // par défaut
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil organisateur créé !')),
      );
      Navigator.pop(context, true); // renvoie "created = true"
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        title: const Text('Devenir organisateur'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Créez votre profil organisateur pour publier vos événements.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nomCtrl,
                decoration: const InputDecoration(labelText: 'Nom de la structure *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _telCtrl,
                decoration: const InputDecoration(labelText: 'Téléphone *'),
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _emailProCtrl,
                decoration: const InputDecoration(labelText: 'Email professionnel'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _villeCtrl,
                decoration: const InputDecoration(labelText: 'Ville'),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description (facultatif)'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _sending ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Créer mon profil organisateur'),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF7F7F7),
    );
  }
}
