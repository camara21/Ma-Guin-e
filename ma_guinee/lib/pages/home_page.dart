import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/user_provider.dart';
import 'cgu_bottom_sheet.dart';
import '../services/message_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _notificationsNonLues = 0;
  int _messagesNonLus = 0;

  @override
  void initState() {
    super.initState();
    _verifierCGU();
    _ecouterNotifications();
    _chargerMessagesNonLus();
  }

  Future<void> _verifierCGU() async {
    final utilisateur = context.read<UserProvider>().utilisateur;
    if (utilisateur != null && utilisateur.cguAccepte != true) {
      Future.delayed(Duration.zero, () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const CGUBottomSheet(),
        );
      });
    }
  }

  void _ecouterNotifications() {
    final user = context.read<UserProvider>().utilisateur;
    if (user == null) return;

    Supabase.instance.client
        .from('notifications:utilisateur_id=eq.${user.id}')
        .stream(primaryKey: ['id'])
        .listen((data) {
      final nonLues = data.where((n) => n['lu'] != true).toList();
      setState(() {
        _notificationsNonLues = nonLues.length;
      });
    });
  }

  Future<void> _chargerMessagesNonLus() async {
    final user = context.read<UserProvider>().utilisateur;
    if (user == null) return;

    final count = await MessageService().getUnreadMessagesCount(user.id);
    setState(() {
      _messagesNonLus = count;
    });
  }

  Widget buildIcon(IconData iconData, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Icon(iconData, color: color, size: 44),
    );
  }

  @override
  Widget build(BuildContext context) {
    final utilisateur = Provider.of<UserProvider>(context).utilisateur;

    if (utilisateur == null) {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 3;
    double childAspectRatio = 1.03;
    double spacing = 6;
    if (width > 600) {
      crossAxisCount = 6;
      childAspectRatio = 1.18;
      spacing = 10;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Bienvenue ${utilisateur.prenom} 👋",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 4),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Color(0xFFCE1126)),
                  onPressed: () {
                    Navigator.pushNamed(context, '/notifications');
                  },
                ),
                if (_notificationsNonLues > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _notificationsNonLues.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 12),
            child: IconButton(
              icon: const Icon(Icons.help_outline, color: Color(0xFF113CFC)),
              onPressed: () {
                Navigator.pushNamed(context, '/aide');
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bannière
            Container(
              margin: const EdgeInsets.only(bottom: 18),
              width: double.infinity,
              height: 142,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
                gradient: const LinearGradient(
                  colors: [Color(0xFFCE1126), Color(0xFFFCD116)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 10,
                    top: -30,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.17),
                            Colors.transparent,
                          ],
                          radius: 0.83,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 18,
                    top: 20,
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Image.asset(
                          'assets/logo_guinee.png',
                          height: 90,
                          fit: BoxFit.contain,
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 6),
                              ],
                            ),
                            child: const Text(
                              "Guinée",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFCE1126),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    top: 29,
                    left: 26,
                    child: Text(
                      "Ma Guinée",
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 75,
                    left: 26,
                    child: Text(
                      "Tous les services à portée de main",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                        shadows: [Shadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 1))],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Grille des services
            GridView.count(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              shrinkWrap: true,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _serviceTile(Icons.campaign, "Annonces", '/annonces', const Color(0xFFCE1126)),
                _serviceTile(Icons.engineering, "Prestataires", '/prestataires', const Color(0xFFFCD116)),
                _serviceTile(Icons.account_balance, "Services Admin", '/administratif', const Color(0xFF009460)),
                _serviceTile(Icons.restaurant, "Restaurants", '/restos', const Color(0xFFFCD116)),
                _serviceTile(Icons.mosque, "Lieux de culte", '/culte', const Color(0xFF009460)),
                _serviceTile(Icons.theaters, "Divertissement", '/divertissement', const Color(0xFFCE1126)),
                _serviceTile(Icons.museum, "Tourisme", '/tourisme', const Color(0xFF009460)),
                _serviceTile(Icons.local_hospital, "Santé", '/sante', const Color(0xFFFCD116)),
                _serviceTile(Icons.hotel, "Hôtels", '/hotels', const Color(0xFFCE1126)),
                _serviceTile(Icons.star, "Favoris", '/favoris', const Color(0xFF009460)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceTile(IconData icon, String label, String route, Color color) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildIcon(icon, color),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
