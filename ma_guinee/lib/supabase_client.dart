// lib/supabase_client.dart
import 'package:flutter/foundation.dart' show kReleaseMode, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Accès global au client Supabase
class SB {
  static SupabaseClient get i => Supabase.instance.client;
}

/// Initialisation unique de Supabase pour toute l’app.
///
/// - En DEV : utilise les `defaultValue` si aucun --dart-define n’est fourni.
/// - En PROD (kReleaseMode) : exige SUPABASE_URL et SUPABASE_ANON_KEY via --dart-define.
/// - Mobile : active PKCE (recommandé).
Future<void> initSupabase() async {
  final url = const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zykbcgqgkdsguirjvwxg.supabase.co', // fallback DEV
  );

  final anonKey = const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp5a2JjZ3Fna2RzZ3Vpcmp2d3hnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI3ODMwMTEsImV4cCI6MjA2ODM1OTAxMX0.R-iSxRy-vFvmmE80EdI2AlZCKqgADvLd9_luvrLQL-E', // fallback DEV
  );

  // En release, on force l’usage des dart-define
  if (kReleaseMode && (url.isEmpty || anonKey.isEmpty)) {
    throw StateError(
      'SUPABASE_URL / SUPABASE_ANON_KEY manquants.\n'
      'Passe-les via --dart-define au moment du build.',
    );
  }

  if (kIsWeb) {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  } else {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
}
