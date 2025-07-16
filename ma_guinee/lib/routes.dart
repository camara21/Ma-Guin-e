import 'package:flutter/material.dart';

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
import 'pages/tourisme_page.dart';
import 'pages/sante_page.dart';
import 'pages/hotel_page.dart';
import 'pages/notifications_page.dart';
import 'pages/profile_page.dart'; // ✅ Ajouté

class AppRoutes {
  static const String home = '/';
  static const String annonces = '/annonces';
  static const String pro = '/prestataires';
  static const String carte = '/carte';
  static const String divertissement = '/divertissement';
  static const String admin = '/administratif';
  static const String resto = '/restos';
  static const String culte = '/culte';
  static const String favoris = '/favoris';
  static const String login = '/login';
  static const String tourisme = '/tourisme';
  static const String sante = '/sante';
  static const String hotel = '/hotels';
  static const String notifications = '/notifications';
  static const String profil = '/profil'; // ✅ Ajouté

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      case annonces:
        return MaterialPageRoute(builder: (_) => const AnnoncesPage());
      case pro:
        return MaterialPageRoute(builder: (_) => const ProPage());
      case carte:
        return MaterialPageRoute(builder: (_) => const CartePage());
      case divertissement:
        return MaterialPageRoute(builder: (_) => const DivertissementPage());
      case admin:
        return MaterialPageRoute(builder: (_) => const AdminPage());
      case resto:
        return MaterialPageRoute(builder: (_) => const RestoPage());
      case culte:
        return MaterialPageRoute(builder: (_) => const CultePage());
      case favoris:
        return MaterialPageRoute(builder: (_) => const FavorisPage());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case tourisme:
        return MaterialPageRoute(builder: (_) => const TourismePage());
      case sante:
        return MaterialPageRoute(builder: (_) => const SantePage());
      case hotel:
        return MaterialPageRoute(builder: (_) => const HotelPage());
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsPage());
      case profil:
        return MaterialPageRoute(builder: (_) => const ProfilePage()); // ✅ Corrigé ici
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Erreur')),
            body: const Center(child: Text('Page non trouvée')),
          ),
        );
    }
  }
}
