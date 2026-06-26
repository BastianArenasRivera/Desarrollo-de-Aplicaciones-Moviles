import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'dashboard_home.dart' show buildEmptyStateMensaje;

/// Pantalla de auditoria historica.
/// Presenta un registro inmutable de las operaciones financieras concretadas por el taller.
class HistorialGananciasScreen extends StatelessWidget {
  const HistorialGananciasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registro Histórico")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehiculos').where('estado', isEqualTo: 'Vehículo finalizado').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return buildEmptyStateMensaje();

          // Ordenamiento cronologico descendente
          var docs = snapshot.data!.docs.toList();
          docs.sort((a, b) {
            Timestamp? tA = (a.data() as Map<String, dynamic>)['fecha_pago'] ?? (a.data() as Map<String, dynamic>)['fecha'];
            Timestamp? tB = (b.data() as Map<String, dynamic>)['fecha_pago'] ?? (b.data() as Map<String, dynamic>)['fecha'];
            if (tA == null || tB == null) return 0;
            return tB.compareTo(tA);
          });

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index]; 
              var v = doc.data() as Map<String, dynamic>;
              DateTime? fecha = v['fecha'] != null ? (v['fecha'] as Timestamp).toDate() : null;
              String fechaStr = fecha != null ? "${fecha.day}/${fecha.month}/${fecha.year}" : "Sin registro de fecha";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.secondary, size: 40),
                  title: Text("${v['marca'] ?? ''} ${v['modelo'] ?? ''} - ${v['patente'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Medio Transaccional: ${v['metodo_pago'] ?? 'Débito'}\nTécnico: ${v['mecanico_responsable'] ?? 'S/R'} • Fecha: $fechaStr"),
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

/// Vista detallada de una transaccion concluida.
/// Proporciona funciones de eliminacion administrativa profunda (Archivos e indices).
class DetalleHistorialScreen extends StatelessWidget {
  final DocumentSnapshot vehiculoDoc; 
  const DetalleHistorialScreen({super.key, required this.vehiculoDoc});

  /// Invocacion de navegador externo para previsualizacion o descarga de evidencia documental.
  Future<void> _abrirNavegador(BuildContext context, String url) async {
    Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Imposible procesar el formato multimedia solicitado.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> vehiculoData = vehiculoDoc.data() as Map<String, dynamic>;
    Map<String, dynamic> tareas = vehiculoData['tareas_asignadas'] ?? {};
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle de Operación"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            tooltip: "Eliminar Registro Administrativo",
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Eliminar Registro", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  content: const Text("Esta acción es irreversible. Se eliminarán los datos transaccionales y la evidencia fotográfica de los servidores."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                        // Purga de archivos binarios en Storage para evitar costos residuales
                        if (vehiculoData['foto_inspeccion'] != null) {
                          List<String> fotosABorrar = vehiculoData['foto_inspeccion'] is String ? [vehiculoData['foto_inspeccion']] : List<String>.from(vehiculoData['foto_inspeccion']);
                          for (String url in fotosABorrar) {
                            try {
                              await FirebaseStorage.instance.refFromURL(url).delete();
                            } catch (e) {
                              debugPrint("Falla en eliminacion de nodo Storage: $e");
                            }
                          }
                        }

                        // Eliminacion de documento Firestore
                        await FirebaseFirestore.instance.collection('vehiculos').doc(vehiculoDoc.id).delete();
                        if (context.mounted) {
                          Navigator.pop(ctx); 
                          Navigator.pop(context); 
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Purgado exitoso de base de datos."), backgroundColor: Colors.green));
                        }
                      },
                      child: const Text("Confirmar Eliminación"),
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
              Text("Vehículo Identificado: ${vehiculoData['marca']} ${vehiculoData['modelo']}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text("Matrícula: ${vehiculoData['patente']} • Año Comercial: ${vehiculoData['ano'] ?? 'N/A'} • Cilindrada: ${vehiculoData['motor'] ?? 'N/A'}", style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              Text("RUT Contratante: ${vehiculoData['rut_cliente'] ?? 'N/A'} • Contacto: ${vehiculoData['telefono_cliente'] ?? 'N/A'}", style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              const SizedBox(height: 20),
              
              Builder(
                builder: (context) {
                  List<String> fotos = [];
                  if (vehiculoData['foto_inspeccion'] != null) {
                    if (vehiculoData['foto_inspeccion'] is String) fotos.add(vehiculoData['foto_inspeccion']);
                    else if (vehiculoData['foto_inspeccion'] is List) fotos = List<String>.from(vehiculoData['foto_inspeccion']);
                  }
                  if (fotos.isEmpty) return const SizedBox.shrink();
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Evidencia Anexa:", style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
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
                                  Positioned(
                                    bottom: 5, right: 5,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.black87,
                                      child: IconButton(icon: const Icon(Icons.download, color: Colors.blue, size: 20), onPressed: () => _abrirNavegador(context, fotos[index]), tooltip: "Descargar Original"),
                                    ),
                                  )
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
              
              Text("Técnico a Cargo:", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              Text("${vehiculoData['mecanico_responsable'] ?? 'N/A'}", style: const TextStyle(fontSize: 18)),
              Text("Identidad Técnica (RUT): ${vehiculoData['mecanico_rut'] ?? 'N/A'}", style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              const Divider(height: 30),
              
              Text("Procedimientos Realizados:", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              ...tareas.keys.map((k) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.check_circle, color: Colors.green), title: Text(k))),
              
              if ((vehiculoData['repuestos_utilizados'] as List?)?.isNotEmpty ?? false) ...[
                const Divider(height: 20),
                Text("Componentes Removidos de Inventario:", style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
                ...((vehiculoData['repuestos_utilizados'] as List).map((r) => Text("• $r"))),
              ],
  
              const Divider(height: 30),
              
              Text("Vía Transaccional: ${vehiculoData['metodo_pago'] ?? 'Débito'}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text("Neto Percibido: \$${vehiculoData['total_cobrado']?.toInt() ?? 0}", style: const TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Variables Técnicos (Comisión): \$${vehiculoData['comision_mecanico']?.toInt() ?? 0}", style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.secondary)),
              Text("Incentivos (Propinas): \$${vehiculoData['propina']?.toInt() ?? 0}", style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.secondary)),
            ],
          ),
        ),
      ),
    );
  }
}