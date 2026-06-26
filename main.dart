import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'firebase_options.dart';

import 'screens/login_page.dart';
import 'screens/cliente_portal.dart';
import 'screens/dashboard_home.dart';
import 'screens/tema_app.dart';

final ValueNotifier<ThemeMode> notificadorTemaGlobal = ValueNotifier(ThemeMode.light);
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool esModoOscuro = prefs.getBool('modo_oscuro_activado') ?? false;
  notificadorTemaGlobal.value = esModoOscuro ? ThemeMode.dark : ThemeMode.light;

  runApp(const BamajoMotorsApp());
}

class BamajoMotorsApp extends StatelessWidget {
  const BamajoMotorsApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: notificadorTemaGlobal,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Bamajo Motors',
          debugShowCheckedModeBanner: false,
          theme: TemaApp.temaClaro,
          darkTheme: TemaApp.temaOscuro,
          themeMode: currentMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});
  @override 
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkInitial();
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      bool offline = results.contains(ConnectivityResult.none);
      if (mounted && _isOffline != offline) {
        setState(() => _isOffline = offline);
      }
    });
  }

  Future<void> _checkInitial() async {
    var results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.none) && mounted) {
      setState(() => _isOffline = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isOffline)
          Positioned(
            top: 0, left: 0, right: 0,
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                bottom: false,
                child: Container(
                  color: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: const Center(
                    child: Text(
                      "Modo Offline: Verifique su conexión de red",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override 
  State<SplashScreen> createState() => _SplashScreenState();
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    // INYECCION DE LOGOS
    String logoPath = isDark ? 'images/logo_2.png' : 'images/logo_1.png';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(logoPath, height: 200, fit: BoxFit.contain),
            const SizedBox(height: 30),
            CircularProgressIndicator(color: Theme.of(context).colorScheme.secondary),
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
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
              String nombreSeguro = data['nombre'] ?? 'Usuario';
              
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    // INYECCION LOGOS
    String logoPath = isDark ? 'images/logo_2.png' : 'images/logo_1.png';
    // Forzar texto blanco en modo oscuro, sin grises.
    Color textColor = isDark ? Colors.white : Theme.of(context).primaryColor;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(logoPath, height: 200, fit: BoxFit.contain),
              const SizedBox(height: 30),
              Text("Bamajo Motors", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
              Text("Seleccione un perfil de acceso", style: TextStyle(fontSize: 16, color: textColor)),
              const SizedBox(height: 40),
              
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(60)),
                icon: const Icon(Icons.build, size: 28),
                label: const Text("Acceso Técnico", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage())),
              ),
              const SizedBox(height: 20),
              
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: textColor,
                  side: BorderSide(color: textColor),
                  minimumSize: const Size.fromHeight(60)
                ),
                icon: const Icon(Icons.person, size: 28),
                label: const Text("Portal de Clientes", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClienteLoginScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}