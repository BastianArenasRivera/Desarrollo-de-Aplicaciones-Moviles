import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override 
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _rolSeleccionado = 'Mecánico';
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      UserCredential uc = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(), 
        password: _passCtrl.text.trim()
      );
      
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uc.user!.uid).get();
      
      if (doc.exists && doc['rol'] != _rolSeleccionado) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Incumplimiento de políticas: Su rol no corresponde a $_rolSeleccionado"), backgroundColor: Colors.red));
        }
      } else {
        if (mounted) {
          Navigator.pop(context); 
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Autenticación fallida. Valide sus credenciales."), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarDialogoRecuperacion() {
    final correoRecuperacionCtrl = TextEditingController(text: _emailCtrl.text.trim());
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("Restauración de Credenciales", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Proporcione la dirección de correo registrada para obtener un token.", style: TextStyle(color: textColor)),
            const SizedBox(height: 15),
            TextField(
              controller: correoRecuperacionCtrl,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: "Correo Electrónico",
                labelStyle: TextStyle(color: textColor),
                prefixIcon: Icon(Icons.email, color: textColor)
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.red))),
          ElevatedButton(
            onPressed: () async {
              String correo = correoRecuperacionCtrl.text.trim();
              if (correo.isEmpty || !correo.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Estructura de correo no válida."), backgroundColor: Colors.red));
                return;
              }

              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: correo);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Token de restauración enviado."), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Inconsistencia en los registros."), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text("Emitir Solicitud"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    // INYECCION DE LOGOS DE LOGIN
    String logoPath = isDark ? 'images/logo_22.png' : 'images/logo_11.png';
    Color textColor = isDark ? Colors.white : Theme.of(context).primaryColor;
    Color iconColor = isDark ? Colors.white : Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Portal Operativo"),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(logoPath, height: 160, fit: BoxFit.contain),
              const SizedBox(height: 20),
              
              Text("Identificación de Personal", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)), 
              const SizedBox(height: 30),
              
              DropdownButtonFormField<String>(
                value: _rolSeleccionado, 
                dropdownColor: Theme.of(context).cardColor,
                style: TextStyle(color: textColor, fontSize: 16),
                decoration: InputDecoration(
                  labelText: "Nivel de Privilegio", 
                  labelStyle: TextStyle(color: textColor),
                  prefixIcon: Icon(Icons.admin_panel_settings, color: iconColor) // Icono mejorado
                ),
                items: ['Jefe', 'Administrador', 'Mecánico'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) => setState(() => _rolSeleccionado = val!),
              ),
              const SizedBox(height: 15),
              
              TextField(
                controller: _emailCtrl, 
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Dirección de Correo", 
                  labelStyle: TextStyle(color: textColor),
                  prefixIcon: Icon(Icons.email, color: iconColor)
                )
              ),
              const SizedBox(height: 15),
              
              TextField(
                controller: _passCtrl, 
                obscureText: _obscurePassword,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Clave Cifrada", 
                  labelStyle: TextStyle(color: textColor),
                  prefixIcon: Icon(Icons.lock, color: iconColor),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: iconColor), 
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword)
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              _isLoading 
                ? CircularProgressIndicator(color: Theme.of(context).colorScheme.secondary) 
                : ElevatedButton(
                    onPressed: _login, 
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(55),
                    ), 
                    child: const Text("Ingresar al Sistema")
                  ),
              
              const SizedBox(height: 15),
              TextButton(
                onPressed: _mostrarDialogoRecuperacion, 
                child: Text("Gestionar credenciales perdidas", style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
              )
            ],
          ),
        ),
      ),
    );
  }
}