// lib/pages/billetterie/pro_inscription_organisateur_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProInscriptionOrganisateurPage extends StatefulWidget {
  const ProInscriptionOrganisateurPage({super.key});

  @override
  State<ProInscriptionOrganisateurPage> createState() => _ProInscriptionOrganisateurPageState();
}

class _ProInscriptionOrganisateurPageState extends State<ProInscriptionOrganisateurPage> {
  final _sb = Supabase.instance.client;
  final _form = GlobalKey<FormState>();

  // Palette Billetterie
  static const _kEventPrimary = Color(0xFF7B2CBF);
  static const _kOnPrimary = Colors.white;

  // Champs
  final _nomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _emailProCtrl = TextEditingController();
  final _villeCtrl = TextEditingController(text: 'Conakry');
  final _descCtrl = TextEditingController();
  final _nifCtrl = TextEditingController();   // optionnel
  final _rccmCtrl = TextEditingController();  // optionnel

  bool _sending = false;

  // Pièces justificatives (images)
  final List<_DocPiece> _pieces = [];

  // Attestations obligatoires
  bool _acceptCgu = false;
  bool _attesteIdentite = false;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _emailProCtrl.dispose();
    _villeCtrl.dispose();
    _descCtrl.dispose();
    _nifCtrl.dispose();
    _rccmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPiece(String typeLabel) async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      setState(() {
        _pieces.add(_DocPiece(label: typeLabel, bytes: bytes));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur pièce: $e')),
      );
    }
  }

  Future<List<String>> _uploadPieces(String organisateurId) async {
    final urls = <String>[];
    for (int i = 0; i < _pieces.length; i++) {
      final p = _pieces[i];
      final mime = lookupMimeType('', headerBytes: p.bytes) ?? 'application/octet-stream';
      String ext = 'bin';
      if (mime.contains('jpeg')) ext = 'jpg';
      else if (mime.contains('png')) ext = 'png';
      else if (mime.contains('webp')) ext = 'webp';

      final ts = DateTime.now().millisecondsSinceEpoch;
      final objectPath = 'org/$organisateurId/docs/$ts-$i.$ext';
      await _sb.storage
          .from('organisateur-docs')
          .uploadBinary(objectPath, p.bytes, fileOptions: FileOptions(upsert: true, contentType: mime));
      final publicUrl = _sb.storage.from('organisateur-docs').getPublicUrl(objectPath);
      urls.add(publicUrl);
    }
    return urls;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    if (!_attesteIdentite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez attester de l’exactitude des informations.')),
      );
      return;
    }
    if (!_acceptCgu) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez accepter les CGU Billetterie.')),
      );
      return;
    }

    final user = _sb.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      // 1) Empêcher la double-inscription
      final exists = await _sb
          .from('organisateurs')
          .select('id, verifie')
          .eq('user_id', user.id)
          .limit(1);
      if (exists is List && exists.isNotEmpty) {
        final alreadyVerified = (exists.first['verifie'] == true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(alreadyVerified
                ? 'Un profil organisateur existe déjà (vérifié).'
                : 'Un profil organisateur existe déjà (en attente de vérification).'),
          ),
        );
        Navigator.pop(context, false);
        return;
      }

      // 2) Création du profil organisateur (verifie: false)
      final inserted = await _sb.from('organisateurs').insert({
        'user_id': user.id,
        'nom_structure': _nomCtrl.text.trim(),
        'telephone': _telCtrl.text.trim(),
        'email_pro': _emailProCtrl.text.trim().isEmpty ? null : _emailProCtrl.text.trim(),
        'ville': _villeCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'nif': _nifCtrl.text.trim().isEmpty ? null : _nifCtrl.text.trim(),     // si colonne absente, on ignore plus bas
        'rccm': _rccmCtrl.text.trim().isEmpty ? null : _rccmCtrl.text.trim(),  // idem
        'verifie': false,
      }).select('id').single();

      final orgId = inserted['id'].toString();

      // 3) Upload des pièces (facultatif mais conseillé)
      List<String> docs = [];
      if (_pieces.isNotEmpty) {
        docs = await _uploadPieces(orgId);
        // Essayez d’enregistrer en colonne si elle existe (documents_urls TEXT[])
        try {
          await _sb.from('organisateurs').update({'documents_urls': docs}).eq('id', orgId);
        } catch (_) {
          // colonne absente : on ignore discrètement
        }
      }

      if (!mounted) return;
      // 4) Message de confirmation + explications vérif
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Demande envoyée'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Votre profil organisateur a été créé.\n\n"
                "Il est maintenant en attente de vérification. "
                "Nos équipes valideront vos informations avant toute mise en vente de billets.",
              ),
              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    "Astuce : ajoutez des pièces (CNI/RCCM) pour accélérer la vérification.",
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );

      Navigator.pop(context, true);
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kEventPrimary,
        foregroundColor: _kOnPrimary,
        title: const Text('Devenir organisateur'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bandeau info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1E9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE7D9FF)),
                ),
                child: const Text(
                  "Cette inscription sera vérifiée manuellement (contrôle identité/structure). "
                  "Sans vérification, aucune vente de billets n’est possible.",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),

              // Identité/Structure
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

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _villeCtrl,
                      decoration: const InputDecoration(labelText: 'Ville'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _nifCtrl,
                      decoration: const InputDecoration(labelText: 'NIF (optionnel)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rccmCtrl,
                      decoration: const InputDecoration(labelText: 'RCCM (optionnel)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description (facultatif)'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Pièces
              Text('Pièces justificatives (conseillé)', style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PieceButton(label: 'CNI/ID', onPick: () => _pickPiece('CNI')),
                  _PieceButton(label: 'RCCM', onPick: () => _pickPiece('RCCM')),
                  _PieceButton(label: 'Autre', onPick: () => _pickPiece('Autre')),
                ],
              ),
              if (_pieces.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _pieces.map((p) {
                    return Stack(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[200],
                            image: DecorationImage(image: MemoryImage(p.bytes), fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: IconButton(
                            onPressed: () => setState(() => _pieces.remove(p)),
                            icon: const Icon(Icons.close, size: 20, color: Colors.red),
                            splashRadius: 16,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 16),
              // Attestations obligatoires
              CheckboxListTile(
                value: _attesteIdentite,
                onChanged: (v) => setState(() => _attesteIdentite = v ?? false),
                title: const Text("J’atteste sur l’honneur de l’exactitude des informations fournies."),
                activeColor: _kEventPrimary,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                value: _acceptCgu,
                onChanged: (v) => setState(() => _acceptCgu = v ?? false),
                title: const Text("J’accepte les CGU Billetterie et la politique de vérification."),
                activeColor: _kEventPrimary,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 12),

              // Bouton
              ElevatedButton(
                onPressed: _sending ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kEventPrimary,
                  foregroundColor: _kOnPrimary,
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

// ----- Petits widgets / modèles -----
class _PieceButton extends StatelessWidget {
  final String label;
  final VoidCallback onPick;
  const _PieceButton({required this.label, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPick,
      icon: const Icon(Icons.upload_file),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF7B2CBF)),
        foregroundColor: const Color(0xFF7B2CBF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _DocPiece {
  final String label;
  final Uint8List bytes;
  _DocPiece({required this.label, required this.bytes});
}
