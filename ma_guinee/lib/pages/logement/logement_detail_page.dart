// lib/pages/logement/logement_detail_page.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart'; // 👈 PARTAGER

import '../../services/logement_service.dart';
import '../../models/logement_models.dart';
import '../../routes.dart';

// user
import '../../providers/user_provider.dart';
import '../../models/utilisateur_model.dart';

// pages
import 'logement_edit_page.dart';
import 'package:ma_guinee/pages/messages/message_chat_page.dart'; // ⬅️ ouvre le chat après l’envoi

class LogementDetailPage extends StatefulWidget {
  const LogementDetailPage({super.key, required this.logementId});
  final String logementId;

  @override
  State<LogementDetailPage> createState() => _LogementDetailPageState();
}

class _LogementDetailPageState extends State<LogementDetailPage> {
  final _svc = LogementService();
  final _page = PageController();
  final _sb = Supabase.instance.client;

  LogementModel? _bien;
  bool _loading = true;
  String? _error;
  int _pageIndex = 0;

  bool _fav = false; // favori pour l'utilisateur courant

  // Compose (message)
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  // --- signalement ---
  bool _sendingReport = false; // 👈 anti double-clic report

  // Palette
  Color get _primary => const Color(0xFF0B3A6A);
  Color get _accent => const Color(0xFFE1005A);
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get _chipBg => _isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);

  String? _currentUserId() {
    try {
      final u = context.read<UserProvider?>()?.utilisateur;
      final id = (u as UtilisateurModel?)?.id;
      if (id != null && id.toString().isNotEmpty) return id.toString();
    } catch (_) {}
    return _sb.auth.currentUser?.id;
  }

  bool get _isOwner {
    final b = _bien;
    final me = _currentUserId();
    return b != null && me != null && me == b.userId;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _page.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.getById(widget.logementId);

      bool fav = false;
      final me = _currentUserId();
      if (me != null) {
        final rows = await _sb
            .from('logement_favoris')
            .select('logement_id')
            .eq('user_id', me)
            .eq('logement_id', widget.logementId)
            .limit(1);
        fav = (rows is List && rows.isNotEmpty);
      }

      if (!mounted) return;
      setState(() {
        _bien = data;
        _fav = fav;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // -------- actions --------
  void _openMap() {
    final b = _bien;
    if (b == null) return;
    if (b.lat == null || b.lng == null) {
      _snack("Coordonnées indisponibles pour ce bien.");
      return;
    }
    Navigator.pushNamed(context, AppRoutes.logementMap, arguments: {
      'id': b.id,
      'lat': b.lat,
      'lng': b.lng,
      'titre': b.titre,
      'ville': b.ville,
      'commune': b.commune,
    });
  }

  // ➜ Edition
  Future<void> _edit() async {
    final b = _bien;
    if (b == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LogementEditPage(existing: b)),
    );
    if (mounted) _load();
  }

  Future<void> _deleteBien() async {
    final b = _bien;
    if (b == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Voulez-vous vraiment supprimer cette annonce ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _sb.from('logements').delete().eq('id', b.id);
      if (!mounted) return;
      _snack('Annonce supprimée');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _snack('Erreur suppression: $e');
    }
  }

  // 🔹 COMPOSE DANS LA PAGE
  void _openMessages() {
    final b = _bien;
    if (b == null) return;
    _msgCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Message • ${b.titre}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _msgCtrl,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Écrire votre message…',
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _sending ? null : () => _sendMessage(closeAfter: true),
                        icon: _sending
                            ? const SizedBox(
                                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send),
                        label: Text(_sending ? 'Envoi…' : 'Envoyer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// ✅ Envoie le message
  Future<void> _sendMessage({bool closeAfter = false}) async {
    final b = _bien;
    if (b == null) return;
    final me = _currentUserId();
    if (me == null) {
      _snack("Connecte-toi pour envoyer un message.");
      Navigator.pushNamed(context, AppRoutes.login);
      return;
    }
    final body = _msgCtrl.text.trim();
    if (body.isEmpty) return;

    setState(() => _sending = true);
    try {
      await _sb.from('messages').insert({
        'sender_id': me,
        'receiver_id': b.userId,
        'contexte': 'logement', // 🔁 CORRIGÉ
        'annonce_id': b.id, // on réutilise annonce_id pour pointer le logement
        'annonce_titre': b.titre,
        'contenu': body,
        'date_envoi': DateTime.now().toIso8601String(),
        'lu': false,
      });

      if (!mounted) return;

      _msgCtrl.clear();
      if (closeAfter) {
        Navigator.of(context).maybePop();
        await Future.delayed(const Duration(milliseconds: 120));
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MessageChatPage(
            peerUserId: b.userId,
            title: b.titre,
            contextType: 'logement', // 🔁 CORRIGÉ
            contextId: b.id,
            contextTitle: b.titre,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snack("Erreur envoi: $e");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _callOwner() async {
    final tel = _bien?.contactTelephone?.trim();
    if (tel == null || tel.isEmpty) {
      _snack("Numéro indisponible.");
      return;
    }
    final uri = Uri(scheme: 'tel', path: tel);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _snack("Impossible d’ouvrir l’app Téléphone.");
    }
  }

  Future<void> _toggleFav() async {
    final me = _currentUserId();
    if (me == null) {
      _snack("Connecte-toi pour ajouter aux favoris.");
      Navigator.pushNamed(context, AppRoutes.login);
      return;
    }
    final id = widget.logementId;
    try {
      if (_fav) {
        await _sb.from('logement_favoris').delete().eq('user_id', me).eq('logement_id', id);
        setState(() => _fav = false);
        _snack("Retiré des favoris");
      } else {
        await _sb.from('logement_favoris').insert({'user_id': me, 'logement_id': id});
        setState(() => _fav = true);
        _snack("Ajouté aux favoris");
      }
    } catch (e) {
      _snack("Erreur favoris : $e");
    }
  }

  String _formatPrice(num? value, LogementMode mode) {
    if (value == null) return 'Prix à discuter';
    if (value >= 1000000) {
      final m = (value / 1000000).toStringAsFixed(1).replaceAll('.0', '');
      return mode == LogementMode.achat ? '$m M GNF' : '$m M GNF / mois';
    }
    final s = value.toStringAsFixed(0);
    return mode == LogementMode.achat ? '$s GNF' : '$s GNF / mois';
  }

  // ======= PARTAGER & SIGNALER =======

  void _shareBien() {
    final b = _bien;
    if (b == null) return;
    final lignes = <String>[
      b.titre,
      _formatPrice(b.prixGnf, b.mode),
      if (b.ville?.isNotEmpty == true) 'Ville : ${b.ville}',
      if (b.commune?.isNotEmpty == true) 'Commune : ${b.commune}',
    ];
    Share.share(lignes.join('\n'));
  }

  void _openReportSheet() {
    final b = _bien;
    if (b == null) return;
    final me = _currentUserId();
    if (me == null) {
      _snack("Connecte-toi pour signaler.");
      Navigator.pushNamed(context, AppRoutes.login);
      return;
    }
    if (_isOwner) {
      _snack("Action non autorisée pour votre propre annonce.");
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
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
              const Text('Signaler ce logement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: reasons
                    .map((r) => ChoiceChip(
                          label: Text(r),
                          selected: selected == r,
                          onSelected: (_) => setLocal(() => selected = r),
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
                  label: Text(_sendingReport ? 'Envoi…' : 'Envoyer le signalement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _sendingReport
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _sendReportToTable(selected, ctrl.text.trim());
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendReportToTable(String reason, String details) async {
    if (_sendingReport) return;
    setState(() => _sendingReport = true);

    final b = _bien!; // déjà vérifié
    final me = _currentUserId()!;

    try {
      // anti-doublon client
      final already = await _sb
          .from('reports')
          .select('id')
          .eq('context', 'logement')
          .eq('cible_id', b.id)
          .eq('reported_by', me)
          .maybeSingle();
      if (already != null) {
        _snack('Vous avez déjà signalé ce logement.');
        setState(() => _sendingReport = false);
        return;
      }

      await _sb.from('reports').insert({
        'context': 'logement',
        'cible_id': b.id,
        'owner_id': b.userId,
        'reported_by': me,
        'reason': reason,
        'details': details.isEmpty ? null : details,
        // infos utiles
        'ville': b.ville,
        'titre': b.titre,
        'prix': b.prixGnf,
        'devise': 'GNF',
        'telephone': b.contactTelephone,
        'created_at': DateTime.now().toIso8601String(),
      });

      _snack('Signalement envoyé. Merci.');
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        _snack('Déjà signalé.');
      } else {
        _snack('Erreur: ${e.message}');
      }
    } catch (e) {
      _snack('Erreur: $e');
    } finally {
      if (mounted) setState(() => _sendingReport = false);
    }
  }

  // ======= / PARTAGER & SIGNALER =======

  @override
  Widget build(BuildContext context) {
    final b = _bien;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: const Text("Détail du bien"),
        actions: [
          IconButton(
            tooltip: _fav ? "Retirer des favoris" : "Ajouter aux favoris",
            onPressed: _toggleFav,
            icon: Icon(_fav ? Icons.favorite : Icons.favorite_border, color: _fav ? Colors.red : Colors.white),
          ),
          IconButton(tooltip: "Rafraîchir", onPressed: _load, icon: const Icon(Icons.refresh, color: Colors.white)),
          PopupMenuButton<String>(
            iconColor: Colors.white,
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  _edit();
                  break;
                case 'share':
                  _shareBien();
                  break; // 👈 PARTAGER
                case 'report':
                  _openReportSheet();
                  break; // 👈 SIGNALER
                case 'delete':
                  _deleteBien();
                  break;
              }
            },
            itemBuilder: (_) => _isOwner
                ? const [
                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(value: 'share', child: Text('Partager')),
                    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ]
                : const [
                    PopupMenuItem(value: 'share', child: Text('Partager')),
                    PopupMenuItem(value: 'report', child: Text('Signaler')),
                  ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorBox(_error!)
              : b == null
                  ? const Center(child: Text("Bien introuvable"))
                  : Column(
                      children: [
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                _imagesHeader(b),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(b.titre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 8),
                                      Text(
                                        _formatPrice(b.prixGnf, b.mode),
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _accent),
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: -6,
                                        children: [
                                          _chip(b.mode == LogementMode.achat ? 'Achat' : 'Location'),
                                          _chip(logementCategorieToString(b.categorie)),
                                          if (b.chambres != null) _chip('${b.chambres} ch'),
                                          if (b.superficieM2 != null) _chip('${b.superficieM2!.toStringAsFixed(0)} m²'),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Icon(Icons.place, size: 18, color: Colors.black54),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              [
                                                if (b.adresse?.isNotEmpty == true) b.adresse!,
                                                if (b.commune?.isNotEmpty == true) b.commune!,
                                                if (b.ville?.isNotEmpty == true) b.ville!,
                                              ].join(' • '),
                                              style: const TextStyle(color: Colors.black54),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: _accent,
                                              side: BorderSide(color: _accent),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: _openMap,
                                            icon: const Icon(Icons.map_outlined),
                                            label: const Text("Carte"),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 18),
                                      const Divider(height: 1),
                                      const SizedBox(height: 18),
                                      const Text("Description",
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 8),
                                      Text(
                                        (b.description ?? '—').trim().isEmpty ? '—' : b.description!.trim(),
                                        style: const TextStyle(fontSize: 14, height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // --------- barre d’actions ---------
                        SafeArea(
                          top: false,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                            decoration: BoxDecoration(
                              color: _bg,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, -4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                if (!_isOwner) ...[
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        side: BorderSide(color: _accent),
                                        foregroundColor: _accent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: _openMessages,
                                      icon: const Icon(Icons.forum_outlined),
                                      label: const Text("Message"),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _accent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: _callOwner,
                                      icon: const Icon(Icons.call),
                                      label: const Text("Contacter"),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

      floatingActionButton: (_loading || _error != null || !_isOwner)
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text("Modifier"),
            ),
    );
  }

  // ---------- images ----------
  Widget _imagesHeader(LogementModel b) {
    final photos = b.photos.where((e) => e.trim().isNotEmpty).toList();
    final hasPhotos = photos.isNotEmpty;
    final isWide = MediaQuery.of(context).size.width >= 700;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: hasPhotos
              ? PageView.builder(
                  controller: _page,
                  itemCount: photos.length,
                  onPageChanged: (i) => setState(() => _pageIndex = i),
                  itemBuilder: (_, i) => Image.network(
                    photos[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.black26),
                      ),
                    ),
                  ),
                )
              : Container(
                  color: Colors.grey.shade200,
                  child: const Center(child: Icon(Icons.image, size: 64, color: Colors.black26)),
                ),
        ),
        if (hasPhotos) _pagerDots(photos.length),
        Positioned(
          top: 10,
          right: 10,
          child: _glass(
            child: IconButton(
              icon: const Icon(Icons.fullscreen, color: Colors.white),
              onPressed: () {
                if (photos.isEmpty) {
                  _snack("Aucune photo.");
                } else {
                  _openViewer(photos, _pageIndex);
                }
              },
            ),
          ),
        ),
        if (hasPhotos && photos.length > 1 && (isWide || kIsWeb)) ...[
          Positioned(
            left: 8,
            child: _glass(
              child: IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                onPressed: () => _page.previousPage(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            child: _glass(
              child: IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                onPressed: () => _page.nextPage(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Visionneuse plein écran
  void _openViewer(List<String> photos, int initial) {
    final ctrl = PageController(initialPage: initial);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'viewer',
      barrierColor: Colors.black.withOpacity(0.92),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, __, ___) {
        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              PageView.builder(
                controller: ctrl,
                itemCount: photos.length,
                itemBuilder: (_, i) => InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      photos[i],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined, size: 80, color: Colors.white54),
                    ),
                  ),
                ),
              ),
              if (photos.length > 1) ...[
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left, size: 36, color: Colors.white),
                    onPressed: () => ctrl.previousPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right, size: 36, color: Colors.white),
                    onPressed: () => ctrl.nextPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
              ],
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pagerDots(int count) => Positioned(
        bottom: 10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: List.generate(
              count,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _pageIndex == i ? 9 : 7,
                height: _pageIndex == i ? 9 : 7,
                decoration: BoxDecoration(
                  color: _pageIndex == i ? Colors.white : Colors.white54,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _glass({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );

  Widget _errorBox(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.red),
              const SizedBox(height: 10),
              Text(msg, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text("Réessayer")),
            ],
          ),
        ),
      );

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}
