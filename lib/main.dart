import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/app_colors.dart';
import 'core/theme_manager.dart';
import 'screens/check_pin_wrapper.dart';
import 'screens/pantalla_acceso.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBhbFjEeyztmXKE-En0yPg9OtzL2aBpROc",
      appId: "1:18395485989:android:5b2a1e13385177259b2ccc",
      messagingSenderId: "18395485989",
      projectId: "gestorprestamos-50e90",
      storageBucket: "gestorprestamos-50e90.firebasestorage.app",
    ),
  );
  await themeManager.cargarPreferencia();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeManager,
      builder: (context, modoActual, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Gestor de Préstamos',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF4F5F7),
            cardColor: Colors.white,
            dividerColor: Colors.grey.shade200,
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.danger),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              secondary: AppColors.accent,
              surface: AppColors.cardDark,
              onSurface: Colors.white,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.bgDark,
            cardColor: AppColors.cardDark,
            dividerColor: Colors.white12,
            cardTheme: const CardTheme(
              color: AppColors.cardDark,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF000000),
              foregroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIconColor: Colors.white54,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accent, width: 2),
              ),
            ),
            dialogTheme: const DialogTheme(
              backgroundColor: Color(0xFF111111),
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              contentTextStyle: TextStyle(color: Colors.white70),
            ),
          ),
          themeMode: modoActual,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasData) return const CheckPinWrapper();
              return const PantallaAcceso();
            },
          ),
        );
      },
    );
  }
}
