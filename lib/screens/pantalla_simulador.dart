import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/app_colors.dart';
import '../core/formatters.dart';
import '../models/loan_data.dart';
import '../services/loan_calculator_service.dart';
import '../services/simulador_pdf_service.dart';

class PantallaSimulador extends StatefulWidget {
  const PantallaSimulador({super.key});
  @override
  State<PantallaSimulador> createState() => _PantallaSimuladorState();
}

class _PantallaSimuladorState extends State<PantallaSimulador> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _montoCtrl = TextEditingController(text: '1,000');
  final _tasaCtrl = TextEditingController(text: '15');
  final _plazoCtrl = TextEditingController(text: '1');

  DateTime _fechaDesembolso = DateTime.now();
  bool _isFrenchSystem = false;
  bool _showUniformPayment = false;
  LoanData? _loanData;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _montoCtrl.dispose();
    _tasaCtrl.dispose();
    _plazoCtrl.dispose();
    super.dispose();
  }

  double _parseMonto(String text) =>
      double.parse(text.replaceAll(',', ''));

  Future<void> _calcular() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final loanAmount = _parseMonto(_montoCtrl.text);
      final months = int.parse(_plazoCtrl.text);
      final annualRate = double.parse(_tasaCtrl.text);

      final data = LoanCalculatorService.calculateLoan(
        loanAmount: loanAmount,
        months: months,
        annualRate: annualRate,
        disbursementDate: _fechaDesembolso,
        isFrenchSystem: _isFrenchSystem,
      );

      setState(() => _loanData = data);
      Navigator.of(context, rootNavigator: true).pop();

      await SimuladorPdfService.generateAndShowPDF(
        context: context,
        loanData: data,
        borrowerName: _nombreCtrl.text,
        showUniformPayment: _showUniformPayment,
      );
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<void> _verPdf() async {
    if (_loanData == null) return;
    try {
      await SimuladorPdfService.generateAndShowPDF(
        context: context,
        loanData: _loanData!,
        borrowerName: _nombreCtrl.text,
        showUniformPayment: _showUniformPayment,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error PDF: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Simular Préstamo",
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_loanData != null)
            TextButton.icon(
              onPressed: _verPdf,
              icon: const Icon(Icons.picture_as_pdf_rounded,
                  color: Colors.white, size: 18),
              label: const Text("PDF",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Selector de sistema ────────────────────────────────────────
            _buildSectionLabel("SISTEMA DE CÁLCULO", esOscuro),
            const SizedBox(height: 8),
            _buildSistemaSelector(esOscuro),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                _isFrenchSystem
                    ? 'Cuota fija mensual (Uso en bancos)'
                    : 'Amortización fija (Cuotas decrecientes)',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: esOscuro ? Colors.white38 : Colors.grey.shade500),
              ),
            ),
            const SizedBox(height: 20),

            // ── Datos del préstamo ─────────────────────────────────────────
            _buildSectionLabel("DATOS DEL PRÉSTAMO", esOscuro),
            const SizedBox(height: 10),

            // Nombre (opcional)
            TextFormField(
              controller: _nombreCtrl,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ\s\.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Nombre del solicitante',
                hintText: 'Opcional',
                prefixIcon: Icon(Icons.account_circle_rounded),
              ),
            ),
            const SizedBox(height: 14),

            // Monto
            TextFormField(
              controller: _montoCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Monto a entregar',
                prefixText: 'S/. ',
                suffixIcon: Icon(Icons.attach_money_rounded),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requerido';
                final n = double.tryParse(v.replaceAll(',', ''));
                if (n == null || n <= 0) return 'Ingresa un monto válido';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Tasa + Plazo en fila
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _tasaCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,4}')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Tasa mensual',
                    suffixIcon: Icon(Icons.percent_rounded),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextFormField(
                  controller: _plazoCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Plazo',
                    suffixText: 'meses',
                    suffixIcon: Icon(Icons.access_time_filled_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if ((int.tryParse(v) ?? 0) <= 0) return 'Inválido';
                    return null;
                  },
                ),
              ),
            ]),
            const SizedBox(height: 14),

            // Fecha de desembolso
            _buildDateField(esOscuro),
            const SizedBox(height: 14),

            // Checkbox cuota fija en PDF
            Row(children: [
              Checkbox(
                value: _showUniformPayment,
                activeColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (v) =>
                    setState(() => _showUniformPayment = v ?? false),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () =>
                    setState(() => _showUniformPayment = !_showUniformPayment),
                child: Text(
                  'Mostrar cuota fija en el PDF',
                  style: TextStyle(
                      fontSize: 14,
                      color: esOscuro ? Colors.white70 : Colors.black87),
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // ── Botón CALCULAR ─────────────────────────────────────────────
            Center(
              child: Container(
                width: 200,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _calcular,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    "CALCULAR",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Colors.white),
                  ),
                ),
              ),
            ),

          ]),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text, bool esOscuro) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: esOscuro ? Colors.white38 : Colors.blueGrey.shade400),
    );
  }

  Widget _buildSistemaSelector(bool esOscuro) {
    return Container(
      decoration: BoxDecoration(
        color: esOscuro ? const Color(0xFF1C1C1C) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: esOscuro
              ? Colors.white.withOpacity(0.07)
              : Colors.grey.shade200,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        _buildSistemaTab("Sistema Alemán", !_isFrenchSystem, esOscuro,
            () => setState(() => _isFrenchSystem = false)),
        _buildSistemaTab("Sistema Francés", _isFrenchSystem, esOscuro,
            () => setState(() => _isFrenchSystem = true)),
      ]),
    );
  }

  Widget _buildSistemaTab(
      String label, bool isSelected, bool esOscuro, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (esOscuro ? Colors.white54 : Colors.grey.shade700)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(bool esOscuro) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _fechaDesembolso,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) setState(() => _fechaDesembolso = picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Fecha de desembolso',
          suffixIcon: Icon(Icons.calendar_today_rounded,
              color: esOscuro ? Colors.white54 : Colors.grey.shade500),
        ),
        child: Text(
          DateFormat('dd/MM/yyyy').format(_fechaDesembolso),
          style: TextStyle(
              fontSize: 16,
              color: esOscuro ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

}
