import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color kRoyalBlue = Color(0xFF1422B8);

  final TextEditingController _emailCtrl =
      TextEditingController(text: 'supervisor@sprintwash.com');
  final TextEditingController _passCtrl =
      TextEditingController(text: '12345678');
  
  bool _ocultarPassword = true;
  bool _isLoading = false; // Controla el estado de carga del botón

  Future<void> _iniciarSesion() async {
    setState(() {
      _isLoading = true;
    });

    final String email = _emailCtrl.text.trim();
    final String password = _passCtrl.text.trim();

    // Ruta hacia tu VPS en Azure (Ajusta '/login' si Erick usó '/token')
    final url = Uri.parse('http://68.211.73.10:8000/login'); 

    try {
      final response = await http.post(
        url,
        // FastAPI usa form-urlencoded para el login estándar de OAuth2
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': email, // FastAPI recibe el correo en el campo 'username'
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Token recibido: ${data["access_token"]}');
        
        // Si el widget sigue montado, navegamos a la pantalla principal
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        // Credenciales incorrectas o error en el servidor
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Correo o contraseña incorrectos'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      // Error de red (VPS caída o falta de internet)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al conectar con el servidor: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _irAlPatio() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // LOGO OFICIAL DE SPRINT WASH
              Center(
                child: Image.asset(
                  'assets/logo.png',
                  height: 155,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'BIENVENIDO DE NUEVO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kRoyalBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 34),

              // Correo electrónico
              const Text(
                'Correo electrónico',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.mail_outline_rounded,
                    color: Color(0xFF6B7280),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kRoyalBlue, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Contraseña
              const Text(
                'Contraseña',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passCtrl,
                obscureText: _ocultarPassword,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFF6B7280),
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _ocultarPassword = !_ocultarPassword);
                    },
                    icon: Icon(
                      _ocultarPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF6B7280),
                      size: 20,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kRoyalBlue, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(
                      color: kRoyalBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Botón Iniciar sesión con indicador de carga
              Container(
                height: 56, // Altura fija para evitar saltos al cargar
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: kRoyalBlue.withAlpha(75),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _iniciarSesion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kRoyalBlue,
                    disabledBackgroundColor: kRoyalBlue.withOpacity(0.7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward_rounded, size: 19),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 70),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '¿Aún no tienes cuenta? ',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: _irAlPatio,
                    child: const Text(
                      'Crear cuenta',
                      style: TextStyle(
                        color: kRoyalBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}