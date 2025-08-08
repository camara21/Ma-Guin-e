import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../services/message_service.dart';

import 'home_page.dart';
import 'carte_page.dart';
import 'messages_page.dart';
import 'profile_page.dart';

// Badge notification pour l'onglet Messages
class Badge extends StatelessWidget {
  final int count;
  final double size;
  const Badge({Key? key, required this.count, this.size = 16}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Positioned(
      right: 0,
      top: 0,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(size / 2),
        ),
        alignment: Alignment.center,
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
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
  int _unreadMessages = 0;

  final MessageService _msgService = MessageService();
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;
  StreamSubscription<void>? _localUnreadSub; // 👈 nouvel abonnement local

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUnread();
      _listenRealtimeAndLocal();
    });
  }

  Future<void> _loadUnread() async {
    final user = Provider.of<UserProvider>(context, listen: false).utilisateur;
    if (user == null) return;
    final n = await _msgService.getUnreadMessagesCount(user.id);
    if (mounted) setState(() => _unreadMessages = n);
  }

  void _listenRealtimeAndLocal() {
    final user = Provider.of<UserProvider>(context, listen: false).utilisateur;
    if (user == null) return;

    // Realtime (insert/update/delete) -> recalcule le badge
    _realtimeSub?.cancel();
    _realtimeSub = _msgService.subscribeAll(_loadUnread);

    // 🔔 Event local déclenché quand on marque lu dans une page de chat
    _localUnreadSub?.cancel();
    _localUnreadSub = _msgService.unreadChanged.stream.listen((_) => _loadUnread());
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _localUnreadSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).utilisateur;

    final List<Widget> _pages = [
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
        body: _pages[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            // Optionnel: quand on ouvre l’onglet Messages, on force une MAJ du badge.
            if (index == 2) _loadUnread();
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home, color: Colors.red),
              label: 'Accueil',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.map),
              label: 'Carte',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.forum_rounded),
                  Badge(count: _unreadMessages),
                ],
              ),
              label: 'Messages',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
          selectedItemColor: Colors.red,
          unselectedItemColor: Colors.grey,
        ),
      ),
    );
  }
}
