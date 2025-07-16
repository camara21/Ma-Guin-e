import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'routes.dart';
import 'providers/favoris_provider.dart';
import 'providers/user_provider.dart';
import 'providers/annonce_provider.dart'; // ✅ Nouveau

void main() {
  runApp(const MaGuineeApp());
}

class MaGuineeApp extends StatelessWidget {
  const MaGuineeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FavorisProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => AnnonceProvider()), // ✅ Ajouté
      ],
      child: MaterialApp(
        title: 'Ma Guinée',
        theme: ThemeData(
          primarySwatch: Colors.deepPurple,
          scaffoldBackgroundColor: Colors.grey[100],
          useMaterial3: true,
        ),
        initialRoute: AppRoutes.home,
        onGenerateRoute: AppRoutes.generateRoute,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
