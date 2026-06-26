import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'gestion_personal.dart' show RutFormatter;

/// Clase encargada de la creacion de nuevos perfiles de empleados.
/// Utiliza una instancia secundaria de Firebase para evitar cerrar la sesion del administrador actual.
class RegistroPersonal extends StatefulWidget {
  final String currentRol;
  const RegistroPersonal({super.key, required this.currentRol});
  
  @override 
  State<RegistroPersonal> createState() => _RegistroPersonalState();
}

class _RegistroPersonalState extends State<RegistroPersonal> {
  // Controladores de estado para los campos del formulario
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

  /// Metodo asincrono para validar datos y registrar al empleado en Firebase Authentication y Firestore.
  Future<void> _registrar() async {
    // Validacion de consistencia en credenciales
    if (_emailCtrl.text != _confEmailCtrl.text || _passCtrl.text != _confPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Correos o contraseñas no coinciden"), backgroundColor: Colors.red));
      return;
    }
    
    // Validacion de campos vacios
    if (_nombreCtrl.text.trim().isEmpty || _apellidoCtrl.text.trim().isEmpty || _rutCtrl.text.trim().isEmpty || _telefonoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Por favor, completa todos los campos requeridos"), backgroundColor: Colors.red));
      return;
    }

    // Validacion de formato telefonico nacional (Chile)
    String tel = _telefonoCtrl.text.trim();
    if (tel.length != 9 || !tel.startsWith('9')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("El teléfono debe contener 9 dígitos y comenzar con 9"), backgroundColor: Colors.red));
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Inicializacion de aplicacion secundaria para aislar el proceso de autenticacion
      FirebaseApp app = await Firebase.initializeApp(name: 'Secondary', options: Firebase.app().options);
      UserCredential uc = await FirebaseAuth.instanceFor(app: app).createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(), 
        password: _passCtrl.text.trim()
      );
      
      String nombreCompleto = '${_nombreCtrl.text.trim()} ${_apellidoCtrl.text.trim()}';

      // Persistencia de los metadatos del empleado en la coleccion base
      await FirebaseFirestore.instance.collection('users').doc(uc.user!.uid).set({
        'nombre': nombreCompleto, 
        'rut': _rutCtrl.text.trim(), 
        'telefono': tel, 
        'email': _emailCtrl.text.trim(), 
        'rol': _rol
      });
      
      // Cierre de la instancia secundaria para liberar memoria
      await app.delete(); 
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Usuario registrado exitosamente"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error interno: $e"), backgroundColor: Colors.red));
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
            TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: "Nombre")), 
            const SizedBox(height: 15),
            TextField(controller: _apellidoCtrl, decoration: const InputDecoration(labelText: "Apellido")), 
            const SizedBox(height: 15), 
            TextField(controller: _rutCtrl, inputFormatters: [RutFormatter()], decoration: const InputDecoration(labelText: "RUT (Ej: 12.345.678-9)")), 
            const SizedBox(height: 15), 
            TextField(
              controller: _telefonoCtrl, 
              keyboardType: TextInputType.number, 
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
              decoration: const InputDecoration(labelText: "Teléfono (Debe empezar con 9)")
            ), 
            const SizedBox(height: 15), 
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: "Correo Electrónico")), 
            const SizedBox(height: 15),
            TextField(controller: _confEmailCtrl, decoration: const InputDecoration(labelText: "Confirmar Correo")), 
            const SizedBox(height: 15),
            TextField(
              controller: _passCtrl, obscureText: _obs1, 
              decoration: InputDecoration(
                labelText: "Contraseña", 
                suffixIcon: IconButton(icon: Icon(_obs1 ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obs1 = !_obs1))
              )
            ), 
            const SizedBox(height: 15),
            TextField(
              controller: _confPassCtrl, obscureText: _obs2, 
              decoration: InputDecoration(
                labelText: "Confirmar Contraseña", 
                suffixIcon: IconButton(icon: Icon(_obs2 ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obs2 = !_obs2))
              )
            ), 
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _rol, 
              decoration: const InputDecoration(labelText: "Rol del Sistema"),
              items: (widget.currentRol == 'Jefe' ? ['Jefe', 'Administrador', 'Mecánico'] : ['Administrador', 'Mecánico'])
                  .map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(), 
              onChanged: (val) => setState(() => _rol = val!),
            ), 
            const SizedBox(height: 30),
            _isLoading 
              ? const CircularProgressIndicator() 
              : ElevatedButton(
                  onPressed: _registrar, 
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)), 
                  child: const Text("Registrar Empleado")
                )
          ],
        ),
      ),
    );
  }
}