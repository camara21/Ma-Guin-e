import 'package:flutter/material.dart';
import 'education_donnees.dart';

class EducationRessourcesPage extends StatelessWidget {
  const EducationRessourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ressources = EducationDonnees.ressources;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ressources éducatives'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: ressources.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final r = ressources[i];
          return Material(
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _LectureRessourcePage(ressource: r),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(child: Icon(Icons.menu_book)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.titre,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r.categorie,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LectureRessourcePage extends StatelessWidget {
  final RessourceEducation ressource;
  const _LectureRessourcePage({required this.ressource});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ressource.titre),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          ressource.contenu,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
