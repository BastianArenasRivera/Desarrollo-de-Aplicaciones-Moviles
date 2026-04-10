import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Taller Mecánico App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// --- 1. VENTANA DE INICIO  ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gestión del Taller")),
      drawer: const MenuLateral(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings_suggest, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            const Text("Panel de Administración", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("Bienvenido. Selecciona una opción del menú lateral para comenzar.", textAlign: TextAlign.center),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ListaTrabajos())),
              icon: const Icon(Icons.list),
              label: const Text("Ver Trabajos Pendientes"),
            )
          ],
        ),
      ),
    );
  }
}

// --- MENU LATERAL PARA NAVEGACIÓN ---
class MenuLateral extends StatelessWidget {
  const MenuLateral({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text("Taller Mecánico v1.0", style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text("Inicio"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HomeScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.car_repair),
            title: const Text("Registro de Vehículos"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistroVehiculo())),
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text("Lista de Trabajos"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ListaTrabajos())),
          ),
          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text("Inventario Repuestos"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Inventario())),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Perfil Taller"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PerfilTaller())),
          ),
        ],
      ),
    );
  }
}

// --- 2. VENTANA REGISTRO DE VEHÍCULOS ---
class RegistroVehiculo extends StatefulWidget {
  const RegistroVehiculo({super.key});

  @override
  State<RegistroVehiculo> createState() => _RegistroVehiculoState();
}

class _RegistroVehiculoState extends State<RegistroVehiculo> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nuevo Ingreso")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const TextField(decoration: InputDecoration(labelText: "Patente")),
            const TextField(decoration: InputDecoration(labelText: "Marca y Modelo")),
            const TextField(decoration: InputDecoration(labelText: "Nombre del Cliente")),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () {}, child: const Text("Registrar Auto"))
          ],
        ),
      ),
    );
  }
}

// --- 3. VENTANA LISTA DE TRABAJOS  ---
class ListaTrabajos extends StatelessWidget {
  const ListaTrabajos({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Trabajos en Curso")),
      body: ListView(
        children: const [
          ListTile(leading: Icon(Icons.build), title: Text("Kia Morning - Cambio Aceite"), subtitle: Text("Estado: En espera")),
          ListTile(leading: Icon(Icons.build), title: Text("Toyota Hilux - Frenos"), subtitle: Text("Estado: En proceso")),
          ListTile(leading: Icon(Icons.check_circle, color: Colors.green), title: Text("Hyundai Accent - Luces"), subtitle: Text("Estado: Terminado")),
        ],
      ),
    );
  }
}

// --- 4. VENTANA INVENTARIO ---
class Inventario extends StatelessWidget {
  const Inventario({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Stock de Repuestos")),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(10),
        children: const [
          Card(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.oil_barrel, size: 50), Text("Aceite 10W40")])),
          Card(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.tire_repair, size: 50), Text("Neumáticos")])),
          Card(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.battery_charging_full, size: 50), Text("Baterías")])),
          Card(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.filter_alt, size: 50), Text("Filtros Aire")])),
        ],
      ),
    );
  }
}

// --- 5. VENTANA PERFIL TALLER ---
class PerfilTaller extends StatelessWidget {
  const PerfilTaller({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configuración")),
      body: const Center(
        child: Column(
          children: [
            SizedBox(height: 30),
            CircleAvatar(
              radius: 50,
              backgroundImage: AssetImage('assets/logo_taller.png'), 
            ),
            SizedBox(height: 10),
            Text("Taller Mecánico Central", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text("Sede: Talca"),
            ListTile(leading: Icon(Icons.phone), title: Text("+56 9 5518052")),
            ListTile(leading: Icon(Icons.email), title: Text("contacto@taller.cl")),
          ],
        ),
      ),
    );
  }
}