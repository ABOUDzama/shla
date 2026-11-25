import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

import 'services/online_data_service.dart';
import 'services/supabase_service.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false; // Cairo bundled in assets/fonts
  await SettingsService.init();
  await SupabaseService.initialize();

  // Sync user profile on startup (registers device even if name is empty)
  SupabaseService.syncProfile(
    deviceId: SettingsService.deviceId,
    name: SettingsService.userName.isEmpty ? "مستخدم جديد" : SettingsService.userName,
    avatar: SettingsService.userAvatar,
  ).catchError((e) {
    debugPrint('Startup Sync Error: $e');
  });

  // Start syncing game data in the background (no await to not block startup)
  OnlineDataService.syncData();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool? _isOffline;

  @override
  void initState() {
    super.initState();
    _subscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final bool currentlyOffline = result.contains(ConnectivityResult.none) || result.isEmpty;
    
    if (_isOffline == null) {
      // First check on startup
      _isOffline = currentlyOffline;
      if (currentlyOffline) {
        _showConnectivitySnackBar('أنت الآن في وضع الأوفلاين 📴', isError: true);
      }
      return;
    }

    if (currentlyOffline != _isOffline) {
      setState(() {
        _isOffline = currentlyOffline;
      });
      if (currentlyOffline) {
        _showConnectivitySnackBar('انقطع الاتصال.. أنت في وضع الأوفلاين 📴', isError: true);
      } else {
        _showConnectivitySnackBar('تم استعادة الاتصال.. أنت أونلاين الآن! ✨', isError: false);
      }
    }
  }

  void _showConnectivitySnackBar(String message, {required bool isError}) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.wifi_off_rounded : Icons.wifi_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade900 : Colors.green.shade900,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'شِلَّة',

      theme: ThemeData(
        useMaterial3: true,
        // Dark & modern theme base
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo
          brightness: Brightness.dark,
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF14B8A6), // Teal
          surface: const Color(0xFF1E293B), // Slate 800
        ),
        textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.cairo(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            shadowColor: const Color(0xFF6366F1).withAlpha(150),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E293B),
          contentTextStyle: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 10,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
