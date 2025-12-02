// lib/pages/main_navigation_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/user_provider.dart';
import '../services/message_service.dart';

import 'home_page.dart';
import 'carte_page.dart';
import 'messages_page.dart';
import 'profile_page.dart';

const Color kBleu = Color(0xFF113CFC);

// ----------------------------------------------------------------------
// Badge rouge
// ----------------------------------------------------------------------
class Badge extends StatelessWidget {
  final int count;
  final double size;

  const Badge({
    Key? key,
    required this.count,
    this.size = 18,
  }) : super(key: key);

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
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.55,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// MainNavigationPage
// ----------------------------------------------------------------------
class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({Key? key}) : super(key: key);

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  // Service messages
  final MessageService _messageService = MessageService();

  // Stream compteur non lus
  Stream<int>? _unreadStream;

  @override
  void dispose() {
    // Si un jour tu veux fermer les StreamController de MessageService :
    // _messageService.disposeService();
    super.dispose();
  }

  /// Stream qui rafraîchit périodiquement le nombre de messages non lus
  /// pour l'utilisateur connecté.
  ///
  /// Ici : toutes les 1 seconde.
  /// Tu peux passer à 2 ou 3 secondes si tu veux alléger la charge.
  Stream<int> _buildUnreadStream(String userId) {
    return Stream.periodic(const Duration(seconds: 3))
        .asyncMap((_) => _messageService.getUnreadMessagesCount(userId))
        .distinct();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().utilisateur;

    // Tant que le user n'est pas chargé
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // On crée le stream UNE SEULE FOIS, quand on a enfin un user
    _unreadStream ??= _buildUnreadStream(user.id);

    final pages = <Widget>[
      const HomePage(),
      const CartePage(),
      const MessagesPage(),
      ProfilePage(user: user), // on ne touche pas
    ];

    // fallback : si pour une raison quelconque le stream est null
    final unreadStream = _unreadStream ?? Stream<int>.value(0);

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
          selectedItemColor: kBleu,
          unselectedItemColor: Colors.grey,
          onTap: (i) => setState(() => _currentIndex = i),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Accueil',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.map),
              label: 'Carte',
            ),

            // ---------------------------------------------------------
            // Onglet Messages avec badge "polling" (rafraîchi en continu)
            // ---------------------------------------------------------
            BottomNavigationBarItem(
              label: 'Messages',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.forum_rounded),
                  Positioned(
                    right: -6,
                    top: -6,
                    child: StreamBuilder<int>(
                      stream: unreadStream,
                      initialData: 0,
                      builder: (context, snapshot) {
                        final unread = snapshot.data ?? 0;
                        return Badge(count: unread, size: 18);
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
