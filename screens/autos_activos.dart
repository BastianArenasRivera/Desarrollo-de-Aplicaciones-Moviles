import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'registro_vehiculo.dart' show UpperCaseTextFormatter;
import 'gestion_personal.dart' show RutFormatter;

/// Vista de solo lectura. Expone las propiedades tecnicas y de negocio de un registro vehicular.
class VistaInfoAutoScreen extends StatelessWidget {
  final Map<String, dynamic> vData;
  const VistaInfoAutoScreen({super.key, required this.vData});

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> tareas = vData['tareas_asignadas'] ?? {};
    List<String> fotos = [];
    if (vData['foto_inspeccion'] != null) {
      if (vData['foto_inspeccion'] is String) fotos.add(vData['foto_inspeccion']);
      else if (vData['foto_inspeccion'] is List) fotos = List<String>.from(vData['foto_inspeccion']);
    }

    return Scaffold(
      appBar: AppBar(title: Text("Ficha Técnica: ${vData['patente'] ?? 'S/R'}")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Dominio Físico", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
            Text("Familia/Línea: ${vData['marca'] ?? ''} ${vData['modelo'] ?? ''}\nMatrícula Legal: ${vData['patente'] ?? ''}\nAño de Ensamblaje: ${vData['ano'] ?? 'N/A'}\nCapacidad Volumétrica: ${vData['motor'] ?? 'N/A'}\nPropósito de Ingreso: ${vData['servicio'] ?? 'General'}"),
            const Divider(height: 30),
            
            Text("Entidad de Facturación", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            Text("Razón Comercial: ${vData['nombre_cliente'] ?? ''} ${vData['apellido_cliente'] ?? ''}\nDocumento ID: ${vData['rut_cliente'] ?? 'N/A'}\nVía Telefónica: ${vData['telefono_cliente'] ?? 'N/A'}\nVía Electrónica: ${vData['email_cliente'] ?? 'N/A'}"),
            const Divider(height: 30),

            const Text("Status Operativo", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
            Text("Asignación de Mano de Obra: ${vData['mecanico_responsable'] ?? 'En cola de espera'}\nFase de Taller: ${vData['estado'] ?? 'Estado Nulo'}", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            if (tareas.isEmpty) const Text("Sin manifiesto de requerimientos técnicos.", style: TextStyle(color: Colors.grey))
            else ...tareas.keys.map((k) => ListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              leading: Icon(tareas[k] == true ? Icons.check_circle : Icons.radio_button_unchecked, color: tareas[k] == true ? Colors.green : Colors.grey),
              title: Text(k, style: TextStyle(decoration: tareas[k] == true ? TextDecoration.lineThrough : null)),
            )),
            const Divider(height: 30),

            const Text("Archivo Visual", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber)),
            const SizedBox(height: 10),
            if (fotos.isEmpty) const Text("Carencia de anexos fotográficos vinculantes.", style: TextStyle(color: Colors.grey))
            else SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: fotos.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(fotos[index], width: 120, height: 150, fit: BoxFit.cover)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

/// Modulo maestro de supervision. Permite CRUD parcial sobre las flotas en reparacion
/// gestionando reasignaciones tecnicas o correcciones en la ingesta de datos del registro.
class AutosActivosScreen extends StatelessWidget {
  const AutosActivosScreen({super.key});

  /// Invocacion de cuadro de dialogo modal para la reestructuracion del documento de Firebase.
  void _editarVehiculo(BuildContext context, DocumentSnapshot doc) {
    var v = doc.data() as Map<String, dynamic>;
    final patenteCtrl = TextEditingController(text: v['patente'] ?? '');
    final marcaCtrl = TextEditingController(text: v['marca'] ?? '');
    final modeloCtrl = TextEditingController(text: v['modelo'] ?? '');
    final rutClienteCtrl = TextEditingController(text: v['rut_cliente'] ?? '');
    String estadoSel = v['estado'] ?? 'Esperando inspección';
    String? nuevoMecanicoId; 

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Modificación Estructural de Orden", style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: patenteCtrl, inputFormatters: [UpperCaseTextFormatter()], decoration: const InputDecoration(labelText: "ID de Patente")),
                  const SizedBox(height: 10),
                  TextField(controller: marcaCtrl, decoration: const InputDecoration(labelText: "Fabricante Base")),
                  const SizedBox(height: 10),
                  TextField(controller: modeloCtrl, decoration: const InputDecoration(labelText: "Línea / Modelo")),
                  const SizedBox(height: 10),
                  TextField(controller: rutClienteCtrl, inputFormatters: [RutFormatter()], decoration: const InputDecoration(labelText: "RUT Asociado")),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: estadoSel, 
                    decoration: const InputDecoration(labelText: "Sobreescribir Fase"),
                    items: ['Esperando inspección', 'En curso', 'Auto Listo', 'Vehículo finalizado'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => estadoSel = val!),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  Text("Traspaso de Responsabilidad", style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').where('rol', isEqualTo: 'Mecánico').snapshots(),
                    builder: (c, snap) {
                      if (!snap.hasData) return const CircularProgressIndicator();
                      return DropdownButtonFormField<String>(
                        value: nuevoMecanicoId, 
                        decoration: InputDecoration(labelText: "Titular actual: ${v['mecanico_responsable']}"),
                        items: snap.data!.docs.map((d) {
                          var data = d.data() as Map<String, dynamic>;
                          return DropdownMenuItem(value: d.id, child: Text(data['nombre'] ?? 'Sin nombre'));
                        }).toList(), 
                        onChanged: (val) => setState(() => nuevoMecanicoId = val),
                      );
                    },
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.red))),
              ElevatedButton(
                onPressed: () async {
                  Map<String, dynamic> actualizacion = {'patente': patenteCtrl.text.trim(), 'marca': marcaCtrl.text.trim(), 'modelo': modeloCtrl.text.trim(), 'rut_cliente': rutClienteCtrl.text.trim(), 'estado': estadoSel};
                  
                  // Inyeccion condicional si ocurre un traspaso
                  if (nuevoMecanicoId != null) {
                    var userDoc = await FirebaseFirestore.instance.collection('users').doc(nuevoMecanicoId).get();
                    if (userDoc.exists) {
                      var userData = userDoc.data() as Map<String, dynamic>;
                      actualizacion['mecanico_responsable'] = userData['nombre'] ?? 'Técnico Desconocido';
                      actualizacion['mecanico_rut'] = userData['rut'] ?? 'S/R';
                    }
                  }
                  await FirebaseFirestore.instance.collection('vehiculos').doc(doc.id).update(actualizacion);
                  if (ctx.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Metadatos alterados exitosamente"), backgroundColor: Colors.green)); }
                },
                child: const Text("Confirmar Modificación"),
              )
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Órdenes Operativas en Taller")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehiculos').where('estado', isNotEqualTo: 'Vehículo finalizado').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Carencia de flujo vehicular activo", style: TextStyle(color: Colors.grey, fontSize: 18)));

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var v = doc.data() as Map<String, dynamic>;
              
              // Codificacion semantica de colores por estado
              Color estadoColor = Colors.grey;
              if (v['estado'] == 'Esperando inspección') estadoColor = Colors.redAccent;
              if (v['estado'] == 'En curso') estadoColor = Colors.amber;
              if (v['estado'] == 'Auto Listo') estadoColor = Colors.lightGreen;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VistaInfoAutoScreen(vData: v))),
                  leading: Icon(Icons.directions_car, color: Theme.of(context).colorScheme.secondary, size: 40),
                  title: Text("${v['marca'] ?? ''} ${v['modelo'] ?? ''}  (${v['patente'] ?? 'S/P'})", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text("Titular Técnico: ${v['mecanico_responsable'] ?? 'Desierto'}\nRUT Facturación: ${v['rut_cliente'] ?? 'N/A'}"),
                      const SizedBox(height: 5),
                      Text("Fase Operativa: ${v['estado']}", style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), tooltip: "Alterar Metadatos", onPressed: () => _editarVehiculo(context, doc)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red), tooltip: "Supresión Total",
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Supresión de Registro", style: TextStyle(color: Colors.red)),
                              content: Text("Esta acción revocará la existencia de la orden ${v['patente']} permanentemente."),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Abortar")),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () async {
                                    // Liberacion forzosa de cuota de almacenamiento Cloud
                                    if (v['foto_inspeccion'] != null) {
                                      List<String> fotosABorrar = v['foto_inspeccion'] is String ? [v['foto_inspeccion']] : List<String>.from(v['foto_inspeccion']);
                                      for (String url in fotosABorrar) {
                                        try {
                                          await FirebaseStorage.instance.refFromURL(url).delete();
                                        } catch (e) {
                                          debugPrint("Imposibilidad tecnica de purga binaria: $e");
                                        }
                                      }
                                    }

                                    await FirebaseFirestore.instance.collection('vehiculos').doc(doc.id).delete();
                                    
                                    if (context.mounted) { 
                                      Navigator.pop(ctx); 
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Expulsión del registro exitosa"), backgroundColor: Colors.green)); 
                                    }
                                  },
                                  child: const Text("Ejecutar Eliminación"),
                                )
                              ],
                            ),
                          );
                        },
                      ),
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