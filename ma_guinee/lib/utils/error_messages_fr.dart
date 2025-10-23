// lib/utils/error_messages_fr.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Renvoie un message d'erreur en FR prêt à afficher à l'utilisateur.
/// Tu peux l'utiliser partout: SnackBar, Dialog, etc.
String frMessageFromError(Object error, [StackTrace? _]) {
  // --- Cas Supabase (Auth/API)
  if (error is AuthException) {
    return _frAuth(error.message);
  }
  if (error is PostgrestException) {
    // Si ta logique remonte des PostgrestException
    return _frHttp(error.code ?? '', error.message);
  }

  // --- Cas HTTP génériques (si tu utilises http/dio ailleurs)
  if (error is HttpException) {
    return "Erreur réseau. Vérifie ta connexion et réessaie.";
  }
  if (error is SocketException) {
    return "Aucune connexion Internet. Vérifie le réseau puis réessaie.";
  }
  if (error is FormatException) {
    return "Réponse invalide du serveur. Réessaie plus tard.";
  }

  // --- Cas classiques Flutter/Dart
  final msg = error.toString().toLowerCase();

  // timeouts
  if (msg.contains('timeout')) {
    return "Délai dépassé. Le serveur ne répond pas.";
  }

  // permissions notifications (web ou mobile)
  if (msg.contains('notification') && msg.contains('permission')) {
    return "Notifications non autorisées. Autorise-les dans les réglages.";
  }

  // invalid key (Google Maps, API externes)
  if (msg.contains('invalid key')) {
    return "Clé API invalide. Contacte l’administrateur.";
  }

  // http status courants
  if (msg.contains('403') || msg.contains('forbidden')) {
    return "Accès refusé (403).";
  }
  if (msg.contains('404')) {
    return "Ressource introuvable (404).";
  }
  if (msg.contains('401') || msg.contains('unauthorized')) {
    return "Authentification requise (401).";
  }
  if (msg.contains('500')) {
    return "Erreur serveur (500). Réessaie plus tard.";
  }

  // fallback
  if (kDebugMode) {
    // En dev on garde l’info brute pour le debug
    return "Erreur : $error";
  }
  return "Une erreur est survenue. Réessaie.";
}

String _frHttp(String code, String message) {
  final m = message.toLowerCase();
  if (code == '404' || m.contains('not found')) {
    return "Ressource introuvable (404).";
  }
  if (code == '403' || m.contains('forbidden')) {
    return "Accès refusé (403).";
  }
  if (code == '401' || m.contains('unauthorized')) {
    return "Authentification requise (401).";
  }
  if (code == '500' || m.contains('server error')) {
    return "Erreur serveur (500). Réessaie plus tard.";
  }
  return "Erreur : $message";
}

String _frAuth(String raw) {
  final msg = raw.toLowerCase().trim();

  // messages Supabase fréquents
  if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
    return "Identifiants invalides.";
  }
  if (msg.contains('email not confirmed') || msg.contains('email not confirmed')) {
    return "E-mail non confirmé. Vérifie ta boîte mail.";
  }
  if (msg.contains('user already registered') ||
      msg.contains('already registered')) {
    return "Cet utilisateur existe déjà.";
  }
  if (msg.contains('user not found')) {
    return "Utilisateur introuvable.";
  }
  if (msg.contains('invalid email') || msg.contains('email')) {
    return "Adresse e-mail invalide.";
  }
  if (msg.contains('password') && msg.contains('weak')) {
    return "Mot de passe trop faible.";
  }
  if (msg.contains('password') && msg.contains('length')) {
    return "Mot de passe trop court.";
  }
  if (msg.contains('token') && msg.contains('expired')) {
    return "Lien expiré. Relance la procédure.";
  }
  if (msg.contains('refresh token') && msg.contains('not found')) {
    return "Session expirée. Connecte-toi de nouveau.";
  }
  if (msg.contains('rate limit')) {
    return "Trop de tentatives. Réessaie plus tard.";
  }

  // fallback : première lettre en majuscule + point
  final cleaned = raw.endsWith('.') ? raw : '$raw.';
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}
