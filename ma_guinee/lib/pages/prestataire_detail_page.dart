import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:postgrest/postgrest.dart' show PostgrestException;

import 'messages_prestataire_page.dart';

class PrestataireDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const PrestataireDetailPage({super.key, required this.data});

  @override
  State<PrestataireDetailPage> createState() => _PrestataireDetailPageState();
}

class _PrestataireDetailPageState extends State<PrestataireDetailPage> {
  // ————————— Etats locaux —————————
  int _noteUtilisateur = 0;
  final TextEditingController _avisController = TextEditingController();
  List<Map<String, dynamic>> _avis = [];
  double _noteMoyenne = 0;

  // Résolution propriétaire réel (utilisateur lié au prestataire)
  String? _ownerId;            // prestataires.utilisateur_id
  bool _ownerResolved = false;

  // Anti double clic sur “Envoyer signalement”
  bool _sending = false;

  // Thème local
  static const Color kPrimary = Color(0xFF113CFC);
  static const Color kDivider = Color(0xFFEAEAEA);

  // Buckets (si tu utilises un path et non une URL complète)
  static const String _avatarBucket = 'profile-photos';

  @override
  void initState() {
    super.initState();
    _resolveOwner();
    _loadAvis();
  }

  // ————————— Utilitaires —————————
  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  bool get _isOwner {
    final me = Supabase.instance.client.auth.currentUser;
    if (!_ownerResolved || me == null || _ownerId == null) return false;
    return me.id == _ownerId;
  }

  String? _publicUrl(String bucket, String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final objectPath = path.startsWith('$bucket/')
        ? path.substring(bucket.length + 1)
        : path;
    return Supabase.instance.client.storage.from(bucket).getPublicUrl(objectPath);
  }

  Future<void> _resolveOwner() async {
    // essaie d’abord les champs présents dans data
    final fromData = (widget.data['utilisateur_id'] ??
            widget.data['user_id'] ??
            widget.data['owner_id'] ??
            widget.data['proprietaire_id'])
        ?.toString();

    if (fromData != null && fromData.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _ownerId = fromData;
        _ownerResolved = true;
      });
      return;
    }

    // sinon, va lire prestataires.utilisateur_id en base
    final prestataireId = widget.data['id']?.toString();
    if (prestataireId == null || prestataireId.isEmpty) {
      if (!mounted) return;
      setState(() => _ownerResolved = true);
      return;
    }

    try {
      final row = await Supabase.instance.client
          .from('prestataires')
          .select('utilisateur_id')
          .eq('id', prestataireId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _ownerId = row?['utilisateur_id']?.toString();
        _ownerResolved = true;
      });
    } catch (_) {
      if (mounted) setState(() => _ownerResolved = true);
    }
  }

  Future<void> _loadAvis() async {
    try {
      final id = widget.data['id'];
      final res = await Supabase.instance.client
          .from('avis')
          .select('note, commentaire, created_at, utilisateurs(nom, prenom, photo_url)')
          .eq('contexte', 'prestataire')
          .eq('cible_id', id)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(res as List);
      final notes = <num>[
        for (final e in list)
          if (e['note'] is num) e['note'] as num,
      ];
      final moyenne = notes.isNotEmpty
          ? notes.reduce((a, b) => a + b) / notes.length
          : 0;

      if (!mounted) return;
      setState(() {
        _avis = list;
        _noteMoyenne = moyenne.toDouble();
      });
    } catch (e) {
      // silencieux pour l’instant
    }
  }

  // ————————— Actions —————————
  Future<void> _call(String? input) async {
    if (_isOwner) return _snack("Action non autorisée pour votre propre fiche.");

    final raw = (input ??
            widget.data['telephone'] ??
            widget.data['phone'] ??
            widget.data['tel'] ??
            '')
        .toString()
        .trim();

    final onlyDigits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (onlyDigits.isEmpty) return _snack("Numéro non disponible");

    String normalized = onlyDigits;
    if (normalized.startsWith('+')) {
      // déjà au format international
    } else if (normalized.startsWith('224')) {
      normalized = '+$normalized';
    } else if (normalized.startsWith('0')) {
      normalized = '+224${normalized.replaceFirst(RegExp(r'^0+'), '')}';
    } else if (normalized.length == 8 || normalized.length == 9) {
      normalized = '+224$normalized';
    } else {
      normalized = '+$normalized';
    }

    final uri = Uri(scheme: 'tel', path: normalized);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack("Impossible de lancer l'appel");
    }
  }

  void _openChat() {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return _snack("Connexion requise.");
    if (_isOwner) return _snack("Vous ne pouvez pas vous contacter vous-même.");

    // ⚠️ Si pas d’utilisateur lié, on bloque (évite P0001)
    if (!_ownerResolved || _ownerId == null || _ownerId!.isEmpty) {
      return _snack("Ce prestataire n'a pas encore de compte relié.");
    }

    // ⚠️ ID du prestataire ≠ ID du propriétaire
    final prestataireId = widget.data['id']?.toString() ?? '';
    if (prestataireId.isEmpty) {
      return _snack("Fiche prestataire invalide.");
    }

    final prenom = widget.data['prenom']?.toString() ?? '';
    final nom = widget.data['nom']?.toString() ?? '';
    final fullName = ('$prenom $nom').trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessagesPrestatairePage(
          // ici on passe bien l’ID DU PRESTATAIRE
          prestataireId: prestataireId,
          prestataireNom: fullName.isNotEmpty
              ? fullName
              : (widget.data['metier']?.toString() ?? 'Prestataire'),
          // et ici l’ID UTILISATEUR lié au prestataire (destinataire)
          receiverId: _ownerId!,
          senderId: me.id,
        ),
      ),
    );
  }

  // Menu AppBar
  void _onMenu(String value) async {
    switch (value) {
      case 'share':
        final metier = widget.data['metier']?.toString() ?? 'Prestataire';
        final ville = widget.data['ville']?.toString() ?? '';
        final prenom = widget.data['prenom']?.toString() ?? '';
        final nom = widget.data['nom']?.toString() ?? '';
        final fullName = ('$prenom $nom').trim();
        final txt = [
          if (fullName.isNotEmpty) 'Prestataire : $fullName',
          'Métier : $metier',
          if (ville.isNotEmpty) 'Ville : $ville',
        ].join('\n');
        await Share.share(txt);
        break;

      case 'report':
        _openReportSheet();
        break;
    }
  }

  // ————————— Bottom-sheet “Signaler” —————————
  void _openReportSheet() {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) {
      _snack("Connexion requise pour signaler.");
      return;
    }
    if (_isOwner) {
      _snack("Action non autorisée pour votre propre fiche.");
      return;
    }

    final reasons = <String>[
      'Fausse annonce',
      'Tentative de fraude',
      'Contenu inapproprié',
      'Mauvaise expérience',
      'Usurpation d’identité',
      'Autre'
    ];
    final TextEditingController ctrl = TextEditingController();
    String selected = reasons.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Signaler ce prestataire',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: reasons
                        .map((r) => ChoiceChip(
                              label: Text(r),
                              selected: selected == r,
                              onSelected: (_) => setLocalState(() => selected = r),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: "Expliquez brièvement… (facultatif)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.report_gmailerrorred),
                      label: Text(_sending ? 'Envoi en cours…' : 'Envoyer le signalement'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _sending
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              await _sendReport(selected, ctrl.text.trim());
                            },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ————————— Version DB : insertion directe dans public.reports —————————
  Future<void> _sendReport(String reason, String details) async {
    if (_sending) return; // anti double-clic
    setState(() => _sending = true);

    // petit loader modal
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final me = Supabase.instance.client.auth.currentUser;
      if (me == null) throw 'Utilisateur non connecté.';

      final body = {
        // ⚠️ si ta colonne est "contexte", renomme la clé ici
        'context': 'prestataire',
        'cible_id': widget.data['id']?.toString(),
        'owner_id': _ownerId,             // optionnel
        'reported_by': me.id,             // (souvent requis par RLS)
        'reason': reason,
        'details': details,
        'ville': widget.data['ville']?.toString(),
        'metier': widget.data['metier']?.toString(),
        'nom': widget.data['nom']?.toString(),
        'prenom': widget.data['prenom']?.toString(),
        'telephone': widget.data['telephone']?.toString(),
        'created_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client.from('reports').insert(body);

      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // close loader
      if (mounted) setState(() => _sending = false);
      if (mounted) _snack('Signalement envoyé. Merci.');
    } on PostgrestException catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) setState(() => _sending = false);

      final msg = (e.message ?? '').toLowerCase();
      if (e.code == '23505' || msg.contains('duplicate')) {
        _snack('Vous avez déjà signalé cette fiche.');
      } else if (e.code == '42501') {
        _snack("Accès refusé : vérifie les règles RLS/policies.");
      } else {
        _snack('Erreur serveur: ${e.message ?? e.toString()}');
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) setState(() => _sending = false);
      if (mounted) _snack('Impossible d’envoyer le signalement ($e)');
    }
  }

  // ————————— UI —————————
  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    final metier = d['metier']?.toString() ?? '';
    final ville = d['ville']?.toString() ?? '';
    // Si tu stockes un PATH de bucket, passe par _publicUrl :
    final String? rawPhoto = d['photo_url']?.toString();
    final photo = _publicUrl(_avatarBucket, rawPhoto) ?? rawPhoto ?? '';

    final String? phone =
        (d['telephone'] ?? d['phone'] ?? d['tel'])?.toString();

    final description = d['description']?.toString() ?? '';
    final prenom = d['prenom']?.toString() ?? '';
    final nom = d['nom']?.toString() ?? '';
    final fullName = ('$prenom $nom').trim();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.7,
        iconTheme: const IconThemeData(color: kPrimary),
        title: Text(
          fullName.isNotEmpty ? fullName : 'Prestataire',
          style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: _onMenu,
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'share',
                child: ListTile(leading: Icon(Icons.share), title: Text('Partager')),
              ),
              PopupMenuItem(
                value: 'report',
                child: ListTile(
                  leading: Icon(Icons.report_gmailerrorred),
                  title: Text('Signaler'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if ((photo).isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(photo, height: 200, fit: BoxFit.cover),
                ),
              const SizedBox(height: 16),
              if (metier.isNotEmpty)
                Text(metier,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(ville, style: const TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 14),
              if (description.isNotEmpty) Text(description),
              const SizedBox(height: 20),

              // Boutons d’action (masqués pour le propriétaire)
              if (_ownerResolved && !_isOwner)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 20),
                  child: Row(
                    children: [
                      // Message (outline bleu)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openChat,
                          icon: const Icon(Icons.chat_bubble_outline, color: kPrimary),
                          label: const Text(
                            "Message",
                            style: TextStyle(color: kPrimary, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kPrimary, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Contacter (plein bleu)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async => _call(phone),
                          icon: const Icon(Icons.phone, color: Colors.white),
                          label: const Text(
                            "Contacter",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const Divider(height: 30, color: kDivider),

              // — Avis (lecture simple + saisie à compléter)
              Row(
                children: [
                  const Text("Avis",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 8),
                  Icon(Icons.star, color: Colors.amber.shade700, size: 18),
                  const SizedBox(width: 2),
                  Text(_noteMoyenne.toStringAsFixed(1)),
                ],
              ),
              const SizedBox(height: 8),
              for (final a in _avis)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.person, size: 20, color: Colors.black54),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((a['utilisateurs']?['prenom'] ?? '').toString().isNotEmpty ||
                                (a['utilisateurs']?['nom'] ?? '').toString().isNotEmpty)
                              Text(
                                "${a['utilisateurs']?['prenom'] ?? ''} ${a['utilisateurs']?['nom'] ?? ''}".trim(),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            if ((a['commentaire'] ?? '').toString().isNotEmpty)
                              Text((a['commentaire'] ?? '').toString()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
              const Text("Laisser un avis",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(
                      i < _noteUtilisateur ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () => setState(() => _noteUtilisateur = i + 1),
                  );
                }),
              ),
              TextField(
                controller: _avisController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: "Votre avis",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _snack("Fonction avis à compléter"),
                icon: const Icon(Icons.send),
                label: const Text("Envoyer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFCD116),
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
