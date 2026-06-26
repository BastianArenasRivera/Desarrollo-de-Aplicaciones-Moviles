import 'package:flutter/material.dart';

// Clase utilitaria para centralizar la configuracion visual de la aplicacion.
class TemaApp {
  
  // MODO CLARO: Acero y Azul Corporativo
  static ThemeData get temaClaro {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F6FA),
      primaryColor: const Color(0xFF1A365D), // Azul Marino
      
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF1A365D),
        secondary: Color(0xFF2980B9), // Azul Eléctrico
        surface: Colors.white,
        onSurface: Color(0xFF2D3748), // Textos principales
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A365D),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2980B9),
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF2980B9),
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2980B9), width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF1A365D)),
      ),
    );
  }

  // MODO OSCURO: Motor Oscuro (Fondos Asfalto, Acentos Naranjas, Textos Blancos)
  static ThemeData get temaOscuro {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212), // Fondo Negro
      primaryColor: const Color(0xFFD2691E), // Acento Naranja Principal
      
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFD2691E), 
        secondary: Color(0xFFD2691E), // Todo lo que resalta es Naranja
        surface: Color(0xFF1E1E1E), // Tarjetas Gris Oscuro
        onSurface: Colors.white, // Textos blancos
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD2691E), // Naranja Bamajo
          foregroundColor: Colors.white, // Letras blancas sobre boton naranja
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFD2691E),
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD2691E), width: 2), // Borde naranja al enfocar
        ),
        labelStyle: const TextStyle(color: Colors.white), // Labels blancos (Cero gris)
        hintStyle: const TextStyle(color: Colors.white70),
      ),
    );
  }
}