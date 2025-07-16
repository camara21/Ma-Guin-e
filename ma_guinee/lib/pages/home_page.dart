import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/custom_card.dart';
import '../providers/user_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (!userProvider.estConnecte) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final utilisateur = Provider.of<UserProvider>(context).utilisateur;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Bienvenue ${utilisateur?.prenom ?? 'Utilisateur'} 👋",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PopupMenuButton<String>(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              offset: const Offset(0, 50),
              onSelected: (value) {
                if (value == 'profile') {
                  Navigator.pushNamed(context, '/profil');
                } else if (value == 'logout') {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: ListTile(
                    leading: Icon(Icons.person),
                    title: Text('Mon profil'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Se déconnecter'),
                  ),
                ),
              ],
              child: CircleAvatar(
                backgroundColor: Colors.grey.shade200,
                radius: 18,
                backgroundImage: utilisateur?.photoUrl != null
                    ? NetworkImage(utilisateur!.photoUrl!)
                    : const AssetImage('assets/default_avatar.png') as ImageProvider,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔶 Bannière
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFFCE1126), Color(0xFFFCD116)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Stack(
                children: [
                  const Positioned(
                    top: 20,
                    left: 20,
                    child: Text(
                      "Ma Guinée",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 55,
                    left: 20,
                    child: Text(
                      "Tous les services à portée de main",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 15,
                    child: Image.asset(
                      'assets/guinee_map.png',
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 🧩 Grille de services
            GridView.count(
              crossAxisCount: 3,
              childAspectRatio: 0.95,
              shrinkWrap: true,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                CustomCard(
                  icon: Icons.campaign,
                  label: "Annonces",
                  backgroundColor: const Color(0xFFCE1126),
                  onTap: () => Navigator.pushNamed(context, '/annonces'),
                ),
                CustomCard(
                  icon: Icons.engineering,
                  label: "Prestataires",
                  backgroundColor: const Color(0xFFFCD116),
                  onTap: () => Navigator.pushNamed(context, '/prestataires'),
                ),
                CustomCard(
                  icon: Icons.account_balance,
                  label: "Services Admin",
                  backgroundColor: const Color(0xFF009460),
                  onTap: () => Navigator.pushNamed(context, '/administratif'),
                ),
                CustomCard(
                  icon: Icons.restaurant,
                  label: "Restaurants",
                  backgroundColor: const Color(0xFFFCD116),
                  onTap: () => Navigator.pushNamed(context, '/restos'),
                ),
                CustomCard(
                  icon: Icons.mosque,
                  label: "Lieux de culte",
                  backgroundColor: const Color(0xFF009460),
                  onTap: () => Navigator.pushNamed(context, '/culte'),
                ),
                CustomCard(
                  icon: Icons.theaters,
                  label: "Divertissement",
                  backgroundColor: const Color(0xFFCE1126),
                  onTap: () => Navigator.pushNamed(context, '/divertissement'), // ✅ corrigé ici
                ),
                CustomCard(
                  icon: Icons.museum,
                  label: "Tourisme",
                  backgroundColor: const Color(0xFF009460),
                  onTap: () => Navigator.pushNamed(context, '/tourisme'),
                ),
                CustomCard(
                  icon: Icons.local_hospital,
                  label: "Santé",
                  backgroundColor: const Color(0xFFFCD116),
                  onTap: () => Navigator.pushNamed(context, '/sante'),
                ),
                CustomCard(
                  icon: Icons.hotel,
                  label: "Hôtels",
                  backgroundColor: const Color(0xFFCE1126),
                  onTap: () => Navigator.pushNamed(context, '/hotels'),
                ),
                CustomCard(
                  icon: Icons.star,
                  label: "Favoris",
                  backgroundColor: const Color(0xFF009460),
                  onTap: () => Navigator.pushNamed(context, '/favoris'),
                ),
              ],
            ),
          ],
        ),
      ),

      // 🔻 Navigation inférieure
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFFCE1126),
        onTap: (index) {
          final routes = ['/', '/carte', '/profil'];
          Navigator.pushNamed(context, routes[index]);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Accueil"),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Carte"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
        ],
      ),
    );
  }
}
