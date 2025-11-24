// lib/pages/main_navigation_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../services/message_service.dart';

import 'home_page.dart';
import 'carte_page.dart';
import 'messages_page.dart';
import 'profile_page.dart';

const Color kBleu = Color(0xFF113CFC);

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
  final MessageService _svc = MessageService();

  Future<void> _onTapTab(int index, String? userId) async {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().utilisateur;

    // STREAM TEMPS RÉEL – COMPTEUR UNREAD
    final unreadStream =
        (user == null) ? Stream<int>.value(0) : _svc.unreadCountStream(user.id);

    final pages = <Widget>[
      const HomePage(),
      const CartePage(),
      const MessagesPage(),
      user != null
          ? ProfilePage(user: user)
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Connectez-vous pour accéder à votre profil",
                  textAlign: TextAlign.center,
                ),
              ),
            ),
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
          onTap: (i) => _onTapTab(i, user?.id),
          selectedItemColor: kBleu,
          unselectedItemColor: Colors.grey,
          iconSize: 30,
          selectedIconTheme: const IconThemeData(size: 34),
          unselectedIconTheme: const IconThemeData(size: 28),
          selectedFontSize: 12,
          unselectedFontSize: 12,
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
            //                   ONGLET MESSAGES
            //        FULL TEMPS RÉEL — BADGE INSTANTANÉ
            // ---------------------------------------------------------
            BottomNavigationBarItem(
              label: 'Messages',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.forum_rounded),

                  // BADGE TEMPS RÉEL
                  Positioned(
                    right: -6,
                    top: -6,
                    child: StreamBuilder<int>(
                      stream: unreadStream,
                      initialData: 0,
                      builder: (context, snap) {
                        final unread = snap.data ?? 0;

                        return Badge(
                          count: unread,
                          size: 18,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // ---------------------------------------------------------

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
