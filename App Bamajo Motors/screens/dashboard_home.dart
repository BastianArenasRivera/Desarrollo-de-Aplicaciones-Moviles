import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'gestion_personal.dart';
import 'inventario.dart';
import 'registro_vehiculo.dart';
import 'historial_trabajos.dart';
import 'autos_activos.dart'; 

Widget buildEmptyStateMensaje() {
  return Center(
    child: Container(
      padding: const EdgeInsets.all(20), margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(10)),
      child: const Text("No hay datos por el momento", style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  final String rol; final String nombre;
  const HomeScreen({super.key, required this.rol, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel Principal"),
        
      ), 
      drawer: MenuLateral(rol: rol, nombre: nombre),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehiculos').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          int autosActivos = 0; int autosFinalizados = 0; 
          int esperando = 0, enCurso = 0, finalizadasMecanico = 0;
          int trabajosMesMecanico = 0; double comisionMecanico = 0.0, propinaMecanico = 0.0;
          
          Map<int, double> ganDebito = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0, 8:0, 9:0, 10:0, 11:0, 12:0};
          Map<int, double> ganCredito = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0, 8:0, 9:0, 10:0, 11:0, 12:0};
          Map<int, double> ganEfectivo = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0, 8:0, 9:0, 10:0, 11:0, 12:0};

          Map<String, int> trabajosPorMecanico = {};
          List<Color> coloresPastel = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.teal];
          int colorIndex = 0;

          for (var doc in snapshot.data!.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            if (!data.containsKey('patente') || data['patente'].toString().trim().isEmpty) continue; 

            String estado = data['estado'] ?? '';
            String mecResp = data['mecanico_responsable'] ?? '';
            double cobrado = (data['total_cobrado'] ?? 0).toDouble();
            String metodoPago = data['metodo_pago'] ?? 'Débito';

            if (estado != 'Vehículo finalizado') autosActivos++; 
            else {
              autosFinalizados++;
              if (data['fecha'] != null) {
                DateTime fecha = (data['fecha'] as Timestamp).toDate();
                if (metodoPago == 'Débito') ganDebito[fecha.month] = ganDebito[fecha.month]! + cobrado;
                if (metodoPago == 'Crédito') ganCredito[fecha.month] = ganCredito[fecha.month]! + cobrado;
                if (metodoPago == 'Efectivo') ganEfectivo[fecha.month] = ganEfectivo[fecha.month]! + cobrado;
              }
              if (mecResp.isNotEmpty) {
                trabajosPorMecanico[mecResp] = (trabajosPorMecanico[mecResp] ?? 0) + 1;
              }
            }

            if (rol == 'Mecánico' && mecResp == nombre) {
              if (estado == 'Esperando inspección') esperando++;
              else if (estado == 'En curso') enCurso++;
              else if (estado == 'Auto Listo' || estado == 'Vehículo finalizado') finalizadasMecanico++;

              if (estado == 'Vehículo finalizado') {
                trabajosMesMecanico++;
                comisionMecanico += (data['comision_mecanico'] ?? 0).toDouble();
                propinaMecanico += (data['propina'] ?? 0).toDouble();
              }
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Hola, $nombre", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                Text(rol, style: const TextStyle(fontSize: 18, color: const Color(0xFFD2691E))),
                const SizedBox(height: 20),
                
                if (['Administrador', 'Jefe'].contains(rol)) ...[
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AutosActivosScreen())),
                          child: _buildCard("Autos Activos", autosActivos.toString(), Colors.blue, Icons.directions_car)
                        )
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _buildCard("Total Reparados", autosFinalizados.toString(), Colors.purple, Icons.done_all)),
                    ],
                  ),
                  const SizedBox(height: 30),
                  
                  const Text("Ganancias por Método de Pago", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Row(
                    children: [
                      Icon(Icons.circle, color: Colors.blue, size: 12), SizedBox(width: 5), Text("Débito", style: TextStyle(fontSize: 12)), SizedBox(width: 15),
                      Icon(Icons.circle, color: Colors.purple, size: 12), SizedBox(width: 5), Text("Crédito", style: TextStyle(fontSize: 12)), SizedBox(width: 15),
                      Icon(Icons.circle, color: Colors.green, size: 12), SizedBox(width: 5), Text("Efectivo", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  Container(
                    height: 220, padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(10)),
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 45, 
                              getTitlesWidget: (value, meta) {
                                return Text('${value.toInt()}k', style: const TextStyle(fontSize: 10, color: Colors.grey));
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30, 
                              interval: 1, 
                              getTitlesWidget: (value, meta) {
                                List<String> meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
                                if(value.toInt() >= 1 && value.toInt() <= 12) {
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    child: Text(meses[value.toInt()-1], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  );
                                }
                                return const Text('');
                              }
                            )
                          ),
                        ),
                        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.2))),
                        lineBarsData: [
                          LineChartBarData(
                            spots: ganDebito.entries.map((e) => FlSpot(e.key.toDouble(), e.value / 1000)).toList(),
                            isCurved: true, color: Colors.blue, barWidth: 3, dotData: const FlDotData(show: false)
                          ),
                          LineChartBarData(
                            spots: ganCredito.entries.map((e) => FlSpot(e.key.toDouble(), e.value / 1000)).toList(),
                            isCurved: true, color: Colors.purple, barWidth: 3, dotData: const FlDotData(show: false)
                          ),
                          LineChartBarData(
                            spots: ganEfectivo.entries.map((e) => FlSpot(e.key.toDouble(), e.value / 1000)).toList(),
                            isCurved: true, color: Colors.green, barWidth: 3, dotData: const FlDotData(show: false)
                          )
                        ]
                      )
                    ),
                  ),
                  const SizedBox(height: 30),

                  const Text("Trabajos Finalizados por Mecánico", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    height: 200, padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4, 
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2, 
                              centerSpaceRadius: 30, 
                              sections: trabajosPorMecanico.entries.map((e) {
                                final color = coloresPastel[colorIndex % coloresPastel.length];
                                colorIndex++;
                                return PieChartSectionData(
                                  color: color, value: e.value.toDouble(), title: '${e.value}', radius: 50,
                                  titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)
                                );
                              }).toList(),
                            )
                          ),
                        ),
                        const SizedBox(width: 30), 
                        Expanded(
                          flex: 5, 
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                            children: trabajosPorMecanico.keys.toList().asMap().entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(children: [
                                  Container(width: 12, height: 12, color: coloresPastel[entry.key % coloresPastel.length]),
                                  const SizedBox(width: 8), 
                                  Flexible(child: Text(entry.value, overflow: TextOverflow.ellipsis))
                                ]),
                              );
                            }).toList(),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                ] else ...[
                  const Text("Estado del Taller", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildCard("Por Inspeccionar", esperando.toString(), Colors.redAccent, Icons.search)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildCard("En Espera", enCurso.toString(), Colors.amber, Icons.build)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildCard("Finalizados", finalizadasMecanico.toString(), Colors.green, Icons.check_circle)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("Desempeño Personal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildCard("Trabajos (Mes)", trabajosMesMecanico.toString(), Colors.blue, Icons.handyman)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildCard("Comisiones", "\$${comisionMecanico.toInt()}", Colors.purple, Icons.account_balance_wallet)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildCard("Propinas", "\$${propinaMecanico.toInt()}", Colors.teal, Icons.volunteer_activism)),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(String title, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5), 
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 5),
          Text(count, style: TextStyle(fontSize: count.length > 5 ? 16 : 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class MenuLateral extends StatelessWidget {
  final String rol; final String nombre;
  const MenuLateral({super.key, required this.rol, required this.nombre});

  @override
  Widget build(BuildContext context) {
    const cafe = Color(0xFFD2691E); 
    return Drawer(
      backgroundColor: const Color(0xFF121212),
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.black),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Bamajo Motors", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), 
                Text(rol, style: const TextStyle(color: cafe)),
              ],
            ),
          ),
          const Divider(color: cafe), 
          ListTile(leading: const Icon(Icons.home, color: cafe), title: const Text("Inicio"), onTap: () => Navigator.pop(context)),
          
          if (['Administrador', 'Jefe'].contains(rol)) ...[
            ListTile(leading: const Icon(Icons.person_add, color: cafe), title: const Text("Registrar Personal"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegistroPersonal(currentRol: rol)))),
            ListTile(leading: const Icon(Icons.people, color: Colors.blueAccent), title: const Text("Gestionar Personal"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ListaPersonalScreen(currentRol: rol, currentUid: FirebaseAuth.instance.currentUser!.uid)))),
            ListTile(leading: const Icon(Icons.add_circle, color: cafe), title: const Text("Nuevo Ingreso"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistroVehiculo()))),
            ListTile(leading: const Icon(Icons.car_repair, color: Colors.blue), title: const Text("Autos Activos"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AutosActivosScreen()))),
            ListTile(leading: const Icon(Icons.done_all, color: Colors.green), title: const Text("Vehículos Terminados"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehiculosTerminadosScreen()))),
            ListTile(leading: const Icon(Icons.inventory, color: Colors.blue), title: const Text("Inventario"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventarioScreen()))),
            ListTile(leading: const Icon(Icons.receipt_long, color: Colors.amber), title: const Text("Historial de Trabajos"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistorialGananciasScreen()))),
          ] else ...[
            ListTile(leading: const Icon(Icons.search, color: cafe), title: const Text("Inspección Física"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SeleccionInspeccionScreen(mecanico: nombre)))),
            ListTile(leading: const Icon(Icons.checklist, color: cafe), title: const Text("Checklist de Trabajos"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ListaTrabajos(mecanico: nombre)))),
          ],
          const Divider(color: cafe), 
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.red)), onTap: () => FirebaseAuth.instance.signOut()),
        ],
      ),
    );
  }
}

class SeleccionInspeccionScreen extends StatelessWidget {
  final String mecanico;
  const SeleccionInspeccionScreen({super.key, required this.mecanico});
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inspeccionar")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehiculos').where('estado', isEqualTo: 'Esperando inspección').where('mecanico_responsable', isEqualTo: mecanico).snapshots(),
        builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.docs.isEmpty) return buildEmptyStateMensaje();

          return ListView.builder(
            itemCount: snap.data!.docs.length,
            itemBuilder: (c, i) {
              var v = snap.data!.docs[i].data() as Map<String, dynamic>;
              String vId = snap.data!.docs[i].id;
              return Card(
                color: const Color(0xFF1E1E1E), margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: const Icon(Icons.assignment, color: Color(0xFFD2691E), size: 40),
                  title: Text("${v['marca'] ?? ''} ${v['modelo'] ?? ''}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  subtitle: Text("Patente: ${v['patente'] ?? ''}  •  Año: ${v['ano'] ?? 'N/A'}  •  Motor: ${v['motor'] ?? 'N/A'}", style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                  onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => FormularioInspeccion(vehiculoId: vId, servicio: v['servicio'] ?? 'General')))
                ),
              );
            }
          );
        },
      ),
    );
  }
}

class FormularioInspeccion extends StatefulWidget {
  final String vehiculoId; final String servicio;
  const FormularioInspeccion({super.key, required this.vehiculoId, required this.servicio});
  @override State<FormularioInspeccion> createState() => _FormularioInspeccionState();
}
class _FormularioInspeccionState extends State<FormularioInspeccion> {
  final _otroCtrl = TextEditingController(); Map<String, bool> tareas = {};
  File? _imagenFisica; 
  bool _isUploading = false;

  @override void initState() {
    super.initState();
    if (widget.servicio == 'Revisión de Frenos') tareas = {'Revisión de líquido': false, 'Rectificación de discos': false, 'Cambio de pastillas': false, 'Cambio de disco': false, 'Ajuste freno de mano': false};
    else if (widget.servicio == 'Mantenimiento General') tareas = {'Cambio de aceite': false, 'Filtro de aire': false, 'Filtro de aceite': false, 'Revisión de luces': false, 'Revisión de niveles': false};
    else if (widget.servicio == 'Reparación de Motor') tareas = {'Escáner electrónico': false, 'Revisión de bujías': false, 'Cambio correa distribución': false, 'Medición compresión': false};
    else if (widget.servicio == 'Alineación y Balanceo') tareas = {'Rotación de neumáticos': false, 'Balanceo por rueda': false, 'Alineación tren delantero': false, 'Ajuste de presión': false};
  }

  Future<void> _tomarFoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (image != null) {
      setState(() { _imagenFisica = File(image.path); });
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inspección")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: InkWell(
                onTap: _tomarFoto,
                child: Container(
                  height: 150, width: double.infinity,
                  decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFD2691E), width: 2, style: BorderStyle.solid)),
                  child: _imagenFisica == null 
                      ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, size: 50, color: Color(0xFFD2691E)), SizedBox(height: 10), Text("Tocar para tomar foto del vehículo", style: TextStyle(color: Colors.white))])
                      : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_imagenFisica!, fit: BoxFit.cover)),
                ),
              ),
            ),
            const Divider(),
            ...tareas.keys.map((k) => CheckboxListTile(title: Text(k), value: tareas[k], onChanged: (v) => setState(() => tareas[k] = v!))),
            Padding(padding: const EdgeInsets.all(8), child: TextField(controller: _otroCtrl, decoration: const InputDecoration(labelText: "Otro (Especifique)", border: OutlineInputBorder()))),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isUploading 
                ? const CircularProgressIndicator()
                : ElevatedButton(
                onPressed: () async {
                  setState(() => _isUploading = true);
                  String? imageUrl;
                  if (_imagenFisica != null) {
                    try {
                      final ref = FirebaseStorage.instance.ref().child('inspecciones/${widget.vehiculoId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
                      await ref.putFile(_imagenFisica!);
                      imageUrl = await ref.getDownloadURL();
                    } catch (e) {
                      print("Error subiendo imagen: $e");
                    }
                  }
                  Map<String, bool> tareasAAsignar = {};
                  tareas.forEach((key, value) { if (value == true) tareasAAsignar[key] = false; });
                  if (_otroCtrl.text.isNotEmpty) tareasAAsignar[_otroCtrl.text] = false;
                  
                  await FirebaseFirestore.instance.collection('vehiculos').doc(widget.vehiculoId).update({'estado': 'En curso', 'tareas_asignadas': tareasAAsignar, if (imageUrl != null) 'foto_inspeccion': imageUrl});
                  if (mounted) Navigator.pop(context);
                }, 
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(55)), 
                child: const Text("Iniciar Trabajo", style: TextStyle(fontSize: 18))
              ),
            )
          ],
        ),
      ),
    );
  }
}

class TrabajoCardWidget extends StatefulWidget {
  final DocumentSnapshot vehiculoDoc;
  const TrabajoCardWidget({super.key, required this.vehiculoDoc});
  @override State<TrabajoCardWidget> createState() => _TrabajoCardWidgetState();
}

class _TrabajoCardWidgetState extends State<TrabajoCardWidget> {
  late Map<String, dynamic> tareas;
  List<dynamic> repuestosUsados = [];

  @override void initState() { 
    super.initState(); 
    var data = widget.vehiculoDoc.data() as Map<String, dynamic>;
    tareas = Map<String, dynamic>.from(data['tareas_asignadas'] ?? {}); 
    repuestosUsados = List.from(data['repuestos_utilizados'] ?? []);
  }

  void _agregarRepuesto() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Seleccionar Repuesto Usado"),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('inventario').where('cantidad', isGreaterThan: 0).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            if (snapshot.data!.docs.isEmpty) return const Text("No hay inventario disponible.");
            
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, i) {
                  var itemDoc = snapshot.data!.docs[i];
                  var item = itemDoc.data() as Map<String, dynamic>;
                  return ListTile(
                    
                    title: Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Tipo: ${item['tipo']}\nSpecs: ${item['especificaciones']}\nStock: ${item['cantidad']}", style: const TextStyle(color: Colors.amber)),
                    isThreeLine: true,
                    trailing: const Icon(Icons.add_circle, color: Colors.blue),
                    onTap: () async {
                      Navigator.pop(ctx);
                      
                      await FirebaseFirestore.instance.collection('inventario').doc(itemDoc.id).update({
                        'cantidad': item['cantidad'] - 1
                      });
                      
                      setState(() {
                        repuestosUsados.add("${item['nombre']} (${item['especificaciones']})"); // Guarda más contexto
                      });
                      
                      await FirebaseFirestore.instance.collection('vehiculos').doc(widget.vehiculoDoc.id).update({
                        'repuestos_utilizados': repuestosUsados
                      });
                      
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${item['nombre']} descontado del inventario")));
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cerrar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  @override Widget build(BuildContext context) {
    var v = widget.vehiculoDoc.data() as Map<String, dynamic>;
    return Card(
      color: const Color(0xFF1E1E1E), margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: const Icon(Icons.directions_car, color: Colors.blueAccent, size: 40),
        title: Text("${v['marca'] ?? ''} ${v['modelo'] ?? ''}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text("Patente: ${v['patente'] ?? ''}  •  Año: ${v['ano'] ?? 'N/A'}  •  Motor: ${v['motor'] ?? 'N/A'}\nMecánico: ${v['mecanico_responsable'] ?? 'Desconocido'}", style: const TextStyle(color: Colors.grey)),
        children: [
          ...tareas.keys.map((k) => CheckboxListTile(
            title: Text(k, style: TextStyle(decoration: tareas[k] ? TextDecoration.lineThrough : null, color: tareas[k] ? Colors.grey : Colors.white)),
            activeColor: Colors.green, value: tareas[k], onChanged: (val) { setState(() { tareas[k] = val; }); },
          )),
          
          const Divider(),
          const Text("Repuestos Utilizados:", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          if (repuestosUsados.isEmpty) const Padding(padding: EdgeInsets.all(8.0), child: Text("No se han registrado repuestos", style: TextStyle(color: Colors.grey))),
          ...repuestosUsados.map((r) => ListTile(dense: true, leading: const Icon(Icons.build, size: 16), title: Text(r))),
          
          TextButton.icon(
            icon: const Icon(Icons.add_shopping_cart, color: Colors.blue),
            label: const Text("Añadir repuesto de inventario", style: TextStyle(color: Colors.blue)),
            onPressed: _agregarRepuesto,
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(50)),
              icon: const Icon(Icons.save), label: const Text("Confirmar Avance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              onPressed: () async {
                bool todasListas = tareas.values.every((element) => element == true);
                await FirebaseFirestore.instance.collection('vehiculos').doc(widget.vehiculoDoc.id).update({'tareas_asignadas': tareas, 'estado': todasListas ? 'Auto Listo' : 'En curso'});
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Avance guardado correctamente")));
              },
            ),
          )
        ],
      ),
    );
  }
}

class ListaTrabajos extends StatelessWidget {
  final String mecanico;
  const ListaTrabajos({super.key, required this.mecanico});
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mis Trabajos")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehiculos').where('mecanico_responsable', isEqualTo: mecanico).where('estado', isEqualTo: 'En curso').snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.docs.isEmpty) return buildEmptyStateMensaje();
          return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (ctx, i) { return TrabajoCardWidget(vehiculoDoc: snap.data!.docs[i]); });
        },
      ),
    );
  }
}
