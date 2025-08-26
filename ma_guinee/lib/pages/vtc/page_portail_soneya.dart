// lib/pages/vtc/page_portail_soneya.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../routes.dart';

class PagePortailSoneya extends StatefulWidget {
  const PagePortailSoneya({super.key});

  @override
  State<PagePortailSoneya> createState() => _PagePortailSoneyaState();
}

class _PagePortailSoneyaState extends State<PagePortailSoneya> {
  bool _chargement = true;
  String? _role; // 'client' | 'chauffeur' | null

  @override
  void initState() {
    super.initState();
    _chargerRole();
  }

  Future<void> _chargerRole() async {
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) {
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    try {
      // 🔎 Récupère par id OU user_id selon ton schéma
      final row = await Supabase.instance.client
          .from('utilisateurs')
          .select('role')
          .or('id.eq.${u.id},user_id.eq.${u.id}')
          .maybeSingle();

      final r = row?['role'] as String?;
      if (!mounted) return;

      setState(() {
        _role = r;
        _chargement = false;
      });

      if (r != null && (r == 'client' || r == 'chauffeur')) {
        _redirigerSelonRole(r);
      }
    } catch (_) {
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _redirigerSelonRole(String role) {
    if (!mounted) return;
    final normalized = role.trim().toLowerCase();
    if (normalized == 'client') {
      Navigator.pushReplacementNamed(context, AppRoutes.soneyaClient);
    } else if (normalized == 'chauffeur') {
      Navigator.pushReplacementNamed(context, AppRoutes.soneyaChauffeur);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.soneyaClient);
    }
  }

  Future<void> _choisirRole(String role) async {
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    try {
      // 1) Essaye d’UPDATE par id OU user_id
      final updated = await Supabase.instance.client
          .from('utilisateurs')
          .update({'role': role})
          .or('id.eq.${u.id},user_id.eq.${u.id}')
          .select('role') // pour forcer le retour & détecter si 0 row
          .maybeSingle();

      // 2) Si aucune ligne mise à jour, tente un UPSERT (id puis user_id)
      if (updated == null) {
        try {
          await Supabase.instance.client
              .from('utilisateurs')
              .upsert({'id': u.id, 'role': role}, onConflict: 'id');
        } catch (_) {
          // Si ton schéma est avec user_id, second essai
          await Supabase.instance.client
              .from('utilisateurs')
              .upsert({'user_id': u.id, 'role': role}, onConflict: 'user_id');
        }
      }

      // 3) On navigue
      _redirigerSelonRole(role);
    } catch (e) {
      // Si l’écriture échoue (RLS, etc.), on informe mais on navigue quand même
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'enregistrer votre choix pour le moment.")),
      );
      _redirigerSelonRole(role); // ✅ fallback: on continue la navigation
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Soneya'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        child: Column(
          children: [
            _enTeteSoneya(context),
            const SizedBox(height: 16),
            Text(
              "Choisissez votre espace",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CarteChoix(
                    titre: 'Je suis client',
                    description: 'Réserver, suivre l’arrivée, payer, noter.',
                    icone: Icons.person_pin_circle,
                    couleur: const Color(0xFF06C167),
                    onTap: () => _choisirRole('client'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CarteChoix(
                    titre: 'Je suis chauffeur',
                    description: 'Recevoir des demandes, naviguer, consulter vos gains.',
                    icone: Icons.drive_eta_rounded,
                    couleur: const Color(0xFF00A884),
                    onTap: () => _choisirRole('chauffeur'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_role == null)
              Text(
                "Vous pourrez changer plus tard dans votre profil.",
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              )
            else
              Column(
                children: [
                  Text(
                    "Vous êtes enregistré comme ${_role == 'chauffeur' ? 'Chauffeur' : 'Client'}.",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => _redirigerSelonRole(_role!),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Continuer'),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => setState(() => _role = null),
                    child: const Text('Changer de rôle'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _enTeteSoneya(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF06C167), Color(0xFF00A884)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Stack(
        children: const [
          Positioned(
            left: 18,
            top: 20,
            child: Text(
              'Soneya',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                shadows: [Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 62,
            right: 18,
            child: Text(
              'Transport simple et rapide.\nChoisissez votre espace.',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Positioned(right: 18, bottom: 12, child: Icon(Icons.two_wheeler, color: Colors.white, size: 46)),
          Positioned(right: 64, bottom: 12, child: Icon(Icons.directions_car, color: Colors.white, size: 28)),
        ],
      ),
    );
  }
}

class _CarteChoix extends StatelessWidget {
  final String titre;
  final String description;
  final IconData icone;
  final Color couleur;
  final VoidCallback onTap;

  const _CarteChoix({
    required this.titre,
    required this.description,
    required this.icone,
    required this.couleur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.dividerColor.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, size: 30, color: couleur),
            const SizedBox(height: 8),
            Text(titre, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(description, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Entrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
