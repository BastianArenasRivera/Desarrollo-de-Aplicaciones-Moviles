import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_home.dart' show buildEmptyStateMensaje;

class InventarioScreen extends StatelessWidget {
  const InventarioScreen({super.key});

  void _reabastecer(BuildContext context, [DocumentSnapshot? item]) {
    var data = item?.data() as Map<String, dynamic>?;
    final nombreCtrl = TextEditingController(text: data?['nombre'] ?? '');
    final especCtrl = TextEditingController(text: data?['especificaciones'] ?? '');
    final cantidadCtrl = TextEditingController(text: data?['cantidad']?.toString() ?? '');
    
    List<String> tipos = ['Aceite', 'Filtro de aire', 'Filtro de aceite', 'Pastillas de freno', 'Otro'];
    String tipoSeleccionado = data != null && tipos.contains(data['tipo']) ? data['tipo'] : 'Aceite';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: Text(item == null ? "Nuevo Artículo" : "Reabastecer / Editar"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: tipoSeleccionado, dropdownColor: Colors.black,
                    decoration: const InputDecoration(labelText: "Tipo de Artículo"),
                    items: tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => tipoSeleccionado = v!),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Marca/Nombre (Ej: Mobil 1)")),
                  const SizedBox(height: 10),
                  TextField(controller: especCtrl, decoration: const InputDecoration(labelText: "Especificaciones")),
                  const SizedBox(height: 10),
                  TextField(controller: cantidadCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Stock Total")),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.red))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD2691E)),
                onPressed: () async {
                  int cant = int.tryParse(cantidadCtrl.text) ?? 0;
                  if (item == null) {
                    await FirebaseFirestore.instance.collection('inventario').add({
                      'tipo': tipoSeleccionado, 'nombre': nombreCtrl.text, 'especificaciones': especCtrl.text, 'cantidad': cant,
                    });
                  } else {
                    await FirebaseFirestore.instance.collection('inventario').doc(item.id).update({
                      'tipo': tipoSeleccionado, 'nombre': nombreCtrl.text, 'especificaciones': especCtrl.text, 'cantidad': cant,
                    });
                  }
                  Navigator.pop(ctx);
                },
                child: const Text("Guardar"),
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
      appBar: AppBar(title: const Text("Inventario de Taller")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _reabastecer(context),
        label: const Text("Reabastecer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_box, color: Colors.white), backgroundColor: const Color(0xFFD2691E),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('inventario').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return buildEmptyStateMensaje();

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text("Stock", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD2691E)))),
                DataColumn(label: Text("Artículo", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD2691E)))),
                DataColumn(label: Text("Tipo", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD2691E)))),
                DataColumn(label: Text("Specs / Uso", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD2691E)))),
                DataColumn(label: Text("Acción", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD2691E)))),
              ],
              rows: snapshot.data!.docs.map((doc) {
                var data = doc.data() as Map<String, dynamic>;
                int stock = data['cantidad'] ?? 0;
                Color stockColor = stock < 3 ? Colors.redAccent : Colors.green;

                return DataRow(cells: [
                  DataCell(Text(stock.toString(), style: TextStyle(color: stockColor, fontWeight: FontWeight.bold, fontSize: 18))),
                  DataCell(Text(data['nombre'] ?? 'Sin nombre')),
                  DataCell(Text(data['tipo'] ?? 'Sin tipo')),
                  DataCell(Text(data['especificaciones'] ?? 'N/A')),
                  DataCell(IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _reabastecer(context, doc))),
                ]);
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}