// lib/pages/prestataire_detail_page.dart
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:postgrest/postgrest.dart' show PostgrestException;
import 'package:cached_network_image/cached_network_image.dart';

import 'messages_prestataire_page.dart';

/// === Palette Prestataires ===
const Color prestatairesPrimary = Color(0xFF0F766E);
const Color prestatairesSecondary = Color(0xFF14B8A6);
const Color prestatairesOnPrimary = Color(0xFFFFFFFF);
const Color prestatairesOnSecondary = Color(0xFF000000);

class PrestataireDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const PrestataireDetailPage({super.key, required this.data});

  @override
  State<PrestataireDetailPage> createState() => _PrestataireDetailPageState();
}

class _PrestataireDetailPageState extends State<PrestataireDetailPage> {
  static const Color _neutralBg = Color(0xFFF7F7F9);
  static const Color _neutralSurface = Color(0xFFFFFFFF);
  static const Color _neutralBorder = Color(0xFFE5E7EB);
  static const Color _divider = Color(0xFFEAEAEA);

  static const String _avatarBucket = 'profile-photos';

  final _client = Supabase.instance.client;

  // Avis
  int _noteUtilisateur = 0;
  final TextEditingController _avisController = TextEditingController();

  List<Map<String, dynamic>> _avis = [];
  Map<String, Map<String, dynamic>> _usersById = {};
  double _noteMoyenne = 0.0;
  bool _dejaNote = false;

  bool _sendingReport = false;
  bool _sendingAvis = false;

  // Résolution propriétaire (utilisateur lié au prestataire)
  String? _ownerId; // prestataires.utilisateur_id
  bool _ownerResolved = false;

  bool get _canSendAvis =>
      !_sendingAvis &&
      _noteUtilisateur > 0 &&
      _avisController.text.trim().isNotEmpty;

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Hero sûr uniquement sur mobile (évite flash rouge desktop/web)
  bool get _enableHero => _isMobilePlatform;

  @override
  void initState() {
    super.initState();
    _resolveOwner();
    _loadAvis();

    _avisController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _avisController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool get _isOwner {
    final me = _client.auth.currentUser;
    if (!_ownerResolved || me == null || _ownerId == null) return false;
    return me.id == _ownerId;
  }

  String? _publicUrl(String bucket, String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final p = path.trim();
    if (p.startsWith('http://') || p.startsWith('https://')) return p;

    final objectPath =
        p.startsWith('$bucket/') ? p.substring(bucket.length + 1) : p;
    return _client.storage.from(bucket).getPublicUrl(objectPath);
  }

  bool _isUuid(String s) => RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(s);

  String _fmtDate(dynamic raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} • ${two(dt.hour)}:${two(dt.minute)}';
  }

  // -----------------------------------------------------
  // Owner
  // -----------------------------------------------------
  Future<void> _resolveOwner() async {
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

    final prestataireId = widget.data['id']?.toString();
    if (prestataireId == null || prestataireId.isEmpty) {
      if (!mounted) return;
      setState(() => _ownerResolved = true);
      return;
    }

    try {
      final row = await _client
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

  // -----------------------------------------------------
  // AVIS : lecture
  // -----------------------------------------------------
  Future<void> _loadAvis() async {
    try {
      final id = widget.data['id']?.toString();
      if (id == null || id.isEmpty) return;

      final res = await _client
          .from('avis_prestataires')
          .select('auteur_id, etoiles, commentaire, created_at')
          .eq('prestataire_id', id)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(res);

      final notes = list
          .map<double>((e) => (e['etoiles'] as num?)?.toDouble() ?? 0.0)
          .where((n) => n > 0)
          .toList();

      final moyenne =
          notes.isEmpty ? 0.0 : notes.reduce((a, b) => a + b) / notes.length;

      final me = _client.auth.currentUser;
      final deja = me != null && list.any((a) => a['auteur_id'] == me.id);

      final ids = list
          .map((e) => e['auteur_id'])
          .where((v) => v != null)
          .map((v) => v.toString())
          .where(_isUuid)
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> usersById = {};
      if (ids.isNotEmpty) {
        final orFilter = ids.map((id) => 'id.eq.$id').join(',');
        final usersRes = await _client
            .from('utilisateurs')
            .select('id, prenom, nom, photo_url')
            .or(orFilter);

        final users = List<Map<String, dynamic>>.from(usersRes);
        for (final u in users) {
          usersById[u['id'].toString()] = {
            'prenom': (u['prenom'] ?? '').toString(),
            'nom': (u['nom'] ?? '').toString(),
            'photo_url': (u['photo_url'] ?? '').toString(),
          };
        }
      }

      if (!mounted) return;
      setState(() {
        _avis = list;
        _usersById = usersById;
        _noteMoyenne = moyenne;
        _dejaNote = deja;
      });
    } catch (_) {}
  }

  Future<void> _ajouterOuModifierAvis({
    required String prestataireId,
    required String utilisateurId,
    required int note,
    required String commentaire,
  }) async {
    await _client.from('avis_prestataires').upsert(
      {
        'prestataire_id': prestataireId,
        'auteur_id': utilisateurId,
        'etoiles': note,
        'commentaire': commentaire,
      },
      onConflict: 'prestataire_id,auteur_id',
    );
  }

  Future<void> _envoyerAvis() async {
    if (_sendingAvis) return;

    final me = _client.auth.currentUser;
    if (me == null) return _snack("Connexion requise.");

    final prestataireId = widget.data['id']?.toString() ?? '';
    if (prestataireId.isEmpty) return _snack("Fiche prestataire invalide.");

    final commentaire = _avisController.text.trim();
    if (_noteUtilisateur == 0 || commentaire.isEmpty) {
      return _snack("Veuillez attribuer une note et écrire un commentaire.");
    }

    setState(() => _sendingAvis = true);

    try {
      await _ajouterOuModifierAvis(
        prestataireId: prestataireId,
        utilisateurId: me.id,
        note: _noteUtilisateur,
        commentaire: commentaire,
      );

      FocusManager.instance.primaryFocus?.unfocus();

      if (!mounted) return;
      setState(() {
        _noteUtilisateur = 0;
        _avisController.clear();
      });

      await _loadAvis();
      if (mounted) _snack("Merci pour votre avis !");
    } catch (e) {
      _snack("Erreur lors de l'envoi de l'avis : $e");
    } finally {
      if (mounted) setState(() => _sendingAvis = false);
    }
  }

  // -----------------------------------------------------
  // Actions
  // -----------------------------------------------------
  Future<void> _call(String? input) async {
    if (_isOwner) {
      return _snack("Action non autorisée pour votre propre fiche.");
    }

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
    if (!normalized.startsWith('+')) {
      if (normalized.startsWith('224')) {
        normalized = '+$normalized';
      } else if (normalized.startsWith('0')) {
        normalized = '+224${normalized.replaceFirst(RegExp(r'^0+'), '')}';
      } else if (normalized.length == 8 || normalized.length == 9) {
        normalized = '+224$normalized';
      } else {
        normalized = '+$normalized';
      }
    }

    final uri = Uri(scheme: 'tel', path: normalized);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack("Impossible de lancer l'appel");
    }
  }

  void _openChat() {
    final me = _client.auth.currentUser;
    if (me == null) return _snack("Connexion requise.");
    if (_isOwner) return _snack("Vous ne pouvez pas vous contacter vous-même.");
    if (!_ownerResolved || _ownerId == null || _ownerId!.isEmpty) {
      return _snack("Ce prestataire n'a pas encore de compte relié.");
    }

    final prestataireId = widget.data['id']?.toString() ?? '';
    if (prestataireId.isEmpty) return _snack("Fiche prestataire invalide.");

    final prenom = widget.data['prenom']?.toString() ?? '';
    final nom = widget.data['nom']?.toString() ?? '';
    final fullName = ('$prenom $nom').trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessagesPrestatairePage(
          prestataireId: prestataireId,
          prestataireNom: fullName.isNotEmpty
              ? fullName
              : (widget.data['metier']?.toString() ?? 'Prestataire'),
          receiverId: _ownerId!,
          senderId: me.id,
        ),
      ),
    );
  }

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

  void _openReportSheet() {
    final me = _client.auth.currentUser;
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
      "Usurpation d'identité",
      'Autre',
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
                  const Text(
                    'Signaler ce prestataire',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: reasons
                        .map(
                          (r) => ChoiceChip(
                            label: Text(r),
                            selected: selected == r,
                            selectedColor: prestatairesSecondary,
                            onSelected: (_) =>
                                setLocalState(() => selected = r),
                          ),
                        )
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
                      label: Text(_sendingReport
                          ? 'Envoi en cours…'
                          : 'Envoyer le signalement'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: prestatairesPrimary,
                        foregroundColor: prestatairesOnPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _sendingReport
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

  Future<void> _sendReport(String reason, String details) async {
    if (_sendingReport) return;
    setState(() => _sendingReport = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final me = _client.auth.currentUser;
      if (me == null) throw 'Utilisateur non connecté.';

      final body = {
        'context': 'prestataire',
        'cible_id': widget.data['id']?.toString(),
        'owner_id': _ownerId,
        'reported_by': me.id,
        'reason': reason,
        'details': details.isNotEmpty ? details : null,
        'ville': widget.data['ville']?.toString(),
        'metier': widget.data['metier']?.toString(),
        'nom': widget.data['nom']?.toString(),
        'prenom': widget.data['prenom']?.toString(),
        'telephone': widget.data['telephone']?.toString(),
        'created_at': DateTime.now().toIso8601String(),
      };

      await _client.from('reports').insert(body);

      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) setState(() => _sendingReport = false);
      if (mounted) _snack('Signalement envoyé. Merci.');
    } on PostgrestException catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) setState(() => _sendingReport = false);

      final msg = (e.message ?? '').toLowerCase();
      if (e.code == '23505' || msg.contains('duplicate')) {
        _snack('Vous avez déjà signalé cette fiche.');
      } else if (e.code == '42501') {
        _snack("Accès refusé : vérifiez les règles RLS/policies.");
      } else {
        _snack('Erreur serveur: ${e.message ?? e.toString()}');
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) setState(() => _sendingReport = false);
      if (mounted) _snack("Impossible d'envoyer le signalement ($e)");
    }
  }

  void _openPhotoFullScreen(String imageUrl, String heroTag) {
    if (imageUrl.trim().isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenImagePage(url: imageUrl, heroTag: heroTag),
      ),
    );
  }

  // UI helpers
  Widget _starsStatic(double avg, {double size = 16}) {
    final full = avg.floor().clamp(0, 5);
    final half = (avg - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) return Icon(Icons.star, size: size, color: Colors.amber);
        if (i == full && half) {
          return Icon(Icons.star_half, size: size, color: Colors.amber);
        }
        return Icon(Icons.star_border, size: size, color: Colors.amber);
      }),
    );
  }

  Widget _starsInput() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final active = i < _noteUtilisateur;
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          iconSize: 24,
          icon: Icon(active ? Icons.star : Icons.star_border,
              color: Colors.amber),
          onPressed: () => setState(() => _noteUtilisateur = i + 1),
        );
      }),
    );
  }

  Widget _starsRead(int value) {
    final v = value.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(i < v ? Icons.star : Icons.star_border,
            size: 14, color: Colors.amber),
      ),
    );
  }

  Widget _ratingSummaryCard() {
    if (_avis.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _neutralSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _neutralBorder),
        ),
        child: const Text("Aucun avis pour le moment",
            style: TextStyle(color: Colors.black54)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _neutralSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _neutralBorder),
      ),
      child: Row(
        children: [
          _starsStatic(_noteMoyenne, size: 16),
          const SizedBox(width: 8),
          Text('${_noteMoyenne.toStringAsFixed(1)} / 5',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text('(${_avis.length})',
              style: const TextStyle(color: Colors.black54)),
          const Spacer(),
          const Icon(Icons.verified, size: 18, color: prestatairesSecondary),
        ],
      ),
    );
  }

  Widget _reviewCard(Map<String, dynamic> a) {
    final uid = (a['auteur_id'] ?? '').toString();
    final u = _usersById[uid] ?? const {};

    final prenom = (u['prenom'] ?? '').toString();
    final nom = (u['nom'] ?? '').toString();
    final fullName = ('$prenom $nom').trim().isEmpty
        ? 'Utilisateur'
        : ('$prenom $nom').trim();

    final avatarRaw = (u['photo_url'] ?? '').toString();
    final avatar = _publicUrl(_avatarBucket, avatarRaw) ?? avatarRaw;

    final etoiles = (a['etoiles'] as num?)?.toInt() ?? 0;
    final commentaire = (a['commentaire'] ?? '').toString().trim();
    final dateStr = _fmtDate(a['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _neutralSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _neutralBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty ? const Icon(Icons.person, size: 18) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fullName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _starsRead(etoiles),
                  ],
                ),
                if (commentaire.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(commentaire, style: const TextStyle(height: 1.3)),
                ],
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(dateStr,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoWidget({
    required String photo,
    required String heroTag,
  }) {
    final child = photo.trim().isEmpty
        ? Container(
            height: 200,
            width: double.infinity,
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: const Icon(Icons.person, size: 48, color: Colors.grey),
          )
        : CachedNetworkImage(
            imageUrl: photo.trim(),
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(height: 200, color: Colors.grey.shade200),
            errorWidget: (_, __, ___) => Container(
              height: 200,
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const Icon(Icons.person, size: 48, color: Colors.grey),
            ),
          );

    // ✅ Sur desktop/web : pas de Hero pour éviter RenderBox not laid out au retour
    if (!_enableHero) return child;

    return Hero(
      tag: heroTag,
      transitionOnUserGestures: true,
      placeholderBuilder: (_, __, child) {
        // ✅ garde une taille fixe pendant le vol Hero (évite layout transient)
        return SizedBox(height: 200, width: double.infinity, child: child);
      },
      flightShuttleBuilder:
          (flightContext, animation, direction, fromCtx, toCtx) {
        // ✅ enveloppe Material pour éviter glitches pendant la transition
        return Material(
          color: Colors.transparent,
          child: toCtx.widget,
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    final metier = d['metier']?.toString() ?? '';
    final ville = d['ville']?.toString() ?? '';
    final description = d['description']?.toString() ?? '';

    final prenom = d['prenom']?.toString() ?? '';
    final nom = d['nom']?.toString() ?? '';
    final fullName = ('$prenom $nom').trim();

    final String? phone =
        (d['telephone'] ?? d['phone'] ?? d['tel'])?.toString();

    final String? rawPhoto = d['photo_url']?.toString();
    final photo = _publicUrl(_avatarBucket, rawPhoto) ?? (rawPhoto ?? '');

    // ✅ Tag 100% stable : uniquement sur ID (sinon pas de Hero)
    final prestId = (d['id'] ?? '').toString().trim();
    final heroTag =
        prestId.isNotEmpty ? 'prest_photo_$prestId' : 'prest_photo_nohero';

    return Scaffold(
      backgroundColor: _neutralBg,
      appBar: AppBar(
        backgroundColor: _neutralSurface,
        elevation: 0.7,
        iconTheme: const IconThemeData(color: prestatairesPrimary),
        title: Text(
          fullName.isNotEmpty ? fullName : 'Prestataire',
          style: const TextStyle(
              color: prestatairesPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: _onMenu,
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'share',
                child: ListTile(
                    leading: Icon(Icons.share), title: Text('Partager')),
              ),
              PopupMenuItem(
                value: 'report',
                child: ListTile(
                    leading: Icon(Icons.report_gmailerrorred),
                    title: Text('Signaler')),
              ),
            ],
          ),
        ],
      ),
      body: Listener(
        onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: GestureDetector(
                    onTap: (photo.trim().isEmpty || prestId.isEmpty)
                        ? null
                        : () => _openPhotoFullScreen(photo, heroTag),
                    child: _photoWidget(photo: photo, heroTag: heroTag),
                  ),
                ),
                const SizedBox(height: 16),
                if (metier.isNotEmpty)
                  Text(metier,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                if (ville.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          ville,
                          style: const TextStyle(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 14),
                if (description.isNotEmpty) ...[
                  const Text("Description",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(description),
                ],
                const SizedBox(height: 12),
                _ratingSummaryCard(),
                const SizedBox(height: 18),
                if (_ownerResolved && !_isOwner)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openChat,
                            icon: const Icon(Icons.chat_bubble_outline,
                                color: prestatairesPrimary),
                            label: const Text(
                              "Message",
                              style: TextStyle(
                                  color: prestatairesPrimary,
                                  fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: prestatairesPrimary, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async => _call(phone),
                            icon: const Icon(Icons.phone, color: Colors.white),
                            label: const Text(
                              "Contacter",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: prestatairesPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 30, color: _divider),
                const Text("Avis des utilisateurs",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                if (_avis.isEmpty)
                  const Text("Aucun avis pour le moment.")
                else
                  ..._avis.map(_reviewCard),
                const SizedBox(height: 10),
                const Divider(height: 30, color: _divider),
                const Text("Votre avis",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (_dejaNote)
                  const Padding(
                    padding: EdgeInsets.only(top: 6, bottom: 6),
                    child: Text(
                      "Vous avez déjà laissé un avis. Renvoyez pour mettre à jour.",
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                _starsInput(),
                const SizedBox(height: 6),
                TextField(
                  controller: _avisController,
                  maxLines: 3,
                  textInputAction: _canSendAvis
                      ? TextInputAction.send
                      : TextInputAction.newline,
                  onSubmitted: (_) {
                    if (_canSendAvis) _envoyerAvis();
                  },
                  decoration: InputDecoration(
                    hintText: "Votre avis",
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _canSendAvis ? _envoyerAvis : null,
                    icon: const Icon(Icons.send, size: 18),
                    label: Text(_dejaNote ? "Mettre à jour" : "Envoyer"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: prestatairesSecondary,
                      foregroundColor: prestatairesOnSecondary,
                      disabledBackgroundColor:
                          prestatairesSecondary.withOpacity(0.35),
                      disabledForegroundColor:
                          prestatairesOnSecondary.withOpacity(0.75),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Plein écran image (mobile only lock + zoom)
class _FullscreenImagePage extends StatefulWidget {
  final String url;
  final String heroTag;
  const _FullscreenImagePage({required this.url, required this.heroTag});

  @override
  State<_FullscreenImagePage> createState() => _FullscreenImagePageState();
}

class _FullscreenImagePageState extends State<_FullscreenImagePage> {
  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    // ✅ Sur PC/Web : ne rien forcer (évite comportements/bugs)
    if (_isMobilePlatform) {
      try {
        SystemChrome.setPreferredOrientations(
            const [DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    if (_isMobilePlatform) {
      try {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = CachedNetworkImage(
      imageUrl: widget.url,
      fit: BoxFit.contain,
      placeholder: (_, __) =>
          const SizedBox.expand(child: ColoredBox(color: Colors.black)),
      errorWidget: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image, color: Colors.white70, size: 64),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SizedBox.expand(
        child: _isMobilePlatform
            ? Hero(
                tag: widget.heroTag,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: img,
                ),
              )
            : InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: img,
              ),
      ),
    );
  }
}
