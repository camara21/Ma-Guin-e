// lib/pages/billetterie/pro_inscription_organisateur_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProInscriptionOrganisateurPage extends StatefulWidget {
  const ProInscriptionOrganisateurPage({super.key});

  @override
  State<ProInscriptionOrganisateurPage> createState() => _ProInscriptionOrganisateurPageState();
}

class _ProInscriptionOrganisateurPageState extends State<ProInscriptionOrganisateurPage> {
  final _sb = Supabase.instance.client;
  final _form = GlobalKey<FormState>();

  // Palette
  static const _kEventPrimary = Color(0xFF7B2CBF);
  static const _kOnPrimary = Colors.white;

  // Type d’inscription
  String _type = 'individu'; // individu | entreprise

  // --- Champs communs ---
  final _telCtrl = TextEditingController();
  final _emailProCtrl = TextEditingController();
  final _villeCtrl = TextEditingController(text: 'Conakry');
  final _descCtrl = TextEditingController();

  // --- Individu ---
  final _nomIndCtrl = TextEditingController();
  final _prenomIndCtrl = TextEditingController();
  String _pieceIndType = 'Passeport';
  Uint8List? _photoIndividu;   // selfie / photo personne (OBLIGATOIRE)
  Uint8List? _pieceIndRecto;   // document identité Recto (OBLIGATOIRE)
  Uint8List? _pieceIndVerso;   // document identité Verso (optionnel)

  // --- Entreprise ---
  final _nomStructureCtrl = TextEditingController();
  final Map<String, Uint8List?> _docsEntreprise = {
    'RCCM': null,
    'NIF': null,
    'Patente': null,
    'CNSS': null,
  };

  // Dirigeant
  final _dirigeantNomCtrl = TextEditingController();
  String _dirigeantPieceType = 'Passeport';
  Uint8List? _dirigeantPiecePhoto; // OBLIGATOIRE
  Uint8List? _dirigeantPhoto;      // selfie/portrait du dirigeant (OBLIGATOIRE)

  bool _sending = false;

  // Attestations
  bool _acceptCgu = false;
  bool _attesteIdentite = false;

  @override
  void dispose() {
    _telCtrl.dispose();
    _emailProCtrl.dispose();
    _villeCtrl.dispose();
    _descCtrl.dispose();
    _nomIndCtrl.dispose();
    _prenomIndCtrl.dispose();
    _nomStructureCtrl.dispose();
    _dirigeantNomCtrl.dispose();
    super.dispose();
  }

  // ----------------------- PICKERS -----------------------

  Future<_PickedLocal?> _pickAnyFile({List<String>? allowed}) async {
    final res = await FilePicker.platform.pickFiles(
      type: allowed == null ? FileType.any : FileType.custom,
      allowMultiple: false,
      withData: true,
      allowedExtensions: allowed,
    );
    if (res == null || res.files.isEmpty) return null;
    final f = res.files.first;
    if (f.bytes == null) return null;
    final name = (f.name.isNotEmpty ? f.name : 'fichier');
    final mime = lookupMimeType(name, headerBytes: f.bytes!) ?? 'application/octet-stream';
    return _PickedLocal(name: name, bytes: f.bytes!, mime: mime);
  }

  Future<Uint8List?> _openCameraSheet({
    String? title,
    CameraLensDirection initial = CameraLensDirection.front,
  }) async {
    // Ouvre la feuille caméra native (Android/iOS). Si la caméra n’est pas dispo,
    // la feuille affichera une erreur et on restera sur place.
    return await showModalBottomSheet<Uint8List?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.92,
          child: _CameraCaptureSheet(
            title: title ?? 'Capture',
            initialDirection: initial,
          ),
        ),
      ),
    );
  }

  // ------ Choix source : Appareil photo / Fichier ------
  Future<_SourceAction?> _pickSourceSheet() async {
    return showModalBottomSheet<_SourceAction>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Appareil photo'),
              onTap: () => Navigator.pop(ctx, _SourceAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Fichier'),
              onTap: () => Navigator.pop(ctx, _SourceAction.file),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // --- Individu: selfie ---
  Future<void> _chooseIndividuSource() async {
    final action = await _pickSourceSheet();
    if (action == null) return;
    if (action == _SourceAction.camera) {
      final bytes = await _openCameraSheet(title: 'Photo de la personne', initial: CameraLensDirection.front);
      if (bytes != null) setState(() => _photoIndividu = bytes);
    } else {
      final f = await _pickAnyFile(allowed: ['jpg', 'jpeg', 'png', 'webp']);
      if (f?.bytes != null) setState(() => _photoIndividu = f!.bytes);
    }
  }

  // --- Individu: pièce recto/verso ---
  Future<void> _choosePieceRecto() async {
    final action = await _pickSourceSheet();
    if (action == null) return;
    if (action == _SourceAction.camera) {
      final bytes = await _openCameraSheet(title: 'Pièce d’identité (Recto)', initial: CameraLensDirection.back);
      if (bytes != null) setState(() => _pieceIndRecto = bytes);
    } else {
      final f = await _pickAnyFile(allowed: ['jpg', 'jpeg', 'png', 'webp', 'pdf']);
      if (f?.bytes != null) setState(() => _pieceIndRecto = f!.bytes);
    }
  }

  Future<void> _choosePieceVerso() async {
    final action = await _pickSourceSheet();
    if (action == null) return;
    if (action == _SourceAction.camera) {
      final bytes = await _openCameraSheet(title: 'Pièce d’identité (Verso)', initial: CameraLensDirection.back);
      if (bytes != null) setState(() => _pieceIndVerso = bytes);
    } else {
      final f = await _pickAnyFile(allowed: ['jpg', 'jpeg', 'png', 'webp', 'pdf']);
      if (f?.bytes != null) setState(() => _pieceIndVerso = f!.bytes);
    }
  }

  // --- Entreprise: docs & dirigeant ---
  Future<void> _chooseDocEntrepriseSource(String label) async {
    final action = await _pickSourceSheet();
    if (action == null) return;
    if (action == _SourceAction.camera) {
      final bytes = await _openCameraSheet(title: 'Document: $label', initial: CameraLensDirection.back);
      if (bytes != null) setState(() => _docsEntreprise[label] = bytes);
    } else {
      final f = await _pickAnyFile(allowed: ['pdf', 'jpg', 'jpeg', 'png', 'webp']);
      if (f?.bytes != null) setState(() => _docsEntreprise[label] = f!.bytes);
    }
  }

  Future<void> _chooseDirigeantPiece() async {
    final action = await _pickSourceSheet();
    if (action == null) return;
    if (action == _SourceAction.camera) {
      final bytes = await _openCameraSheet(title: 'Pièce du dirigeant', initial: CameraLensDirection.back);
      if (bytes != null) setState(() => _dirigeantPiecePhoto = bytes);
    } else {
      final f = await _pickAnyFile(allowed: ['pdf', 'jpg', 'jpeg', 'png', 'webp']);
      if (f?.bytes != null) setState(() => _dirigeantPiecePhoto = f!.bytes);
    }
  }

  Future<void> _chooseDirigeantPhoto() async {
    final action = await _pickSourceSheet();
    if (action == null) return;
    if (action == _SourceAction.camera) {
      final bytes = await _openCameraSheet(title: 'Photo du dirigeant', initial: CameraLensDirection.front);
      if (bytes != null) setState(() => _dirigeantPhoto = bytes);
    } else {
      final f = await _pickAnyFile(allowed: ['jpg', 'jpeg', 'png', 'webp']);
      if (f?.bytes != null) setState(() => _dirigeantPhoto = f!.bytes);
    }
  }

  // ----------------------- UPLOAD -----------------------

  Future<List<String>> _uploadBlobs(String organisateurId, List<_NamedBlob> blobs) async {
    final urls = <String>[];
    for (int i = 0; i < blobs.length; i++) {
      final b = blobs[i];
      final mime = b.mime ?? (lookupMimeType(b.originalName ?? '', headerBytes: b.bytes) ?? 'application/octet-stream');

      String ext = 'bin';
      if (b.originalName != null && b.originalName!.contains('.')) {
        ext = b.originalName!.split('.').last.toLowerCase();
      } else if (mime.contains('jpeg')) ext = 'jpg';
      else if (mime.contains('png')) ext = 'png';
      else if (mime.contains('webp')) ext = 'webp';
      else if (mime == 'application/pdf') ext = 'pdf';

      final ts = DateTime.now().millisecondsSinceEpoch;
      final safeName = (b.name).replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final objectPath = 'org/$organisateurId/docs/$ts-$i-$safeName.$ext';

      await _sb.storage
          .from('organisateur-docs')
          .uploadBinary(objectPath, b.bytes, fileOptions: FileOptions(upsert: true, contentType: mime));
      final publicUrl = _sb.storage.from('organisateur-docs').getPublicUrl(objectPath);
      urls.add(publicUrl);
    }
    return urls;
  }

  bool _validateBusinessDocs() => _docsEntreprise.values.any((b) => b != null);

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

    if (_type == 'individu') {
      if (_photoIndividu == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo de la personne obligatoire.')));
        return;
      }
      if (_pieceIndRecto == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document d’identité (Recto) obligatoire.')));
        return;
      }
    } else {
      if (!_validateBusinessDocs()) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Au moins un document légal d’entreprise est obligatoire.')));
        return;
      }
      if (_dirigeantPhoto == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo du dirigeant obligatoire.')));
        return;
      }
      if (_dirigeantPiecePhoto == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pièce d’identité du dirigeant obligatoire.')));
        return;
      }
    }

    setState(() => _sending = true);
    try {
      // Anti double-inscription
      final exists = await _sb
          .from('organisateurs')
          .select('id, verifie')
          .eq('user_id', user.id)
          .limit(1);
      if (exists is List && exists.isNotEmpty) {
        final alreadyVerified = (exists.first['verifie'] == true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(alreadyVerified
                ? 'Un profil organisateur existe déjà (vérifié).'
                : 'Un profil organisateur existe déjà (en attente de vérification).'),
          ),
        );
        if (mounted) Navigator.pop(context, false);
        return;
      }

      // 1) Insert
      final base = <String, dynamic>{
        'user_id': user.id,
        'type': _type,
        'telephone': _telCtrl.text.trim(),
        'email_pro': _emailProCtrl.text.trim().isEmpty ? null : _emailProCtrl.text.trim(),
        'ville': _villeCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'verifie': false,
      };

      if (_type == 'individu') {
        base.addAll({
          'nom': _nomIndCtrl.text.trim(),
          'prenom': _prenomIndCtrl.text.trim(),
          'piece_type': _pieceIndType,
        });
      } else {
        base.addAll({
          'nom_structure': _nomStructureCtrl.text.trim(),
          'dirigeant_nom': _dirigeantNomCtrl.text.trim(),
          'dirigeant_piece_type': _dirigeantPieceType,
        });
      }

      final inserted = await _sb.from('organisateurs').insert(base).select('id').single();
      final orgId = inserted['id'].toString();

      // 2) Préparer uploads
      final uploads = <_NamedBlob>[];
      if (_type == 'individu') {
        uploads.add(_NamedBlob(name: 'individu-photo', bytes: _photoIndividu!, mime: 'image/*'));
        uploads.add(_NamedBlob(name: 'individu-piece-recto', bytes: _pieceIndRecto!));
        if (_pieceIndVerso != null) {
          uploads.add(_NamedBlob(name: 'individu-piece-verso', bytes: _pieceIndVerso!));
        }
      } else {
        // Entreprise - documents légaux
        _docsEntreprise.forEach((label, bytes) {
          if (bytes != null) uploads.add(_NamedBlob(name: 'entreprise-$label', bytes: bytes));
        });
        // Dirigeant
        uploads.add(_NamedBlob(name: 'dirigeant-photo', bytes: _dirigeantPhoto!));
        uploads.add(_NamedBlob(name: 'dirigeant-piece', bytes: _dirigeantPiecePhoto!));
      }

      final urls = uploads.isEmpty ? <String>[] : await _uploadBlobs(orgId, uploads);

      // 3) Enregistrer URLs si colonne présente
      try {
        await _sb.from('organisateurs').update({'documents_urls': urls}).eq('id', orgId);
      } catch (_) {}

      if (!mounted) return;

      // 4) Succès + liens de téléchargement
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Demande envoyée'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Votre profil organisateur a été créé et est en attente de vérification.\n\n"
                  "Nous contrôlerons votre identité (et vos documents d’entreprise le cas échéant).",
                ),
                if (urls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Documents déposés :', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 160,
                    child: ListView.separated(
                      itemCount: urls.length,
                      separatorBuilder: (_, __) => const Divider(height: 10),
                      itemBuilder: (ctx, i) {
                        final u = urls[i];
                        final label = 'Fichier ${i + 1}';
                        return Row(
                          children: [
                            const Icon(Icons.insert_drive_file_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
                            TextButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(u);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              icon: const Icon(Icons.download),
                              label: const Text('Voir / Télécharger'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ----------------------- UI -----------------------

  @override
  Widget build(BuildContext context) {
    final isIndividu = _type == 'individu';

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
                  'Ajoutez vos justificatifs via un unique bouton "Ajouter", puis choisissez : Appareil photo ou Fichier (PDF/Images).',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),

              // Choix type
              Text("Type d’inscription", style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'individu', label: Text('Individu'), icon: Icon(Icons.person_outline)),
                  ButtonSegment(value: 'entreprise', label: Text('Entreprise'), icon: Icon(Icons.apartment)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
                style: ButtonStyle(
                  side: MaterialStateProperty.resolveWith((_) => const BorderSide(color: Color(0xFF7B2CBF))),
                ),
              ),
              const SizedBox(height: 16),

              if (isIndividu) _buildIndividuSection(),
              if (!isIndividu) _buildEntrepriseSection(),

              const SizedBox(height: 16),
              // Coordonnées
              Text("Coordonnées", style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
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

              const SizedBox(height: 16),
              // Attestations
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

              ElevatedButton(
                onPressed: _sending ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kEventPrimary,
                  foregroundColor: _kOnPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isIndividu ? 'Créer mon profil (Individu)' : 'Créer mon profil (Entreprise)'),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF7F7F7),
    );
  }

  Widget _buildIndividuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Identité (Individu)", style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _nomIndCtrl,
                decoration: const InputDecoration(labelText: 'Nom *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _prenomIndCtrl,
                decoration: const InputDecoration(labelText: 'Prénom *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _pieceIndType,
          items: const [
            DropdownMenuItem(value: 'Passeport', child: Text('Passeport')),
            DropdownMenuItem(value: 'CNI', child: Text('Carte d’identité (CNI)')),
            DropdownMenuItem(value: 'Carte d’électeur', child: Text('Carte d’électeur')),
          ],
          onChanged: (v) => setState(() => _pieceIndType = v ?? 'Passeport'),
          decoration: const InputDecoration(labelText: 'Type de pièce *'),
        ),
        const SizedBox(height: 14),

        // Selfie individu
        Text('Photo de la personne (selfie)', style: TextStyle(color: Colors.grey[700])),
        const SizedBox(height: 8),
        Row(
          children: [
            _CaptureThumb(bytes: _photoIndividu),
            const SizedBox(width: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _chooseIndividuSource,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF7B2CBF)),
                    foregroundColor: const Color(0xFF7B2CBF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (_photoIndividu != null)
                  IconButton(
                    onPressed: () => setState(() => _photoIndividu = null),
                    icon: const Icon(Icons.close, color: Colors.red),
                    splashRadius: 18,
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Pièce identité recto / verso
        Text('Document d’identité', style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _DocTileOneButton(
              label: 'Recto (obligatoire)',
              hasFile: _pieceIndRecto != null,
              onAdd: _choosePieceRecto,
              onRemove: _pieceIndRecto == null ? null : () => setState(() => _pieceIndRecto = null),
            ),
            _DocTileOneButton(
              label: 'Verso (optionnel)',
              hasFile: _pieceIndVerso != null,
              onAdd: _choosePieceVerso,
              onRemove: _pieceIndVerso == null ? null : () => setState(() => _pieceIndVerso = null),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildEntrepriseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Informations entreprise", style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nomStructureCtrl,
          decoration: const InputDecoration(labelText: 'Nom de la structure *'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
        ),
        const SizedBox(height: 16),

        _DocsInfoCard(),

        const SizedBox(height: 8),
        Text('Documents légaux (au moins 1)', style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _docsEntreprise.keys.map((label) {
            final hasFile = _docsEntreprise[label] != null;
            return _DocTileOneButton(
              label: label,
              hasFile: hasFile,
              onAdd: () => _chooseDocEntrepriseSource(label),
              onRemove: hasFile ? () => setState(() => _docsEntreprise[label] = null) : null,
            );
          }).toList(),
        ),

        const SizedBox(height: 16),
        Text("Dirigeant", style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _dirigeantNomCtrl,
          decoration: const InputDecoration(labelText: 'Nom et prénom du dirigeant *'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _dirigeantPieceType,
          items: const [
            DropdownMenuItem(value: 'Passeport', child: Text('Passeport')),
            DropdownMenuItem(value: 'CNI', child: Text('Carte d’identité (CNI)')),
            DropdownMenuItem(value: 'Carte d’électeur', child: Text('Carte d’électeur')),
          ],
          onChanged: (v) => setState(() => _dirigeantPieceType = v ?? 'Passeport'),
          decoration: const InputDecoration(labelText: 'Type de pièce du dirigeant *'),
        ),
        const SizedBox(height: 14),

        // Selfie dirigeant (OBLIGATOIRE)
        Text('Photo du dirigeant (selfie)', style: TextStyle(color: Colors.grey[700])),
        const SizedBox(height: 8),
        Row(
          children: [
            _CaptureThumb(bytes: _dirigeantPhoto),
            const SizedBox(width: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _chooseDirigeantPhoto,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF7B2CBF)),
                    foregroundColor: const Color(0xFF7B2CBF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (_dirigeantPhoto != null)
                  IconButton(
                    onPressed: () => setState(() => _dirigeantPhoto = null),
                    icon: const Icon(Icons.close, color: Colors.red),
                    splashRadius: 18,
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Pièce dirigeant (OBLIGATOIRE)
        Text('Pièce du dirigeant', style: TextStyle(color: Colors.grey[700])),
        const SizedBox(height: 8),
        Row(
          children: [
            _CaptureThumb(bytes: _dirigeantPiecePhoto),
            const SizedBox(width: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _chooseDirigeantPiece,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF7B2CBF)),
                    foregroundColor: const Color(0xFF7B2CBF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (_dirigeantPiecePhoto != null)
                  IconButton(
                    onPressed: () => setState(() => _dirigeantPiecePhoto = null),
                    icon: const Icon(Icons.close, color: Colors.red),
                    splashRadius: 18,
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// ====== Widgets & modèles ======

class _DocsInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7D9FF)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ℹ️ Comprendre les documents', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          _Bullet(text: 'RCCM : immatriculation au Registre du Commerce et du Crédit Mobilier.'),
          _Bullet(text: 'NIF : Numéro d’Identification Fiscale.'),
          _Bullet(text: 'Patente : autorisation d’exercer / quittance fiscale.'),
          _Bullet(text: 'CNSS : affiliation à la Caisse Nationale de Sécurité Sociale.'),
          SizedBox(height: 6),
          Text('👉 Utilisez “Ajouter”, puis choisissez : Appareil photo ou Fichier (PDF/Images).', style: TextStyle(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('•  '),
        Expanded(child: Text(text)),
      ],
    );
  }
}

// Tuile documents entreprise/individu avec 1 seul bouton "Ajouter"
class _DocTileOneButton extends StatelessWidget {
  final String label;
  final bool hasFile;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  const _DocTileOneButton({
    required this.label,
    required this.hasFile,
    required this.onAdd,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF7B2CBF)),
        borderRadius: BorderRadius.circular(10),
        color: hasFile ? const Color(0xFFEDE7F6) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
              ),
              if (hasFile) const SizedBox(width: 6),
              if (hasFile)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, color: Colors.red),
                  splashRadius: 18,
                ),
            ],
          ),
          if (hasFile)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Fichier prêt à l’envoi', style: TextStyle(fontSize: 12, color: Colors.green)),
            ),
        ],
      ),
    );
  }
}

class _CaptureThumb extends StatelessWidget {
  final Uint8List? bytes;
  const _CaptureThumb({this.bytes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey[200],
        image: bytes == null ? null : DecorationImage(image: MemoryImage(bytes!), fit: BoxFit.cover),
      ),
      child: bytes == null
          ? const Icon(Icons.person_outline, size: 28, color: Colors.grey)
          : null,
    );
  }
}

class _PickedLocal {
  final String name;
  final Uint8List bytes;
  final String mime;
  _PickedLocal({required this.name, required this.bytes, required this.mime});
}

class _NamedBlob {
  final String name;
  final Uint8List bytes;
  final String? mime;
  final String? originalName;
  _NamedBlob({required this.name, required this.bytes, this.mime, this.originalName});
}

enum _SourceAction { camera, file }

/// --------- FEUILLE DE CAPTURE CAMÉRA AVEC APERÇU ---------
class _CameraCaptureSheet extends StatefulWidget {
  final String title;
  final CameraLensDirection initialDirection;

  const _CameraCaptureSheet({
    required this.title,
    this.initialDirection = CameraLensDirection.back,
  });

  @override
  State<_CameraCaptureSheet> createState() => _CameraCaptureSheetState();
}

class _CameraCaptureSheetState extends State<_CameraCaptureSheet> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cams = [];
  bool _busy = true;
  CameraLensDirection _direction = CameraLensDirection.back;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _direction = widget.initialDirection;
    _init();
  }

  Future<void> _init() async {
    try {
      _cams = await availableCameras();
      CameraDescription? cam = _cams.firstWhere(
        (c) => c.lensDirection == _direction,
        orElse: () => _cams.isNotEmpty ? _cams.first : throw 'Aucune caméra détectée',
      );
      _controller = CameraController(cam, ResolutionPreset.medium, enableAudio: false);
      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Caméra indisponible: $e')));
      // Fermer la feuille si totalement indisponible ?
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _flip() async {
    if (_cams.isEmpty) return;
    final newDir = _direction == CameraLensDirection.back ? CameraLensDirection.front : CameraLensDirection.back;
    final sameDir = _cams.where((c) => c.lensDirection == newDir).toList();
    if (sameDir.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _controller?.dispose();
      _controller = CameraController(sameDir.first, ResolutionPreset.medium, enableAudio: false);
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _direction = newDir;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible de changer de caméra: $e')));
    }
  }

  Future<void> _shoot() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      Navigator.pop(context, bytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Capture échouée: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Row(
          children: [
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(onPressed: _flip, icon: const Icon(Icons.cameraswitch, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Center(
            child: _busy || _controller == null || !_controller!.value.isInitialized
                ? const CircularProgressIndicator()
                : AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ElevatedButton.icon(
            onPressed: _shoot,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Capturer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
