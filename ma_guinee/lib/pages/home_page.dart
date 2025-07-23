import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ⛔️ SUPPRIME le initState : pas de redirection ici !

  // Fonction pour l’icône messages stylée
  Widget buildStyledMessageIcon() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            Color(0xFFCE1126), // Rouge
            Color(0xFFFCD116), // Jaune
            Color(0xFF009460), // Vert
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: const Icon(
        Icons.forum_rounded,
        color: Colors.white,
        size: 34,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final utilisateur = Provider.of<UserProvider>(context).utilisateur;

    if (utilisateur == null) {
      // ✅ Redirection unique ici (ça suffit largement)
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Widget buildIcon(IconData iconData, Color color) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Icon(iconData, color: color, size: 38),
      );
    }

    // Responsive grid setup
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 3;
    double childAspectRatio = 1;
    if (width > 600) {
      crossAxisCount = 6;
      childAspectRatio = 1.1;
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
          // Icône notification
          IconButton(
            icon: const Icon(Icons.notifications, color: Color(0xFFCE1126)),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications');
            },
          ),
          // Icône point d'interrogation
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF113CFC)),
            onPressed: () {
              Navigator.pushNamed(context, '/aide');
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nouvelle bannière Ma Guinée
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
                  // Effet lumière
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
                  // Carte de la Guinée + badge
                  Positioned(
                    right: 18,
                    top: 20,
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Image.asset(
                          'assets/guinee_map.png',
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
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6,
                                ),
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
                  // Titre
                  const Positioned(
                    top: 29,
                    left: 26,
                    child: Text(
                      "Ma Guinée",
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Sous-titre
                  const Positioned(
                    top: 75,
                    left: 26,
                    child: Text(
                      "Tous les services à portée de main",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                        shadows: [
                          Shadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Grille de services
            GridView.count(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              shrinkWrap: true,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/annonces'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildIcon(Icons.campaign, const Color(0xFFCE1126)),
                      const SizedBox(height: 6),
                      const Text("Annonces", textAlign: TextAlign.center),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/prestataires'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildIcon(Icons.engineering, const Color(0xFFFCD116)),
                      const SizedBox(height: 6),
                      const Text("Prestataires", textAlign: TextAlign.center),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/administratif'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildIcon(Icons.account_balance, const Color(0xFF009460)),
                      const SizedBox(height: 6),
                      const Text("Services Admin", textAlign: TextAlign.center),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/restos'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildIcon(Icons.restaurant, const Color(0xFFFCD116)),
                      const SizedBox(height: 6),
                      const Text("Restaurants", textAlign: TextAlign.center),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/culte'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildIcon(Icons.mosque, const Color(0xFF009460)),
                      const SizedBox(height: 6),
                      const Text("Lieux de culte", textAlign: TextAlign.center),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/divertissement'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildIcon(Icons.theaters, const Color(0xFFCE1126)),
                      const SizedBox(height: 6),
                      const Text("Divertissement", textAlign: TextAlign.center),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/tourisme'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildIcon(Icons.museum, const Color(0xFF009460)),
                      const SizedBox(height: 6),
                      const Text("Tourisme", textAlign: TextAlign.center),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/sante'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildIcon(Icons.local_hospital, const Color(0xFFFCD116)),
                      const SizedBox(height: 6),
                      const Text("Santé", textAlign: TextAlign.center),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/hotels'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildIcon(Icons.hotel, const Color(0xFFCE1126)),
                      const SizedBox(height: 6),
                      const Text("Hôtels", textAlign: TextAlign.center),
                    ],
                  ),
                ),
                // Favoris
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/favoris'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildIcon(Icons.star, const Color(0xFF009460)),
                      const SizedBox(height: 6),
                      const Text("Favoris", textAlign: TextAlign.center),
                    ],
                  ),
                ),
                // Messages stylé (après Favoris)
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/messages'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildStyledMessageIcon(),
                      const SizedBox(height: 6),
                      const Text(
                        "Messages",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
