import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../core/app_colors.dart';
import '../core/formatters.dart';
import '../models/prestamo.dart';
import '../services/pdf_service.dart';

class PantallaHistorial extends StatefulWidget {
  const PantallaHistorial({super.key});
  @override
  State<PantallaHistorial> createState() => _PantallaHistorialState();
}

class _PantallaHistorialState extends State<PantallaHistorial> {
  int _mesSeleccionado = DateTime.now().month;
  int _anioSeleccionado = DateTime.now().year;
  bool _buscando = false;
  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _meses = [
    "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
    "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
  ];
  final List<int> _anios = List.generate(10, (index) => 2024 + index);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _generarPDFMovimientos(
    List<Map<String, dynamic>> movimientos,
    double stockEnCalle,
    double stockPorCobrar,
    double flujoGanancia,
    double flujoRecuperado,
    double flujoIngresoTotal,
    double flujoColocado,
  ) async {
    final tituloPeriodo = _mesSeleccionado == 0
        ? "Año $_anioSeleccionado"
        : "${_meses[_mesSeleccionado - 1]} $_anioSeleccionado";

    await PdfService.generarReporteMovimientos(
      tituloPeriodo: tituloPeriodo,
      movimientos: movimientos,
      stockEnCalle: stockEnCalle,
      stockPorCobrar: stockPorCobrar,
      flujoGanancia: flujoGanancia,
      flujoRecuperado: flujoRecuperado,
      flujoIngresoTotal: flujoIngresoTotal,
      flujoColocado: flujoColocado,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final colorBarra =
        Theme.of(context).appBarTheme.backgroundColor ?? AppColors.primary;
    final Color colorFondoFiltro =
        esOscuro ? const Color(0xFF2A2A3E) : Colors.white;
    final Color colorTextoFiltro = esOscuro ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: _buscando
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(
                    color: Theme.of(context).textTheme.titleLarge?.color),
                decoration: const InputDecoration(
                    hintText: "Buscar cliente...", border: InputBorder.none),
                onChanged: (v) => setState(() {}),
              )
            : const Text("Movimientos y Balance",
                style: TextStyle(fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(
            color: _buscando ? Theme.of(context).iconTheme.color : Colors.white),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: Icon(_buscando ? Icons.close : Icons.search_rounded),
            color: _buscando ? Theme.of(context).iconTheme.color : Colors.white,
            onPressed: () => setState(() {
              _buscando = !_buscando;
              if (!_buscando) _searchCtrl.clear();
            }),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('prestamos')
            .where('usuarioId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final todosLosPrestamos = snapshot.data!.docs
              .map((d) => Prestamo.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();

          DateTime fechaInicioPeriodo;
          DateTime fechaFinPeriodo;
          if (_mesSeleccionado == 0) {
            fechaInicioPeriodo = DateTime(_anioSeleccionado, 1, 1);
            fechaFinPeriodo = DateTime(_anioSeleccionado, 12, 31, 23, 59, 59);
          } else {
            fechaInicioPeriodo = DateTime(_anioSeleccionado, _mesSeleccionado, 1);
            int ultimoDia =
                DateTime(_anioSeleccionado, _mesSeleccionado + 1, 0).day;
            fechaFinPeriodo = DateTime(
                _anioSeleccionado, _mesSeleccionado, ultimoDia, 23, 59, 59);
          }

          double flujoGanancia = 0;
          double flujoRecuperado = 0;
          double flujoColocado = 0;
          double stockEnCalle = 0;
          double stockPorCobrar = 0;
          List<Map<String, dynamic>> movimientosVisibles = [];

          for (var p in todosLosPrestamos) {
            double actualRestante = p.estaCancelado ? 0 : p.montoLiquidarFull;
            if (p.fechaCreacion.isAfter(
                    fechaInicioPeriodo.subtract(const Duration(seconds: 1))) &&
                p.fechaCreacion.isBefore(
                    fechaFinPeriodo.add(const Duration(seconds: 1)))) {
              double montoInicial = p.montoInicialEstatico ?? p.montoOriginal;
              flujoColocado += montoInicial;
              movimientosVisibles.add({
                'fecha': p.fechaDesembolso,
                'cliente': p.nombre,
                'montoCapital': -montoInicial,
                'montoInteres': 0.0,
                'montoRestante': actualRestante,
                'esAmpliacion': false,
                'esNuevoPrestamo': true,
                'esCancelacion': false,
              });
            }

            List pagosOrdenados = List.from(p.pagos);
            pagosOrdenados.sort((a, b) => a.fecha.compareTo(b.fecha));
            for (int i = 0; i < pagosOrdenados.length; i++) {
              var pago = pagosOrdenados[i];
              bool esUltimoPago = (i == pagosOrdenados.length - 1);
              bool esCancelacion = p.estaCancelado && esUltimoPago;
              bool enPeriodo = pago.fecha.year == _anioSeleccionado &&
                  (_mesSeleccionado == 0 || pago.fecha.month == _mesSeleccionado);
              if (enPeriodo) {
                flujoGanancia += pago.montoInteres;
                if (pago.montoCapital > 0) {
                  flujoRecuperado += pago.montoCapital;
                } else {
                  flujoColocado += pago.montoCapital.abs();
                }
                movimientosVisibles.add({
                  'fecha': pago.fecha,
                  'cliente': p.nombre,
                  'montoCapital': pago.montoCapital,
                  'montoInteres': pago.montoInteres,
                  'montoRestante': actualRestante,
                  'esAmpliacion': pago.montoCapital < 0,
                  'esNuevoPrestamo': false,
                  'esCancelacion': esCancelacion,
                });
              }
            }

            if (p.fechaCreacion.isAfter(fechaFinPeriodo)) continue;
            double saldoAFecha = p.montoInicialEstatico ?? p.montoOriginal;
            for (var pago in p.pagos) {
              if (pago.fecha.isBefore(fechaFinPeriodo) ||
                  pago.fecha.isAtSameMomentAs(fechaFinPeriodo)) {
                saldoAFecha -= pago.montoCapital;
              }
            }
            if (saldoAFecha > 0.01) {
              stockEnCalle += saldoAFecha;
              stockPorCobrar += saldoAFecha * (p.tasaInteres / 100);
            }
          }

          movimientosVisibles
              .sort((a, b) => (b['fecha'] as DateTime).compareTo(a['fecha'] as DateTime));

          if (_searchCtrl.text.isNotEmpty) {
            String query = _searchCtrl.text.toLowerCase();
            movimientosVisibles = movimientosVisibles
                .where((m) => m['cliente'].toString().toLowerCase().contains(query))
                .toList();
          }

          double flujoIngresoTotal = flujoGanancia + flujoRecuperado;

          return Column(children: [
            Container(
              color: colorBarra,
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
              child: Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorFondoFiltro,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_month_rounded,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _mesSeleccionado,
                            isExpanded: true,
                            dropdownColor: colorFondoFiltro,
                            style: TextStyle(
                                color: colorTextoFiltro,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                            items: [
                              DropdownMenuItem(
                                  value: 0,
                                  child: Text("Todo el Año",
                                      style: TextStyle(color: colorTextoFiltro))),
                              ...List.generate(
                                12,
                                (index) => DropdownMenuItem(
                                  value: index + 1,
                                  child: Text(_meses[index],
                                      style: TextStyle(color: colorTextoFiltro)),
                                ),
                              ),
                            ],
                            onChanged: (val) =>
                                setState(() => _mesSeleccionado = val!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 20, color: Colors.grey.shade300),
                      const SizedBox(width: 8),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _anioSeleccionado,
                          dropdownColor: colorFondoFiltro,
                          style: TextStyle(
                              color: colorTextoFiltro,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                          items: _anios
                              .map((anio) => DropdownMenuItem(
                                    value: anio,
                                    child: Text(anio.toString(),
                                        style: TextStyle(color: colorTextoFiltro)),
                                  ))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _anioSeleccionado = val!),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: colorFondoFiltro,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.print_rounded, color: AppColors.primary),
                    tooltip: "Imprimir Reporte PDF",
                    onPressed: movimientosVisibles.isEmpty
                        ? null
                        : () => _generarPDFMovimientos(
                              movimientosVisibles,
                              stockEnCalle,
                              stockPorCobrar,
                              flujoGanancia,
                              flujoRecuperado,
                              flujoIngresoTotal,
                              flujoColocado,
                            ),
                  ),
                ),
              ]),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(children: [
                  const SizedBox(height: 14),

                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF09377C),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(children: [
                      const Text("BALANCE DEL PERIODO",
                          style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              letterSpacing: 2,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: _datoResumen("Capital al Cierre",
                                stockEnCalle, Colors.white)),
                        Container(width: 1, height: 36, color: Colors.white12),
                        Expanded(
                            child: _datoResumen("Int. por Cobrar",
                                stockPorCobrar, Colors.orangeAccent)),
                      ]),
                      const SizedBox(height: 10),
                      Container(height: 1, color: Colors.white12),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: _datoResumen(
                                "Interés Ganado", flujoGanancia, Colors.greenAccent)),
                        Container(width: 1, height: 36, color: Colors.white12),
                        Expanded(
                            child: _datoResumen("Ingreso de Capital",
                                flujoRecuperado, Colors.white)),
                      ]),
                      const SizedBox(height: 10),
                      Container(height: 1, color: Colors.white12),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: _datoResumen(
                                "Ingreso Total", flujoIngresoTotal, Colors.cyanAccent)),
                        Container(width: 1, height: 36, color: Colors.white12),
                        Expanded(
                            child: _datoResumen(
                                "Salida de Capital", flujoColocado, Colors.redAccent)),
                      ]),
                    ]),
                  ),

                  const SizedBox(height: 20),

                  if (movimientosVisibles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Column(children: [
                        Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text("Sin movimientos en este periodo",
                            style: TextStyle(color: Colors.grey.shade500)),
                      ]),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                      child: Row(children: [
                        const Icon(Icons.list_alt_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 6),
                        Text("${movimientosVisibles.length} Movimientos",
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary)),
                      ]),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: movimientosVisibles.length,
                      itemBuilder: (ctx, i) =>
                          _buildMovementCard(movimientosVisibles[i]),
                    ),
                  ],
                  const SizedBox(height: 30),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _datoResumen(String label, double monto, Color color) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      const SizedBox(height: 4),
      Text("S/. ${moneyFormat.format(monto)}",
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 17)),
    ]);
  }

  Widget _buildMovementCard(Map<String, dynamic> mov) {
    DateTime fecha = mov['fecha'];
    String cliente = mov['cliente'];
    double capital = mov['montoCapital'];
    double interes = mov['montoInteres'];
    bool esAmpliacion = mov['esAmpliacion'];
    bool esNuevoPrestamo = mov['esNuevoPrestamo'] ?? false;
    bool esCancelacion = mov['esCancelacion'] ?? false;

    String titulo;
    Color colorBorde;
    IconData icono;
    Color colorIcono;

    if (esNuevoPrestamo) {
      titulo = "Nuevo Préstamo";
      colorBorde = AppColors.danger;
      icono = Icons.account_balance_wallet_rounded;
      colorIcono = AppColors.danger;
    } else if (esAmpliacion) {
      titulo = "Ampliación Capital";
      colorBorde = AppColors.warning;
      icono = Icons.add_business_rounded;
      colorIcono = AppColors.warning;
    } else if (esCancelacion) {
      titulo = "Cuenta Cancelada";
      colorBorde = const Color(0xFF1B5E20);
      icono = Icons.check_circle_rounded;
      colorIcono = const Color(0xFF1B5E20);
    } else if (capital > 0 && interes > 0) {
      titulo = "Pago Cap. + Interés";
      colorBorde = AppColors.success;
      icono = Icons.payments_rounded;
      colorIcono = AppColors.success;
    } else if (capital > 0) {
      titulo = "Amortización";
      colorBorde = Colors.blue;
      icono = Icons.savings_rounded;
      colorIcono = Colors.blue;
    } else {
      titulo = "Pago de Interés";
      colorBorde = AppColors.teal;
      icono = Icons.attach_money_rounded;
      colorIcono = AppColors.teal;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorBorde.withOpacity(0.4), width: 1.2),
      ),
      child: Row(children: [
        Column(children: [
          Text(DateFormat('dd').format(fecha),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(DateFormat('MMM').format(fecha).toUpperCase(),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cliente,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              Icon(icono, size: 14, color: colorIcono),
              const SizedBox(width: 4),
              Text(titulo,
                  style: TextStyle(
                      fontSize: 12,
                      color: colorIcono,
                      fontWeight: FontWeight.w500)),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (esNuevoPrestamo || esAmpliacion)
            Text("S/. ${moneyFormat.format(capital.abs())}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.danger)),
          if (!esNuevoPrestamo && !esAmpliacion && capital > 0)
            Text("+${moneyFormat.format(capital)}",
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600)),
          if (interes > 0)
            Text("S/. ${moneyFormat.format(interes)}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.success)),
        ]),
      ]),
    );
  }
}
