import 'package:flutter/material.dart';
import '../../routes.dart';

class ParametresPage extends StatelessWidget {
  const ParametresPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            icon: Icons.navigation_rounded,
            title: 'Navigation',
            subtitle: 'Préférences d’itinéraire et d’app carto',
            onTap: () => Navigator.pushNamed(context, AppRoutes.paramNavigation),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.dark_mode_rounded,
            title: 'Mode nuit',
            subtitle: 'Thème clair / sombre / automatique',
            onTap: () => Navigator.pushNamed(context, AppRoutes.paramModeNuit),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.accessibility_new_rounded,
            title: 'Accessibilité',
            subtitle: 'Taille du texte, contraste, animations',
            onTap: () => Navigator.pushNamed(context, AppRoutes.paramAccessibilite),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.record_voice_over_rounded,
            title: 'Son & voix',
            subtitle: 'Guidage vocal, bips et volume',
            onTap: () => Navigator.pushNamed(context, AppRoutes.paramSonVoix),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.forum_rounded,
            title: 'Communication',
            subtitle: 'Notifications, promos, contacts',
            onTap: () => Navigator.pushNamed(context, AppRoutes.paramCommunication),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.info_rounded,
            title: 'À propos',
            subtitle: 'Version, conditions et support',
            onTap: () => Navigator.pushNamed(context, AppRoutes.paramAPropos),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(.1),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
