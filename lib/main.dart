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
      title: 'Biblioteca Digital',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Vibrant Indigo
          brightness: Brightness.dark,
          primary: const Color(0xFF6366F1),
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFF282B48),
          onPrimaryContainer: const Color(0xFFE0E2FF),
          secondary: const Color(0xFF38BDF8), // Electric Cyan
          onSecondary: const Color(0xFF003548),
          secondaryContainer: const Color(0xFF0F3854),
          onSecondaryContainer: const Color(0xFFBAEAFF),
          tertiary: const Color(0xFFA855F7), // Purple accent
          tertiaryContainer: const Color(0xFF371D58),
          onTertiaryContainer: const Color(0xFFF3E8FF),
          surface: const Color(0xFF131520),
          surfaceContainerLowest: const Color(0xFF090A10),
          surfaceContainerLow: const Color(0xFF0E1018),
          surfaceContainer: const Color(0xFF131520),
          surfaceContainerHigh: const Color(0xFF1A1D2C),
          surfaceContainerHighest: const Color(0xFF222638),
          outline: const Color(0xFF373B52),
          outlineVariant: const Color(0xFF26293A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0C12),
        cardTheme: CardThemeData(
          color: const Color(0xFF151824),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF26293A), width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFF0F111A),
          foregroundColor: Color(0xFFF1F0FB),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: Color(0xFFF1F0FB),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0F111A),
          elevation: 0,
          indicatorColor: const Color(0xFF312E5B),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFFE0E2FF) : const Color(0xFF8B8FA8),
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 24,
              color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF8B8FA8),
            );
          }),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF161824),
          hintStyle: const TextStyle(color: Color(0xFF6B728D), fontSize: 14),
          labelStyle: const TextStyle(color: Color(0xFF9CA3BF), fontSize: 14),
          prefixIconColor: const Color(0xFF818CF8),
          suffixIconColor: const Color(0xFF818CF8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF26293A)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF26293A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.8),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: const Color(0x666366F1),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF6366F1),
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF1B1E2D),
          labelStyle: const TextStyle(
            fontSize: 12,
            color: Color(0xFFCBD5E1),
            fontWeight: FontWeight.w500,
          ),
          side: const BorderSide(color: Color(0xFF2D3247), width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
