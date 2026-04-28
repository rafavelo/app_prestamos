import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../core/app_colors.dart';
import '../core/formatters.dart';
import '../models/prestamo.dart';
import '../widgets/resumen_item.dart';

class FormularioPrestamo extends StatefulWidget {
  final Prestamo? prestamoExistente;
  const FormularioPrestamo({super.key, this.prestamoExistente});
  @override
  State<FormularioPrestamo> createState() => _FormularioPrestamoState();
}

class _FormularioPrestamoState extends State<FormularioPrestamo> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _montoCtrl;
  late TextEditingController _plazoCtrl;
  late TextEditingController _tasaCtrl;
  DateTime _fechaSeleccionada = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl =
        TextEditingController(text: widget.prestamoExistente?.nombre ?? '');
    _telefonoCtrl =
        TextEditingController(text: widget.prestamoExistente?.telefono ?? '');
    String montoInicial = '';
    if (widget.prestamoExistente != null) {
      montoInicial = moneyFormat.format(widget.prestamoExistente!.montoOriginal);
    }
    _montoCtrl = TextEditingController(text: montoInicial);
    _plazoCtrl = TextEditingController(
        text: widget.prestamoExistente?.plazoDias.toString() ?? '30');
    _tasaCtrl = TextEditingController(
        text: widget.prestamoExistente?.tasaInteres.toString() ?? '15');
    if (widget.prestamoExistente != null) {
      _fechaSeleccionada = widget.prestamoExistente!.fechaDesembolso;
    }
  }

  Future<void> _guardar() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      String montoLimpio = _montoCtrl.text.replaceAll(',', '');
      double montoFinal = double.parse(montoLimpio);
      final nuevoPrestamo = Prestamo(
        id: widget.prestamoExistente?.id ?? '',
        usuarioId: user.uid,
        nombre: _nombreCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
        montoOriginal: montoFinal,
        montoInicialEstatico:
            widget.prestamoExistente?.montoInicialEstatico ?? montoFinal,
        montoPagadoCapital: widget.prestamoExistente?.montoPagadoCapital ?? 0.0,
        interesCobradoAcumulado:
            widget.prestamoExistente?.interesCobradoAcumulado ?? 0.0,
        estaCancelado: widget.prestamoExistente?.estaCancelado ?? false,
        fechaCancelacion: widget.prestamoExistente?.fechaCancelacion,
        plazoDias: int.parse(_plazoCtrl.text),
        tasaInteres: double.parse(_tasaCtrl.text),
        fechaDesembolso: _fechaSeleccionada,
        fechaCreacion: widget.prestamoExistente?.fechaCreacion ?? DateTime.now(),
        pagos: widget.prestamoExistente?.pagos ?? [],
      );
      final collection = FirebaseFirestore.instance.collection('prestamos');
      if (widget.prestamoExistente != null) {
        await collection.doc(widget.prestamoExistente!.id).update(nuevoPrestamo.toMap());
      } else {
        await collection.add(nuevoPrestamo.toMap());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ Guardado correctamente'),
          backgroundColor: AppColors.success,
        ));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.prestamoExistente == null ? 'Nuevo Préstamo' : 'Editar Préstamo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(children: [
            _buildSectionHeader("Datos del Cliente", Icons.person_rounded),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre Completo',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'El nombre es requerido';
                if (v.trim().length < 3) return 'Mínimo 3 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono WhatsApp (Opcional)',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: 'Ej: 987654321',
              ),
              validator: (v) {
                if (v != null && v.isNotEmpty) {
                  final soloNumeros = v.replaceAll(RegExp(r'[^0-9]'), '');
                  if (soloNumeros.length < 7) return 'Número inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildSectionHeader("Condiciones del Préstamo", Icons.monetization_on_rounded),
            const SizedBox(height: 12),
            TextFormField(
              controller: _montoCtrl,
              inputFormatters: [CurrencyInputFormatter()],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto a Entregar',
                prefixIcon: Icon(Icons.attach_money_rounded),
                prefixText: 'S/. ',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'El monto es requerido';
                final limpio = v.replaceAll(',', '');
                final monto = double.tryParse(limpio) ?? 0;
                if (monto <= 0) return 'El monto debe ser mayor a 0';
                return null;
              },
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _plazoCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Plazo (Días)',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    final dias = int.tryParse(v) ?? 0;
                    if (dias <= 0) return 'Mínimo 1 día';
                    if (dias > 3650) return 'Máximo 10 años';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextFormField(
                  controller: _tasaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Tasa Interés',
                    prefixIcon: Icon(Icons.percent_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    final tasa = double.tryParse(v) ?? -1;
                    if (tasa < 0 || tasa > 100) return '0% - 100%';
                    return null;
                  },
                ),
              ),
            ]),
            const SizedBox(height: 14),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fechaSeleccionada,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _fechaSeleccionada = picked);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(
                  color: esOscuro ? const Color(0xFF2A2A3E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: esOscuro ? Colors.white12 : Colors.grey.shade300),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded,
                      color: esOscuro ? Colors.white54 : Colors.grey.shade600, size: 20),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("Fecha de Desembolso",
                        style: TextStyle(
                            fontSize: 12,
                            color: esOscuro ? Colors.white54 : Colors.grey.shade600)),
                    Text(DateFormat('dd/MM/yyyy').format(_fechaSeleccionada),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  ]),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down_rounded,
                      color: esOscuro ? Colors.white54 : Colors.grey.shade600),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            _buildResumenEstimado(esOscuro),
            const SizedBox(height: 20),
            if (_isSaving)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                onPressed: _guardar,
                icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                label: const Text('GUARDAR EN LA NUBE',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: AppColors.primary.withOpacity(0.3))),
    ]);
  }

  Widget _buildResumenEstimado(bool esOscuro) {
    return StatefulBuilder(builder: (ctx, setStateLocal) {
      String montoLimpio = _montoCtrl.text.replaceAll(',', '');
      double m = double.tryParse(montoLimpio) ?? 0;
      double t = double.tryParse(_tasaCtrl.text) ?? 0;
      double interes = m * (t / 100);
      double total = m + interes;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: esOscuro
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Column(children: [
          const Text("Resumen Estimado",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            ResumenItem("Capital", "S/. ${moneyFormat.format(m)}", Colors.grey),
            ResumenItem("Interés", "S/. ${moneyFormat.format(interes)}", AppColors.warning),
            ResumenItem("Total", "S/. ${moneyFormat.format(total)}", AppColors.success),
          ]),
        ]),
      );
    });
  }
}
