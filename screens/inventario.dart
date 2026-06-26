import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Gestor de almacenes y cadena de suministro.
/// Implementa una arquitectura Offline-First rudimentaria para asegurar la lectura del inventario sin red.
class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  List<Map<String, dynamic>> _cachedData = [];

  @override
  void initState() {
    super.initState();
    _cargarCacheLocal(); 
  }

  /// Hidrata el estado inicial de la pantalla leyendo el ultimo String JSON almacenado en dispositivo.
  Future<void> _cargarCacheLocal() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? dataString = prefs.getString('inventario_offline');
    if (dataString != null) {
      setState(() {
        _cachedData = List<Map<String, dynamic>>.from(json.decode(dataString));
      });
    }
  }

  /// Serializa la coleccion de documentos actual de Firestore y la consolida en SharedPreferences.
  Future<void> _guardarCacheLocal(List<QueryDocumentSnapshot> docs) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> datosParaGuardar = docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      data['doc_id'] = doc.id; 
      return data;
    }).toList();
    await prefs.setString('inventario_offline', json.encode(datosParaGuardar));
  }

  /// Inicia el flujo logico para la creacion de nuevos SKU o abastecimiento de existencias.
  void _reabastecer(BuildContext context, [Map<String, dynamic>? item]) {
    final nombreCtrl = TextEditingController(text: item?['nombre'] ?? '');
    final especCtrl = TextEditingController(text: item?['especificaciones'] ?? '');
    final cantidadCtrl = TextEditingController(text: item?['cantidad']?.toString() ?? '');
    
    List<String> tipos = ['Aceite', 'Filtro de aire', 'Filtro de aceite', 'Pastillas de freno', 'Otro'];
    String tipoSeleccionado = item != null && tipos.contains(item['tipo']) ? item['tipo'] : 'Aceite';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(item == null ? "Alta de Producto" : "Actualización de SKU", style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: tipoSeleccionado, 
                    decoration: const InputDecoration(labelText: "Categoría Logística"),
                    items: tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setStateDialog(() => tipoSeleccionado = v!),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Descripción (Ej: Mobil 1)")),
                  const SizedBox(height: 10),
                  TextField(controller: especCtrl, decoration: const InputDecoration(labelText: "Propiedades Técnicas")),
                  const SizedBox(height: 10),
                  TextField(controller: cantidadCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Existencias")),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.red))),
              ElevatedButton(
                onPressed: () async {
                  int cant = int.tryParse(cantidadCtrl.text) ?? 0;
                  try {
                    // Operador logico ternario para bifurcar entre INSERCION o ACTUALIZACION
                    if (item == null) {
                      await FirebaseFirestore.instance.collection('inventario').add({
                        'tipo': tipoSeleccionado, 'nombre': nombreCtrl.text, 'especificaciones': especCtrl.text, 'cantidad': cant,
                      });
                    } else {
                      await FirebaseFirestore.instance.collection('inventario').doc(item['doc_id']).update({
                        'tipo': tipoSeleccionado, 'nombre': nombreCtrl.text, 'especificaciones': especCtrl.text, 'cantidad': cant,
                      });
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Red requerida para inyeccion de datos")));
                  }
                },
                child: const Text("Registrar Movimiento"),
              )
            ],
          );
        }
      ),
    );
  }

  void _eliminarProducto(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Baja de Inventario", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text("¿Confirma la eliminación del catálogo para el ítem '${data['nombre']}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Abortar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('inventario').doc(data['doc_id']).delete();
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Red requerida para eliminación")));
              }
            },
            child: const Text("Ejecutar Baja"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Almacén"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box),
            tooltip: "Ingresar Nuevo SKU",
            onPressed: () => _reabastecer(context),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('inventario').orderBy('nombre').snapshots(),
        builder: (context, snapshot) {
          
          bool usandoCache = false;
          List<Map<String, dynamic>> itemsAMostrar = [];

          if (snapshot.hasData) {
            _guardarCacheLocal(snapshot.data!.docs);
            itemsAMostrar = snapshot.data!.docs.map((d) {
              var data = d.data() as Map<String, dynamic>;
              data['doc_id'] = d.id;
              return data;
            }).toList();
          } else {
            usandoCache = true;
            itemsAMostrar = _cachedData;
          }

          if (itemsAMostrar.isEmpty) {
            return usandoCache 
                ? const Center(child: Text("Bases de datos locales e remotas vacías.", style: TextStyle(color: Colors.grey)))
                : const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              if (usandoCache)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: const Text("Operando en modo desconectado (Caché local activa)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: itemsAMostrar.length,
                  itemBuilder: (context, index) {
                    var data = itemsAMostrar[index];
                    int stock = data['cantidad'] ?? 0;
                    Color stockColor = stock <= 3 ? Colors.redAccent : Colors.green;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: stockColor.withOpacity(0.2),
                          child: Text(stock.toString(), style: TextStyle(color: stockColor, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(data['nombre'] ?? 'Desconocido', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text(stock <= 3 ? "¡Alerta: Quiebre inminente!" : "Existencias Operativas", style: TextStyle(color: stockColor, fontSize: 12)),
                        children: [
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Propiedades Técnicas:", style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 5),
                                      Text(data['especificaciones'] ?? 'No detallado', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                      const SizedBox(height: 10),
                                      Text("Categoría: ${data['tipo']}", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      tooltip: "Modificar Datos Base",
                                      onPressed: () => _reabastecer(context, data),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: "Suprimir SKU",
                                      onPressed: () => _eliminarProducto(context, data),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}