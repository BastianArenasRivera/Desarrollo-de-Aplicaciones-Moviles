import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'gestion_personal.dart' show RutFormatter; 

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}

class RegistroVehiculo extends StatefulWidget {
  const RegistroVehiculo({super.key});
  @override State<RegistroVehiculo> createState() => _RegistroVehiculoState();
}

class _RegistroVehiculoState extends State<RegistroVehiculo> {
  String _serv = 'Mantenimiento General'; 
  String _motor = '1.4';
  String? _mecanicoId; 
  
  final _rutClienteCtrl = TextEditingController(); 
  final _telClienteCtrl = TextEditingController(); 
  final _emailClienteCtrl = TextEditingController(); 
  final _patente = TextEditingController(); 
  final _marca = TextEditingController(); 
  final _modelo = TextEditingController(); 
  final _ano = TextEditingController();
  
  bool _isLoading = false;

  Future<void> _guardar() async {
    if (_mecanicoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Debes asignar un mecánico"), backgroundColor: Colors.red));
      return;
    }

    
    String tel = _telClienteCtrl.text.trim();
    if (tel.length != 9 || !tel.startsWith('9')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("El teléfono debe tener EXACTAMENTE 9 dígitos y empezar con 9"), backgroundColor: Colors.red));
      return;
    }

    if (_emailClienteCtrl.text.trim().isEmpty || !_emailClienteCtrl.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ingresa un correo electrónico válido para el cliente"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    
    DocumentSnapshot mecDoc = await FirebaseFirestore.instance.collection('users').doc(_mecanicoId).get();
    Map<String, dynamic>? mecData = mecDoc.data() as Map<String, dynamic>?;
    String mecNombre = mecData?['nombre'] ?? 'Mecánico Desconocido';
    String mecRut = mecData?['rut'] ?? 'No registrado';

    await FirebaseFirestore.instance.collection('vehiculos').add({
      'rut_cliente': _rutClienteCtrl.text.trim(), 
      'telefono_cliente': tel, 
      'email_cliente': _emailClienteCtrl.text.trim(), 
      'patente': _patente.text.trim(), 
      'marca': _marca.text.trim(), 
      'modelo': _modelo.text.trim(), 
      'ano': _ano.text.trim(), 
      'motor': _motor,
      'servicio': _serv, 
      'estado': 'Esperando inspección', 
      'fecha': DateTime.now(), 
      'mecanico_responsable': mecNombre, 
      'mecanico_rut': mecRut, 
      'tareas_asignadas': {},
      'repuestos_utilizados': [], 
    });
    if (mounted) { Navigator.pop(context); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nuevo Vehículo")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Datos del Cliente", style: TextStyle(color: Color(0xFFD2691E), fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            TextField(
              controller: _rutClienteCtrl, 
              inputFormatters: [RutFormatter()], 
              decoration: const InputDecoration(labelText: "RUT Cliente", border: OutlineInputBorder())
            ), 
            const SizedBox(height: 15),
            TextField(
              controller: _telClienteCtrl, 
              keyboardType: TextInputType.number, 
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
              decoration: const InputDecoration(labelText: "Teléfono Cliente (Debe empezar con 9)", border: OutlineInputBorder())
            ), 
            const SizedBox(height: 15),
            TextField(
              controller: _emailClienteCtrl, 
              keyboardType: TextInputType.emailAddress, 
              decoration: const InputDecoration(labelText: "Correo Electrónico (Para envío de recibo)", border: OutlineInputBorder())
            ), 
            const SizedBox(height: 25),
            
            const Text("Datos del Vehículo", style: TextStyle(color: Color(0xFFD2691E), fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            TextField(
              controller: _patente, 
              inputFormatters: [UpperCaseTextFormatter()], 
              decoration: const InputDecoration(labelText: "Patente", border: OutlineInputBorder())
            ), 
            const SizedBox(height: 15),
            TextField(controller: _marca, decoration: const InputDecoration(labelText: "Marca", border: OutlineInputBorder())), const SizedBox(height: 15),
            TextField(controller: _modelo, decoration: const InputDecoration(labelText: "Modelo", border: OutlineInputBorder())), const SizedBox(height: 15),
            
            Row(
              children: [
                Expanded(child: TextField(controller: _ano, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Año", border: OutlineInputBorder()))),
                const SizedBox(width: 15),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _motor, dropdownColor: const Color(0xFF1E1E1E), decoration: const InputDecoration(labelText: "Motor", border: OutlineInputBorder()),
                    items: ['1.0', '1.2', '1.4', '1.5', '1.6', '1.8', '2.0', '2.2', '2.4', '2.5', '3.0', 'Otro'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), 
                    onChanged: (v) => setState(() => _motor = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: _serv, dropdownColor: const Color(0xFF1E1E1E), decoration: const InputDecoration(labelText: "Servicio", border: OutlineInputBorder()),
              items: ['Mantenimiento General', 'Reparación de Motor', 'Revisión de Frenos', 'Alineación y Balanceo'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => _serv = v!),
            ), const SizedBox(height: 15),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('rol', isEqualTo: 'Mecánico').snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const CircularProgressIndicator();
                return DropdownButtonFormField<String>(
                  value: _mecanicoId, dropdownColor: const Color(0xFF1E1E1E), decoration: const InputDecoration(labelText: "Asignar Mecánico", border: OutlineInputBorder()),
                  items: snap.data!.docs.map((d) {
                    var data = d.data() as Map<String, dynamic>;
                    return DropdownMenuItem(value: d.id, child: Text(data['nombre'] ?? 'Sin nombre'));
                  }).toList(), 
                  onChanged: (v) => setState(() => _mecanicoId = v),
                );
              },
            ), const SizedBox(height: 30),
            _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _guardar, style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)), child: const Text("Registrar"))
          ],
        ),
      ),
    );
  }
}
