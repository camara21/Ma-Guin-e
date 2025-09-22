// lib/pages/jobs/job_detail_page.dart
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/jobs_service.dart';

/// ───────────────────────────────────────────────────────────────────
/// 1) Helpers formats
String _fmtMontant(dynamic v) {
  if (v == null) return '';
  final n = (v is num) ? v : num.tryParse(v.toString());
  if (n == null) return v.toString();
  final s = n.toStringAsFixed(0);
  final out = StringBuffer();
  int c = 0;
  for (int i = s.length - 1; i >= 0; i--) {
    out.write(s[i]);
    c++;
    if (c % 3 == 0 && i != 0) out.write('.');
  }
  return out.toString().split('').reversed.join();
}

String _relativeFromIso(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final d = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().toLocal().difference(d);
    if (diff.inMinutes < 60) return 'Publié il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Publié il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Publié il y a ${diff.inDays} j';
    return 'Publié le ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  } catch (_) {
    return '';
  }
}
/// ───────────────────────────────────────────────────────────────────

class JobDetailPage extends StatefulWidget {
  final String jobId;
  const JobDetailPage({super.key, required this.jobId});

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  // 🎨 Palette
  static const kBlue = Color(0xFF1976D2);
  static const kBg = Color(0xFFF6F7F9);
  static const kRed = Color(0xFFCE1126);
  static const kYellow = Color(0xFFFCD116);
  static const kGreen = Color(0xFF009460);

  final _svc = JobsService();
  final _sb = Supabase.instance.client;

  Map<String, dynamic>? job;
  Map<String, dynamic>? employer;
  bool _loading = true;

  // ⭐ Favori
  bool _isFavorite = false;
  bool _togglingFav = false;

  // 👤 Infos candidat
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _letterCtrl = TextEditingController();

  // 📎 CV (état local)
  String? _cvBucket; // 'cvs' (privé) ou 'cvs_public' (public)
  String? _cvPath; // chemin interne 'uid/ts_nom.ext'
  String? _cvName; // nom d’origine pour affichage
  bool _cvPublic = false; // choix utilisateur
  bool _posting = false;

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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final j = await _svc.sb
          .from('emplois')
          .select('*')
          .eq('id', widget.jobId)
          .maybeSingle();

      Map<String, dynamic>? emp;
      final empId = j?['employeur_id'];
      if (empId != null) {
        emp = await _svc.employeur(empId.toString());
      }

      bool fav = false;
      final uid = _sb.auth.currentUser?.id;
      if (uid != null) {
        // ✅ table officielle des favoris
        final f = await _svc.sb
            .from('emplois_favoris')
            .select('emploi_id')
            .eq('utilisateur_id', uid)
            .eq('emploi_id', widget.jobId)
            .maybeSingle();
        fav = f != null;
      }

      if (!mounted) return;
      setState(() {
        job = j == null ? null : Map<String, dynamic>.from(j as Map);
        employer = emp;
        _isFavorite = fav;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Impossible de charger l’offre.');
    }
  }

  // ✅ Toggle favori directement sur public.emplois_favoris
  Future<void> _toggleFavorite() async {
    if (_togglingFav) return;
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) {
      _toast('Connectez-vous pour gérer vos favoris.');
      return;
    }
    setState(() => _togglingFav = true);
    try {
      if (_isFavorite) {
        await _sb.from('emplois_favoris').delete().match({
          'utilisateur_id': uid,
          'emploi_id': widget.jobId,
        });
        if (mounted) setState(() => _isFavorite = false);
        _toast('Retiré des favoris');
      } else {
        await _sb.from('emplois_favoris').insert({
          'utilisateur_id': uid,
          'emploi_id': widget.jobId,
        });
        if (mounted) setState(() => _isFavorite = true);
        _toast('Ajouté aux favoris');
      }
    } catch (e) {
      _toast('Action impossible : $e');
    } finally {
      if (mounted) setState(() => _togglingFav = false);
    }
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: kBlue),
      border: const OutlineInputBorder(),
      focusedBorder:
          const OutlineInputBorder(borderSide: BorderSide(color: kBlue, width: 2)),
      enabledBorder:
          const OutlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

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
      final userId = _sb.auth.currentUser?.id ?? 'anonymous';
      final safeName = _sanitizeFileName(file.name);
      final path =
          '$userId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final targetBucket = _cvPublic ? 'cvs_public' : 'cvs';

      await _sb.storage.from(targetBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: false,
              cacheControl: '3600',
              contentType: _guessContentType(file.name),
            ),
          );

      if (!mounted) return;
      setState(() {
        _cvName = file.name;
        _cvBucket = targetBucket;
        _cvPath = path;
      });
      _toast(_cvPublic ? 'CV public ajouté ✅' : 'CV ajouté (privé) ✅');
    } catch (e) {
      if (!mounted) return;
      _toast('Échec de l’upload du CV : $e');
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
      final ok = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!ok) _toast('Impossible d’ouvrir le CV.');
    } catch (_) {
      _toast('Aperçu du CV indisponible.');
    }
  }

  Future<void> _removeCv() async {
    if (_cvPath == null || _cvBucket == null) {
      setState(() {
        _cvName = null;
        _cvPath = null;
        _cvBucket = null;
      });
      return;
    }
    try {
      await _sb.storage.from(_cvBucket!).remove([_cvPath!]);
      if (!mounted) return;
      setState(() {
        _cvName = null;
        _cvPath = null;
        _cvBucket = null;
      });
      _toast('CV retiré.');
    } catch (e) {
      if (!mounted) return;
      _toast('Suppression impossible : $e');
    }
  }

  // ✅ Envoi candidature (message clair si déjà postulé)
  Future<void> _submit() async {
    final user = _sb.auth.currentUser;
    if (user == null) {
      _toast('Veuillez vous connecter pour postuler.');
      return;
    }

    final prenom = _firstNameCtrl.text.trim();
    final nom = _lastNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final lettre = _letterCtrl.text.trim();

    if (prenom.isEmpty || nom.isEmpty) {
      _toast('Prénom et Nom sont requis');
      return;
    }
    if (phone.isEmpty) {
      _toast('Téléphone requis');
      return;
    }
    if (_cvPath == null || _cvBucket == null) {
      _toast('Merci de joindre votre CV');
      return;
    }

    final String cvValue = (_cvBucket == 'cvs_public')
        ? _sb.storage.from('cvs_public').getPublicUrl(_cvPath!)
        : _cvPath!;

    setState(() => _posting = true);
    try {
      await _svc.sb.from('candidatures').insert({
        'emploi_id': widget.jobId,
        'candidat': user.id, // compat historic
        'candidat_id': user.id,
        'prenom': prenom,
        'nom': nom,
        'telephone': phone,
        if (email.isNotEmpty) 'email': email,
        if (lettre.isNotEmpty) 'lettre': lettre,
        'cv_url': cvValue,
        'cv_is_public': _cvBucket == 'cvs_public',
      });

      if (!mounted) return;
      _toast('Candidature envoyée ✅');
      Navigator.pop(context);
    } catch (e) {
      final msg = e.toString();
      final isUniqueViolation =
          (e is PostgrestException && e.code == '23505') ||
              msg.contains('23505') ||
              msg.contains('candidatures_emploi_id_candidat_key');

      if (isUniqueViolation) {
        _toast('Vous avez déjà postulé à cette offre.');
      } else {
        _toast('Envoi impossible : $e');
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (job == null) {
      return const Scaffold(body: Center(child: Text('Offre introuvable')));
    }

    final title = (job!['titre'] ?? 'Offre').toString();
    final ville = (job!['ville'] ?? '').toString();
    final commune = (job!['commune'] ?? '').toString();
    final typeContrat = (job!['type_contrat'] ?? '').toString();
    final teletravail = job!['teletravail'] == true;

    final salMin = job!['salaire_min_gnf'];
    final salMax = job!['salaire_max_gnf'];
    final periodeSalaire = (job!['periode_salaire'] ?? '').toString();
    final publieAt = (job!['cree_le'] ??
            job!['created_at'] ??
            job!['creeLe'] ??
            job!['createdAt'])
        ?.toString();

    final description = (job!['description'] ?? '').toString();
    final exigences = (job!['exigences'] ?? '').toString();
    final avantages = (job!['avantages'] ?? '').toString();

    String salaireStr() {
      if (salMin != null) {
        final base = salMax != null
            ? '${_fmtMontant(salMin)} - ${_fmtMontant(salMax)}'
            : _fmtMontant(salMin);
        final per = (periodeSalaire.isNotEmpty ? periodeSalaire : 'mois');
        return '$base (GNF / $per)';
      }
      return 'Salaire : à négocier';
    }

    final logoUrl =
        (employer?['logo_url'] as String?) ?? (employer?['logo'] as String?);

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
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // ---- En-tête employeur + infos principales
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (logoUrl != null && logoUrl.trim().isNotEmpty)
                        CircleAvatar(
                            radius: 22, backgroundImage: NetworkImage(logoUrl))
                      else
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: kBlue,
                          child:
                              Icon(Icons.business, color: Colors.white, size: 20),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          (employer?['nom'] ?? 'Employeur').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 16, color: Colors.black45),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${ville}${commune.isNotEmpty ? ', $commune' : ''}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.badge_outlined,
                          size: 16, color: Colors.black45),
                      const SizedBox(width: 6),
                      Text(
                        typeContrat.toUpperCase(),
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    salaireStr(),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (teletravail)
                        const _ChipInfo(
                            text: 'Télétravail',
                            color: kGreen,
                            icon: Icons.home_work_outlined),
                      if (!teletravail)
                        const _ChipInfo(
                            text: 'Sur site',
                            color: kYellow,
                            icon: Icons.location_on_outlined),
                      if (employer?['telephone'] != null &&
                          (employer!['telephone'] as String).isNotEmpty)
                        _MiniPill(
                            icon: Icons.phone,
                            text: employer!['telephone'].toString()),
                      if (employer?['email'] != null &&
                          (employer!['email'] as String).isNotEmpty)
                        _MiniPill(
                            icon: Icons.email_outlined,
                            text: employer!['email'].toString()),
                    ],
                  ),
                  if (publieAt != null && publieAt.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.schedule,
                            size: 16, color: Colors.black45),
                        const SizedBox(width: 6),
                        Text(
                          _relativeFromIso(publieAt),
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ---- Description
            if (description.isNotEmpty) ...[
              const _SectionTitle('Description'),
              _Card(child: Text(description)),
              const SizedBox(height: 12),
            ],

            // ---- Exigences
            if (exigences.isNotEmpty) ...[
              const _SectionTitle('Exigences'),
              _Card(child: Text(exigences)),
              const SizedBox(height: 12),
            ],

            // ---- Avantages
            if (avantages.isNotEmpty) ...[
              const _SectionTitle('Avantages'),
              _Card(child: Text(avantages)),
              const SizedBox(height: 12),
            ],

            // ---- Candidature rapide
            const _SectionTitle('Candidature rapide'),
            _Card(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _firstNameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration:
                              _dec('Prénom (obligatoire)', Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _lastNameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _dec('Nom (obligatoire)', Icons.badge),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _dec('Téléphone (obligatoire)', Icons.phone),
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
                    decoration:
                        _dec('Message / Lettre (court)', Icons.edit_note_outlined),
                  ),
                  const SizedBox(height: 10),

                  // --- Boutons & aperçu CV
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.attach_file),
                          label: Text(_cvName == null
                              ? 'Joindre mon CV (PDF/DOCX)'
                              : 'Remplacer le CV'),
                          onPressed: _pickCv,
                        ),
                      ),
                    ],
                  ),
                  if (_cvPath != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.attachment,
                              color:
                                  _cvBucket == 'cvs_public' ? kGreen : Colors.black54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _cvName ?? 'cv',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Voir le CV',
                            icon: const Icon(Icons.open_in_new),
                            onPressed: _viewCv,
                          ),
                          IconButton(
                            tooltip: 'Supprimer le CV',
                            icon: const Icon(Icons.close),
                            onPressed: _removeCv,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _cvPublic,
                    onChanged: (_cvPath == null)
                        ? (v) => setState(() => _cvPublic = v ?? false)
                        : null, // désactivée si un CV est déjà uploadé
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                        'Rendre mon CV public (visible par tous les recruteurs)'),
                    subtitle: const Text(
                        'Si décoché : CV privé, accessible via lien signé uniquement'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _togglingFav ? null : _toggleFavorite,
                    icon: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorite ? kRed : Colors.black87,
                    ),
                    label: Text(
                        _isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kBlue,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      textStyle:
                          const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: _posting ? null : _submit,
                    child: _posting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Postuler'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------- UI helpers

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
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ChipInfo extends StatelessWidget {
  const _ChipInfo(
      {required this.text, required this.color, required this.icon});
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape:
          StadiumBorder(side: BorderSide(color: color.withOpacity(.35))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(text,
                style:
                    TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
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
      shape:
          const StadiumBorder(side: BorderSide(color: Colors.black12)),
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
