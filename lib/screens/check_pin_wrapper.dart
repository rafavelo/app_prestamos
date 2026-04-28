import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'menu_principal.dart';
import 'pantalla_pin.dart';

class CheckPinWrapper extends StatefulWidget {
  const CheckPinWrapper({super.key});
  @override
  State<CheckPinWrapper> createState() => _CheckPinWrapperState();
}

class _CheckPinWrapperState extends State<CheckPinWrapper> {
  bool _verificando = true;
  bool _tienePin = false;
  bool _pinDesbloqueado = false;

  @override
  void initState() {
    super.initState();
    _checkPin();
  }

  Future<void> _checkPin() async {
    final prefs = await SharedPreferences.getInstance();
    String? pin = prefs.getString('user_pin');
    setState(() {
      _tienePin = pin != null;
      _verificando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_verificando) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_tienePin && !_pinDesbloqueado) {
      return PantallaPin(onSuccess: () => setState(() => _pinDesbloqueado = true));
    }
    return const MenuPrincipal();
  }
}
