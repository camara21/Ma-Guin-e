import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/annonce_model.dart';
import 'models/utilisateur_model.dart';

// Pages
import 'pages/splash_screen.dart';
import 'pages/welcome_page.dart';
import 'pages/home_page.dart';
import 'pages/annonces_page.dart';
import 'pages/pro_page.dart';
import 'pages/carte_page.dart';
import 'pages/divertissement_page.dart';
import 'pages/admin_page.dart';
import 'pages/resto_page.dart';
import 'pages/culte_page.dart';
import 'pages/favoris_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/tourisme_page.dart';
import 'pages/sante_page.dart';
import 'pages/hotel_page.dart';
import 'pages/notifications_page.dart';
import 'pages/profile_page.dart';
import 'pages/main_navigation_page.dart';
import 'pages/parametre_page.dart';
import 'pages/aide_page.dart';
import 'pages/messages_page.dart';
import 'pages/mes_annonces_page.dart';
import 'pages/annonce_detail_page.dart';

// Edition
import 'pages/edit_prestataire_page.dart';
import 'pages/edit_hotel_page.dart';
import 'pages/edit_resto_page.dart';
import 'pages/edit_clinique_page.dart';
import 'pages/edit_annonce_page.dart';

import 'providers/user_provider.dart';

class AppRoutes {
  // ------- NOMS DES ROUTES -------
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String mainNav = '/main';
  static const String home = '/home';
  static const String annonces = '/annonces';
  static const String pro = '/prestataires';
  static const String carte = '/carte';
  static const String divertissement = '/divertissement';
  static const String admin = '/administratif';
  static const String resto = '/restos';
  static const String culte = '/culte';
  static const String favoris = '/favoris';
  static const String login = '/login';
  static const String register = '/register';
  static const String tourisme = '/tourisme';
  static const String sante = '/sante';
  static const String hotel = '/hotels';
  static const String notifications = '/notifications';
  static const String profil = '/profil';
  static const String parametre = '/parametre';
  static const String aide = '/aide';
  static const String messages = '/messages';
  static const String mesAnnonces = '/mes_annonces';
  static const String annonceDetail = '/annonce_detail';

  // Edition
  static const String editPrestataire = '/edit_prestataire';
  static const String editHotel = '/edit_hotel';
  static const String editResto = '/edit_resto';
  static const String editClinique = '/edit_clinique';
  static const String editAnnonce = '/edit_annonce';

  // ------- GENERATE ROUTE -------
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _page(const SplashScreen());
      case welcome:
        return _page(const WelcomePage());
      case mainNav:
        return _page(const MainNavigationPage());
      case home:
        return _page(const HomePage());

      case annonces:
        return _page(const AnnoncesPage());
      case pro:
        return _page(const ProPage());
      case carte:
        return _page(const CartePage());
      case divertissement:
        return _page(const DivertissementPage());
      case admin:
        return _page(const AdminPage());
      case resto:
        return _page(const RestoPage());
      case culte:
        return _page(const CultePage());
      case favoris:
        return _page(const FavorisPage());
      case login:
        return _page(const LoginPage());
      case register:
        return _page(const RegisterPage());
      case tourisme:
        return _page(const TourismePage());
      case sante:
        return _page(const SantePage());
      case hotel:
        return _page(const HotelPage());
      case notifications:
        return _page(const NotificationsPage());
      case aide:
        return _page(const AidePage());
      case messages:
        return _page(const MessagesPage());

      case parametre:
        return _userProtected((u) => ParametrePage(user: u));

      case profil:
        return _userProtected((u) => ProfilePage(user: u));

      case mesAnnonces:
        return _userProtected((_) => const MesAnnoncesPage());

      case annonceDetail:
        final arg = settings.arguments;
        if (arg is AnnonceModel) {
          return _page(AnnonceDetailPage(annonce: arg));
        }
        return _error("Argument invalide pour /annonce_detail");

      // ---------- EDIT ----------
      case editPrestataire:
        final argsP = settings.arguments as Map<String, dynamic>? ?? {};
        return _page(EditPrestatairePage(prestataire: argsP));

      case editHotel:
        final argsH = settings.arguments as Map<String, dynamic>? ?? {};
        return _page(EditHotelPage(hotelId: argsH['id']));

      case editResto:
        final argsR = settings.arguments as Map<String, dynamic>? ?? {};
        return _page(EditRestoPage(resto: argsR));

      case editClinique:
        final argsC = settings.arguments as Map<String, dynamic>? ?? {};
        return _page(EditCliniquePage(clinique: argsC));

      case editAnnonce:
        final argsA = settings.arguments as Map<String, dynamic>? ?? {};
        return _page(EditAnnoncePage(annonce: argsA));

      default:
        return _error('Page non trouvée : ${settings.name}');
    }
  }

  // ------- HELPERS -------

  static MaterialPageRoute _page(Widget child) =>
      MaterialPageRoute(builder: (_) => child);

  static MaterialPageRoute _error(String msg) => MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Erreur')),
          body: Center(child: Text(msg)),
        ),
      );

  /// Protège une route : si l'utilisateur est null, on pousse /login.
  static MaterialPageRoute _userProtected(
    Widget Function(UtilisateurModel) builder,
  ) {
    return MaterialPageRoute(
      builder: (context) {
        final user =
            Provider.of<UserProvider>(context, listen: false).utilisateur;
        if (user == null) {
          // éviter d'empiler plusieurs fois par frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ModalRoute.of(context)?.settings.name != login) {
              Navigator.pushNamed(context, login);
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return builder(user);
      },
    );
  }
}
