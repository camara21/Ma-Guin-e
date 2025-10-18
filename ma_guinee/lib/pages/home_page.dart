// lib/pages/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/user_provider.dart';
import 'cgu_bottom_sheet.dart';
import '../services/message_service.dart';
import '../routes.dart';

// ✅ Jobs
import 'package:ma_guinee/pages/jobs/job_home_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _notificationsNonLues = 0; // ← admin-only
  int _messagesNonLus = 0;

  StreamSubscription<List<Map<String, dynamic>>>? _notifSub;

  @override
  void initState() {
    super.initState();
    _verifierCGU();
    _ecouterNotificationsAdminOnly();
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

  // --------- Notifications ADMIN uniquement ---------
  void _ecouterNotificationsAdminOnly() {
    final user = context.read<UserProvider>().utilisateur;
    if (user == null) return;

    _notifSub?.cancel();

    // Stream filtré côté serveur : user + type != message
    _notifSub = Supabase.instance.client
        .from('notifications:utilisateur_id=eq.${user.id}&type=neq.message')
        .stream(primaryKey: ['id'])
        .listen((rows) {
      if (!mounted) return;

      final nonLues = rows.where((n) {
        final lu = n['lu'] == true;
        return !lu; // type!=message déjà filtré dans le canal
      }).length;

      setState(() => _notificationsNonLues = nonLues);
    });
  }

  Future<void> _chargerMessagesNonLus() async {
    final user = context.read<UserProvider>().utilisateur;
    if (user == null) return;

    try {
      final rows = await Supabase.instance.client
          .from('notifications')
          .select('id, utilisateur_id, lu, type')
          .eq('utilisateur_id', user.id)
          .neq('type', 'message');

      final nonLues = (rows as List).where((n) => n['lu'] != true).length;
      if (mounted) setState(() => _notificationsNonLues = nonLues);
    } catch (_) {}

    final count = await MessageService().getUnreadMessagesCount(user.id);
    if (!mounted) return;
    setState(() => _messagesNonLus = count);
  }

  // ========== UI helpers ==========
  // taille icône adaptative pour mini-écrans
  double _adaptiveIconSize(BuildContext context) {
    final w = MediaBox.of(context).size.width;
    if (w < 360) return 44; // plus petit sur téléphones étroits
    return 51;              // valeur "standard"
  }

  // carte carrée pour une géométrie stable
  Widget _iconCard(Widget child) {
    final w = MediaBox.of(context).size.width;
    final side = w < 360 ? 84.0 : 92.0; // réserve visuelle fixe pour l’icône
    return Container(
      width: side,
      height: side,
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
      alignment: Alignment.center,
      child: child,
    );
  }

  // Badge discret : reprend EXACTEMENT la couleur de l’icône principale
  Widget _smallBadge(Color bgColor, IconData icon) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.95),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.22),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(icon, size: 9, color: Colors.white),
    );
  }

  // Icône Material + badge accordé à la couleur principale
  Widget _iconWithBadge({
    required IconData main,
    required Color color,
    required IconData badge,
    required BuildContext context,
  }) {
    final size = _adaptiveIconSize(context);
    return _iconCard(
      Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: Icon(main, color: color, size: size)),
          Positioned(right: 6, bottom: 6, child: _smallBadge(color, badge)),
        ],
      ),
    );
  }

  // Icône Jobs
  Widget _soneyaIcon(BuildContext context) {
    const blue = Color(0xFF1976D2);
    final size = _adaptiveIconSize(context);
    return _iconCard(
      Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: Icon(Icons.work_outline, color: blue, size: size)),
          Positioned(right: 6, bottom: 6, child: _smallBadge(blue, Icons.description)),
        ],
      ),
    );
  }

  // ✅ Icône Logement (badge bleu cohérent)
  Widget _logementIcon(BuildContext context) {
    const primary = Color(0xFF0B3A6A); // bleu profond
    final size = _adaptiveIconSize(context);
    return _iconCard(
      Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: Icon(Icons.apartment_rounded, color: primary, size: size)),
          Positioned(right: 6, bottom: 6, child: _smallBadge(primary, Icons.location_on_rounded)),
        ],
      ),
    );
  }

  // tuile “bientôt”
  void _showComingSoon(BuildContext context,
      {required String title, required String message}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }
  // =================================

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

    final mq = MediaBox.of(context);
    final width = mq.size.width;
    final textScale = mq.textScaleFactor;

    int crossAxisCount = width > 600 ? 6 : 3;

    // 🔧 ratio plus "haut" si petit écran ou texte agrandi → plus d'espace au label
    double childAspectRatio;
    if (width < 360 || textScale > 1.1) {
      childAspectRatio = 0.82;
    } else if (width < 420) {
      childAspectRatio = 0.92;
    } else {
      childAspectRatio = 1.05;
    }

    double spacing = width > 600 ? 10 : 6;

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
          // 🔔 Notifications (admin-only) avec compteur rouge
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
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF113CFC)),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.aide),
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
                      "Soneya",
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
                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.campaign,
                    color: const Color(0xFFCE1126),
                    badge: Icons.add,
                    context: context,
                  ),
                  label: "Annonces",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.annonces),
                ),

                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.handyman_rounded,
                    color: const Color(0xFFFCD116),
                    badge: Icons.build_rounded,
                    context: context,
                  ),
                  label: "Prestataires",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.pro),
                ),

                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.account_balance,
                    color: const Color(0xFF009460),
                    badge: Icons.description_rounded,
                    context: context,
                  ),
                  label: "Services Admin",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.admin),
                ),

                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.restaurant,
                    color: const Color(0xFFFCD116),
                    badge: Icons.delivery_dining_rounded,
                    context: context,
                  ),
                  label: "Restaurants",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.resto),
                ),

                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.mosque,
                    color: const Color(0xFF009460),
                    badge: Icons.schedule_rounded,
                    context: context,
                  ),
                  label: "Lieux de culte",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.culte),
                ),

                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.theaters,
                    color: const Color(0xFFCE1126),
                    badge: Icons.music_note_rounded,
                    context: context,
                  ),
                  label: "Divertissement",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.divertissement),
                ),

                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.travel_explore_rounded,
                    color: const Color(0xFF009460),
                    badge: Icons.place_rounded,
                    context: context,
                  ),
                  label: "Tourisme",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.tourisme),
                ),

                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.local_hospital,
                    color: const Color(0xFFFCD116),
                    badge: Icons.health_and_safety_rounded,
                    context: context,
                  ),
                  label: "Santé",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.sante),
                ),

                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.hotel,
                    color: const Color(0xFFCE1126),
                    badge: Icons.star_rate_rounded,
                    context: context,
                  ),
                  label: "Hôtels",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.hotel),
                ),

                _ServiceTile(
                  icon: _logementIcon(context),
                  label: "Logement",
                  onTap: () => Navigator.pushNamed(context, AppRoutes.logement),
                ),

                _ServiceTile(
                  icon: _soneyaIcon(context),
                  label: "Wali fen",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const JobHomePage()),
                  ),
                ),

                _ServiceTile(
                  icon: _iconWithBadge(
                    main: Icons.confirmation_num,
                    color: const Color(0xFFFCD116),
                    badge: Icons.lock_clock,
                    context: context,
                  ),
                  label: "Billetterie",
                  onTap: () => _showComingSoon(
                    context,
                    title: "Billetterie",
                    message:
                        "Un service de billetterie sera bientôt disponible pour vendre vos billets d’événements avec un système de QR Code sécurisé et traçable pour toutes vos organisations.",
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

// ======= Widgets/utilitaires =======

// tuile réutilisable : zone icône fixe + label centré, impossible de se chevaucher
class _ServiceTile extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaBox.of(context).size.width;
    final iconZone = w < 360 ? 84.0 : 92.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: iconZone, child: Center(child: icon)),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// MediaQuery “safe”
class MediaBox {
  static MediaQueryData of(BuildContext context) =>
      MediaQuery.maybeOf(context) ?? const MediaQueryData();
}
