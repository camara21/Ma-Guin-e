// lib/pages/jobs/job_detail_page.dart
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/jobs_service.dart';

/// ───────────────────────────────────────────────────────────────────
/// Format montant avec des points: 1.000 / 25.000 / 1.250.000
String _fmtMontant(dynamic v) {
  if (v == null) return '';
  final n = (v is num) ? v : num.tryParse(v.toString());
  if (n == null) return v.toString();
  final s = n.toStringAsFixed(0);
  final b = StringBuffer();
  var c = 0;
  for (int i = s.length - 1; i >= 0; i--) {
    b.write(s[i]);
    c++;
    if (c % 3 == 0 && i != 0) b.write('.');
  }
  return b.toString().split('').reversed.join();
}
/// ───────────────────────────────────────────────────────────────────

class JobDetailPage extends StatefulWidget {
  const JobDetailPage({super.key, required this.jobId});
  final String jobId;

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  // 🎨 Palette
  static const kBlue   = Color(0xFF1976D2);
  static const kBg     = Color(0xFFF6F7F9);
  static const kRed    = Color(0xFFCE1126);
  static const kYellow = Color(0xFFFCD116);
  static const kGreen  = Color(0xFF009460);

  final _svc = JobsService();
  final _sb  = Supabase.instance.client;

  Map<String, dynamic>? job;
  Map<String, dynamic>? employer;
  bool _loading = true;

  // ⭐ Favori
  bool _isFavorite = false;
  bool _togglingFav = false;

  // 👤 Candidature rapide
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _letterCtrl    = TextEditingController();

  // 📎 CV
  String? _cvBucket; // 'cvs' ou 'cvs_public'
  String? _cvPath;
  String? _cvName;
  bool _cvPublic = false;

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _letterCtrl.dispose();
    super.dispose();
  }

  // ───────────────── DATA ─────────────────
  String _relative(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().toLocal().difference(d);
      if (diff.inMinutes < 60) return 'publié il y a ${diff.inMinutes} min';
      if (diff.inHours   < 24) return 'publié il y a ${diff.inHours} h';
      if (diff.inDays    < 7)  return 'publié il y a ${diff.inDays} j';
      final dd = d.day.toString().padLeft(2,'0');
      final mm = d.month.toString().padLeft(2,'0');
      return 'publié le $dd/$mm/${d.year}';
    } catch (_) { return ''; }
  }

  String _relativeFromJob(Map<String,dynamic> j) {
    final iso = (j['cree_le'] ?? j['created_at'] ?? j['createdAt'] ?? j['creeLe'])?.toString();
    return _relative(iso);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final j = await _svc.sb.from('emplois').select('*')
          .eq('id', widget.jobId).maybeSingle();

      Map<String, dynamic>? emp;
      final empId = j?['employeur_id'];
      if (empId != null) {
        emp = await _svc.employeur(empId.toString());
      }

      // état favori → public.emplois_favoris (par utilisateur)
      bool fav = false;
      final uid = _sb.auth.currentUser?.id;
      if (uid != null) {
        final row = await _svc.sb
            .from('emplois_favoris')
            .select('emploi_id')
            .eq('utilisateur_id', uid)
            .eq('emploi_id', widget.jobId)
            .maybeSingle();
        fav = row != null;
      }

      if (!mounted) return;
      setState(() {
        job         = j == null ? null : Map<String, dynamic>.from(j as Map);
        employer    = emp;
        _isFavorite = fav;
        _loading    = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Impossible de charger l’offre.');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_togglingFav) return;
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) {
      _toast('Connectez-vous pour ajouter des favoris.');
      return;
    }
    setState(() => _togglingFav = true);
    try {
      if (_isFavorite) {
        await _sb.from('emplois_favoris').delete().match({
          'utilisateur_id': uid,
          'emploi_id': widget.jobId,
        });
      } else {
        await _sb.from('emplois_favoris').insert({
          'utilisateur_id': uid,
          'emploi_id': widget.jobId,
        });
      }
      if (!mounted) return;
      setState(() => _isFavorite = !_isFavorite);
      _toast(_isFavorite ? 'Ajouté aux favoris' : 'Retiré des favoris');
    } catch (e) {
      _toast('Action impossible : $e');
    } finally {
      if (mounted) setState(() => _togglingFav = false);
    }
  }

  // ───────────────── CV ─────────────────
  String _sanitizeFileName(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');

  String _guessContentType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    if (ext == 'pdf') return 'application/pdf';
    if (ext == 'doc') return 'application/msword';
    if (ext == 'docx') {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return 'application/octet-stream';
  }

  Future<void> _pickCv() async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx'],
    );
    if (res == null || res.files.isEmpty) return;

    final file = res.files.single;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) {
      _toast("Impossible de lire le fichier. Réessayez.");
      return;
    }

    try {
      final userId   = _sb.auth.currentUser?.id ?? 'anonymous';
      final safeName = _sanitizeFileName(file.name);
      final path     = '$userId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final bucket   = _cvPublic ? 'cvs_public' : 'cvs';

      await _sb.storage.from(bucket).uploadBinary(
        path, bytes,
        fileOptions: FileOptions(
          upsert: false,
          cacheControl: '3600',
          contentType: _guessContentType(file.name),
        ),
      );

      if (!mounted) return;
      setState(() {
        _cvName   = file.name;
        _cvBucket = bucket;
        _cvPath   = path;
      });
      _toast(_cvPublic ? 'CV public ajouté ✅' : 'CV ajouté (privé) ✅');
    } catch (e) {
      _toast('Échec upload CV : $e');
    }
  }

  Future<void> _viewCv() async {
    if (_cvPath == null || _cvBucket == null) return;
    try {
      String url;
      if (_cvBucket == 'cvs_public') {
        url = _sb.storage.from('cvs_public').getPublicUrl(_cvPath!);
      } else {
        url = await _sb.storage.from('cvs').createSignedUrl(_cvPath!, 300);
      }
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) _toast('Impossible d’ouvrir le CV.');
    } catch (_) {
      _toast('Aperçu du CV indisponible.');
    }
  }

  Future<void> _removeCv() async {
    if (_cvPath == null || _cvBucket == null) {
      setState(() { _cvName = _cvPath = _cvBucket = null; });
      return;
    }
    try {
      await _sb.storage.from(_cvBucket!).remove([_cvPath!]);
      if (!mounted) return;
      setState(() { _cvName = _cvPath = _cvBucket = null; });
      _toast('CV retiré.');
    } catch (e) {
      _toast('Suppression impossible : $e');
    }
  }

  // ───────────────── Candidature ─────────────────
  Future<void> _submit() async {
    final user = _sb.auth.currentUser;
    if (user == null) { _toast('Veuillez vous connecter pour postuler.'); return; }

    final prenom = _firstNameCtrl.text.trim();
    final nom    = _lastNameCtrl.text.trim();
    final phone  = _phoneCtrl.text.trim();
    final email  = _emailCtrl.text.trim();
    final lettre = _letterCtrl.text.trim();
    if (prenom.isEmpty || nom.isEmpty) { _toast('Prénom et Nom sont requis'); return; }
    if (phone.isEmpty) { _toast('Téléphone requis'); return; }
    if (_cvPath == null || _cvBucket == null) { _toast('Merci de joindre votre CV'); return; }

    final String cvValue = (_cvBucket == 'cvs_public')
        ? _sb.storage.from('cvs_public').getPublicUrl(_cvPath!)
        : _cvPath!;

    try {
      await _svc.sb.from('candidatures').insert({
        'emploi_id'   : widget.jobId,
        'candidat_id' : user.id,
        'prenom'      : prenom,
        'nom'         : nom,
        'telephone'   : phone,
        if (email.isNotEmpty) 'email': email,
        if (lettre.isNotEmpty) 'lettre': lettre,
        'cv_url'      : cvValue,
        'cv_is_public': _cvBucket == 'cvs_public',
      });
      if (!mounted) return;
      _toast('Candidature envoyée ✅');
      Navigator.pop(context);
    } catch (e) {
      final msg = e.toString();
      final isUnique =
          (e is PostgrestException && e.code == '23505') ||
          msg.contains('23505') || msg.contains('candidatures_emploi_id_candidat_key');
      _toast(isUnique ? 'Vous avez déjà postulé à cette offre.' : 'Envoi impossible : $e');
    }
  }

  // ───────────────── UI ─────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (job == null) {
      return const Scaffold(body: Center(child: Text('Offre introuvable')));
    }

    final j = job!;
    final title       = (j['titre'] ?? 'Offre').toString();
    final ville       = (j['ville'] ?? '').toString();
    final commune     = (j['commune'] ?? '').toString();
    final contrat     = (j['type_contrat'] ?? '').toString();
    final teletravail = j['teletravail'] == true;

    final salMin         = j['salaire_min_gnf'];
    final salMax         = j['salaire_max_gnf'];
    final periodeSalaire = (j['periode_salaire'] ?? 'mois').toString();

    final description = (j['description'] ?? '').toString();
    final exigences   = (j['exigences'] ?? '').toString();
    final avantages   = (j['avantages'] ?? '').toString();

    // 👉 libellé salaire explicite
    String salaireText() {
      final per = (periodeSalaire.isEmpty ? 'mois' : periodeSalaire);
      if (salMin != null && salMax != null) {
        return 'Salaire : entre ${_fmtMontant(salMin)} et ${_fmtMontant(salMax)} GNF par $per';
      } else if (salMin != null) {
        return 'Salaire : ${_fmtMontant(salMin)} GNF par $per';
      } else if (salMax != null) {
        return 'Salaire : jusqu’à ${_fmtMontant(salMax)} GNF par $per';
      }
      return 'Salaire : à négocier';
    }

    final logoUrl = (employer?['logo_url'] as String?) ?? (employer?['logo'] as String?);
    final publie  = _relativeFromJob(j);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: .5,
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: _isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
            onPressed: _togglingFav ? null : _toggleFavorite,
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? kRed : Colors.black87,
            ),
          ),
        ],
      ),

      // CTA collant
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              SizedBox(
                height: 48,
                width: 52,
                child: OutlinedButton(
                  onPressed: _togglingFav ? null : _toggleFavorite,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isFavorite ? kRed : Colors.black87,
                    side: BorderSide(color: _isFavorite ? kRed : Colors.black26),
                  ),
                  child: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: _submit,
                  child: const Text('Postuler'),
                ),
              ),
            ],
          ),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120), // espace pr le CTA bas
          children: [
            // ── En-tête
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (logoUrl != null && logoUrl.trim().isNotEmpty)
                        CircleAvatar(radius: 22, backgroundImage: NetworkImage(logoUrl))
                      else
                        const CircleAvatar(
                          radius: 22, backgroundColor: kBlue,
                          child: Icon(Icons.business, color: Colors.white, size: 20),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (employer?['nom'] ?? 'Employeur').toString(),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            if (publie.isNotEmpty)
                              Text(publie, style: const TextStyle(color: Colors.black45, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _Tag(icon: Icons.place, text: commune.isNotEmpty ? '$ville, $commune' : ville),
                      if (contrat.isNotEmpty)
                        _Tag(icon: Icons.badge_outlined, text: contrat.toUpperCase()),
                      // 💰 Salaire explicite
                      _Tag(icon: Icons.payments_outlined, text: salaireText()),
                      _Tag(
                        icon: teletravail ? Icons.home_work_outlined : Icons.pin_drop_outlined,
                        text: teletravail ? 'Télétravail' : 'Sur site',
                        color: teletravail ? kGreen : kYellow,
                      ),
                      if ((employer?['telephone'] ?? '').toString().isNotEmpty)
                        _MiniPill(icon: Icons.phone, text: employer!['telephone'].toString()),
                      if ((employer?['email'] ?? '').toString().isNotEmpty)
                        _MiniPill(icon: Icons.email_outlined, text: employer!['email'].toString()),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── 🔲 Bloc unique "lisse" à la HelloWork
            if (description.isNotEmpty ||
                exigences.isNotEmpty ||
                avantages.isNotEmpty)
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty) ...[
                      const _InnerTitle('Les missions du poste'),
                      const SizedBox(height: 6),
                      _ExpandableText(description),
                    ],
                    if (description.isNotEmpty && (exigences.isNotEmpty || avantages.isNotEmpty))
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),
                    if (exigences.isNotEmpty) ...[
                      const _InnerTitle('Le profil recherché'),
                      const SizedBox(height: 6),
                      _ExpandableText(exigences),
                    ],
                    if (exigences.isNotEmpty && avantages.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),
                    if (avantages.isNotEmpty) ...[
                      const _InnerTitle('Infos complémentaires'),
                      const SizedBox(height: 6),
                      _ExpandableText(avantages),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // ── Candidature rapide (compact)
            const _SectionTitle('Envoyez votre candidature'),
            _Card(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _firstNameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _dec('Prénom', Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _lastNameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _dec('Nom', Icons.badge),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _dec('Téléphone', Icons.phone),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _dec('Email (optionnel)', Icons.email_outlined),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _letterCtrl,
                    maxLines: 5,
                    decoration: _dec('Message / Lettre (court)', Icons.edit_note_outlined),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.attach_file),
                          label: Text(_cvName == null ? 'Joindre mon CV (PDF/DOCX)' : 'Remplacer le CV'),
                          onPressed: _pickCv,
                        ),
                      ),
                    ],
                  ),
                  if (_cvPath != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.attachment, color: _cvBucket == 'cvs_public' ? kGreen : Colors.black54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _cvName ?? 'cv',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(tooltip: 'Voir le CV', icon: const Icon(Icons.open_in_new), onPressed: _viewCv),
                          IconButton(tooltip: 'Supprimer le CV', icon: const Icon(Icons.close), onPressed: _removeCv),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _cvPublic,
                    onChanged: (_cvPath == null) ? (v) => setState(() => _cvPublic = v ?? false) : null,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Rendre mon CV public (visible par les recruteurs)'),
                    subtitle: const Text('Si décoché : CV privé, accessible via lien signé'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // Input decoration
  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: kBlue),
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: kBlue, width: 2),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}

// ───────────────── Helpers UI ─────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: child,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InnerTitle extends StatelessWidget {
  const _InnerTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.black54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(side: BorderSide(color: Colors.black12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.black54),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText(this.text, {this.maxLines = 8});
  final String text;
  final int maxLines;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final textWidget = Text(
      widget.text,
      maxLines: _expanded ? null : widget.maxLines,
      overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
      style: style,
    );

    final moreNeeded = widget.text.length > 320; // heuristique simple

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        textWidget,
        if (moreNeeded) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Voir moins' : 'Voir plus',
              style: const TextStyle(
                color: _JobDetailPageState.kBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
