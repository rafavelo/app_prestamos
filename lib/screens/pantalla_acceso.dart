import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_colors.dart';

class PantallaAcceso extends StatefulWidget {
  const PantallaAcceso({super.key});
  @override
  State<PantallaAcceso> createState() => _PantallaAccesoState();
}

class _PantallaAccesoState extends State<PantallaAcceso>
    with SingleTickerProviderStateMixin {
  bool _esRegistro = false;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _ocultarPassword = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _procesarAcceso() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Completa todos los campos"),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    setState(() => _isLoading = true);
    try {
      UserCredential cred;
      if (_esRegistro) {
        cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
        await FirebaseFirestore.instance
            .collection('config_usuarios')
            .doc(cred.user!.uid)
            .set({
          'email': _emailCtrl.text.trim(),
          'rol': 'user',
          'estaBloqueado': false,
          'fechaVencimiento': DateTime.now().add(const Duration(days: 30)),
          'fechaRegistro': DateTime.now(),
        });
      } else {
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
      }
      final docConfig = await FirebaseFirestore.instance
          .collection('config_usuarios')
          .doc(cred.user!.uid)
          .get();
      if (docConfig.exists) {
        final data = docConfig.data()!;
        bool bloqueado = data['estaBloqueado'] ?? false;
        Timestamp? vencimientoTs = data['fechaVencimiento'];
        DateTime vencimiento = vencimientoTs?.toDate() ?? DateTime.now();
        if (bloqueado) {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("⛔ CUENTA BLOQUEADA — Contacta al administrador"),
              backgroundColor: AppColors.danger,
            ));
          }
          setState(() => _isLoading = false);
          return;
        }
        String rol = data['rol'] ?? 'user';
        if (rol != 'admin' && DateTime.now().isAfter(vencimiento)) {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("📅 LICENCIA CADUCADA — Renueva tu suscripción"),
              backgroundColor: AppColors.warning,
            ));
          }
          setState(() => _isLoading = false);
          return;
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error: ${e.message}"),
          backgroundColor: AppColors.danger,
        ));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _recuperarContrasena() async {
    if (_emailCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Escribe tu correo primero"),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _emailCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Correo de recuperación enviado ✓"),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Error al enviar el correo"),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDark, AppColors.primary, AppColors.accent],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _esRegistro ? Icons.person_add_rounded : Icons.account_balance_rounded,
                        size: 42,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _esRegistro ? "Crear Cuenta" : "Gestor de Préstamos",
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _esRegistro ? "Regístrate para comenzar" : "Inicia sesión para continuar",
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo Electrónico',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passCtrl,
                            obscureText: _ocultarPassword,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_ocultarPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () =>
                                    setState(() => _ocultarPassword = !_ocultarPassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_isLoading)
                            const CircularProgressIndicator()
                          else
                            ElevatedButton(
                              onPressed: _procesarAcceso,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 52),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(
                                _esRegistro ? "CREAR CUENTA" : "INICIAR SESIÓN",
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (!_esRegistro)
                            TextButton(
                              onPressed: _recuperarContrasena,
                              child: const Text("¿Olvidaste tu contraseña?",
                                  style: TextStyle(color: AppColors.danger)),
                            ),
                          TextButton(
                            onPressed: () {
                              _animCtrl.reset();
                              setState(() => _esRegistro = !_esRegistro);
                              _animCtrl.forward();
                            },
                            child: Text(
                              _esRegistro
                                  ? "¿Ya tienes cuenta? Inicia sesión"
                                  : "¿Nuevo aquí? Regístrate",
                              style: const TextStyle(color: AppColors.primary),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
