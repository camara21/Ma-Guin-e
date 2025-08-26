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

// ✅ Alias clairs
import 'pages/resto_page.dart' as resto_pg;
import 'pages/register_page.dart' as register_pg;

import 'pages/culte_page.dart';
import 'pages/favoris_page.dart';
import 'pages/login_page.dart';
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
import 'pages/mes_restaurants_page.dart' as myresto_pg;
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

// ✅ Social/Live
import 'pages/posts_reels_page.dart';
import 'pages/events_list_page.dart';
import 'pages/my_tickets_page.dart';
import 'pages/scanner_page.dart';
import 'pages/live_page.dart';
import 'pages/live_room_page.dart';

// 🚖 VTC / Moto-taxi
import 'pages/vtc/page_portail_soneya.dart';
import 'pages/vtc/demande_course_page.dart';
import 'pages/vtc/offres_course_page.dart';
import 'pages/vtc/suivi_course_page.dart';
import 'pages/vtc/portefeuille_page.dart';
import 'pages/vtc/paiements_page.dart';
import 'pages/vtc/regles_tarifaires_page.dart';
import 'pages/vtc/creneaux_page.dart';
import 'pages/vtc/vehicules_page.dart';
import 'pages/vtc/inscription_chauffeur_page.dart';
import 'pages/vtc/admin_vtc_page.dart';

// ✅ Nouveaux homes VTC
import 'pages/vtc/home_client_vtc_page.dart';
import 'pages/vtc/home_chauffeur_vtc_page.dart';

class AppRoutes {
  // Core
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String mainNav = '/main';
  static const String home = '/home';

  // Existants
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

  // Social / Live
  static const String talents = '/talents';
  static const String live = '/live';
  static const String liveRoom = '/live/room';

  // Billetterie
  static const String billetterie = '/billetterie';
  static const String myTickets = '/mes_billets';
  static const String scanner = '/scanner';

  // 🚖 VTC / Moto-taxi
  static const String vtcHome = '/vtc'; // Portail Soneya
  static const String vtcDemande = '/vtc/demande';
  static const String vtcOffres = '/vtc/offres';
  static const String vtcSuivi = '/vtc/suivi';
  static const String vtcPortefeuille = '/vtc/portefeuille';
  static const String vtcPaiements = '/vtc/paiements';
  static const String vtcReglesTarifaires = '/vtc/tarifs';
  static const String vtcCreneaux = '/vtc/creneaux';
  static const String vtcVehicules = '/vtc/vehicules';
  static const String vtcInscriptionChauffeur = '/vtc/inscription_chauffeur';
  static const String vtcAdmin = '/vtc/admin';

  // ✅ Cibles du portail
  static const String soneyaClient = '/soneya/client';
  static const String soneyaChauffeur = '/soneya/chauffeur';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // Core
      case splash:
        return _page(const SplashScreen());
      case welcome:
        return _page(const WelcomePage());
      case mainNav:
        return _page(const MainNavigationPage());
      case home:
        return _page(const HomePage());

      // Existants
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
        return _page(const resto_pg.RestoPage());
      case culte:
        return _page(const CultePage());
      case favoris:
        return _page(const FavorisPage());
      case login:
        return _page(const LoginPage());
      case register:
        return _page(const register_pg.RegisterPage());
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
          final prestations = u.espacePrestataire != null ? [u.espacePrestataire!] : <Map<String, dynamic>>[];
          return MesPrestationsPage(prestations: prestations);
        });
      case mesRestaurants:
        return _userProtected((u) {
          final restos = u.restos ?? [];
          return myresto_pg.MesRestaurantsPage(restaurants: restos);
        });
      case mesHotels:
        return _userProtected((u) {
          final hotels = u.hotels ?? [];
          return hotel_page.MesHotelsPage(hotels: hotels);
        });
      case mesCliniques:
        return _userProtected((u) {
          final cliniques = u.cliniques ?? [];
          return MesCliniquesPage(cliniques: cliniques);
        });

      case inscriptionResto: {
        final arg = settings.arguments;
        if (arg == null || arg is Map<String, dynamic>) {
          return _page(InscriptionRestoPage(restaurant: arg as Map<String, dynamic>?));
        }
        return _error("Argument invalide pour $inscriptionResto");
      }
      case inscriptionHotel: {
        final arg = settings.arguments;
        if (arg == null || arg is Map<String, dynamic>) {
          return _page(InscriptionHotelPage(hotel: arg as Map<String, dynamic>?));
        }
        return _error("Argument invalide pour $inscriptionHotel");
      }
      case inscriptionClinique: {
        final arg = settings.arguments;
        if (arg == null || arg is Map<String, dynamic>) {
          return _page(EditCliniquePage(clinique: arg as Map<String, dynamic>?));
        }
        return _error("Argument invalide pour $inscriptionClinique");
      }

      case annonceDetail: {
        final arg = settings.arguments;
        if (arg is AnnonceModel) return _page(AnnonceDetailPage(annonce: arg));
        return _error("Argument invalide pour $annonceDetail");
      }
      case restoDetail: {
        final arg = settings.arguments;
        final String? restoId = (arg is String) ? arg : arg?.toString();
        if (restoId == null || restoId.isEmpty) return _error("ID invalide pour $restoDetail");
        return _page(RestoDetailPage(restoId: restoId));
      }
      case hotelDetail: {
        final id = settings.arguments;
        if (id is int) return _page(HotelDetailPage(hotelId: id));
        return _error("ID invalide pour $hotelDetail");
      }

      case editPrestataire:
        return _page(EditPrestatairePage(prestataire: _argsMap(settings)));
      case editHotel:
        return _page(EditHotelPage(hotelId: _argsMap(settings)['id']));
      case editResto:
        return _page(EditRestoPage(resto: _argsMap(settings)));
      case editAnnonce:
        return _page(EditAnnoncePage(annonce: _argsMap(settings)));
      case editClinique:
        return _page(EditCliniquePage(clinique: _argsMap(settings)));

      // Social
      case talents:
        return _page(const PostsReelsPage());

      // Live
      case live:
        return _page(const LivePage());
      case liveRoom: {
        final m = _argsMap(settings);
        final roomId = (m['roomId'] as String?) ?? '';
        if (roomId.isEmpty) return _error('Argument manquant roomId pour $liveRoom');
        final isHost = (m['isHost'] as bool?) ?? false;
        final title = m['title'] as String?;
        return _page(LiveRoomPage(roomId: roomId, isHost: isHost, initialTitle: title));
      }

      // Billetterie
      case billetterie:
        return _page(const EventsListPage());
      case myTickets:
        return _userProtected((_) => const MyTicketsPage());
      case scanner:
        return _userProtected((_) => const ScannerPage());

      // 🚖 VTC / Moto-taxi
      case vtcHome:
        return _page(const PagePortailSoneya());

      case vtcDemande:
        return _userProtected((u) => DemandeCoursePage(currentUser: u));

      case vtcOffres: {
        final m = _argsMap(settings);
        final demandeId = (m['demandeId'] as String?) ?? '';
        if (demandeId.isEmpty) return _error('demandeId requis pour $vtcOffres');
        return _userProtected((_) => OffresCoursePage(demandeId: demandeId));
      }

      case vtcSuivi: {
        final m = _argsMap(settings);
        final courseId = (m['courseId'] as String?) ?? '';
        if (courseId.isEmpty) return _error('courseId requis pour $vtcSuivi');
        return _userProtected((_) => SuiviCoursePage(courseId: courseId));
      }

      case vtcPortefeuille:
        return _userProtected((u) => PortefeuilleChauffeurPage(userId: u.id));

      case vtcPaiements:
        return _userProtected((u) => PaiementsPage(userId: u.id));

      case vtcReglesTarifaires:
        return _userProtected((_) => const ReglesTarifairesPage());

      case vtcCreneaux:
        return _userProtected((u) => CreneauxChauffeurPage(userId: u.id));

      case vtcVehicules:
        return _userProtected((u) => VehiculesPage(ownerUserId: u.id));

      case vtcInscriptionChauffeur:
        return _page(const InscriptionChauffeurPage());

      case vtcAdmin:
        return _userProtected((_) => const AdminVtcPage());

      // ✅ Cibles du portail -> ouvrent les HOMES VTC
      case soneyaClient:
        return _userProtected((u) => HomeClientVtcPage(currentUser: u));

      case soneyaChauffeur:
        return _userProtected((u) => HomeChauffeurVtcPage(currentUser: u));

      default:
        return _error('Page non trouvée : ${settings.name}');
    }
  }

  // Helpers
  static Map<String, dynamic> _argsMap(RouteSettings s) {
    final a = s.arguments;
    return (a is Map) ? Map<String, dynamic>.from(a as Map) : <String, dynamic>{};
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
        final user = Provider.of<UserProvider>(context, listen: false).utilisateur;
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ModalRoute.of(context)?.settings.name != login) {
              Navigator.pushNamed(context, login);
            }
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return builder(user);
      },
    );
  }
}
