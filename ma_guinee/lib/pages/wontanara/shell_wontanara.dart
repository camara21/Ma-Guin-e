// lib/pages/wontanara/shell_wontanara.dart

import 'package:flutter/material.dart';

import 'theme_wontanara.dart';
import 'pages/page_flux.dart';
import 'pages/page_carte.dart';
import 'pages/page_services.dart';
import 'pages/page_collecte.dart';
import 'pages/page_votes.dart';
import 'pages/page_profil.dart';

class ShellWontanara extends StatefulWidget {
  const ShellWontanara({super.key});

  @override
  State<ShellWontanara> createState() => _ShellWontanaraState();
}

class _ShellWontanaraState extends State<ShellWontanara> {
  int _index = 0;

  // Onglets principaux -> vraies pages “prod”
  final List<Widget> _pages = const [
    PageFlux(), // Actualités locales
    PageCarte(), // Carte communautaire
    PageServices(), // Entraide & micro-services
    PageCollecte(), // Collecte / abonnements
    PageVotes(), // Votes & gouvernance
    PageProfil(), // Profil & rôle
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_index],
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: ThemeWontanara.vertPetrole,
            unselectedItemColor: Colors.grey[600],
            showUnselectedLabels: true,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.feed_rounded),
                label: 'Actualités',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map_rounded),
                label: 'Carte',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.volunteer_activism_rounded),
                label: 'Entraide',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.recycling_rounded),
                label: 'Collecte',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.how_to_vote_rounded),
                label: 'Gouvernance',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
      // Chaque page gère désormais son propre FAB,
      // donc pas de FloatingActionButton global ici.
    );
  }
}
