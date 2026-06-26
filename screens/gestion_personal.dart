import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_home.dart' show buildEmptyStateMensaje;

/// Utilidad para inyeccion automatica del separador de RUT chileno en campos de texto.
class RutFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    // Purgar caracteres no alfanumericos invalidos
    String text = newValue.text.replaceAll(RegExp(r'[^0-9kK]'), '');
    // Insercion automatica del guion verificador
    if (text.length > 1) {
      text = '${text.substring(0, text.length - 1)}-${text.substring(text.length - 1)}';
    }
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Modulo administrativo para la gestion de RRHH.
/// Implementa controles de acceso escalonado (Jefe vs Administrador).
class ListaPersonalScreen extends StatelessWidget {
  final String currentRol;
  final String currentUid;
  
  const ListaPersonalScreen({super.key, required this.currentRol, required this.currentUid});

  /// Inicia flujo de alteracion de metadatos del empleado.
  void _editarEmpleado(BuildContext context, DocumentSnapshot doc) {
    var userData = doc.data() as Map<String, dynamic>;
    
    final nombreCtrl = TextEditingController(text: userData['nombre'] ?? '');
    final rutCtrl = TextEditingController(text: userData['rut'] ?? '');
    final telefonoCtrl = TextEditingController(text: userData['telefono'] ?? '');
    String rolSel = userData['rol'] ?? 'Mecánico';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Modificar Ficha de Empleado", style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Nombres y Apellidos")),
                  const SizedBox(height: 10),
                  TextField(
                    controller: rutCtrl, 
                    inputFormatters: [RutFormatter()], 
                    decoration: const InputDecoration(labelText: "Documento ID")
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: telefonoCtrl, 
                    keyboardType: TextInputType.number, 
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)], 
                    decoration: const InputDecoration(labelText: "Contacto Celular")
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: rolSel,
                    decoration: const InputDecoration(labelText: "Jerarquía de Acceso"),
                    items: currentRol == 'Jefe' 
                        ? ['Jefe', 'Administrador', 'Mecánico'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList()
                        : ['Administrador', 'Mecánico'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setState(() => rolSel = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Abortar", style: TextStyle(color: Colors.red))),
              ElevatedButton(
                onPressed: () async {
                  String tel = telefonoCtrl.text.trim();
                  if (tel.length != 9 || !tel.startsWith('9')) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error estructural en numero telefonico"), backgroundColor: Colors.red));
                    return;
                  }

                  // Transaccion de actualizacion
                  await FirebaseFirestore.instance.collection('users').doc(doc.id).update({
                    'nombre': nombreCtrl.text.trim(),
                    'rut': rutCtrl.text.trim(),
                    'telefono': tel,
                    'rol': rolSel,
                  });
                  
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ficha actualizada en sistema"), backgroundColor: Colors.green));
                  }
                },
                child: const Text("Aplicar Cambios"),
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
      appBar: AppBar(title: const Text("Planta de Personal")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return buildEmptyStateMensaje();

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var userData = doc.data() as Map<String, dynamic>;
              String targetRol = userData['rol'] ?? 'Mecánico';
              bool isCurrentUser = doc.id == currentUid;
              Widget? trailingWidget;

              // Logica de permisos para la visualizacion de botones de accion
              if (isCurrentUser) {
                if (currentRol == 'Jefe') {
                  trailingWidget = IconButton(icon: const Icon(Icons.edit, color: Colors.blue), tooltip: "Editar mis datos", onPressed: () => _editarEmpleado(context, doc));
                } else {
                  trailingWidget = const Tooltip(message: "Usuario Activo", child: Icon(Icons.person, color: Colors.green));
                }
              } else {
                bool puedeGestionar = false;
                if (currentRol == 'Jefe' && (targetRol == 'Administrador' || targetRol == 'Mecánico')) puedeGestionar = true;
                else if (currentRol == 'Administrador' && targetRol == 'Mecánico') puedeGestionar = true;

                if (puedeGestionar) {
                  trailingWidget = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), tooltip: "Editar Ficha", onPressed: () => _editarEmpleado(context, doc)),
                      IconButton(
                        icon: const Icon(Icons.person_off, color: Colors.red),
                        tooltip: "Revocar Acceso",
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Revocación de Credenciales", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              content: Text("El empleado ${userData['nombre'] ?? ''} perderá inmediatamente el acceso al sistema corporativo. ¿Confirma esta acción?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance.collection('users').doc(doc.id).delete();
                                    if (context.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Acceso denegado y ficha destruida"), backgroundColor: Colors.green));
                                    }
                                  },
                                  child: const Text("Desvincular"),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  );
                }
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  isThreeLine: true,
                  leading: Icon(['Administrador', 'Jefe'].contains(targetRol) ? Icons.admin_panel_settings : Icons.build, color: Theme.of(context).colorScheme.secondary, size: 40),
                  title: Text("${userData['nombre'] ?? 'Identidad Desconocida'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Rango: $targetRol\nID Interno: ${userData['rut'] ?? 'S/R'}\nContacto: ${userData['telefono'] ?? 'S/R'}"),
                  trailing: trailingWidget, 
                ),
              );
            },
          );
        },
      ),
    );
  }
}