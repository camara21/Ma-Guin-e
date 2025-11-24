import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme_wontanara.dart';
import 'package:ma_guinee/providers/user_provider.dart';

class PageProfil extends StatelessWidget {
  const PageProfil({super.key});

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "La mise en place de ce service est encore en cours.\n"
          "Vous serez informé dès son lancement dans Wontanara. "
          "Merci pour votre confiance et à très bientôt 💚",
        ),
      ),
    );
  }

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

    // --------- Métadonnées Wontanara ---------
    bool isEntrepriseRecyclage = false;
    bool isModerateur = false;

    if (supaUser != null) {
      final meta = supaUser.userMetadata ?? {};

      // Entreprise recyclage
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
                    ],
                  ),
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
                _showComingSoon(context);
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
                _showComingSoon(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
 * UI Components
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
 *  Pages liées
 * ==========================================================*/

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
