import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart'; 

import 'gestion_personal.dart';
import 'inventario.dart';
import 'registro_vehiculo.dart';
import 'historial_trabajos.dart';
import 'autos_activos.dart'; 
import 'notificaciones.dart';
import 'registro_personal.dart';
import 'vehiculos_terminados.dart';
import 'asistente_ia.dart';

Widget buildEmptyStateMensaje() {
  return Builder(
    builder: (context) {
      bool isDark = Theme.of(context).brightness == Brightness.dark;
      Color textColor = isDark ? Colors.white : Theme.of(context).primaryColor;
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20), 
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor, 
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
            ]
          ),
          child: Text("No hay datos por el momento", style: TextStyle(color: textColor, fontSize: 16), textAlign: TextAlign.center),
        ),
      );
    }
  );
}

class HomeScreen extends StatefulWidget {
  final String rol; final String nombre;
  const HomeScreen({super.key, required this.rol, required this.nombre});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  void initState() {
    super.initState();
    _solicitarPermisosNotificaciones();
  }

  void _solicitarPermisosNotificaciones() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true, announcement: false, badge: true, carPlay: false, criticalAlert: false, provisional: false, sound: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : Theme.of(context).primaryColor;
    Color primaryColor = Theme.of(context).primaryColor;
    Color secondaryColor = Theme.of(context).colorScheme.secondary;

    // Asignación de colores estrictos sin usar amarillos ni morados
    Color colorDebito = secondaryColor; 
    Color colorCredito = isDark ? Colors.white : primaryColor; 
    Color colorEfectivo = Colors.green;

    // CAMBIO QUIRURGICO: Se ajustó el colorCredito en modo oscuro por Colors.deepOrangeAccent para el gráfico de pastel
    List<Color> paletaGraficos = [
      colorDebito,
      isDark ? Colors.deepOrangeAccent : colorCredito, // <--- AQUÍ ESTÁ LA MAGIA (Rojo anaranjado)
      colorEfectivo,
      isDark ? Colors.blueGrey : primaryColor.withOpacity(0.7),
      isDark ? Colors.redAccent : Colors.red,
      isDark ? Colors.lightBlue : Colors.teal,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel Principal"),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: isDark ? Colors.white : Colors.white),
            tooltip: "Notificaciones",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => NotificacionesScreen(currentRol: widget.rol)));
            },
          )
        ],
      ), 
      drawer: MenuLateral(rol: widget.rol, nombre: widget.nombre),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehiculos').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error de acceso: ${snapshot.error}"));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          int autosActivos = 0; int autosFinalizados = 0; 
          int esperando = 0, enCurso = 0, finalizadasMecanico = 0;
          int trabajosMesMecanico = 0; double comisionMecanico = 0.0, propinaMecanico = 0.0;
          
          Map<int, double> ganDebito = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0, 8:0, 9:0, 10:0, 11:0, 12:0};
          Map<int, double> ganCredito = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0, 8:0, 9:0, 10:0, 11:0, 12:0};
          Map<int, double> ganEfectivo = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0, 8:0, 9:0, 10:0, 11:0, 12:0};

          double totalDebito = 0.0;
          double totalCredito = 0.0;
          double totalEfectivo = 0.0;

          Map<String, int> trabajosPorMecanico = {};
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
              if (data['fecha_pago'] != null || data['fecha'] != null) {
                DateTime fecha = (data['fecha_pago'] != null ? (data['fecha_pago'] as Timestamp) : (data['fecha'] as Timestamp)).toDate();
                
                if (metodoPago == 'Débito') { ganDebito[fecha.month] = ganDebito[fecha.month]! + cobrado; totalDebito += cobrado; }
                if (metodoPago == 'Crédito') { ganCredito[fecha.month] = ganCredito[fecha.month]! + cobrado; totalCredito += cobrado; }
                if (metodoPago == 'Efectivo') { ganEfectivo[fecha.month] = ganEfectivo[fecha.month]! + cobrado; totalEfectivo += cobrado; }
              }
              if (mecResp.isNotEmpty) trabajosPorMecanico[mecResp] = (trabajosPorMecanico[mecResp] ?? 0) + 1;
            }

            if (widget.rol == 'Mecánico' && mecResp == widget.nombre) {
              if (estado == 'Esperando inspección') esperando++;
              else if (estado == 'En curso') enCurso++;
              else if (estado == 'Auto Listo' || estado == 'Vehículo finalizado') finalizadasMecanico++;

              if (estado == 'Vehículo finalizado') {
                trabajosMesMecanico++; comisionMecanico += (data['comision_mecanico'] ?? 0).toDouble(); propinaMecanico += (data['propina'] ?? 0).toDouble();
              }
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Hola, ${widget.nombre}", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
                Text(widget.rol, style: TextStyle(fontSize: 18, color: secondaryColor)),
                const SizedBox(height: 20),
                
                if (['Administrador', 'Jefe'].contains(widget.rol)) ...[
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AutosActivosScreen())),
                          child: _buildCard("Autos Activos", autosActivos.toString(), secondaryColor, Icons.directions_car)
                        )
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _buildCard("Total Reparados", autosFinalizados.toString(), colorCredito, Icons.done_all)),
                    ],
                  ),
                  const SizedBox(height: 30),
                  
                  Text("Ganancias por Método de Pago", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.circle, color: colorDebito, size: 12), const SizedBox(width: 5), Text("Débito", style: TextStyle(fontSize: 12, color: textColor)), const SizedBox(width: 15),
                      Icon(Icons.circle, color: colorCredito, size: 12), const SizedBox(width: 5), Text("Crédito", style: TextStyle(fontSize: 12, color: textColor)), const SizedBox(width: 15),
                      Icon(Icons.circle, color: colorEfectivo, size: 12), const SizedBox(width: 5), Text("Efectivo", style: TextStyle(fontSize: 12, color: textColor)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  Container(
                    height: 220, padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
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
                                return Text('${value.toInt()}k', style: TextStyle(fontSize: 10, color: textColor));
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
                                    meta: meta,
                                    child: Text(meses[value.toInt()-1], style: TextStyle(fontSize: 10, color: textColor)),
                                  );
                                }
                                return const Text('');
                              }
                            )
                          ),
                        ),
                        borderData: FlBorderData(show: true, border: Border.all(color: isDark ? Colors.white24 : Colors.black12)),
                        lineBarsData: [
                          LineChartBarData(
                            spots: ganDebito.entries.map((e) => FlSpot(e.key.toDouble(), e.value / 1000)).toList(),
                            isCurved: true, color: colorDebito, barWidth: 3, dotData: const FlDotData(show: false)
                          ),
                          LineChartBarData(
                            spots: ganCredito.entries.map((e) => FlSpot(e.key.toDouble(), e.value / 1000)).toList(),
                            isCurved: true, color: colorCredito, barWidth: 3, dotData: const FlDotData(show: false)
                          ),
                          LineChartBarData(
                            spots: ganEfectivo.entries.map((e) => FlSpot(e.key.toDouble(), e.value / 1000)).toList(),
                            isCurved: true, color: colorEfectivo, barWidth: 3, dotData: const FlDotData(show: false)
                          )
                        ]
                      )
                    ),
                  ),
                  const SizedBox(height: 30),

                  Row(
                    children: [
                      Expanded(child: _buildCard("Total Débito", "\$${totalDebito.toInt()}", colorDebito, Icons.credit_card)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildCard("Total Crédito", "\$${totalCredito.toInt()}", colorCredito, Icons.credit_score)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildCard("Total Efectivo", "\$${totalEfectivo.toInt()}", colorEfectivo, Icons.payments)),
                    ],
                  ),
                  const SizedBox(height: 30),

                  Text("Trabajos Finalizados por Mecánico", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 10),
                  Container(
                    height: 200, padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4, 
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2, 
                              centerSpaceRadius: 30, 
                              sections: trabajosPorMecanico.entries.map((e) {
                                final color = paletaGraficos[colorIndex % paletaGraficos.length];
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
                                  Container(width: 12, height: 12, color: paletaGraficos[entry.key % paletaGraficos.length]),
                                  const SizedBox(width: 8), 
                                  Flexible(child: Text(entry.value, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor)))
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
                  Text("Estado del Taller", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildCard("Por Inspeccionar", esperando.toString(), Colors.redAccent, Icons.search)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildCard("En Espera", enCurso.toString(), secondaryColor, Icons.build)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildCard("Finalizados", finalizadasMecanico.toString(), Colors.green, Icons.check_circle)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text("Desempeño Personal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildCard("Trabajos (Mes)", trabajosMesMecanico.toString(), secondaryColor, Icons.handyman)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildCard("Comisiones", "\$${comisionMecanico.toInt()}", colorCredito, Icons.account_balance_wallet)),
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
    return Builder(
      builder: (context) {
        bool isDark = Theme.of(context).brightness == Brightness.dark;
        Color textColor = isDark ? Colors.white : Theme.of(context).primaryColor;
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5), 
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 5),
              Text(count, style: TextStyle(fontSize: count.length > 5 ? 16 : 22, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 5),
              Text(title, style: TextStyle(color: textColor, fontSize: 11), textAlign: TextAlign.center),
            ],
          ),
        );
      }
    );
  }
}

class MenuLateral extends StatelessWidget {
  final String rol; final String nombre;
  const MenuLateral({super.key, required this.rol, required this.nombre});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color secondaryColor = Theme.of(context).colorScheme.secondary; 
    
    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Bamajo Motors", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), 
                Text(rol, style: TextStyle(color: isDark ? Colors.white : Colors.white70)),
              ],
            ),
          ),
          
          if (['Administrador', 'Jefe'].contains(rol)) ...[
            ListTile(leading: Icon(Icons.person_add, color: secondaryColor), title: const Text("Registrar Personal"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegistroPersonal(currentRol: rol)))),
            ListTile(leading: Icon(Icons.people, color: secondaryColor), title: const Text("Gestionar Personal"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ListaPersonalScreen(currentRol: rol, currentUid: FirebaseAuth.instance.currentUser!.uid)))),
            ListTile(leading: Icon(Icons.add_circle, color: secondaryColor), title: const Text("Nuevo Ingreso"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistroVehiculo()))),
            ListTile(leading: Icon(Icons.car_repair, color: secondaryColor), title: const Text("Autos Activos"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AutosActivosScreen()))),
            ListTile(leading: Icon(Icons.done_all, color: Colors.green), title: const Text("Vehículos Terminados"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehiculosTerminadosScreen()))),
            ListTile(leading: Icon(Icons.inventory, color: secondaryColor), title: const Text("Inventario"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventarioScreen()))),
            ListTile(leading: Icon(Icons.receipt_long, color: secondaryColor), title: const Text("Historial de Trabajos"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistorialGananciasScreen()))),
          ] else ...[
            ListTile(leading: Icon(Icons.search, color: secondaryColor), title: const Text("Inspección Física"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SeleccionInspeccionScreen(mecanico: nombre)))),
            ListTile(leading: Icon(Icons.checklist, color: secondaryColor), title: const Text("Checklist de Trabajos"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ListaTrabajos(mecanico: nombre)))),
          ],
          
          Divider(color: secondaryColor.withOpacity(0.5)),
          ListTile(
            leading: Icon(Icons.smart_toy, color: secondaryColor), 
            title: const Text("Asistente Virtual IA"), 
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AsistenteIAScreen()))
          ),

          Divider(color: secondaryColor.withOpacity(0.5)), 
          ListTile(
            leading: Icon(Icons.security, color: secondaryColor), 
            title: const Text("Cambiar Mi Contraseña"), 
            onTap: () async {
              try {
                String miCorreo = FirebaseAuth.instance.currentUser!.email!;
                await FirebaseAuth.instance.sendPasswordResetEmail(email: miCorreo);
                if (context.mounted) {
                  Navigator.pop(context); 
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Te hemos enviado un link seguro a tu correo."), backgroundColor: Colors.green));
                }
              } catch (e) {
                if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al solicitar el enlace."), backgroundColor: Colors.red));
              }
            }
          ),

          ValueListenableBuilder<ThemeMode>(
            valueListenable: notificadorTemaGlobal,
            builder: (context, currentMode, child) {
              bool esModoOscuro = currentMode == ThemeMode.dark;
              return SwitchListTile(
                secondary: Icon(
                  esModoOscuro ? Icons.dark_mode : Icons.light_mode,
                  color: esModoOscuro ? Colors.white : secondaryColor,
                ),
                title: const Text('Modo Oscuro', style: TextStyle(fontWeight: FontWeight.bold)),
                value: esModoOscuro,
                activeColor: secondaryColor,
                onChanged: (bool valorSeleccionado) async {
                  notificadorTemaGlobal.value = valorSeleccionado ? ThemeMode.dark : ThemeMode.light;
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('modo_oscuro_activado', valorSeleccionado);
                },
              );
            },
          ),

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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color subTextColor = isDark ? Colors.white : Colors.grey.shade700;

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
                color: Theme.of(context).cardColor, margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: Icon(Icons.assignment, color: Theme.of(context).colorScheme.secondary, size: 40),
                  title: Text("${v['marca'] ?? ''} ${v['modelo'] ?? ''}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  subtitle: Text("Patente: ${v['patente'] ?? ''}  •  Año: ${v['ano'] ?? 'N/A'}  •  Motor: ${v['motor'] ?? 'N/A'}", style: TextStyle(fontSize: 14, color: subTextColor)),
                  trailing: Icon(Icons.arrow_forward_ios, color: subTextColor),
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
  List<File> _imagenesFisicas = []; 
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
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 60);
    if (image != null) setState(() { _imagenesFisicas.add(File(image.path)); });
  }

  Future<void> _elegirDeGaleria() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(imageQuality: 60);
    if (images.isNotEmpty) setState(() { _imagenesFisicas.addAll(images.map((e) => File(e.path))); });
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inspección")),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: ElevatedButton.icon(onPressed: _tomarFoto, icon: const Icon(Icons.camera_alt), label: const Text("Cámara"))),
                      const SizedBox(width: 10),
                      Expanded(child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).scaffoldBackgroundColor, 
                          foregroundColor: Theme.of(context).colorScheme.secondary,
                          side: BorderSide(color: Theme.of(context).colorScheme.secondary)
                        ),
                        onPressed: _elegirDeGaleria, icon: const Icon(Icons.photo_library), label: const Text("Galería"))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_imagenesFisicas.isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imagenesFisicas.length,
                        itemBuilder: (ctx, i) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Stack(
                            children: [
                              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_imagenesFisicas[i], width: 100, height: 120, fit: BoxFit.cover)),
                              Positioned(top: 0, right: 0, child: IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => setState(() => _imagenesFisicas.removeAt(i)))),
                            ],
                          ),
                        ),
                      ),
                    )
                ],
              ),
            ),
            const Divider(),
            ...tareas.keys.map((k) => CheckboxListTile(title: Text(k), value: tareas[k], onChanged: (v) => setState(() => tareas[k] = v!))),
            Padding(padding: const EdgeInsets.all(8), child: TextField(controller: _otroCtrl, decoration: const InputDecoration(labelText: "Otro (Especifique)", border: OutlineInputBorder()))),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isUploading 
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                onPressed: () async {
                  setState(() => _isUploading = true);
                  List<String> imageUrls = [];
                  try {
                    for (var img in _imagenesFisicas) {
                      final ref = FirebaseStorage.instance.ref().child('inspecciones/${widget.vehiculoId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
                      await ref.putFile(img);
                      imageUrls.add(await ref.getDownloadURL());
                    }
                  } catch (e) { print("Error subiendo imágenes: $e"); }
                  
                  Map<String, bool> tareasAAsignar = {};
                  tareas.forEach((key, value) { if (value == true) tareasAAsignar[key] = false; });
                  if (_otroCtrl.text.isNotEmpty) tareasAAsignar[_otroCtrl.text] = false;
                  
                  await FirebaseFirestore.instance.collection('vehiculos').doc(widget.vehiculoId).update({
                    'estado': 'En curso', 
                    'tareas_asignadas': tareasAAsignar, 
                    if (imageUrls.isNotEmpty) 'foto_inspeccion': imageUrls
                  });
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
    _cargarDatosLocales();
  }

  @override void didUpdateWidget(TrabajoCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cargarDatosLocales();
  }

  void _cargarDatosLocales() {
    var data = widget.vehiculoDoc.data() as Map<String, dynamic>;
    tareas = Map<String, dynamic>.from(data['tareas_asignadas'] ?? {}); 
    repuestosUsados = List.from(data['repuestos_utilizados'] ?? []);
  }

  Future<void> _quitarRepuesto(String repuestoStr) async {
    final scaffoldMsg = ScaffoldMessenger.of(context);
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color subTextColor = isDark ? Colors.white : Colors.grey.shade700;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text("Devolver Repuesto", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        content: Text("¿Deseas quitar '$repuestoStr' de este vehículo y devolverlo al inventario general?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancelar", style: TextStyle(color: subTextColor))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Devolver"),
          ),
        ],
      )
    );

    if (confirm != true) return;

    try {
      QuerySnapshot invSnap = await FirebaseFirestore.instance.collection('inventario').get();
      DocumentSnapshot? match;
      for (var doc in invSnap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String formatted = "${data['nombre']} (${data['especificaciones']})";
        if (formatted == repuestoStr) {
          match = doc;
          break;
        }
      }

      if (match != null) {
        int stockActual = (match.data() as Map<String, dynamic>)['cantidad'] ?? 0;
        await FirebaseFirestore.instance.collection('inventario').doc(match.id).update({
          'cantidad': stockActual + 1
        });
      }

      setState(() {
        repuestosUsados.remove(repuestoStr); 
      });

      await FirebaseFirestore.instance.collection('vehiculos').doc(widget.vehiculoDoc.id).update({
        'repuestos_utilizados': repuestosUsados
      });

      if (mounted) scaffoldMsg.showSnackBar(const SnackBar(content: Text("Repuesto devuelto al inventario con éxito"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) scaffoldMsg.showSnackBar(const SnackBar(content: Text("Error al devolver. Revisa tu conexión a Internet."), backgroundColor: Colors.red));
    }
  }

  void _agregarRepuesto() {
    Set<String> tiposRecomendados = {};

    for (String tarea in tareas.keys) {
      String t = tarea.toLowerCase();

      if (t.contains('aceite') || t.contains('lubricación') || t.contains('mantenimiento general')) tiposRecomendados.addAll(['Aceite', 'Filtro de aceite', 'Líquidos', 'Filtro de aire']);
      if (t.contains('freno') || t.contains('pastilla') || t.contains('disco')) tiposRecomendados.addAll(['Pastillas de freno', 'Frenos', 'Líquidos']);
      if (t.contains('aire') || t.contains('polen') || t.contains('climatización') || t.contains('cabina')) tiposRecomendados.addAll(['Filtro de aire', 'Climatización']);
      if (t.contains('batería') || t.contains('eléctric') || t.contains('alternador')) tiposRecomendados.addAll(['Batería', 'Eléctrico']);
      if (t.contains('motor') || t.contains('distribución') || t.contains('bomba') || t.contains('refrigerante')) tiposRecomendados.addAll(['Motor', 'Líquidos']);
      if (t.contains('suspensión') || t.contains('amortiguador') || t.contains('balanceo') || t.contains('alineación') || t.contains('rueda')) tiposRecomendados.addAll(['Ruedas / Suspensión', 'Suspensión']);
      if (t.contains('transmisión') || t.contains('embrague') || t.contains('caja')) tiposRecomendados.addAll(['Transmisión', 'Líquidos']);
      if (t.contains('bujía') || t.contains('encendido') || t.contains('sensor') || t.contains('check engine')) tiposRecomendados.addAll(['Encendido', 'Sensores']);
      if (t.contains('luz') || t.contains('luces') || t.contains('iluminación') || t.contains('ampolleta') || t.contains('foco')) tiposRecomendados.add('Iluminación');
      if (t.contains('limpiaparabrisas') || t.contains('plumilla') || t.contains('accesorio')) tiposRecomendados.add('Accesorios');
    }
    
    bool verTodo = tiposRecomendados.isEmpty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Color secondaryColor = Theme.of(context).colorScheme.secondary;

          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Seleccionar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                if (tiposRecomendados.isNotEmpty)
                  TextButton(
                    onPressed: () => setStateDialog(() => verTodo = !verTodo),
                    child: Text(verTodo ? "Ocultar" : "Ver todos", style: TextStyle(color: secondaryColor, fontSize: 13)),
                  )
              ],
            ),
            content: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('inventario').where('cantidad', isGreaterThan: 0).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
                
                var docsFiltrados = snapshot.data!.docs.where((d) {
                  if (verTodo) return true; 
                  var item = d.data() as Map<String, dynamic>;
                  return tiposRecomendados.contains(item['tipo']);
                }).toList();

                docsFiltrados.sort((a, b) => ((a.data() as Map)['nombre'] as String).compareTo((b.data() as Map)['nombre'] as String));

                if (docsFiltrados.isEmpty) return const Text("No hay repuestos en stock para esta tarea.");
                
                return SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: docsFiltrados.length,
                    itemBuilder: (context, i) {
                      var itemDoc = docsFiltrados[i];
                      var item = itemDoc.data() as Map<String, dynamic>;
                      
                      return ListTile(
                        leading: Icon(Icons.build, color: secondaryColor),
                        title: Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text("Disponible: ${item['cantidad']} unid.", style: const TextStyle(color: Colors.green)),
                        trailing: Icon(Icons.add_circle, color: secondaryColor, size: 30),
                        onTap: () async {
                          final scaffoldMsg = ScaffoldMessenger.of(context);
                          Navigator.pop(ctx);
                          
                          int cantidadActual = item['cantidad'];
                          int nuevaCantidad = cantidadActual - 1;

                          await FirebaseFirestore.instance.collection('inventario').doc(itemDoc.id).update({'cantidad': nuevaCantidad});
                          
                          if (nuevaCantidad <= 3) {
                            await FirebaseFirestore.instance.collection('notificaciones').add({
                              'titulo': '⚠️ Alerta de Stock', 'cuerpo': 'El producto "${item['nombre']}" está en rojo. Quedan $nuevaCantidad unidades.',
                              'rol_destino': 'Jefe', 'fecha': FieldValue.serverTimestamp(), 'leida': false,
                            });
                          }
                          
                          List<dynamic> nuevosRepuestos = List.from(repuestosUsados)..add("${item['nombre']} (${item['especificaciones']})");
                          await FirebaseFirestore.instance.collection('vehiculos').doc(widget.vehiculoDoc.id).update({
                            'repuestos_utilizados': nuevosRepuestos
                          });
                          
                          if (mounted) scaffoldMsg.showSnackBar(SnackBar(content: Text("${item['nombre']} añadido")));
                        },
                      );
                    },
                  ),
                );
              },
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.red))),
            ],
          );
        }
      ),
    );
  }

  @override Widget build(BuildContext context) {
    var v = widget.vehiculoDoc.data() as Map<String, dynamic>;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color subTextColor = isDark ? Colors.white : Colors.grey.shade700;
    Color secondaryColor = Theme.of(context).colorScheme.secondary;

    return Card(
      color: Theme.of(context).cardColor, margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        key: PageStorageKey(widget.vehiculoDoc.id), 
        leading: Icon(Icons.directions_car, color: secondaryColor, size: 40),
        title: Text("${v['marca'] ?? ''} ${v['modelo'] ?? ''}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text("Patente: ${v['patente'] ?? ''}  •  Año: ${v['ano'] ?? 'N/A'}  •  Motor: ${v['motor'] ?? 'N/A'}\nMecánico: ${v['mecanico_responsable'] ?? 'Desconocido'}", style: TextStyle(color: subTextColor)),
        children: [
          ...tareas.keys.map((k) => CheckboxListTile(
            title: Text(k, style: TextStyle(decoration: tareas[k] ? TextDecoration.lineThrough : null, color: tareas[k] ? (isDark ? Colors.white54 : Colors.grey) : Theme.of(context).colorScheme.onSurface)),
            activeColor: Colors.green, value: tareas[k], onChanged: (val) async { 
              Map<String, dynamic> nuevasTareas = Map.from(tareas);
              nuevasTareas[k] = val;
              await FirebaseFirestore.instance.collection('vehiculos').doc(widget.vehiculoDoc.id).update({'tareas_asignadas': nuevasTareas});
            },
          )),
          
          const Divider(),
          Text("Repuestos Utilizados:", style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold)),
          if (repuestosUsados.isEmpty) Padding(padding: const EdgeInsets.all(8.0), child: Text("No se han registrado repuestos", style: TextStyle(color: subTextColor))),
          
          ...repuestosUsados.map((r) => ListTile(
            dense: true, 
            leading: const Icon(Icons.build, size: 16), 
            title: Text(r),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              tooltip: "Quitar y devolver al stock",
              onPressed: () => _quitarRepuesto(r as String),
            ),
          )),
          
          TextButton.icon(
            icon: Icon(Icons.add_shopping_cart, color: secondaryColor),
            label: Text("Añadir repuesto de inventario", style: TextStyle(color: secondaryColor)),
            onPressed: _agregarRepuesto,
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(50)),
              icon: const Icon(Icons.save), label: const Text("Confirmar Avance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              onPressed: () async {
                final scaffoldMsg = ScaffoldMessenger.of(context);
                bool todasListas = tareas.values.every((element) => element == true);
                await FirebaseFirestore.instance.collection('vehiculos').doc(widget.vehiculoDoc.id).update({'estado': todasListas ? 'Auto Listo' : 'En curso'});
                if (mounted) scaffoldMsg.showSnackBar(const SnackBar(content: Text("Avance guardado correctamente")));
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