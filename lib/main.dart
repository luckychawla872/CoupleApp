import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'theme/couple_theme.dart';
import 'providers/AuthProvider.dart';
import 'providers/RelationshipProvider.dart';
import 'providers/ChatProvider.dart';
import 'providers/SecurityProvider.dart';
import 'providers/ThemeProvider.dart';
import 'screens/SplashScreen.dart';
import 'screens/LockScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase client
  final supabaseService = SupabaseService();
  try {
    await supabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase Initialization Error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RelationshipProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => SecurityProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial online status
    SupabaseService().updateOnlineStatus(true);
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      SupabaseService().updateOnlineStatus(true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    SupabaseService().updateOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SupabaseService().updateOnlineStatus(true);
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(minutes: 3), (_) {
        SupabaseService().updateOnlineStatus(true);
      });
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.hidden) {
      _heartbeatTimer?.cancel();
      SupabaseService().updateOnlineStatus(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Couple',
          debugShowCheckedModeBanner: false,
          theme: CoupleTheme.lightTheme,
          darkTheme: CoupleTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          scrollBehavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
          builder: (context, child) {
            return LockScreen(child: child!);
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
