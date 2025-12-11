// lib/utils/error_messages_fr.dart
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Renvoie un message d'erreur en FR prêt à afficher à l'utilisateur.
/// À utiliser partout : SnackBar, Dialog, etc.
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
  if (error is TimeoutException) {
    return "Délai dépassé. Le serveur ne répond pas.";
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

  // --- Identifiants invalides / mauvais mot de passe ---
  if (msg.contains('invalid login') ||
      msg.contains('invalid credentials') ||
      msg.contains('invalid email or password')) {
    return "E-mail ou mot de passe incorrect.";
  }

  // --- E-mail non confirmé ---
  if (msg.contains('email not confirmed')) {
    return "E-mail non confirmé. Vérifie ta boîte mail.";
  }

  // --- Utilisateur déjà existant ---
  if (msg.contains('user already registered') ||
      msg.contains('already registered') ||
      msg.contains('user already exists')) {
    return "Un compte existe déjà avec cette adresse e-mail.";
  }

  // --- Utilisateur introuvable ---
  if (msg.contains('user not found')) {
    return "Utilisateur introuvable.";
  }

  // --- Adresse e-mail invalide ---
  if (msg.contains('invalid email') || msg.contains('email is not valid')) {
    return "Adresse e-mail invalide.";
  }

  // --- Mots de passe qui ne correspondent pas (reset password) ---
  if (msg.contains('passwords do not match')) {
    return "Les mots de passe ne correspondent pas.";
  }

  // --- Mot de passe trop court / longueur ---
  if (msg.contains('password') &&
      (msg.contains('too short') ||
          msg.contains('at least') ||
          msg.contains('length'))) {
    return "Mot de passe trop court. Il doit contenir au moins 6 caractères.";
  }

  // --- Mot de passe trop faible ---
  if (msg.contains('password') && msg.contains('weak')) {
    return "Mot de passe trop faible.";
  }

  // --- Session / token expiré ---
  if (msg.contains('token has expired') ||
      msg.contains('jwt expired') ||
      (msg.contains('session') && msg.contains('expire')) ||
      (msg.contains('refresh token') && msg.contains('not found'))) {
    return "Session expirée. Connecte-toi de nouveau.";
  }

  // --- Lien de reset / magic link expiré ---
  if (msg.contains('link is no longer valid') ||
      msg.contains('link has expired')) {
    return "Lien expiré. Relance la procédure.";
  }

  // --- Trop de tentatives (rate limit) ---
  if (msg.contains('rate limit') ||
      msg.contains('too many requests') ||
      msg.contains('for security purposes, you can only request this after')) {
    return "Trop de tentatives. Réessaie un peu plus tard.";
  }

  // fallback : première lettre en majuscule + point
  final cleaned = raw.endsWith('.') ? raw : '$raw.';
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}
