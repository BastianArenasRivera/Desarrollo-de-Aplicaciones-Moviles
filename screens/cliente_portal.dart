import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'gestion_personal.dart' show RutFormatter; 

class ClienteLoginScreen extends StatefulWidget {
  const ClienteLoginScreen({super.key});
  @override 
  State<ClienteLoginScreen> createState() => _ClienteLoginScreenState();
}

class _ClienteLoginScreenState extends State<ClienteLoginScreen> {
  final _rutCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _buscarVehiculos() async {
    if (_rutCtrl.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    var query = await FirebaseFirestore.instance.collection('vehiculos').where('rut_cliente', isEqualTo: _rutCtrl.text.trim()).get();
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (query.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No existen ordenes activas asociadas a este documento"), backgroundColor: Colors.red));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ClienteDashboardScreen(rut: _rutCtrl.text.trim())));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // INYECCION DE LOGOS Y COLORES QUIRURGICOS
    String logoPath = isDark ? 'images/logo_22.png' : 'images/logo_11.png';
    Color bgColor = isDark ? const Color(0xFFD2691E) : Theme.of(context).scaffoldBackgroundColor;
    Color textColor = isDark ? Colors.white : Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Portal de Clientes"),
        backgroundColor: isDark ? const Color(0xFFD2691E) : Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(logoPath, height: 150, fit: BoxFit.contain),
              const SizedBox(height: 20),
              Text(
                "Seguimiento en Tiempo Real", 
                textAlign: TextAlign.center, 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _rutCtrl, 
                inputFormatters: [RutFormatter()], 
                style: TextStyle(color: isDark ? Colors.black : textColor),
                decoration: InputDecoration(
                  labelText: "Documento de Identidad (RUT)", 
                  labelStyle: TextStyle(color: isDark ? Colors.black87 : textColor),
                  prefixIcon: Icon(Icons.badge, color: isDark ? Colors.black87 : null),
                  filled: true,
                  fillColor: isDark ? Colors.white : Theme.of(context).inputDecorationTheme.fillColor,
                )
              ),
              const SizedBox(height: 20),
              _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(55),
                      backgroundColor: isDark ? Colors.black : Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _buscarVehiculos,
                    child: const Text("Consultar Estado", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  )
            ],
          ),
        ),
      ),
    );
  }
}

class ClienteDashboardScreen extends StatelessWidget {
  final String rut;
  const ClienteDashboardScreen({super.key, required this.rut});

  double _getProgreso(String estado) {
    switch (estado) {
      case 'Esperando inspección': return 0.2;
      case 'En curso': return 0.6;
      case 'Auto Listo': return 0.9;
      case 'Vehículo finalizado': return 1.0;
      default: return 0.0;
    }
  }

  Color _getColorProgreso(BuildContext context, String estado) {
    switch (estado) {
      case 'Esperando inspección': return Colors.redAccent;
      case 'En curso': return Theme.of(context).colorScheme.secondary;
      case 'Auto Listo': return Colors.lightGreen;
      case 'Vehículo finalizado': return Colors.green;
      default: return Theme.of(context).primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // COLORES QUIRURGICOS MODO OSCURO
    Color bgColor = isDark ? const Color(0xFFD2691E) : Theme.of(context).scaffoldBackgroundColor;
    Color textColor = isDark ? Colors.white : Theme.of(context).primaryColor;
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Theme.of(context).cardColor;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('vehiculos').where('rut_cliente', isEqualTo: rut).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error de acceso: ${snapshot.error}"));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return Scaffold(backgroundColor: bgColor, appBar: AppBar(title: const Text("Tus Vehículos"), backgroundColor: isDark ? const Color(0xFFD2691E) : null, elevation: 0), body: Center(child: Text("Sin información reciente.", style: TextStyle(color: textColor))));

        var primerAuto = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        String nombreCL = primerAuto['nombre_cliente'] ?? 'Estimado';
        String apellidoCL = primerAuto['apellido_cliente'] ?? 'Cliente';

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text("Resumen - $nombreCL $apellidoCL"),
            backgroundColor: isDark ? const Color(0xFFD2691E) : Theme.of(context).appBarTheme.backgroundColor,
            elevation: 0,
          ), 
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var v = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              String estado = v['estado'] ?? 'No Identificado';
              Map<String, dynamic> tareas = v['tareas_asignadas'] ?? {};
              
              List<String> fotos = [];
              if (v['foto_inspeccion'] != null) {
                if (v['foto_inspeccion'] is String) fotos.add(v['foto_inspeccion']);
                else if (v['foto_inspeccion'] is List) fotos = List<String>.from(v['foto_inspeccion']);
              }
              
              return Card(
                color: cardColor,
                margin: const EdgeInsets.only(bottom: 15),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("${v['marca'] ?? 'Marca'} ${v['modelo'] ?? 'Modelo'}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white24 : Theme.of(context).colorScheme.primary.withOpacity(0.1), 
                              borderRadius: BorderRadius.circular(8)
                            ),
                            child: Text(v['patente'] ?? 'S/P', style: TextStyle(color: isDark ? Colors.white : Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text("Atención Requerida: ${v['servicio'] ?? 'General'}", style: TextStyle(color: textColor)),
                      const Divider(height: 30),
                      Text("Estatus: $estado", style: TextStyle(color: _getColorProgreso(context, estado), fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: _getProgreso(estado), 
                        backgroundColor: isDark ? Colors.white24 : Colors.black12, 
                        color: _getColorProgreso(context, estado), 
                        minHeight: 10, 
                        borderRadius: BorderRadius.circular(10)
                      ),
                      const SizedBox(height: 15),
                      
                      Text("Registro de Intervenciones:", style: TextStyle(color: isDark ? Colors.white70 : Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
                      if (tareas.isEmpty) Text("En espera de diagnóstico técnico...", style: TextStyle(color: textColor))
                      else ...tareas.keys.map((k) => ListTile(
                        dense: true, contentPadding: EdgeInsets.zero,
                        leading: Icon(tareas[k] == true ? Icons.check_circle : Icons.handyman, color: tareas[k] == true ? Colors.green : textColor),
                        title: Text(k, style: TextStyle(color: tareas[k] == true ? Colors.green : textColor)),
                      )),

                      if (fotos.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text("Respaldo Visual:", style: TextStyle(color: isDark ? Colors.white70 : Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: fotos.length,
                            itemBuilder: (context, i) => Padding(padding: const EdgeInsets.only(right: 10), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(fotos[i], width: 100, fit: BoxFit.cover))),
                          ),
                        )
                      ],

                      const SizedBox(height: 10),
                      if (estado == 'Vehículo finalizado') const Text("Operación comercial y técnica finalizada exitosamente.", style: TextStyle(color: Colors.green)),
                      if (estado == 'Auto Listo') const Text("Unidad operativa. Proceda al área de caja para retiro.", style: TextStyle(color: Colors.lightGreen, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}