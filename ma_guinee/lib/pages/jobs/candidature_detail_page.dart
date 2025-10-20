// lib/pages/jobs/candidature_detail_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class CandidatureDetailPage extends StatelessWidget {
  const CandidatureDetailPage({super.key, required this.candidature});
  final Map<String, dynamic> candidature;

  // Palette commune (conservée)
  static const kBlue = Color(0xFF1976D2);
  static const kBg = Color(0xFFF6F7F9);
  static const kRed = Color(0xFFCE1126);
  static const kYellow = Color(0xFFFCD116);
  static const kGreen = Color(0xFF009460);

  static final _sb = Supabase.instance.client;

  void _toast(BuildContext context, String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _openCv(BuildContext context) async {
    try {
      final raw = (candidature['cv_url'] as String?)?.trim();
      final isPublic = candidature['cv_is_public'] == true;

      if (raw == null || raw.isEmpty) {
        _toast(context, 'Aucun CV joint.');
        return;
      }

      // Si public on a déjà une URL ; sinon on génère un lien signé depuis le path privé.
      final String url = (isPublic || raw.startsWith('http'))
          ? raw
          : await _sb.storage.from('cvs').createSignedUrl(raw, 300);

      final ok =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) _toast(context, 'Ouverture du CV impossible.');
    } catch (e) {
      _toast(context, 'Impossible d’ouvrir le CV : $e');
    }
  }

  Color _statutColor(String s) {
    switch (s.toLowerCase()) {
      case 'refusee':
        return kRed;
      case 'acceptee':
        return kGreen;
      case 'en_cours':
      case 'en cours':
        return kYellow;
      case 'envoyee':
      default:
        return kBlue;
    }
  }

  String _statutLabel(String s) {
    switch (s.toLowerCase()) {
      case 'refusee':
        return 'Refusée';
      case 'acceptee':
        return 'Acceptée';
      case 'en_cours':
      case 'en cours':
        return 'En cours';
      case 'envoyee':
      default:
        return 'Envoyée';
    }
  }

  @override
  Widget build(BuildContext context) {
    final prenom = (candidature['prenom'] ?? '').toString().trim();
    final nom = (candidature['nom'] ?? '').toString().trim();
    final fullName = ([prenom, nom]..removeWhere((s) => s.isEmpty)).join(' ');
    final tel = (candidature['telephone'] ?? '').toString();
    final email = (candidature['email'] ?? '').toString();
    final lettre = (candidature['lettre'] ?? '').toString();
    final statut = (candidature['statut'] ?? '').toString();

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: .5,
        title: Text(
          fullName.isNotEmpty ? fullName : (tel.isNotEmpty ? tel : 'Candidat'),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _CardLine(
            icon: Icons.badge_outlined,
            label: 'Nom',
            value: fullName.isNotEmpty ? fullName : '—',
          ),
          _CardLine(
            icon: Icons.phone,
            label: 'Téléphone',
            value: tel.isNotEmpty ? tel : '—',
          ),
          _CardLine(
            icon: Icons.email_outlined,
            label: 'Email',
            value: email.isNotEmpty ? email : '—',
          ),

          // Statut avec pastille colorée
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.timeline, color: Colors.black54),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Statut', style: TextStyle(color: Colors.black54)),
                ),
                _StatusChip(
                  text: _statutLabel(statut),
                  color: _statutColor(statut),
                ),
              ],
            ),
          ),

          // Lettre
          if (lettre.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text('Lettre / Message',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(lettre),
            ),
          ],
          const SizedBox(height: 16),

          // CV
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    candidature['cv_is_public'] == true
                        ? 'CV (public)'
                        : 'CV (privé)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openCv(context),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Voir le CV'),
                  style: TextButton.styleFrom(foregroundColor: kGreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardLine extends StatelessWidget {
  const _CardLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Text(value),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: StadiumBorder(side: BorderSide(color: color.withOpacity(.45))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: color),
            const SizedBox(width: 6),
            Text(text,
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
