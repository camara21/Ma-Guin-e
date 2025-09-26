// lib/pages/main_navigation_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../services/message_service.dart';

import 'home_page.dart';
import 'carte_page.dart';
import 'messages_page.dart';
import 'profile_page.dart';

// Pastille du badge (affiche le nombre)
class Badge extends StatelessWidget {
  final int count;
  final double size;
  const Badge({Key? key, required this.count, this.size = 18}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({Key? key}) : super(key: key);

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  final _svc = MessageService();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().utilisateur;

    // Stream du badge Messages (nombre non lus)
    final Stream<int> badgeStream =
        (user == null) ? Stream<int>.value(0) : _svc.unreadCountStream(user.id);

    final pages = <Widget>[
      const HomePage(),
      const CartePage(),
      const MessagesPage(),
      user != null
          ? ProfilePage(user: user)
          : const Center(child: Text("Connectez-vous pour accéder à votre profil")),
    ];

    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: pages[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),

          // Couleurs
          selectedItemColor: Colors.red,
          unselectedItemColor: Colors.grey,

          // TAILLE DES ICÔNES (↑)
          iconSize: 30, // taille de base
          selectedIconTheme: const IconThemeData(size: 34),
          unselectedIconTheme: const IconThemeData(size: 28),

          // (optionnel) Lisibilité labels
          selectedFontSize: 12,
          unselectedFontSize: 12,

          items: [
            const BottomNavigationBarItem(
              // Laisser le thème gérer la couleur (retire color: Colors.red)
              icon: Icon(Icons.home),
              label: 'Accueil',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.map),
              label: 'Carte',
            ),
            BottomNavigationBarItem(
              label: 'Messages',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.forum_rounded),
                  Positioned(
                    right: -6, // ajusté pour icônes plus grandes
                    top: -6,
                    child: StreamBuilder<int>(
                      stream: badgeStream,
                      initialData: 0,
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return Badge(count: count, size: 18);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
