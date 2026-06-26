import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

/// Modulo operativo para los tecnicos de taller.
/// Gestiona la recoleccion de evidencia multimedia y la declaracion de finalizacion de tareas.
class ChecklistMecanicoScreen extends StatefulWidget {
  final DocumentSnapshot vehiculoDoc;
  
  const ChecklistMecanicoScreen({super.key, required this.vehiculoDoc});

  @override
  State<ChecklistMecanicoScreen> createState() => _ChecklistMecanicoScreenState();
}

class _ChecklistMecanicoScreenState extends State<ChecklistMecanicoScreen> {
  bool _isUploading = false;
  List<String> _fotosSubidas = [];

  @override
  void initState() {
    super.initState();
    _sincronizarEvidenciaPrevia();
  }

  /// Recupera los identificadores URI de la evidencia subida en sesiones anteriores.
  void _sincronizarEvidenciaPrevia() {
    var data = widget.vehiculoDoc.data() as Map<String, dynamic>;
    if (data['foto_inspeccion'] != null) {
      if (data['foto_inspeccion'] is String) {
        _fotosSubidas.add(data['foto_inspeccion']);
      } else if (data['foto_inspeccion'] is List) {
        _fotosSubidas = List<String>.from(data['foto_inspeccion']);
      }
    }
  }

  /// Inicializa la camara nativa del dispositivo para captura de evidencia en tiempo real.
  Future<void> _tomarFoto() async {
    final ImagePicker picker = ImagePicker();
    // Resolucion reducida (quality: 70) para optimizar costos de ancho de banda y almacenamiento Cloud
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    
    if (photo != null) {
      await _subirImagenAFirebase(File(photo.path));
    }
  }

  /// Despliega el selector de galeria nativo permitiendo seleccion multiple de archivos.
  Future<void> _elegirDeGaleria() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(imageQuality: 70);
    
    if (images.isNotEmpty) {
      for (var img in images) {
        await _subirImagenAFirebase(File(img.path));
      }
    }
  }

  /// Procesa la subida binaria al bucket de Firebase Storage y actualiza el documento en Firestore.
  Future<void> _subirImagenAFirebase(File imagen) async {
    setState(() => _isUploading = true);
    try {
      String fileName = 'inspecciones/${widget.vehiculoDoc.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = ref.putFile(imagen);
      
      TaskSnapshot snapshot = await uploadTask;
      String urlDescarga = await snapshot.ref.getDownloadURL();

      setState(() {
        _fotosSubidas.add(urlDescarga);
      });

      // Se ejecuta un update del arreglo completo para garantizar consistencia
      await FirebaseFirestore.instance.collection('vehiculos').doc(widget.vehiculoDoc.id).update({
        'foto_inspeccion': _fotosSubidas
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Evidencia sincronizada correctamente"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Falla de sincronizacion: $e"), backgroundColor: Colors.red));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  /// Marca la orden de trabajo como concluida a nivel tecnico, derivandola a caja.
  void _marcarComoListo() async {
    await FirebaseFirestore.instance.collection('vehiculos').doc(widget.vehiculoDoc.id).update({
      'estado': 'Auto Listo',
      'foto_inspeccion': _fotosSubidas 
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Operación técnica finalizada. Orden derivada a cobro."), backgroundColor: Colors.green));
      Navigator.pop(context); 
    }
  }

  @override
  Widget build(BuildContext context) {
    var vData = widget.vehiculoDoc.data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(title: const Text("Estación de Trabajo")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Vehículo: ${vData['marca']} ${vData['modelo']}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              Text("Matrícula: ${vData['patente']} • Motor: ${vData['motor']}", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 16)),
              const Divider(height: 30),

              Text("Evidencia Fotográfica Requerida:", style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Cámara"),
                      onPressed: _isUploading ? null : _tomarFoto,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        foregroundColor: Theme.of(context).primaryColor,
                        side: BorderSide(color: Theme.of(context).primaryColor)
                      ),
                      icon: const Icon(Icons.photo_library),
                      label: const Text("Galería"),
                      onPressed: _isUploading ? null : _elegirDeGaleria,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_isUploading) const Center(child: CircularProgressIndicator()),

              if (_fotosSubidas.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _fotosSubidas.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 10, top: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(_fotosSubidas[index], width: 100, height: 100, fit: BoxFit.cover),
                        ),
                      );
                    },
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text("Ausencia de documentación visual en este expediente.", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                ),

              const Divider(height: 40),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, 
                  minimumSize: const Size.fromHeight(60),
                ),
                icon: const Icon(Icons.check_circle, size: 28),
                label: const Text("Liberar Vehículo (Finalizado)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                onPressed: _marcarComoListo,
              )
            ],
          ),
        ),
      ),
    );
  }
}