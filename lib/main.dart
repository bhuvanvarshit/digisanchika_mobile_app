import 'package:digi_sanchika/presentations/Screens/home_page.dart';
import 'package:digi_sanchika/presentations/Screens/login_page.dart';
import 'package:digi_sanchika/services/api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize API service with your remote server
  await ApiService.initialize();

  if (kDebugMode) {
    print('🌐 Using backend: ${ApiService.currentBaseUrl}');
    print('🔗 Connected: ${ApiService.isConnected}');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digi Sanchika',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}
