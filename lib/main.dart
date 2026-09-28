import 'package:flutter/material.dart';
import 'login_screen.dart'; // Conecta este archivo con la pantalla de login

void main() {
  runApp(const SprintWashApp());
}

class SprintWashApp extends StatelessWidget {
  const SprintWashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sprint Wash',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginScreen(), 
    );
  }
}