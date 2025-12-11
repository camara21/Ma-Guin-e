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

  // --- Cas classiques Flutter/Dart (analyse du texte brut)
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

  // fallback global
  if (kDebugMode) {
    // En dev on garde l’info brute pour le debug
    return "Erreur : $error";
  }
  return "Une erreur est survenue. Réessaie.";
}

String _frHttp(String code, String message) {
  final m = message.toLowerCase();

  // RLS / permissions
  if (m.contains('row-level security') || m.contains('rls')) {
    return "Accès refusé par la politique de sécurité.";
  }

  // Contrainte d'unicité (duplicate key)
  if (m.contains('duplicate key') &&
      m.contains('unique') &&
      m.contains('constraint')) {
    return "Cet enregistrement existe déjà.";
  }

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

  // fallback HTTP
  if (kDebugMode) {
    return "Erreur HTTP : $message";
  }
  return "Une erreur serveur est survenue. Réessaie.";
}

String _frAuth(String raw) {
  final msg = raw.toLowerCase().trim();

  // ===================== CAS SPÉCIFIQUES =====================

  // --- Mot de passe identique à l'ancien ---
  if (msg.contains('new password should be different from the old password') ||
      (msg.contains('new password') && msg.contains('old password'))) {
    return "Le nouveau mot de passe doit être différent de l'ancien.";
  }

  // --- Identifiants invalides / mauvais mot de passe ---
  if (msg.contains('invalid login') ||
      msg.contains('invalid credentials') ||
      msg.contains('invalid email or password') ||
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
  if (msg.contains('invalid email') ||
      msg.contains('email is not valid') ||
      (msg.contains('email') && msg.contains('invalid'))) {
    return "Adresse e-mail invalide.";
  }

  // --- Mots de passe qui ne correspondent pas ---
  if (msg.contains('passwords do not match') ||
      msg.contains('confirm password') && msg.contains('match')) {
    return "Les mots de passe ne correspondent pas.";
  }

  // --- Mot de passe trop court / longueur ---
  if (msg.contains('password') &&
      (msg.contains('too short') ||
          msg.contains('at least') ||
          msg.contains('6 characters') ||
          msg.contains('length'))) {
    return "Mot de passe trop court. Il doit contenir au moins 6 caractères.";
  }

  // --- Mot de passe trop faible / complexité ---
  if (msg.contains('password') && msg.contains('weak')) {
    return "Mot de passe trop faible.";
  }
  if (msg.contains('password') &&
      (msg.contains('one number') ||
          msg.contains('uppercase') ||
          msg.contains('lowercase') ||
          msg.contains('special character'))) {
    return "Mot de passe trop faible. Utilise des lettres, chiffres et symboles.";
  }

  // --- Mot de passe déjà utilisé récemment ---
  if (msg.contains('previously used password')) {
    return "Tu as déjà utilisé ce mot de passe récemment. Choisis-en un autre.";
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
      msg.contains('link has expired') ||
      (msg.contains('recovery') && msg.contains('expired'))) {
    return "Lien expiré. Relance la procédure.";
  }

  // --- OTP / code de vérification ---
  if (msg.contains('otp') && msg.contains('expired')) {
    return "Code expiré. Demande un nouveau code.";
  }
  if (msg.contains('invalid otp') ||
      msg.contains('invalid code') ||
      msg.contains('incorrect code')) {
    return "Code de vérification invalide.";
  }

  // --- Trop de tentatives (rate limit) ---
  if (msg.contains('rate limit') ||
      msg.contains('too many requests') ||
      msg.contains('for security purposes, you can only request this after')) {
    return "Trop de tentatives. Réessaie un peu plus tard.";
  }

  // --- Actions non autorisées / RLS ---
  if (msg.contains('not allowed') ||
      msg.contains('permission denied') ||
      msg.contains('insufficient permissions')) {
    return "Action non autorisée.";
  }

  // ===================== FALLBACK AUTH =====================

  if (kDebugMode) {
    // En dev: on garde le message original pour t'aider à mapper les nouveaux cas
    return "Erreur d'authentification : $raw";
  }

  // En prod: message générique 100% FR, pas d'anglais brut
  return "Une erreur d'authentification est survenue. Réessaie.";
}
