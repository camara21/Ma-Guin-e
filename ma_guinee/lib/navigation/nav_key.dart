// lib/navigation/nav_key.dart
import 'package:flutter/material.dart';

/// Clé de navigation globale utilisée par toute l'app
/// (Main + navigation depuis les push).
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
