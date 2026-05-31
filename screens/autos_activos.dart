import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'registro_vehiculo.dart' show UpperCaseTextFormatter;
import 'gestion_personal.dart' show RutFormatter;

class AutosActivosScreen extends StatelessWidget {
  const AutosActivosScreen({super.key});

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
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("Editar Vehículo / Mecánico", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: patenteCtrl, inputFormatters: [UpperCaseTextFormatter()], decoration: const InputDecoration(labelText: "Patente")),
                  const SizedBox(height: 10),
                  TextField(controller: marcaCtrl, decoration: const InputDecoration(labelText: "Marca")),
                  const SizedBox(height: 10),
                  TextField(controller: modeloCtrl, decoration: const InputDecoration(labelText: "Modelo")),
                  const SizedBox(height: 10),
                  TextField(controller: rutClienteCtrl, inputFormatters: [RutFormatter()], decoration: const InputDecoration(labelText: "RUT Cliente")),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: estadoSel, dropdownColor: Colors.black, decoration: const InputDecoration(labelText: "Estado Actual"),
                    items: ['Esperando inspección', 'En curso', 'Auto Listo', 'Vehículo finalizado'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => estadoSel = val!),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.grey),
                  const Text("Reasignar Mecánico (Opcional)", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').where('rol', isEqualTo: 'Mecánico').snapshots(),
                    builder: (c, snap) {
                      if (!snap.hasData) return const CircularProgressIndicator();
                      return DropdownButtonFormField<String>(
                        value: nuevoMecanicoId, dropdownColor: Colors.black, decoration: InputDecoration(labelText: "Mecánico actual: ${v['mecanico_responsable']}"),
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
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () async {
                  Map<String, dynamic> actualizacion = {
                    'patente': patenteCtrl.text.trim(),
                    'marca': marcaCtrl.text.trim(),
                    'modelo': modeloCtrl.text.trim(),
                    'rut_cliente': rutClienteCtrl.text.trim(),
                    'estado': estadoSel,
                  };

                  // 🔥 Si el jefe seleccionó un mecánico nuevo, actualiza los datos
                  if (nuevoMecanicoId != null) {
                    var userDoc = await FirebaseFirestore.instance.collection('users').doc(nuevoMecanicoId).get();
                    if (userDoc.exists) {
                      var userData = userDoc.data() as Map<String, dynamic>;
                      actualizacion['mecanico_responsable'] = userData['nombre'] ?? 'Mecánico Desconocido';
                      actualizacion['mecanico_rut'] = userData['rut'] ?? 'S/R';
                    }
                  }

                  await FirebaseFirestore.instance.collection('vehiculos').doc(doc.id).update(actualizacion);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vehículo actualizado"), backgroundColor: Colors.green));
                  }
                },
                child: const Text("Guardar Cambios"),
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
      appBar: AppBar(title: const Text("Autos Activos en Taller")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehiculos').where('estado', isNotEqualTo: 'Vehículo finalizado').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No hay autos activos en este momento", style: TextStyle(color: Colors.grey, fontSize: 18)));

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var v = doc.data() as Map<String, dynamic>;
              
              Color estadoColor = Colors.grey;
              if (v['estado'] == 'Esperando inspección') estadoColor = Colors.redAccent;
              if (v['estado'] == 'En curso') estadoColor = Colors.amber;
              if (v['estado'] == 'Auto Listo') estadoColor = Colors.lightGreen;

              return Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: const Icon(Icons.directions_car, color: Colors.blueAccent, size: 40),
                  title: Text("${v['marca'] ?? ''} ${v['modelo'] ?? ''}  (${v['patente'] ?? 'S/P'})", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text("Mecánico: ${v['mecanico_responsable'] ?? 'Sin asignar'}\nCliente RUT: ${v['rut_cliente'] ?? 'N/A'}"),
                      const SizedBox(height: 5),
                      Text("Estado: ${v['estado']}", style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), tooltip: "Editar Vehículo", onPressed: () => _editarVehiculo(context, doc)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: "Eliminar Registro",
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E1E),
                              title: const Text("Eliminar Vehículo", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              content: Text("¿Estás seguro de que deseas eliminar la orden de ${v['patente']}?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance.collection('vehiculos').doc(doc.id).delete();
                                    if (context.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vehículo eliminado exitosamente"), backgroundColor: Colors.green));
                                    }
                                  },
                                  child: const Text("Eliminar"),
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