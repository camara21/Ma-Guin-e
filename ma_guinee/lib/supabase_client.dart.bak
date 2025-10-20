// lib/supabase_client.dart
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:supabase_flutter/supabase_flutter.dart';

class SB {
  static SupabaseClient get i => Supabase.instance.client;
}

Future<void> initSupabase() async {
  // On lit d'abord les dart-define (si fournis), sinon on prend un fallback DEV.
  final url = const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zykbcgqgkdsguirjvwxg.supabase.co', // <-- fallback
  );
  final anonKey = const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp5a2JjZ3Fna2RzZ3Vpcmp2d3hnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI3ODMwMTEsImV4cCI6MjA2ODM1OTAxMX0.R-iSxRy-vFvmmE80EdI2AlZCKqgADvLd9_luvrLQL-E', // <-- fallback
  );

  // Garde-fou: en prod, on exige que les dart-define soient fournis.
  if (kReleaseMode) {
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL / SUPABASE_ANON_KEY manquants. '
        'Passe-les via --dart-define pour le build/runner.',
      );
    }
  }

  await Supabase.initialize(url: url, anonKey: anonKey);
}
