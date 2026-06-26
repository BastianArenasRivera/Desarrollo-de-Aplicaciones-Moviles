import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'gestion_personal.dart' show RutFormatter; 

/// Formateador de texto para asegurar estandarizacion en mayusculas (Ej: Patentes).
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}

/// Modulo de ingreso de nuevos vehiculos al taller.
/// Integra validaciones de negocio y consumo de API externa para modelos automotrices.
class RegistroVehiculo extends StatefulWidget {
  const RegistroVehiculo({super.key});
  @override 
  State<RegistroVehiculo> createState() => _RegistroVehiculoState();
}

class _RegistroVehiculoState extends State<RegistroVehiculo> {
  String _serv = 'Mantenimiento General'; 
  String _motor = '1.4';
  String? _mecanicoId; 
  
  final _nombreClienteCtrl = TextEditingController(); 
  final _apellidoClienteCtrl = TextEditingController(); 
  final _rutClienteCtrl = TextEditingController(); 
  final _telClienteCtrl = TextEditingController(); 
  final _emailClienteCtrl = TextEditingController(); 
  final _patente = TextEditingController(); 
  final _ano = TextEditingController();
  final _marcaCtrl = TextEditingController(); 
  final _modeloCtrl = TextEditingController(); 
  
  bool _isLoading = false;
  bool _cargandoMarcasAPI = true;
  List<String> _marcasAPI = [];
  List<String> _modelosAPI = [];

  @override
  void initState() {
    super.initState();
    _cargarMarcasDesdeAPI(); 
  }

  /// Peticion HTTP para obtener marcas globales, aplicando filtro de relevancia regional (LATAM) y manejo de cache.
  Future<void> _cargarMarcasDesdeAPI() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    final List<String> marcasComunes = [
      'TOYOTA', 'CHEVROLET', 'NISSAN', 'HYUNDAI', 'KIA', 'FORD', 'SUZUKI', 'PEUGEOT', 
      'MAZDA', 'HONDA', 'VOLKSWAGEN', 'SUBARU', 'MITSUBISHI', 'RENAULT', 'CHERY', 
      'MG', 'CHANGAN', 'SSANGYONG', 'FIAT', 'JEEP', 'DODGE', 'BMW', 'MERCEDES-BENZ', 'AUDI', 'VOLVO'
    ];

    try {
      final response = await http.get(Uri.parse('https://vpic.nhtsa.dot.gov/api/vehicles/getallmakes?format=json')).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        List<dynamic> results = data['Results'];
        Set<String> todasLasMarcasAPI = results.map<String>((m) => m['Make_Name'].toString().toUpperCase()).toSet();
        
        _marcasAPI = marcasComunes.where((m) => todasLasMarcasAPI.contains(m)).toList();
        
        if (!_marcasAPI.contains('MG')) _marcasAPI.add('MG');
        if (!_marcasAPI.contains('CHERY')) _marcasAPI.add('CHERY');
        if (!_marcasAPI.contains('CHANGAN')) _marcasAPI.add('CHANGAN');

        _marcasAPI.sort(); 
        await prefs.setString('api_marcas_cache', json.encode(_marcasAPI));
      }
    } catch (e) {
      debugPrint("Advertencia: Fallo conexion con API, empleando persistencia local. Detalles: $e");
      String? cache = prefs.getString('api_marcas_cache');
      if (cache != null) {
        _marcasAPI = List<String>.from(json.decode(cache));
      } else {
        _marcasAPI = marcasComunes;
      }
    } finally {
      if (mounted) setState(() => _cargandoMarcasAPI = false);
    }
  }

  /// Peticion HTTP para obtener modelos especificos segun la marca seleccionada.
  Future<void> _cargarModelosDesdeAPI(String marca) async {
    setState(() => _modelosAPI = []); 
    try {
      final response = await http.get(Uri.parse('https://vpic.nhtsa.dot.gov/api/vehicles/GetModelsForMake/$marca?format=json')).timeout(const Duration(seconds: 5));
      
      List<String> modelosCombinados = [];
      
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        List<dynamic> results = data['Results'];
        modelosCombinados = results.map<String>((m) => m['Model_Name'].toString().toUpperCase()).toList();
      }

      // Inyeccion de modelos populares regionales no cubiertos por API base
      if (marca == 'KIA') modelosCombinados.addAll(['MORNING', 'SOLUTO', 'FRONTIER', 'RIO', 'CARENS', 'SONET']);
      if (marca == 'CHEVROLET') modelosCombinados.addAll(['SAIL', 'SPARK', 'AVEO', 'OPTRA', 'CAPTIVA', 'D-MAX', 'GROOVE', 'ONIX']);
      if (marca == 'SUZUKI') modelosCombinados.addAll(['MARUTI', 'ALTO', 'BALENO', 'SWIFT', 'DZIRE', 'CELERIO', 'S-PRESSO']);
      if (marca == 'HYUNDAI') modelosCombinados.addAll(['ACCENT', 'I10', 'GRAND I10', 'H1', 'CRETA', 'VERNA']);
      if (marca == 'TOYOTA') modelosCombinados.addAll(['YARIS', 'HILUX', 'COROLLA', 'URBAN CRUISER', 'RAV4', 'RAIZE']);
      if (marca == 'NISSAN') modelosCombinados.addAll(['V16', 'MARCH', 'TERRANO', 'NAVARA', 'VERSA', 'KICKS', 'QASHQAI']);
      if (marca == 'PEUGEOT') modelosCombinados.addAll(['208', '301', '308', 'PARTNER', '2008', '3008']);
      if (marca == 'MG') modelosCombinados.addAll(['ZS', 'ZX', 'MG3', 'MG6', 'HS']);
      if (marca == 'CHERY') modelosCombinados.addAll(['TIGGO 2', 'TIGGO 3', 'TIGGO 8', 'IQ', 'ARRIZO']);
      if (marca == 'CHANGAN') modelosCombinados.addAll(['CS15', 'CS35', 'CX70', 'HUNTER']);

      setState(() {
        _modelosAPI = modelosCombinados.toSet().toList(); 
        _modelosAPI.sort();
      });
    } catch (e) {
      debugPrint("Error de red al consultar modelos: $e");
    }
  }

  /// Valida el formulario y persiste el nuevo registro en la base de datos Firestore.
  Future<void> _guardar() async {
    if (_mecanicoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Asignación de mecánico requerida"), backgroundColor: Colors.red));
      return;
    }

    String tel = _telClienteCtrl.text.trim();
    if (tel.length != 9 || !tel.startsWith('9')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Formato de teléfono inválido"), backgroundColor: Colors.red));
      return;
    }

    if (_nombreClienteCtrl.text.trim().isEmpty || _apellidoClienteCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Datos de identificación del cliente incompletos"), backgroundColor: Colors.red));
      return;
    }

    if (_emailClienteCtrl.text.trim().isEmpty || !_emailClienteCtrl.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Correo electrónico corporativo requerido para notificaciones"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    
    DocumentSnapshot mecDoc = await FirebaseFirestore.instance.collection('users').doc(_mecanicoId).get();
    Map<String, dynamic>? mecData = mecDoc.data() as Map<String, dynamic>?;
    String mecNombre = mecData?['nombre'] ?? 'Mecánico Desconocido';
    String mecRut = mecData?['rut'] ?? 'No registrado';

    await FirebaseFirestore.instance.collection('vehiculos').add({
      'nombre_cliente': _nombreClienteCtrl.text.trim(), 
      'apellido_cliente': _apellidoClienteCtrl.text.trim(), 
      'rut_cliente': _rutClienteCtrl.text.trim(), 
      'telefono_cliente': tel, 
      'email_cliente': _emailClienteCtrl.text.trim(), 
      'patente': _patente.text.trim(), 
      'marca': _marcaCtrl.text.trim(), 
      'modelo': _modeloCtrl.text.trim(), 
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
      appBar: AppBar(title: const Text("Ingreso de Vehículo")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Información del Cliente", style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: _nombreClienteCtrl, decoration: const InputDecoration(labelText: "Nombres"))),
                const SizedBox(width: 15),
                Expanded(child: TextField(controller: _apellidoClienteCtrl, decoration: const InputDecoration(labelText: "Apellidos"))),
              ],
            ),
            const SizedBox(height: 15),
            TextField(controller: _rutClienteCtrl, inputFormatters: [RutFormatter()], decoration: const InputDecoration(labelText: "RUT Cliente")), 
            const SizedBox(height: 15),
            TextField(controller: _telClienteCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)], decoration: const InputDecoration(labelText: "Teléfono Móvil")), 
            const SizedBox(height: 15),
            TextField(controller: _emailClienteCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Correo Electrónico (Facturación)")), 
            const SizedBox(height: 25),
            
            Text("Especificaciones del Vehículo", style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            TextField(controller: _patente, inputFormatters: [UpperCaseTextFormatter()], decoration: const InputDecoration(labelText: "Patente")), 
            const SizedBox(height: 15),
            
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                return _marcasAPI.where((String option) => option.contains(textEditingValue.text.toUpperCase()));
              },
              onSelected: (String selection) {
                _marcaCtrl.text = selection; 
                _cargarModelosDesdeAPI(selection); 
              },
              fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                controller.addListener(() { _marcaCtrl.text = controller.text; });
                return TextField(
                  controller: controller, focusNode: focusNode, inputFormatters: [UpperCaseTextFormatter()],
                  decoration: InputDecoration(
                    labelText: "Marca Fabricante",
                    suffixIcon: _cargandoMarcasAPI 
                      ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Icon(Icons.cloud_done, color: Colors.green),
                  ),
                );
              },
            ),
            const SizedBox(height: 15),

            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) return _modelosAPI.take(10); 
                return _modelosAPI.where((String option) => option.contains(textEditingValue.text.toUpperCase()));
              },
              onSelected: (String selection) => _modeloCtrl.text = selection,
              fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                controller.addListener(() { _modeloCtrl.text = controller.text; });
                return TextField(
                  controller: controller, focusNode: focusNode, inputFormatters: [UpperCaseTextFormatter()],
                  decoration: const InputDecoration(labelText: "Línea / Modelo", helperText: "Dependiente de marca seleccionada"),
                );
              },
            ),
            const SizedBox(height: 15),
            
            Row(
              children: [
                Expanded(child: TextField(controller: _ano, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Año Comercial"))),
                const SizedBox(width: 15),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _motor, 
                    decoration: const InputDecoration(labelText: "Cilindrada"),
                    items: ['1.0', '1.2', '1.4', '1.5', '1.6', '1.8', '2.0', '2.2', '2.4', '2.5', '3.0', 'Otro'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), 
                    onChanged: (v) => setState(() => _motor = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: _serv, 
              decoration: const InputDecoration(labelText: "Tipo de Servicio"),
              items: ['Mantenimiento General', 'Reparación de Motor', 'Revisión de Frenos', 'Alineación y Balanceo'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => _serv = v!),
            ), 
            const SizedBox(height: 15),
            
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('rol', isEqualTo: 'Mecánico').snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const CircularProgressIndicator();
                return DropdownButtonFormField<String>(
                  value: _mecanicoId, 
                  decoration: const InputDecoration(labelText: "Asignar Responsable Técnico"),
                  items: snap.data!.docs.map((d) {
                    var data = d.data() as Map<String, dynamic>;
                    return DropdownMenuItem(value: d.id, child: Text(data['nombre'] ?? 'Sin nombre'));
                  }).toList(), 
                  onChanged: (v) => setState(() => _mecanicoId = v),
                );
              },
            ), 
            const SizedBox(height: 30),
            _isLoading 
              ? const CircularProgressIndicator() 
              : ElevatedButton(
                  onPressed: _guardar, 
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)), 
                  child: const Text("Registrar Orden de Trabajo")
                )
          ],
        ),
      ),
    );
  }
}