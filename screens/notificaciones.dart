import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Centro de mensajes asincronos y alertas del sistema.
/// Incorpora segmentacion de visualizacion filtrada estrictamente por el rol en uso.
class NotificacionesScreen extends StatelessWidget {
  final String currentRol;
  const NotificacionesScreen({super.key, required this.currentRol});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bandeja de Entradas")),
      body: StreamBuilder<QuerySnapshot>(
        // Inyeccion de query compuesta: filtro por destinatario y ordenacion cronologica
        stream: FirebaseFirestore.instance
            .collection('notificaciones')
            .where('rol_destino', isEqualTo: currentRol)
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 80, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                  Text("Bandeja vacía. No existen alertas pendientes.", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              bool leida = data['leida'] ?? false;
              
              // Parsea el Timestamp a objeto logico de fecha
              DateTime? fecha = data['fecha'] != null ? (data['fecha'] as Timestamp).toDate() : null;
              String fechaStr = fecha != null ? "${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}" : "";

              return Card(
                // Diferenciacion visual subtil entre notificaciones pendientes y archivadas
                color: leida ? Theme.of(context).cardTheme.color : Theme.of(context).colorScheme.primary.withOpacity(0.05), 
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: Icon(
                    Icons.notifications_active,
                    color: leida ? Colors.grey : Theme.of(context).colorScheme.secondary,
                  ),
                  title: Text(data['titulo'] ?? 'Sin Asunto', style: TextStyle(fontWeight: leida ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Text("${data['cuerpo'] ?? ''}\n$fechaStr"),
                  isThreeLine: true,
                  onTap: () async {
                    // Marcaje de lectura transaccional al interactuar con el widget
                    if (!leida) {
                      await FirebaseFirestore.instance.collection('notificaciones').doc(doc.id).update({'leida': true});
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}