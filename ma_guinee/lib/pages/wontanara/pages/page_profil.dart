import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme_wontanara.dart';
import 'package:ma_guinee/providers/user_provider.dart';

class PageProfil extends StatelessWidget {
  const PageProfil({super.key});

  @override
  Widget build(BuildContext context) {
    final supaUser = Supabase.instance.client.auth.currentUser;
    final appUser = context.watch<UserProvider>().utilisateur;

    // --------- Données venant du profil général Soneya ---------
    String displayName = 'Profil Wontanara';
    String? photoUrl;

    if (appUser != null) {
      displayName = '${appUser.prenom} ${appUser.nom}'.trim();
      photoUrl = appUser.photoUrl;
    }

    // --------- Métadonnées Wontanara (quartier, rôle, points...) ---------
    String quartier = 'Quartier inconnu';
    String prefecture = 'Préfecture inconnue';
    String role = 'Citoyen';

    int points = 0;
    int nbAides = 0;

    bool isEntrepriseRecyclage = false;
    bool isModerateur = false;

    if (supaUser != null) {
      final meta = supaUser.userMetadata ?? {};

      final q = (meta['quartier'] as String?)?.trim();
      if (q != null && q.isNotEmpty) quartier = q;

      final p = (meta['prefecture'] as String?)?.trim();
      if (p != null && p.isNotEmpty) prefecture = p;

      final r = (meta['role'] as String?)?.trim();
      if (r != null && r.isNotEmpty) role = r;

      points = (meta['points'] as int?) ?? 0;
      nbAides = (meta['aides'] as int?) ?? 0;

      // Entreprise de recyclage
      final typeProfil = (meta['type_profil'] as String?)?.trim();
      if (typeProfil == 'entreprise_recyclage') {
        isEntrepriseRecyclage = true;
      }

      // Modérateur local
      final modMeta = meta['is_moderateur_wontanara'];
      if (modMeta is bool && modMeta == true) {
        isModerateur = true;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: ThemeWontanara.texte,
        title: const Text(
          'Profil Wontanara',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // -------- HEADER PROFIL PUBLIC --------
          Container(
            decoration: _cardBox,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: ThemeWontanara.menthe,
                  backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                      ? NetworkImage(photoUrl!)
                      : null,
                  child: (photoUrl == null || photoUrl!.isEmpty)
                      ? const Icon(
                          Ionicons.person,
                          size: 32,
                          color: ThemeWontanara.vertPetrole,
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$role • $quartier • $prefecture',
                        style: const TextStyle(
                          fontSize: 13,
                          color: ThemeWontanara.texte2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // -------- RÔLE & PERMISSIONS --------
          const _SectionTitle('Rôle & permissions'),
          const SizedBox(height: 8),
          Container(
            decoration: _cardBox,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rôle : $role',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('• Peut publier infos / alertes'),
                const Text('• Peut créer des demandes d’aide'),
                const Text('• Peut signaler déchets'),
                const Text('• Peut participer aux votes'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // -------- RÉPUTATION & BADGES --------
          const _SectionTitle('Réputation & badges'),
          const SizedBox(height: 8),
          Container(
            decoration: _cardBox,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _KpiChip(
                      label: 'Points',
                      value: '$points',
                      icon: Ionicons.star,
                    ),
                    const SizedBox(width: 8),
                    _KpiChip(
                      label: 'Aides données',
                      value: '$nbAides',
                      icon: Ionicons.hand_left_outline,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Badges',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: const [
                    _BadgeChip(
                      icon: Ionicons.hand_left_outline,
                      label: 'Aides données',
                    ),
                    _BadgeChip(
                      icon: Ionicons.ribbon_outline,
                      label: 'Citoyen actif',
                    ),
                    _BadgeChip(
                      icon: Ionicons.leaf_outline,
                      label: 'Eco-responsable',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // -------- MON ABONNEMENT --------
          const _SectionTitle('Mon abonnement'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              leading: const Icon(
                Ionicons.card_outline,
                color: ThemeWontanara.vertPetrole,
              ),
              title: const Text(
                'Mon abonnement',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Suivre mon abonnement collecte et autres services du quartier.',
                style: TextStyle(fontSize: 13),
              ),
              trailing: const Icon(Ionicons.chevron_forward),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PageAbonnementWontanara(),
                  ),
                );
              },
            ),
          ),

          // -------- MODÉRATION --------
          if (isModerateur) ...[
            const SizedBox(height: 20),
            const _SectionTitle('Modération'),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: const Icon(
                  Ionicons.shield_checkmark_outline,
                  color: ThemeWontanara.vertPetrole,
                ),
                title: const Text(
                  'Outils modérateur',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Accéder aux signalements et à la modération du quartier.',
                  style: TextStyle(fontSize: 13),
                ),
                trailing: const Icon(Ionicons.chevron_forward),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PageModerationWontanara(),
                    ),
                  );
                },
              ),
            ),
          ],

          // -------- ENTREPRISE DE RECYCLAGE --------
          const SizedBox(height: 20),
          const _SectionTitle('Recyclage'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.recycling,
                color: ThemeWontanara.vertPetrole,
              ),
              title: Text(
                isEntrepriseRecyclage
                    ? 'Gestion de mon entreprise'
                    : 'Enregistrer mon entreprise de recyclage',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                isEntrepriseRecyclage
                    ? 'Suivre vos tournées, abonnements et équipes.'
                    : 'Déclarer votre activité de collecte / recyclage.',
                style: const TextStyle(fontSize: 13),
              ),
              trailing: const Icon(Ionicons.chevron_forward),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PageEntrepriseRecyclage(),
                  ),
                );
              },
            ),
          ),

          // 🔕 PAS DE SECTION "Compte" ici : gérée par le profil général Soneya
        ],
      ),
    );
  }
}

/* ============================================================
 *  Petits widgets UI
 * ==========================================================*/

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: ThemeWontanara.vertPetrole,
      ),
    );
  }
}

class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _KpiChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: ThemeWontanara.menthe,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: ThemeWontanara.vertPetrole),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BadgeChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: ThemeWontanara.menthe,
      avatar: Icon(
        icon,
        size: 16,
        color: ThemeWontanara.vertPetrole,
      ),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

final _cardBox = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(18),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ],
);

/* ============================================================
 *  Pages liées (à brancher plus tard)
 * ==========================================================*/

class PageAbonnementWontanara extends StatelessWidget {
  const PageAbonnementWontanara({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon abonnement Wontanara'),
      ),
      body: const Center(
        child: Text(
          'Espace abonnement Wontanara (intégration à faire).',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class PageModerationWontanara extends StatelessWidget {
  const PageModerationWontanara({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outils modérateur'),
      ),
      body: const Center(
        child: Text(
          'Espace modération Wontanara (à brancher sur le backend).',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class PageEntrepriseRecyclage extends StatelessWidget {
  const PageEntrepriseRecyclage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entreprise de recyclage'),
      ),
      body: const Center(
        child: Text(
          'Espace entreprise de recyclage Wontanara (inscription / gestion).',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
