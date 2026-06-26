import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Integracion nativa de modelos fundacionales (LLMs) via API REST.
/// Construye contextos dinamicos con retencion conversacional.
class AsistenteIAScreen extends StatefulWidget {
  const AsistenteIAScreen({super.key});

  @override
  State<AsistenteIAScreen> createState() => _AsistenteIAScreenState();
}

class _AsistenteIAScreenState extends State<AsistenteIAScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  
  final List<Map<String, String>> _mensajes = [];
  bool _isLoading = false;

  final String _apiKey = 'AQ.Ab8RN6KPajbwsHmPKWuM4uIe-N25g8a8T09buJBEklgt6DajLg'; 
  final String _claveMemoria = 'historial_chat_ia_final';

  @override
  void initState() {
    super.initState();
    _cargarHistorialLocal();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Recupera el estado de la interaccion previa desde SharedPreferences.
  Future<void> _cargarHistorialLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historialGuardado = prefs.getString(_claveMemoria);

    if (historialGuardado != null) {
      List<dynamic> decodificado = jsonDecode(historialGuardado);
      setState(() {
        _mensajes.clear();
        for (var item in decodificado) {
          _mensajes.add(Map<String, String>.from(item));
        }
      });
      _hacerScrollAlFinal();
    } else {
      setState(() {
        _mensajes.add({
          'rol': 'ia',
          'texto': '¡Hola! Soy tu asistente mecánico con IA. ¿En qué te puedo asesorar hoy?'
        });
      });
      _guardarHistorialLocal();
    }
  }

  Future<void> _guardarHistorialLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveMemoria, jsonEncode(_mensajes));
  }

  Future<void> _limpiarChat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveMemoria);
    setState(() {
      _mensajes.clear();
      _mensajes.add({'rol': 'ia', 'texto': 'Memoria purgada. ¿Con qué procedemos?'});
    });
    _guardarHistorialLocal();
  }

  /// Ejecuta la transaccion HTTP inyectando la cadena completa de mensajes como Prompt colapsado.
  Future<void> _enviarMensaje() async {
    String textoUsuario = _msgCtrl.text.trim();
    if (textoUsuario.isEmpty) return;

    setState(() {
      _mensajes.add({'rol': 'user', 'texto': textoUsuario});
      _isLoading = true;
      _msgCtrl.clear();
    });
    _hacerScrollAlFinal();
    _guardarHistorialLocal();

    try {
      String contextoCompleto = "Eres un Asistente Mecánico Virtual experto para el software corporativo 'Bamajo Motors'. Proporciona información técnica, breve y asertiva.\n\n--- REGISTRO DE EVENTOS ---\n";
      for (var m in _mensajes) {
        String quien = m['rol'] == 'user' ? "Usuario" : "IA Asistente";
        contextoCompleto += "$quien: ${m['texto']}\n";
      }
      contextoCompleto += "-----------------\nAtiende la última consulta del Usuario.";

      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${_apiKey.trim()}');
      
      bool exito = false;
      int maxIntentos = 3;

      // Mecanismo de resiliencia ante saturacion temporal del servicio externo (Fallback)
      for (int i = 0; i < maxIntentos; i++) {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "contents": [{"parts": [{"text": contextoCompleto}]}]
          }),
        );

        if (!mounted) return; 

        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);
          String respuestaIA = data['candidates'][0]['content']['parts'][0]['text'];
          setState(() {
            _mensajes.add({'rol': 'ia', 'texto': respuestaIA.trim()});
          });
          exito = true;
          break; 
        } else if (response.statusCode == 503) {
          if (i < maxIntentos - 1) {
            debugPrint("Latencia en pasarela IA (503). Retardo aplicado de 2s...");
            await Future.delayed(const Duration(seconds: 2));
          } else {
            throw Exception("503");
          }
        } else {
          throw Exception("Codigo Inesperado ${response.statusCode}: ${response.body}");
        }
      }

      if (!exito) throw Exception("Interrupcion de pasarela supero los intentos maximos.");

    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.toString().contains("503")) {
          _mensajes.add({'rol': 'ia', 'texto': 'Alerta: Intermitencia de conectividad con servidores remotos. Reintente en breves momentos.'});
        } else {
          _mensajes.add({'rol': 'ia', 'texto': 'Error crítico de procesamiento de lenguaje natural. Revise la consola de depuración.'});
        }
      });
      debugPrint("Excepcion HTTP modulo IA: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _hacerScrollAlFinal();
      }
      _guardarHistorialLocal();
    }
  }

  void _hacerScrollAlFinal() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Asistente Copilot"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: "Vaciar buffers locales",
            onPressed: () async {
              bool? confirm = await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Purga de Memoria"),
                  content: const Text("¿Autoriza eliminar la trazabilidad del contexto actual?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
                    ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text("Purga Total", style: TextStyle(color: Colors.white))),
                  ],
                )
              );
              if (confirm == true) _limpiarChat();
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _mensajes.length,
              itemBuilder: (context, index) {
                bool esUsuario = _mensajes[index]['rol'] == 'user';
                return Align(
                  alignment: esUsuario ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      // Aplicacion nativa del color Scheme corporativo
                      color: esUsuario ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.surface,
                      border: esUsuario ? null : Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(15),
                        topRight: const Radius.circular(15),
                        bottomLeft: Radius.circular(esUsuario ? 15 : 0),
                        bottomRight: Radius.circular(esUsuario ? 0 : 15),
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
                      ]
                    ),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    child: Text(
                      _mensajes[index]['texto']!,
                      style: TextStyle(
                        color: esUsuario ? Colors.white : Theme.of(context).colorScheme.onSurface,
                        fontSize: 15
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.secondary)),
                  const SizedBox(width: 10),
                  Text("Procesando inferencia...", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      keyboardType: TextInputType.multiline,
                      minLines: 1, 
                      maxLines: 5, 
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: "Estructura de la consulta...",
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _isLoading ? null : () {
                          FocusScope.of(context).unfocus();
                          _enviarMensaje();
                        },
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}