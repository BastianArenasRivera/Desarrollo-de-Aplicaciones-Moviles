import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // 🔥 Importación obligatoria para correos y descargas
import 'dashboard_home.dart' show buildEmptyStateMensaje;

class VehiculosTerminadosScreen extends StatelessWidget {
  const VehiculosTerminadosScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Listos para Cobro")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehiculos').where('estado', isEqualTo: 'Auto Listo').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return buildEmptyStateMensaje();
          
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (ctx, i) {
              var doc = snapshot.data!.docs[i];
              var v = doc.data() as Map<String, dynamic>;
              return Card(
                color: const Color(0xFF1E1E1E),
                child: ListTile(
                  leading: const Icon(Icons.monetization_on, color: Colors.green, size: 40),
                  title: Text("${v['marca'] ?? ''} ${v['modelo'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Patente: ${v['patente'] ?? ''}  •  Motor: ${v['motor'] ?? 'N/A'}\nMecánico: ${v['mecanico_responsable'] ?? 'Desconocido'}"),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleCobroScreen(vehiculoDoc: doc))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class DetalleCobroScreen extends StatefulWidget {
  final DocumentSnapshot vehiculoDoc;
  const DetalleCobroScreen({super.key, required this.vehiculoDoc});
  @override State<DetalleCobroScreen> createState() => _DetalleCobroScreenState();
}

class _DetalleCobroScreenState extends State<DetalleCobroScreen> {
  // Precios base de repuestos
  final Map<String, int> preciosBase = {
    'Revisión de líquido': 10000, 'Rectificación de discos': 40000, 'Cambio de pastillas': 35000, 'Cambio de disco': 70000, 'Ajuste freno de mano': 5000,
    'Cambio de aceite': 45000, 'Filtro de aire': 15000, 'Filtro de aceite': 12000, 'Revisión de luces': 8000, 'Revisión de niveles': 5000,
    'Escáner electrónico': 10000, 'Revisión de bujías': 30000, 'Cambio correa distribución': 150000, 'Medición compresión': 15000,
    'Rotación de neumáticos': 0, 'Balanceo por rueda': 15000, 'Alineación tren delantero': 20000, 'Ajuste de presión': 0,
  };

  // Precios de Mano de Obra
  final Map<String, int> preciosManoObra = {
    'Revisión de líquido': 5000, 'Rectificación de discos': 25000, 'Cambio de pastillas': 15000, 'Cambio de disco': 20000, 'Ajuste freno de mano': 10000,
    'Cambio de aceite': 20000, 'Filtro de aire': 5000, 'Filtro de aceite': 5000, 'Revisión de luces': 5000, 'Revisión de niveles': 5000,
    'Escáner electrónico': 15000, 'Revisión de bujías': 10000, 'Cambio correa distribución': 80000, 'Medición compresión': 20000,
    'Rotación de neumáticos': 10000, 'Balanceo por rueda': 5000, 'Alineación tren delantero': 15000, 'Ajuste de presión': 2000,
  };
  
  final Map<String, TextEditingController> _preciosOtrosCtrls = {};
  final TextEditingController _propinaCtrl = TextEditingController(text: "0"); 
  String _metodoPago = 'Débito'; 
  bool _isProcessing = false; 

  Future<void> _abrirNavegador(String url) async {
    Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo abrir el archivo")));
    }
  }

  Future<void> _enviarCorreoRecibo(Map<String, dynamic> datos, int total, double iva, int subtotal) async {
    String email = datos['email_cliente'] ?? '';
    if (email.isEmpty) return;

    String asunto = "Recibo de Pago - Bamajo Motors (${datos['patente']})";
    String cuerpo = "Hola,\n\nAdjuntamos el detalle de pago de su vehículo ${datos['marca']} ${datos['modelo']} (Patente: ${datos['patente']}).\n\n"
                    "Subtotal: \$${subtotal.toInt()}\n"
                    "IVA (19%): \$${iva.toInt()}\n"
                    "TOTAL PAGADO: \$$total\n"
                    "Método de Pago: $_metodoPago\n\n"
                    "Gracias por preferir Bamajo Motors.";

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(asunto)}&body=${Uri.encodeComponent(cuerpo)}',
    );

    try {
      await launchUrl(emailLaunchUri);
    } catch (e) {
      debugPrint("No se pudo abrir la app de correos: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> vData = widget.vehiculoDoc.data() as Map<String, dynamic>;
    Map<String, dynamic> tareas = vData['tareas_asignadas'] ?? {};
    int subtotal = 0; List<Widget> desglose = [];
    
    for (String t in tareas.keys) {
      if (preciosBase.containsKey(t)) {
        int repuesto = preciosBase[t]!;
        int mo = preciosManoObra[t]!;
        int totalTarea = repuesto + mo;
        subtotal += totalTarea; 
        
        desglose.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text("• $t:\n  Repuestos: \$${repuesto} + M.O: \$${mo} = \$${totalTarea}", style: const TextStyle(fontSize: 14)),
        ));
      } else {
        if (!_preciosOtrosCtrls.containsKey(t)) _preciosOtrosCtrls[t] = TextEditingController(text: "0");
        int precioPersonalizado = int.tryParse(_preciosOtrosCtrls[t]!.text) ?? 0;
        subtotal += precioPersonalizado;
        desglose.add(Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: TextField(controller: _preciosOtrosCtrls[t], keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Valor manual para: $t", border: const OutlineInputBorder()), onChanged: (v) => setState(() {}))));
      }
    }

    double iva = subtotal * 0.19; int propina = int.tryParse(_propinaCtrl.text) ?? 0;
    double totalCobrar = subtotal + iva + propina; double comisionMecanico = subtotal * 0.30; 

    return Scaffold(
      appBar: AppBar(title: const Text("Detalle de Cobro")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Vehículo: ${vData['marca'] ?? ''} ${vData['modelo'] ?? ''}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text("Patente: ${vData['patente'] ?? ''} • Año: ${vData['ano'] ?? 'N/A'} • Motor: ${vData['motor'] ?? 'N/A'}", style: const TextStyle(color: Colors.grey)),
              Text("Cliente RUT: ${vData['rut_cliente'] ?? 'N/A'} • Tel: ${vData['telefono_cliente'] ?? 'N/A'}", style: const TextStyle(color: Colors.grey)),
              Text("Correo: ${vData['email_cliente'] ?? 'No registrado'}", style: const TextStyle(color: Colors.lightBlue)), 
              const Divider(),
              
              if (vData['foto_inspeccion'] != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Foto de Inspección:", style: TextStyle(color: Color(0xFFD2691E), fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.download, color: Colors.blue), 
                      tooltip: "Ver y descargar imagen",
                      onPressed: () => _abrirNavegador(vData['foto_inspeccion'])
                    )
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(vData['foto_inspeccion'], height: 150, width: double.infinity, fit: BoxFit.cover),
                ),
                const Divider(),
              ],

              const Text("Desglose de Tareas:", style: TextStyle(color: Color(0xFFD2691E), fontWeight: FontWeight.bold)),
              ...desglose,
              
              if ((vData['repuestos_utilizados'] as List?)?.isNotEmpty ?? false) ...[
                const SizedBox(height: 10),
                const Text("Repuestos de Inventario Utilizados:", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ...((vData['repuestos_utilizados'] as List).map((r) => Text("• $r", style: const TextStyle(color: Colors.white70)))),
              ],

              const Divider(),
              Text("Subtotal Neto: \$${subtotal.toInt()}"), Text("IVA (19%): \$${iva.toInt()}"), const SizedBox(height: 10),
              TextField(controller: _propinaCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Propina Voluntaria Cliente (\$)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.volunteer_activism)), onChanged: (v) => setState(() {})),
              const SizedBox(height: 15),
              
              DropdownButtonFormField<String>(
                value: _metodoPago, dropdownColor: const Color(0xFF1E1E1E), 
                decoration: const InputDecoration(labelText: "Método de Pago", border: OutlineInputBorder(), prefixIcon: Icon(Icons.point_of_sale)),
                items: ['Débito', 'Crédito', 'Efectivo'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), 
                onChanged: (v) => setState(() => _metodoPago = v!),
              ),
              const SizedBox(height: 15),

              Text("TOTAL A COBRAR: \$${totalCobrar.toInt()}", style: const TextStyle(fontSize: 22, color: Colors.green, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(10), color: const Color(0xFF1E1E1E), 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Mecánico: ${vData['mecanico_responsable'] ?? 'Desconocido'}", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("RUT Mecánico: ${vData['mecanico_rut'] ?? 'N/A'}", style: const TextStyle(color: Colors.amber)),
                    Text("Comisión: \$${comisionMecanico.toInt()} + Propina: \$${propina}", style: const TextStyle(color: Colors.amber)),
                  ],
                )
              ),
              const SizedBox(height: 30),
              
              _isProcessing 
              ? const Center(child: CircularProgressIndicator()) 
              : ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(55)),
                icon: const Icon(Icons.send),
                label: const Text("Confirmar Pago y Enviar Recibo", style: TextStyle(fontSize: 18)),
                onPressed: () async {
                  setState(() => _isProcessing = true);
                  
                  await FirebaseFirestore.instance.collection('vehiculos').doc(widget.vehiculoDoc.id).update({
                    'estado': 'Vehículo finalizado', 
                    'total_cobrado': totalCobrar, 
                    'comision_mecanico': comisionMecanico, 
                    'propina': propina,
                    'metodo_pago': _metodoPago 
                  });
                  
                  await _enviarCorreoRecibo(vData, totalCobrar.toInt(), iva, subtotal);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pago Confirmado ✅"), backgroundColor: Colors.green));
                    Navigator.pop(context);
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

class HistorialGananciasScreen extends StatelessWidget {
  const HistorialGananciasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Historial de Trabajos")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehiculos').where('estado', isEqualTo: 'Vehículo finalizado').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return buildEmptyStateMensaje();

          var docs = snapshot.data!.docs.toList();
          docs.sort((a, b) {
            Timestamp? tA = (a.data() as Map<String, dynamic>)['fecha'];
            Timestamp? tB = (b.data() as Map<String, dynamic>)['fecha'];
            if (tA == null || tB == null) return 0;
            return tB.compareTo(tA);
          });

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index]; 
              var v = doc.data() as Map<String, dynamic>;
              DateTime? fecha = v['fecha'] != null ? (v['fecha'] as Timestamp).toDate() : null;
              String fechaStr = fecha != null ? "${fecha.day}/${fecha.month}/${fecha.year}" : "Sin fecha";

              return Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long, color: Colors.amber, size: 40),
                  title: Text("${v['marca'] ?? ''} ${v['modelo'] ?? ''} - ${v['patente'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Pago: ${v['metodo_pago'] ?? 'Débito'}\nMecánico: ${v['mecanico_responsable'] ?? 'Desconocido'} • Fecha: $fechaStr"),
                  trailing: Text("\$${v['total_cobrado']?.toInt() ?? 0}", style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleHistorialScreen(vehiculoDoc: doc))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class DetalleHistorialScreen extends StatelessWidget {
  final DocumentSnapshot vehiculoDoc; 
  const DetalleHistorialScreen({super.key, required this.vehiculoDoc});

  Future<void> _abrirNavegador(BuildContext context, String url) async {
    Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo abrir el archivo")));
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> vehiculoData = vehiculoDoc.data() as Map<String, dynamic>;
    Map<String, dynamic> tareas = vehiculoData['tareas_asignadas'] ?? {};
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle del Trabajo"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: "Eliminar Registro",
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: const Text("Eliminar Registro", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  content: const Text("¿Estás seguro de que deseas eliminar este trabajo del historial? Esta acción no se puede deshacer y los gráficos se actualizarán."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                        await FirebaseFirestore.instance.collection('vehiculos').doc(vehiculoDoc.id).delete();
                        if (context.mounted) {
                          Navigator.pop(ctx); 
                          Navigator.pop(context); 
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registro eliminado correctamente"), backgroundColor: Colors.green));
                        }
                      },
                      child: const Text("Eliminar"),
                    )
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Vehículo: ${vehiculoData['marca']} ${vehiculoData['modelo']}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text("Patente: ${vehiculoData['patente']} • Año: ${vehiculoData['ano'] ?? 'N/A'} • Motor: ${vehiculoData['motor'] ?? 'N/A'}", style: const TextStyle(fontSize: 16, color: Colors.grey)),
              Text("Cliente RUT: ${vehiculoData['rut_cliente'] ?? 'N/A'} • Tel: ${vehiculoData['telefono_cliente'] ?? 'N/A'}", style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 20),
              
              if (vehiculoData['foto_inspeccion'] != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Foto de Inspección:", style: TextStyle(color: Color(0xFFD2691E), fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.download, color: Colors.blue), 
                      tooltip: "Descargar",
                      onPressed: () => _abrirNavegador(context, vehiculoData['foto_inspeccion'])
                    )
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(vehiculoData['foto_inspeccion'], height: 200, width: double.infinity, fit: BoxFit.cover),
                ),
                const Divider(height: 30),
              ],
              
              const Text("Mecánico Responsable:", style: TextStyle(color: Color(0xFFD2691E), fontWeight: FontWeight.bold)),
              Text("${vehiculoData['mecanico_responsable'] ?? 'Desconocido'}", style: const TextStyle(fontSize: 18)),
              Text("RUT: ${vehiculoData['mecanico_rut'] ?? 'N/A'}", style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const Divider(height: 30),
              
              const Text("Tareas Realizadas:", style: TextStyle(color: Color(0xFFD2691E), fontWeight: FontWeight.bold)),
              ...tareas.keys.map((k) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.check_circle, color: Colors.green), title: Text(k))),
              
              if ((vehiculoData['repuestos_utilizados'] as List?)?.isNotEmpty ?? false) ...[
                const Divider(height: 20),
                const Text("Repuestos Utilizados:", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ...((vehiculoData['repuestos_utilizados'] as List).map((r) => Text("• $r", style: const TextStyle(color: Colors.white70)))),
              ],
  
              const Divider(height: 30),
              
              Text("Método de Pago: ${vehiculoData['metodo_pago'] ?? 'Débito'}", style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text("Total Cobrado al Cliente: \$${vehiculoData['total_cobrado']?.toInt() ?? 0}", style: const TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Comisión Mecánico: \$${vehiculoData['comision_mecanico']?.toInt() ?? 0}", style: const TextStyle(fontSize: 16, color: Colors.amber)),
              Text("Propina: \$${vehiculoData['propina']?.toInt() ?? 0}", style: const TextStyle(fontSize: 16, color: Colors.amber)),
            ],
          ),
        ),
      ),
    );
  }
}