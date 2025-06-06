// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp/core/services/session_service.dart';
import 'package:temp/application/bloc/auth/auth_bloc.dart';
import 'package:temp/application/bloc/auth/auth_event.dart';
import 'package:temp/presentation/screens/auth/login.dart';
import 'package:temp/presentation/screens/home.dart'; // ruta real

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Pequeño delay para mostrar el splash
    await Future.delayed(const Duration(seconds: 2));

    // ¿Hay usuario guardado?
    final isLogged = await SessionService.isLoggedIn();

    if (isLogged) {
      // Sincronizamos el bloc para que toda la app
      // tenga el usuario cargado antes de llegar al Home
      context.read<AuthBloc>().add(LoadCurrentUser());

      _goTo(const HomeScreen());
    } else {
      _goTo(const LoginScreen());
    }
  }

  void _goTo(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---------- LOGO ----------
            Image.asset(
              'assets/logo.png', // recuerda declarar en pubspec.yaml
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 12),
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Cargando sesión…'),
          ],
        ),
      ),
    );
  }
}
