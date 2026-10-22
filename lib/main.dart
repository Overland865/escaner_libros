import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/api_service.dart';
import 'views/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Aviso al cargar el archivo .env: $e');
  }
  await ApiService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biblioteca Eclesiástica',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF283593), // Indigo eclesiástico
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF101116),
        cardTheme: const CardThemeData(
          color: Color(0xFF1B1C24),
          surfaceTintColor: Colors.transparent,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFF171820),
          foregroundColor: Color(0xFFE6E1F5),
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF171820),
          indicatorColor: Color(0xFF39345C),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(color: Color(0xFFE6E1F5)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF23242D),
          hintStyle: TextStyle(color: Color(0xFFB9B4C7)),
          labelStyle: TextStyle(color: Color(0xFFCAC4D8)),
          prefixIconColor: Color(0xFFC6BFFF),
          suffixIconColor: Color(0xFFC6BFFF),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF494653)),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF494653)),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
