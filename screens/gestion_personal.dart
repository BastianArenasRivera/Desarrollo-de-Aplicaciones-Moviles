import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dashboard_home.dart' show buildEmptyStateMensaje;

class RutFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    String text = newValue.text.replaceAll(RegExp(r'[^0-9kK]'), '');
    if (text.length > 1) {
      text = '${text.substring(0, text.length - 1)}-${text.substring(text.length - 1)}';
    }
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class ListaPersonalScreen extends StatelessWidget {
  final String currentRol;
  final String currentUid;
  
  const ListaPersonalScreen({super.key, required this.currentRol, required this.currentUid});

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
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("Editar Empleado", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Nombre Completo")),
                  const SizedBox(height: 10),
                  TextField(
                    controller: rutCtrl, 
                    inputFormatters: [RutFormatter()], // 🔥 RUT Formateado
                    decoration: const InputDecoration(labelText: "RUT")
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: telefonoCtrl, 
                    keyboardType: TextInputType.number, 
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)], // 🔥 Límite de 9
                    decoration: const InputDecoration(labelText: "Teléfono (Debe empezar con 9)")
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: rolSel,
                    dropdownColor: Colors.black,
                    decoration: const InputDecoration(labelText: "Rol"),
                    items: currentRol == 'Jefe' 
                        ? ['Jefe', 'Administrador', 'Mecánico'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList()
                        : ['Administrador', 'Mecánico'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setState(() => rolSel = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.red))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () async {
                  // 🔥 Validación de Teléfono en edición
                  String tel = telefonoCtrl.text.trim();
                  if (tel.length != 9 || !tel.startsWith('9')) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("El teléfono debe tener 9 dígitos y empezar con 9"), backgroundColor: Colors.red));
                    return;
                  }

                  await FirebaseFirestore.instance.collection('users').doc(doc.id).update({
                    'nombre': nombreCtrl.text.trim(),
                    'rut': rutCtrl.text.trim(),
                    'telefono': tel,
                    'rol': rolSel,
                  });
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Datos actualizados correctamente"), backgroundColor: Colors.green));
                  }
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
      appBar: AppBar(title: const Text("Gestión de Personal")),
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

              if (isCurrentUser) {
                if (currentRol == 'Jefe') {
                  trailingWidget = IconButton(icon: const Icon(Icons.edit, color: Colors.blue), tooltip: "Editar mis datos", onPressed: () => _editarEmpleado(context, doc));
                } else {
                  trailingWidget = const Tooltip(message: "Este eres tú", child: Icon(Icons.person, color: Colors.green));
                }
              } else {
                bool puedeGestionar = false;
                if (currentRol == 'Jefe' && (targetRol == 'Administrador' || targetRol == 'Mecánico')) puedeGestionar = true;
                else if (currentRol == 'Administrador' && targetRol == 'Mecánico') puedeGestionar = true;

                if (puedeGestionar) {
                  trailingWidget = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), tooltip: "Editar Empleado", onPressed: () => _editarEmpleado(context, doc)),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: "Despedir / Eliminar",
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E1E),
                              title: const Text("Eliminar Empleado", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              content: Text("¿Estás seguro de que deseas eliminar a ${userData['nombre'] ?? 'este empleado'} del sistema?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance.collection('users').doc(doc.id).delete();
                                    if (context.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Acceso revocado exitosamente"), backgroundColor: Colors.green));
                                    }
                                  },
                                  child: const Text("Despedir / Eliminar"),
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
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  isThreeLine: true,
                  leading: Icon(['Administrador', 'Jefe'].contains(targetRol) ? Icons.admin_panel_settings : Icons.build, color: const Color(0xFFD2691E), size: 40),
                  title: Text("${userData['nombre'] ?? 'Sin Nombre'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Rol: $targetRol\nCorreo: ${userData['email'] ?? 'Sin correo'}\nRUT: ${userData['rut'] ?? 'No registrado'}\nTeléfono: ${userData['telefono'] ?? 'No registrado'}"),
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

class RegistroPersonal extends StatefulWidget {
  final String currentRol;
  const RegistroPersonal({super.key, required this.currentRol});
  @override State<RegistroPersonal> createState() => _RegistroPersonalState();
}

class _RegistroPersonalState extends State<RegistroPersonal> {
  final _nombreCtrl = TextEditingController(); 
  final _apellidoCtrl = TextEditingController(); 
  final _rutCtrl = TextEditingController(); 
  final _telefonoCtrl = TextEditingController(); 
  final _emailCtrl = TextEditingController(); 
  final _confEmailCtrl = TextEditingController();
  final _passCtrl = TextEditingController(); 
  final _confPassCtrl = TextEditingController();
  
  String _rol = 'Mecánico'; 
  bool _isLoading = false; 
  bool _obs1 = true; 
  bool _obs2 = true;

  Future<void> _registrar() async {
    if (_emailCtrl.text != _confEmailCtrl.text || _passCtrl.text != _confPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Correos o contraseñas no coinciden"), backgroundColor: Colors.red));
      return;
    }
    if (_nombreCtrl.text.trim().isEmpty || _apellidoCtrl.text.trim().isEmpty || _rutCtrl.text.trim().isEmpty || _telefonoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Por favor, completa todos los campos"), backgroundColor: Colors.red));
      return;
    }

    // 🔥 Validación estricta del Teléfono en registro
    String tel = _telefonoCtrl.text.trim();
    if (tel.length != 9 || !tel.startsWith('9')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("El teléfono debe tener 9 dígitos y empezar con 9"), backgroundColor: Colors.red));
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      FirebaseApp app = await Firebase.initializeApp(name: 'Secondary', options: Firebase.app().options);
      UserCredential uc = await FirebaseAuth.instanceFor(app: app).createUserWithEmailAndPassword(email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
      String nombreCompleto = '${_nombreCtrl.text.trim()} ${_apellidoCtrl.text.trim()}';

      await FirebaseFirestore.instance.collection('users').doc(uc.user!.uid).set({
        'nombre': nombreCompleto, 'rut': _rutCtrl.text.trim(), 'telefono': tel, 'email': _emailCtrl.text.trim(), 'rol': _rol
      });
      await app.delete(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Usuario registrado con éxito"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registrar Empleado")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: "Nombre", border: OutlineInputBorder())), const SizedBox(height: 15),
            TextField(controller: _apellidoCtrl, decoration: const InputDecoration(labelText: "Apellido", border: OutlineInputBorder())), const SizedBox(height: 15), 
            TextField(controller: _rutCtrl, inputFormatters: [RutFormatter()], decoration: const InputDecoration(labelText: "RUT (Ej: 12.345.678-9)", border: OutlineInputBorder())), const SizedBox(height: 15), 
            TextField(
              controller: _telefonoCtrl, 
              keyboardType: TextInputType.number, 
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
              decoration: const InputDecoration(labelText: "Teléfono (Debe empezar con 9)", border: OutlineInputBorder())
            ), 
            const SizedBox(height: 15), 
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: "Correo", border: OutlineInputBorder())), const SizedBox(height: 15),
            TextField(controller: _confEmailCtrl, decoration: const InputDecoration(labelText: "Confirmar Correo", border: OutlineInputBorder())), const SizedBox(height: 15),
            TextField(controller: _passCtrl, obscureText: _obs1, decoration: InputDecoration(labelText: "Contraseña", border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(_obs1 ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obs1 = !_obs1)))), const SizedBox(height: 15),
            TextField(controller: _confPassCtrl, obscureText: _obs2, decoration: InputDecoration(labelText: "Confirmar Contraseña", border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(_obs2 ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obs2 = !_obs2)))), const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _rol, dropdownColor: const Color(0xFF1E1E1E), decoration: const InputDecoration(labelText: "Rol", border: OutlineInputBorder()),
              items: (widget.currentRol == 'Jefe' 
                      ? ['Jefe', 'Administrador', 'Mecánico'] 
                      : ['Administrador', 'Mecánico'])
                  .map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(), 
              onChanged: (val) => setState(() => _rol = val!),
            ), const SizedBox(height: 30),
            _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _registrar, style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)), child: const Text("Registrar"))
          ],
        ),
      ),
    );
  }
}