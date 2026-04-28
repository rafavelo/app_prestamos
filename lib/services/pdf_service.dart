import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/formatters.dart';

class PdfService {
  /// Genera e imprime el reporte de movimientos del periodo indicado.
  /// La construcción del PDF corre en un isolate secundario para no bloquear la UI.
  static Future<void> generarReporteMovimientos({
    required String tituloPeriodo,
    required List<Map<String, dynamic>> movimientos,
    required double stockEnCalle,
    required double stockPorCobrar,
    required double flujoGanancia,
    required double flujoRecuperado,
    required double flujoIngresoTotal,
    required double flujoColocado,
  }) async {
    final bytes = await compute(_buildPdfBytes, {
      'tituloPeriodo': tituloPeriodo,
      'movimientos': movimientos,
      'stockEnCalle': stockEnCalle,
      'stockPorCobrar': stockPorCobrar,
      'flujoGanancia': flujoGanancia,
      'flujoRecuperado': flujoRecuperado,
      'flujoIngresoTotal': flujoIngresoTotal,
      'flujoColocado': flujoColocado,
    });
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<Uint8List> _buildPdfBytes(Map<String, dynamic> args) async {
    final tituloPeriodo = args['tituloPeriodo'] as String;
    final movimientos = args['movimientos'] as List<Map<String, dynamic>>;
    final stockEnCalle = args['stockEnCalle'] as double;
    final stockPorCobrar = args['stockPorCobrar'] as double;
    final flujoGanancia = args['flujoGanancia'] as double;
    final flujoRecuperado = args['flujoRecuperado'] as double;
    final flujoIngresoTotal = args['flujoIngresoTotal'] as double;
    final flujoColocado = args['flujoColocado'] as double;

    final doc = pw.Document();
    final fechaImpresion = DateTime.now();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) => [
        pw.Header(
          level: 0,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Reporte: $tituloPeriodo',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(fechaImpresion),
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        _buildBalanceBox(
          stockEnCalle: stockEnCalle,
          stockPorCobrar: stockPorCobrar,
          flujoGanancia: flujoGanancia,
          flujoRecuperado: flujoRecuperado,
          flujoIngresoTotal: flujoIngresoTotal,
          flujoColocado: flujoColocado,
        ),
        pw.SizedBox(height: 20),
        _buildTablaMovimientos(movimientos),
      ],
    ));

    return doc.save();
  }

  // ── Helpers privados ───────────────────────────────────────────────────────

  static pw.Widget _buildBalanceBox({
    required double stockEnCalle,
    required double stockPorCobrar,
    required double flujoGanancia,
    required double flujoRecuperado,
    required double flujoIngresoTotal,
    required double flujoColocado,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(children: [
        pw.Text("BALANCE DEL PERIODO",
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        pw.Divider(thickness: 0.5),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
          _celda("Capital Invertido", stockEnCalle),
          _celda("Interés por Cobrar", stockPorCobrar, color: PdfColors.orange),
        ]),
        pw.Divider(thickness: 0.5, color: PdfColors.grey300),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
          _celda("Interés Ganado", flujoGanancia, color: PdfColors.green),
          _celda("Ingreso de Capital", flujoRecuperado),
        ]),
        pw.Divider(thickness: 0.5, color: PdfColors.grey300),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
          _celda("Ingreso Total", flujoIngresoTotal, color: PdfColors.cyan),
          _celda("Salida de Capital", flujoColocado, color: PdfColors.red),
        ]),
      ]),
    );
  }

  static pw.Widget _celda(String label, double monto,
      {PdfColor? color}) {
    return pw.Column(children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
      pw.Text("S/. ${moneyFormat.format(monto)}",
          style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
              color: color)),
    ]);
  }

  static pw.Widget _buildTablaMovimientos(
      List<Map<String, dynamic>> movimientos) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
      cellStyle: const pw.TextStyle(fontSize: 8),
      columnWidths: {
        0: const pw.FixedColumnWidth(50),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FixedColumnWidth(65),
        4: const pw.FixedColumnWidth(65),
        5: const pw.FixedColumnWidth(70),
      },
      data: <List<String>>[
        <String>['Fecha', 'Cliente', 'Tipo', 'Capital', 'Interés', 'Restante'],
        ...movimientos.map((m) {
          final f = m['fecha'] as DateTime;
          final cap = m['montoCapital'] as double;
          final inte = m['montoInteres'] as double;
          final restante = (m['montoRestante'] as double?) ?? 0.0;
          final tipo = _tipoMovimiento(m);
          return [
            DateFormat('dd/MM').format(f),
            m['cliente'] as String,
            tipo,
            cap == 0 ? '-' : 'S/. ${moneyFormat.format(cap)}',
            inte == 0 ? '-' : 'S/. ${moneyFormat.format(inte)}',
            restante == 0 ? '-' : 'S/. ${moneyFormat.format(restante)}',
          ];
        }),
      ],
    );
  }

  static String _tipoMovimiento(Map<String, dynamic> m) {
    final cap = m['montoCapital'] as double;
    final inte = m['montoInteres'] as double;
    if (m['esNuevoPrestamo'] == true) return "Préstamo Nuevo";
    if (m['esAmpliacion'] == true) return "Ampliación";
    if (m['esCancelacion'] == true) return "Cancelado";
    if (cap > 0 && inte == 0) return "Amortización";
    if (cap == 0 && inte > 0) return "Solo Interés";
    return "Cap. + Int.";
  }
}
