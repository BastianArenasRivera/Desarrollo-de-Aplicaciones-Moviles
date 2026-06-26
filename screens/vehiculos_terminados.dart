import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'dashboard_home.dart' show buildEmptyStateMensaje;

/// Pantalla encargada de listar los vehiculos cuyo ciclo tecnico ha concluido 
/// y se encuentran pendientes de gestion financiera y facturacion.
class VehiculosTerminadosScreen extends StatelessWidget {
  const VehiculosTerminadosScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Liquidación y Cobro")),
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
                child: ListTile(
                  leading: const Icon(Icons.monetization_on, color: Colors.green, size: 40),
                  title: Text("${v['marca'] ?? ''} ${v['modelo'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Patente: ${v['patente'] ?? ''}\nMecánico: ${v['mecanico_responsable'] ?? 'No asignado'}"),
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

/// Pantalla de despliegue financiero. Ejecuta calculos de tarifas dinamicas,
/// emision de notificaciones por email y cierre de la transaccion en base de datos.
class DetalleCobroScreen extends StatefulWidget {
  final DocumentSnapshot vehiculoDoc;
  const DetalleCobroScreen({super.key, required this.vehiculoDoc});
  @override 
  State<DetalleCobroScreen> createState() => _DetalleCobroScreenState();
}

class _DetalleCobroScreenState extends State<DetalleCobroScreen> {
  // Tabuladores de costos fijos para procedimientos estandar
  final Map<String, int> preciosBase = {
    'Revisión de líquido': 10000, 'Rectificación de discos': 40000, 'Cambio de pastillas': 35000, 'Cambio de disco': 70000, 'Ajuste freno de mano': 5000,
    'Cambio de aceite': 45000, 'Filtro de aire': 15000, 'Filtro de aceite': 12000, 'Revisión de luces': 8000, 'Revisión de niveles': 5000,
    'Escáner electrónico': 10000, 'Revisión de bujías': 30000, 'Cambio correa distribución': 150000, 'Medición compresión': 15000,
    'Rotación de neumáticos': 0, 'Balanceo por rueda': 15000, 'Alineación tren delantero': 20000, 'Ajuste de presión': 0,
  };

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

  /// Inicializa la llamada al sistema operativo para abrir enlaces externos (Ej. Fotos en navegador).
  Future<void> _abrirNavegador(String url) async {
    Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Imposible procesar el formato del archivo.")));
    }
  }

  /// Construye y despacha un correo electronico mediante la API nativa de MailTo para notificar facturacion.
  Future<void> _enviarCorreoRecibo(Map<String, dynamic> datos, int total, double iva, int subtotal) async {
    String email = datos['email_cliente'] ?? '';
    if (email.isEmpty) return;
    
    String asunto = "Recibo de Servicio Técnico - Bamajo Motors (${datos['patente']})";
    String cuerpo = "Estimado cliente,\n\nAdjuntamos el detalle administrativo correspondiente al servicio de su vehículo ${datos['marca']} ${datos['modelo']} (Patente: ${datos['patente']}).\n\nResumen Financiero:\n- Subtotal Neto: \$${subtotal.toInt()}\n- I.V.A. (19%): \$${iva.toInt()}\n- TOTAL LIQUIDADO: \$$total\n\nMedio de Pago: $_metodoPago\n\nAgradecemos su confianza en nuestro equipo profesional.";
    final Uri emailLaunchUri = Uri(scheme: 'mailto', path: email, query: 'subject=${Uri.encodeComponent(asunto)}&body=${Uri.encodeComponent(cuerpo)}');
    
    try { 
      await launchUrl(emailLaunchUri); 
    } catch (e) { 
      debugPrint("Error de integracion con el cliente de correo: $e"); 
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> vData = widget.vehiculoDoc.data() as Map<String, dynamic>;
    Map<String, dynamic> tareas = vData['tareas_asignadas'] ?? {};
    int subtotal = 0; 
    List<Widget> desglose = [];
    
    // Algoritmo de calculo iterativo para costos segmentados
    for (String t in tareas.keys) {
      if (preciosBase.containsKey(t)) {
        int repuesto = preciosBase[t]!; 
        int mo = preciosManoObra[t]!; 
        int totalTarea = repuesto + mo;
        subtotal += totalTarea; 
        desglose.add(Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Text("• $t:\n  Costos Fijos: \$${repuesto} + M.Obra: \$${mo} = \$${totalTarea}", style: const TextStyle(fontSize: 14))));
      } else {
        if (!_preciosOtrosCtrls.containsKey(t)) _preciosOtrosCtrls[t] = TextEditingController(text: "0");
        int precioPersonalizado = int.tryParse(_preciosOtrosCtrls[t]!.text) ?? 0;
        subtotal += precioPersonalizado;
        desglose.add(Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: TextField(controller: _preciosOtrosCtrls[t], keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Valor manual para: $t"))));
      }
    }

    double iva = subtotal * 0.19; 
    int propina = int.tryParse(_propinaCtrl.text) ?? 0;
    double totalCobrar = subtotal + iva + propina; 
    double comisionMecanico = subtotal * 0.30; 

    return Scaffold(
      appBar: AppBar(title: const Text("Detalle de Liquidación")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Vehículo: ${vData['marca'] ?? ''} ${vData['modelo'] ?? ''}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text("Identificador: ${vData['patente'] ?? ''} • Motor: ${vData['motor'] ?? 'N/A'}", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              const Divider(),
              
              Builder(
                builder: (context) {
                  List<String> fotos = [];
                  if (vData['foto_inspeccion'] != null) {
                    if (vData['foto_inspeccion'] is String) fotos.add(vData['foto_inspeccion']);
                    else if (vData['foto_inspeccion'] is List) fotos = List<String>.from(vData['foto_inspeccion']);
                  }
                  if (fotos.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Evidencia Fotográfica:", style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: fotos.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Stack(
                                children: [
                                  ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(fotos[index], height: 160, width: 120, fit: BoxFit.cover)),
                                  Positioned(bottom: 5, right: 5, child: CircleAvatar(backgroundColor: Colors.black87, child: IconButton(icon: const Icon(Icons.download, color: Colors.blue, size: 20), onPressed: () => _abrirNavegador(fotos[index]), tooltip: "Descargar Original")))
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(height: 30),
                    ],
                  );
                },
              ),
              
              Text("Estructura de Costos:", style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
              ...desglose,
              
              if ((vData['repuestos_utilizados'] as List?)?.isNotEmpty ?? false) ...[
                const SizedBox(height: 10),
                Text("Inventario Afectado:", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                ...((vData['repuestos_utilizados'] as List).map((r) => Text("• $r", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8))))),
              ],
              const Divider(),
              
              Text("Subtotal Neto: \$${subtotal.toInt()}", style: const TextStyle(fontWeight: FontWeight.w500)), 
              Text("Impuesto de Ley (19%): \$${iva.toInt()}", style: const TextStyle(fontWeight: FontWeight.w500)), 
              const SizedBox(height: 10),
              
              TextField(
                controller: _propinaCtrl, 
                keyboardType: TextInputType.number, 
                decoration: const InputDecoration(labelText: "Bono / Propina Voluntaria (\$)", prefixIcon: Icon(Icons.volunteer_activism)), 
                onChanged: (v) => setState(() {})
              ),
              const SizedBox(height: 15),
              
              DropdownButtonFormField<String>(
                value: _metodoPago, 
                decoration: const InputDecoration(labelText: "Medio Transaccional", prefixIcon: Icon(Icons.point_of_sale)),
                items: ['Débito', 'Crédito', 'Efectivo'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), 
                onChanged: (v) => setState(() => _metodoPago = v!),
              ),
              const SizedBox(height: 15),
              
              Text("MONTO A LIQUIDAR: \$${totalCobrar.toInt()}", style: const TextStyle(fontSize: 22, color: Colors.green, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text("Técnico Asignado: ${vData['mecanico_responsable'] ?? 'S/A'}", style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("Remuneración Variable Estimada: \$${comisionMecanico.toInt()} + \$${propina} (Bono)", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              _isProcessing 
              ? const Center(child: CircularProgressIndicator()) 
              : ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(55)),
                  icon: const Icon(Icons.send),
                  label: const Text("Registrar Pago y Notificar", style: TextStyle(fontSize: 18)),
                  onPressed: () async {
                    setState(() => _isProcessing = true);
                    
                    // Actualizacion transaccional
                    await FirebaseFirestore.instance.collection('vehiculos').doc(widget.vehiculoDoc.id).update({
                      'estado': 'Vehículo finalizado', 
                      'total_cobrado': totalCobrar, 
                      'comision_mecanico': comisionMecanico, 
                      'propina': propina, 
                      'metodo_pago': _metodoPago, 
                      'fecha_pago': FieldValue.serverTimestamp() 
                    });
                    
                    // Auditoria de evento
                    await FirebaseFirestore.instance.collection('notificaciones').add({
                      'titulo': 'Ingreso Monetario Confirmado', 'cuerpo': 'Se registró una liquidación por \$${totalCobrar.toInt()} vinculada a la matrícula ${vData['patente']}.',
                      'rol_destino': 'Jefe', 'fecha': FieldValue.serverTimestamp(), 'leida': false,
                    });
                    
                    // Despacho asíncrono
                    await _enviarCorreoRecibo(vData, totalCobrar.toInt(), iva, subtotal);
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transacción Cerrada Exitosamente"), backgroundColor: Colors.green));
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