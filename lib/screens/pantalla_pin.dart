import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_colors.dart';

class PantallaPin extends StatefulWidget {
  final bool esConfiguracion;
  final VoidCallback? onSuccess;
  const PantallaPin({super.key, this.esConfiguracion = false, this.onSuccess});
  @override
  State<PantallaPin> createState() => _PantallaPinState();
}

class _PantallaPinState extends State<PantallaPin> with SingleTickerProviderStateMixin {
  String _pinIngresado = "";
  String? _pinGuardado;
  String _titulo = "Cargando...";
  String _subtitulo = "";
  bool _confirmando = false;
  String _primerIntento = "";
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
    _cargarEstado();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarEstado() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pinGuardado = prefs.getString('user_pin');
      if (widget.esConfiguracion) {
        if (_pinGuardado != null) {
          _titulo = "Ingresa tu PIN actual";
          _subtitulo = "para desactivar la seguridad";
        } else {
          _titulo = "Crea tu PIN";
          _subtitulo = "elige 4 dígitos";
        }
      } else {
        _titulo = "Ingresa tu PIN";
        _subtitulo = "para acceder a la app";
      }
    });
  }

  void _onTecladoTap(String valor) {
    if (_pinIngresado.length < 4) {
      setState(() => _pinIngresado += valor);
      if (_pinIngresado.length == 4) {
        Future.delayed(const Duration(milliseconds: 100), _validarPin);
      }
    }
  }

  void _onBorrar() {
    if (_pinIngresado.isNotEmpty) {
      setState(() => _pinIngresado = _pinIngresado.substring(0, _pinIngresado.length - 1));
    }
  }

  Future<void> _validarPin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!widget.esConfiguracion) {
      if (_pinIngresado == _pinGuardado) {
        if (widget.onSuccess != null) widget.onSuccess!();
      } else {
        _errorFeedback("PIN incorrecto");
      }
      return;
    }
    if (_pinGuardado != null) {
      if (_pinIngresado == _pinGuardado) {
        await prefs.remove('user_pin');
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Seguridad por PIN desactivada"),
            backgroundColor: AppColors.warning,
          ));
        }
      } else {
        _errorFeedback("PIN incorrecto");
      }
      return;
    }
    if (!_confirmando) {
      setState(() {
        _primerIntento = _pinIngresado;
        _pinIngresado = "";
        _titulo = "Confirma tu PIN";
        _subtitulo = "repite los 4 dígitos";
        _confirmando = true;
      });
    } else {
      if (_pinIngresado == _primerIntento) {
        await prefs.setString('user_pin', _pinIngresado);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("✓ PIN de seguridad activado"),
            backgroundColor: AppColors.success,
          ));
        }
      } else {
        _errorFeedback("Los PINs no coinciden. Intenta de nuevo.");
        setState(() {
          _confirmando = false;
          _primerIntento = "";
          _titulo = "Crea tu PIN";
          _subtitulo = "elige 4 dígitos";
        });
      }
    }
  }

  void _errorFeedback(String msg) {
    _shakeCtrl.forward(from: 0);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.danger,
      duration: const Duration(seconds: 2),
    ));
    setState(() => _pinIngresado = "");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(_titulo,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(_subtitulo,
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 36),

          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (context, child) {
              double offset = _shakeCtrl.isAnimating
                  ? (8 * (0.5 - _shakeAnim.value)).abs() * (_shakeAnim.value > 0.5 ? -1 : 1)
                  : 0;
              return Transform.translate(
                offset: Offset(offset * 4, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    bool relleno = index < _pinIngresado.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: relleno ? Colors.white : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    );
                  }),
                ),
              );
            },
          ),

          const SizedBox(height: 50),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: GridView.count(
                crossAxisCount: 3,
                childAspectRatio: 1.4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ...List.generate(9, (i) => _botonNum("${i + 1}")),
                  const SizedBox(),
                  _botonNum("0"),
                  InkWell(
                    onTap: _onBorrar,
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.backspace_rounded,
                            color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (widget.esConfiguracion)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CANCELAR",
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _botonNum(String num) {
    return InkWell(
      onTap: () => _onTecladoTap(num),
      borderRadius: BorderRadius.circular(50),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.1),
        ),
        child: Center(
          child: Text(num,
              style: const TextStyle(
                  fontSize: 32, color: Colors.white, fontWeight: FontWeight.w300)),
        ),
      ),
    );
  }
}
