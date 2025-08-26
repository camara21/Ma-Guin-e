import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/user_provider.dart';
import 'cgu_bottom_sheet.dart';
import '../services/message_service.dart';
import '../routes.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _notificationsNonLues = 0;
  int _messagesNonLus = 0;

  StreamSubscription<List<Map<String, dynamic>>>? _notifSub;

  @override
  void initState() {
    super.initState();
    _verifierCGU();
    _ecouterNotifications();
    _chargerMessagesNonLus();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  Future<void> _verifierCGU() async {
    final utilisateur = context.read<UserProvider>().utilisateur;
    if (utilisateur != null && utilisateur.cguAccepte != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
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

  /// Écoute la table notifications et filtre côté client
  void _ecouterNotifications() {
    final user = context.read<UserProvider>().utilisateur;
    if (user == null) return;

    _notifSub?.cancel();

    _notifSub = Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .listen((rows) {
      if (!mounted) return;

      final nonLues = rows.where((n) {
        final uid = n['utilisateur_id']?.toString();
        final lu = n['lu'] == true;
        return uid == user.id && !lu;
      }).length;

      setState(() => _notificationsNonLues = nonLues);
    });
  }

  /// Charge la valeur initiale (notifications non lues + messages non lus)
  Future<void> _chargerMessagesNonLus() async {
    final user = context.read<UserProvider>().utilisateur;
    if (user == null) return;

    // badge notifications
    try {
      final rows = await Supabase.instance.client
          .from('notifications')
          .select('id, utilisateur_id, lu');

      final nonLues = (rows as List).where((n) {
        final uid = n['utilisateur_id']?.toString();
        final lu = n['lu'] == true;
        return uid == user.id && !lu;
      }).length;

      if (mounted) {
        setState(() => _notificationsNonLues = nonLues);
      }
    } catch (_) {
      // ignore
    }

    // messages non lus
    final count = await MessageService().getUnreadMessagesCount(user.id);
    if (!mounted) return;
    setState(() => _messagesNonLus = count);
  }

  // Carte d’icône standard
  Widget buildIcon(IconData iconData, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Icon(iconData, color: color, size: 44),
    );
  }

  /// Icône personnalisée Soneya
  Widget _soneyaIcon() {
    final br = BorderRadius.circular(14);
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: const LinearGradient(
          colors: [Color(0xFF06C167), Color(0xFF00A884)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Stack(
        children: [
          Center(child: Icon(Icons.two_wheeler, color: Colors.white, size: 36)),
          Positioned(
            right: 10,
            bottom: 10,
            child: Icon(Icons.directions_car, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final utilisateur = context.watch<UserProvider>().utilisateur;

    if (utilisateur == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      });
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
          // Notifications + badge
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 4),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Color(0xFFCE1126)),
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
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
          // Aide
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 12),
            child: IconButton(
              icon: const Icon(Icons.help_outline, color: Color(0xFF113CFC)),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.aide),
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
                    right: 12,
                    top: 10,
                    child: Image.asset(
                      'assets/logo_guinee.png',
                      height: 124,
                      fit: BoxFit.contain,
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

            // Grille
            GridView.count(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              shrinkWrap: true,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _serviceTile(Icons.campaign, "Annonces", AppRoutes.annonces, const Color(0xFFCE1126)),
                _serviceTile(Icons.engineering, "Prestataires", AppRoutes.pro, const Color(0xFFFCD116)),
                _serviceTile(Icons.account_balance, "Services Admin", AppRoutes.admin, const Color(0xFF009460)),
                _serviceTile(Icons.restaurant, "Restaurants", AppRoutes.resto, const Color(0xFFFCD116)),
                _serviceTile(Icons.mosque, "Lieux de culte", AppRoutes.culte, const Color(0xFF009460)),
                _serviceTile(Icons.theaters, "Divertissement", AppRoutes.divertissement, const Color(0xFFCE1126)),
                _serviceTile(Icons.museum, "Tourisme", AppRoutes.tourisme, const Color(0xFF009460)),
                _serviceTile(Icons.local_hospital, "Santé", AppRoutes.sante, const Color(0xFFFCD116)),
                _serviceTile(Icons.hotel, "Hôtels", AppRoutes.hotel, const Color(0xFFCE1126)),
                _serviceTile(Icons.star, "Favoris", AppRoutes.favoris, const Color(0xFF009460)),

                // 🔹 Soneya -> Portail VTC
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.vtcHome),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _soneyaIcon(),
                      const SizedBox(height: 6),
                      const Text("Soneya", textAlign: TextAlign.center),
                    ],
                  ),
                ),

                // 🔹 Billetterie (bientôt)
                _serviceTileFuture(
                  Icons.confirmation_num,
                  "Billetterie",
                  const Color(0xFFFCD116),
                  "Un service de billetterie sera bientôt disponible pour vendre vos billets d’événements "
                  "avec un système de QR Code sécurisé et traçable pour toutes vos organisations.",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Tuile d'un service disponible
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

  /// Tuile d'un service futur
  Widget _serviceTileFuture(IconData icon, String label, Color color, String message) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(label),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      },
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

  /// Tuile d'un service futur avec icône personnalisée
  Widget _serviceTileFutureCustom(Widget iconWidget, String label, String message) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(label),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
