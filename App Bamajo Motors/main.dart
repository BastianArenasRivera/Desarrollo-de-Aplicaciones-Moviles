import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'screens/login_page.dart';
import 'screens/cliente_portal.dart';
import 'screens/dashboard_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    const Color cafeBrillante = Color(0xFFD2691E);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bamajo Motors',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black, foregroundColor: Colors.white, centerTitle: true),
        colorScheme: const ColorScheme.dark(primary: cafeBrillante, secondary: Colors.grey),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: cafeBrillante, foregroundColor: Colors.white)),
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: cafeBrillante, width: 2)),
          labelStyle: TextStyle(color: Colors.grey),
          floatingLabelStyle: TextStyle(color: cafeBrillante),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthWrapper()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF08A00),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('images/logo.jpg', height: 200, fit: BoxFit.contain),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Colors.black),
          ],
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        if (snapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              if (!userSnap.hasData || !userSnap.data!.exists) {
                FirebaseAuth.instance.signOut();
                return const RoleSelectionScreen(); 
              }
              var data = userSnap.data!.data() as Map<String, dynamic>? ?? {};
              String rolSeguro = data['rol'] ?? 'Mecánico';
              String nombreSeguro = data['nombre'] ?? 'Usuario Desconocido';
              
              return HomeScreen(rol: rolSeguro, nombre: nombreSeguro);
            },
          );
        }
        return const RoleSelectionScreen();
      },
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color colorFondo = Color(0xFFF08A00);
    return Scaffold(
      backgroundColor: colorFondo,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('images/logo.jpg', height: 200, fit: BoxFit.contain),
              const SizedBox(height: 30),
              const Text("Bienvenido a Bamajo Motors", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
              const Text("Selecciona tu perfil para ingresar", style: TextStyle(fontSize: 16, color: Colors.black87)),
              const SizedBox(height: 40),
              
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, foregroundColor: colorFondo,
                  minimumSize: const Size.fromHeight(60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                icon: const Icon(Icons.build, size: 28),
                label: const Text("Soy Trabajador", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                icon: const Icon(Icons.person, size: 28),
                label: const Text("Soy Cliente", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ClienteLoginScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}