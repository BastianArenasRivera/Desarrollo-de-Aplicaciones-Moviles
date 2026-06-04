import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RutFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    String text = newValue.text.replaceAll(RegExp(r'[^0-9kK]'), '');
    if (text.length > 1) {
      text = '${text.substring(0, text.length - 1)}-${text.substring(text.length - 1)}';
    }
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class ClienteLoginScreen extends StatefulWidget {
  const ClienteLoginScreen({super.key});
  @override State<ClienteLoginScreen> createState() => _ClienteLoginScreenState();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se encontraron vehículos asociados a este RUT"), backgroundColor: Colors.red));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ClienteDashboardScreen(rut: _rutCtrl.text.trim())));
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color colorFondo = Color(0xFFF08A00);
    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text("Acceso Clientes")),
      
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.car_repair, size: 100, color: Colors.black),
              const SizedBox(height: 20),
              const Text("Consulta el estado de tu vehículo", textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 30),
              TextField(
                controller: _rutCtrl, 
                inputFormatters: [RutFormatter()], 
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: "Ingresa tu RUT (Se formatea solo)", labelStyle: const TextStyle(color: Colors.black87),
                  filled: true, fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.badge, color: Colors.black),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                )
              ),
              const SizedBox(height: 20),
              _isLoading 
                ? const CircularProgressIndicator(color: Colors.black)
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: colorFondo, minimumSize: const Size.fromHeight(55)),
                    onPressed: _buscarVehiculos,
                    child: const Text("Buscar Mis Vehículos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  Color _getColorProgreso(String estado) {
    switch (estado) {
      case 'Esperando inspección': return Colors.redAccent;
      case 'En curso': return Colors.amber;
      case 'Auto Listo': return Colors.lightGreen;
      case 'Vehículo finalizado': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mis Vehículos")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehiculos').where('rut_cliente', isEqualTo: rut).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No se encontraron datos."));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var v = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              String estado = v['estado'] ?? 'Desconocido';
              
              return Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("${v['marca'] ?? 'Marca'} ${v['modelo'] ?? 'Modelo'}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                            child: Text(v['patente'] ?? 'S/P', style: const TextStyle(color: Color(0xFFD2691E), fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text("Servicio: ${v['servicio'] ?? 'General'}", style: const TextStyle(color: Colors.grey)),
                      const Divider(height: 30),
                      Text("Estado actual: $estado", style: TextStyle(color: _getColorProgreso(estado), fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: _getProgreso(estado),
                        backgroundColor: Colors.grey[800],
                        color: _getColorProgreso(estado),
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(height: 10),
                      if (estado == 'Vehículo finalizado')
                        const Text("¡Tu vehículo está listo y el trabajo finalizado!", style: TextStyle(color: Colors.green)),
                      if (estado == 'Auto Listo')
                        const Text("¡Tu vehículo está reparado! Puedes pasar por caja.", style: TextStyle(color: Colors.lightGreen)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
