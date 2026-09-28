import 'package:flutter/material.dart';
import 'home_screen.dart'; // Conecta este archivo con la pantalla del patio

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sprint Wash - Acceso")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              decoration: InputDecoration(labelText: "Usuario", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(labelText: "Contraseña", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Al presionar, navega a la pantalla HomeScreen importada arriba
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HomeScreen()), 
                );
              },
              child: const Text("Ingresar"),
            )
          ],
        ),
      ),
    );
  }
}