import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  static const Color kRoyalBlue = Color(0xFF1422B8);
  
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _correoCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  
  bool _ocultarPassword = true;
  bool _isLoading = false;

  Future<void> _registrarUsuario() async {
    final nombre = _nombreCtrl.text.trim();
    final correo = _correoCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (nombre.isEmpty || correo.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, llena todos los campos'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await http.post(
        Uri.parse('http://10.0.2.2:8000/finanzas/usuarios'), // IP local de tu emulador
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'rol_id': 3, // Operario / Supervisor por defecto
          'nombre_completo': nombre,
          'correo': correo,
          'password': password,
        }),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Cuenta creada exitosamente!'), backgroundColor: Colors.green),
          );
          // Devolvemos el correo y la contraseña a la pantalla de Login
          Navigator.pop(context, {'correo': correo, 'password': password});
        }
      } else {
        if (mounted) {
          final errorMsg = jsonDecode(res.body)['detail'] ?? 'Error desconocido';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $errorMsg'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión con el servidor'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Crear nueva cuenta',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Regístrate para acceder al panel de SprintWash',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 36),
              
              const Text('Nombre completo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
              const SizedBox(height: 8),
              TextField(
                controller: _nombreCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF6B7280), size: 20),
                  filled: true, fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kRoyalBlue, width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Correo electrónico', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
              const SizedBox(height: 8),
              TextField(
                controller: _correoCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF6B7280), size: 20),
                  filled: true, fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kRoyalBlue, width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Contraseña', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
              const SizedBox(height: 8),
              TextField(
                controller: _passCtrl,
                obscureText: _ocultarPassword,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF6B7280), size: 20),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _ocultarPassword = !_ocultarPassword),
                    icon: Icon(_ocultarPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFF6B7280), size: 20),
                  ),
                  filled: true, fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kRoyalBlue, width: 1.5)),
                ),
              ),
              const SizedBox(height: 32),

              Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: kRoyalBlue.withAlpha(75), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registrarUsuario,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kRoyalBlue, disabledBackgroundColor: kRoyalBlue.withOpacity(0.7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Registrarse', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}