import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Acceso denegado: No eres $_rolSeleccionado"), backgroundColor: Colors.red));
        }
      } else {
        if (mounted) {
          Navigator.pop(context); 
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error de credenciales o usuario incorrecto"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  void _mostrarDialogoRecuperacion() {
    final correoRecuperacionCtrl = TextEditingController(text: _emailCtrl.text.trim());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Recuperar Contraseña", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Ingresa tu correo electrónico. Te enviaremos un enlace seguro para crear una nueva contraseña.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: correoRecuperacionCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Tu correo electrónico",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email, color: Color(0xFFD2691E))
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.red))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD2691E)),
            onPressed: () async {
              String correo = correoRecuperacionCtrl.text.trim();
              if (correo.isEmpty || !correo.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ingresa un correo válido"), backgroundColor: Colors.red));
                return;
              }

              try {
                // Comando oficial de Firebase para enviar el correo
                await FirebaseAuth.instance.sendPasswordResetEmail(email: correo);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Correo de recuperación enviado. Revisa tu bandeja."), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Verifica que el correo esté registrado"), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text("Enviar Enlace", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color colorFondoLogo = Color(0xFFF08A00); 

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorFondoLogo,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black), 
      ),
      backgroundColor: colorFondoLogo, 
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                labelStyle: TextStyle(color: Colors.black87),
                floatingLabelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black87, width: 1.5)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2.5)),
                border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
              ),
              textSelectionTheme: const TextSelectionThemeData(cursorColor: Colors.black),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('images/logo.jpg', height: 160, fit: BoxFit.contain),
                const SizedBox(height: 20),
                const Text("Acceso Trabajadores", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)), 
                const SizedBox(height: 30),
                
                DropdownButtonFormField<String>(
                  value: _rolSeleccionado, 
                  dropdownColor: colorFondoLogo, 
                  iconEnabledColor: Colors.black, 
                  style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold), 
                  decoration: const InputDecoration(
                    labelText: "Iniciar sesión como:", 
                    prefixIcon: Icon(Icons.work, color: Colors.black)
                  ),
                  items: ['Jefe', 'Administrador', 'Mecánico'].map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(color: Colors.black)))).toList(),
                  onChanged: (val) => setState(() => _rolSeleccionado = val!),
                ),
                const SizedBox(height: 15),
                
                TextField(
                  controller: _emailCtrl, 
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold), 
                  decoration: const InputDecoration(
                    labelText: "Correo", 
                    prefixIcon: Icon(Icons.email, color: Colors.black)
                  )
                ),
                const SizedBox(height: 15),
                
                TextField(
                  controller: _passCtrl, 
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold), 
                  decoration: InputDecoration(
                    labelText: "Contraseña", 
                    prefixIcon: const Icon(Icons.lock, color: Colors.black),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, color: Colors.black), 
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword)
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                
                _isLoading 
                  ? const CircularProgressIndicator(color: Colors.black) 
                  : ElevatedButton(
                      onPressed: _login, 
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black, 
                        foregroundColor: colorFondoLogo, 
                        minimumSize: const Size.fromHeight(55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ), 
                      child: const Text("Entrar", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
                    ),
                
                const SizedBox(height: 15),
                TextButton(
                  onPressed: _mostrarDialogoRecuperacion, 
                  child: const Text("¿Olvidaste tu contraseña?", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16, decoration: TextDecoration.underline)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
