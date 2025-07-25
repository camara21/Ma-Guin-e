import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/annonce_model.dart';
import 'models/utilisateur_model.dart';

// Pages principales
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
import 'pages/mes_prestations_page.dart';
import 'pages/mes_restaurants_page.dart' as resto_page;
import 'pages/mes_hotels_page.dart' as hotel_page;
import 'pages/mes_cliniques_page.dart';
import 'pages/annonce_detail_page.dart';
import 'pages/resto_detail_page.dart';
import 'pages/hotel_detail_page.dart';

// Edition & Inscription
import 'pages/edit_prestataire_page.dart';
import 'pages/edit_hotel_page.dart';
import 'pages/edit_resto_page.dart';
import 'pages/edit_annonce_page.dart';
import 'pages/edit_clinique_page.dart';
import 'pages/inscription_resto_page.dart';
import 'pages/inscription_prestataire_page.dart';
import 'pages/inscription_hotel_page.dart';

import 'providers/user_provider.dart';

class AppRoutes {
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
  static const String mesPrestations = '/mes_prestations';
  static const String mesRestaurants = '/mesRestaurants';
  static const String mesHotels = '/mesHotels';
  static const String mesCliniques = '/mesCliniques';

  static const String inscriptionResto = '/inscriptionResto';
  static const String inscriptionHotel = '/inscriptionHotel';
  static const String inscriptionClinique = '/inscriptionClinique';

  static const String annonceDetail = '/annonce_detail';
  static const String restoDetail = '/resto_detail';
  static const String hotelDetail = '/hotel_detail';

  static const String editPrestataire = '/edit_prestataire';
  static const String editHotel = '/edit_hotel';
  static const String editResto = '/edit_resto';
  static const String editAnnonce = '/edit_annonce';
  static const String editClinique = '/edit_clinique';

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
      case profil:
        return _userProtected((u) => ProfilePage(user: u));
      case parametre:
        return _userProtected((u) => ParametrePage(user: u));
      case aide:
        return _page(const AidePage());
      case messages:
        return _page(const MessagesPage());
      case mesAnnonces:
        return _userProtected((_) => const MesAnnoncesPage());
      case mesPrestations:
        return _userProtected((u) {
          final prestations = u.espacePrestataire != null
              ? [u.espacePrestataire!]
              : <Map<String, dynamic>>[];
          return MesPrestationsPage(prestations: prestations);
        });
      case mesRestaurants:
        return _userProtected((u) {
          final restos = u.restos ?? [];
          return resto_page.MesRestaurantsPage(restaurants: restos);
        });
      case mesHotels:
        return _userProtected((u) {
          final hotels = u.hotels ?? [];
          return hotel_page.MesHotelsPage(hotels: hotels);
        });
      case mesCliniques:
        return _page(const MesCliniquesPage());
      case inscriptionResto:
        final resto = settings.arguments;
        if (resto == null || resto is Map<String, dynamic>) {
          return _page(InscriptionRestoPage(
              restaurant: resto as Map<String, dynamic>?));
        }
        return _error("Argument invalide pour /inscriptionResto");
      case inscriptionHotel:
        final hotel = settings.arguments;
        if (hotel == null || hotel is Map<String, dynamic>) {
          return _page(InscriptionHotelPage(
              hotel: hotel as Map<String, dynamic>?));
        }
        return _error("Argument invalide pour /inscriptionHotel");
      case inscriptionClinique:
        final clinique = settings.arguments;
        if (clinique == null || clinique is Map<String, dynamic>) {
          return _page(EditCliniquePage(
              clinique: clinique as Map<String, dynamic>?));
        }
        return _error("Argument invalide pour /inscriptionClinique");
      case annonceDetail:
        final arg = settings.arguments;
        if (arg is AnnonceModel) {
          return _page(AnnonceDetailPage(annonce: arg));
        }
        return _error("Argument invalide pour /annonce_detail");
      case restoDetail:
        final id = settings.arguments;
        if (id is int) {
          return _page(RestoDetailPage(restoId: id));
        }
        return _error("ID invalide pour /resto_detail");
      case hotelDetail:
        final id = settings.arguments;
        if (id is int) {
          return _page(HotelDetailPage(hotelId: id));
        }
        return _error("ID invalide pour /hotel_detail");
      case editPrestataire:
        final argsP = settings.arguments as Map<String, dynamic>? ?? {};
        return _page(EditPrestatairePage(prestataire: argsP));
      case editHotel:
        final argsH = settings.arguments as Map<String, dynamic>? ?? {};
        return _page(EditHotelPage(hotelId: argsH['id']));
      case editResto:
        final argsR = settings.arguments as Map<String, dynamic>? ?? {};
        return _page(EditRestoPage(resto: argsR));
      case editAnnonce:
        final argsA = settings.arguments as Map<String, dynamic>? ?? {};
        return _page(EditAnnoncePage(annonce: argsA));
      case editClinique:
        final argsC = settings.arguments as Map<String, dynamic>? ?? {};
        return _page(EditCliniquePage(clinique: argsC));
      default:
        return _error('Page non trouvée : ${settings.name}');
    }
  }

  static MaterialPageRoute _page(Widget child) =>
      MaterialPageRoute(builder: (_) => child);

  static MaterialPageRoute _error(String msg) => MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Erreur')),
          body: Center(child: Text(msg)),
        ),
      );

  static MaterialPageRoute _userProtected(
    Widget Function(UtilisateurModel) builder,
  ) {
    return MaterialPageRoute(
      builder: (context) {
        final user =
            Provider.of<UserProvider>(context, listen: false).utilisateur;
        if (user == null) {
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
