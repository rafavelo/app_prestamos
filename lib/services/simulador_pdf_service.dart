import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/loan_data.dart';
import '../services/loan_calculator_service.dart';
import '../screens/pdf_preview_screen.dart';

class SimuladorPdfService {
  static String _formatCurrency(double value) {
    final valueStr = value.toStringAsFixed(2);
    final parts = valueStr.split('.');
    String integerPart = parts[0];
    String decimalPart = parts[1];
    String formatted = '';
    int count = 0;
    for (int i = integerPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) formatted = ',$formatted';
      formatted = integerPart[i] + formatted;
      count++;
    }
    return '$formatted.$decimalPart';
  }

  static Future<void> generateAndShowPDF({
    required BuildContext context,
    required LoanData loanData,
    required String borrowerName,
    required bool showUniformPayment,
  }) async {
    final pdf = _buildPdf(loanData, borrowerName, showUniformPayment);
    final pdfBytes = await pdf.save();
    if (context.mounted) {
      final now = DateTime.now();
      final fecha =
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfBytes: pdfBytes,
            fileName: 'cronograma_$fecha.pdf',
          ),
        ),
      );
    }
  }

  static pw.Document _buildPdf(
      LoanData loanData, String borrowerName, bool showUniformPayment) {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(left: 32, right: 32, bottom: 25, top: 40),
        header: (pw.Context context) {
          if (context.pageNumber > 1) return pw.SizedBox(height: 20);
          return pw.SizedBox();
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10, right: 22),
            child: pw.Text(
              'Pág. ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                'Simulador de Préstamo',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Container(
                width: 491,
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                margin: const pw.EdgeInsets.only(left: 20, bottom: 15),
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                child: pw.Text('Resultados',
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black)),
              ),
            ),
            _buildInfoTable(loanData, borrowerName, showUniformPayment),
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Container(
                width: 491,
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                margin: const pw.EdgeInsets.only(left: 20, bottom: 15),
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                child: pw.Text('Cronograma de Pagos',
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black)),
              ),
            ),
            _buildScheduleTable(loanData, showUniformPayment),
          ];
        },
      ),
    );
    return pdf;
  }

  static pw.Widget _buildInfoTable(
      LoanData loanData, String borrowerName, bool showUniformPayment) {
    return pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(260),
        1: pw.FlexColumnWidth(),
      },
      children: [
        _buildInfoRow('Nombre del Solicitante:',
            borrowerName.isNotEmpty ? borrowerName : 'No especificado', true),
        _buildInfoRow(
            'Préstamo solicitado:', 'S/ ${_formatCurrency(loanData.loanAmount)}'),
        _buildInfoRow('Plazo establecido:',
            '${loanData.months} ${loanData.months == 1 ? "mes" : "meses"}'),
        _buildInfoRow('Tasa de Interés Mensual:',
            '${loanData.monthlyRate.toStringAsFixed(2)} %'),
        if (showUniformPayment)
          _buildInfoRow(
              'Cuota Fija:', 'S/ ${_formatCurrency(loanData.uniformPayment)}'),
        _buildInfoRow('Fecha desembolso:',
            LoanCalculatorService.formatDate(loanData.disbursementDate)),
      ],
    );
  }

  static pw.TableRow _buildInfoRow(String label, String value,
      [bool boldValue = false]) {
    return pw.TableRow(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 50, top: 4, bottom: 4),
        child: pw.Text(label, style: const pw.TextStyle(fontSize: 13)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight:
                      boldValue ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
      ),
    ]);
  }

  static pw.Widget _buildScheduleTable(
      LoanData loanData, bool showUniformPayment) {
    final headers = [
      'Nro',
      'Fecha',
      'Capital S/',
      'Interés S/',
      'Cuota S/',
      if (showUniformPayment) 'C. Fija S/',
      'Saldo S/',
    ];

    final tableData = <List<dynamic>>[];
    for (int i = 0; i < loanData.schedule.length; i++) {
      final row = loanData.schedule[i];
      tableData.add([
        row.number.toString(),
        LoanCalculatorService.formatDate(row.date),
        _formatCurrency(row.amortization),
        (i == 0) ? '' : _formatCurrency(row.interest),
        _formatCurrency(row.payment),
        if (showUniformPayment) _formatCurrency(row.uniformPayment),
        _formatCurrency(row.balance),
      ]);
    }

    final totalStyle =
        pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12);
    tableData.add([
      pw.Text('Total', style: totalStyle),
      pw.Text('-', style: totalStyle),
      pw.Text(_formatCurrency(loanData.totalAmortization), style: totalStyle),
      pw.Text(_formatCurrency(loanData.totalInterest), style: totalStyle),
      pw.Text(_formatCurrency(loanData.totalPayments), style: totalStyle),
      if (showUniformPayment)
        pw.Text(_formatCurrency(loanData.totalUniformPayments), style: totalStyle),
      pw.Text('0.00', style: totalStyle),
    ]);

    Map<int, pw.TableColumnWidth> colWidths = {
      0: const pw.FixedColumnWidth(37),
      1: const pw.FixedColumnWidth(70),
      2: const pw.FixedColumnWidth(80),
      3: const pw.FixedColumnWidth(80),
      4: const pw.FixedColumnWidth(80),
    };
    if (showUniformPayment) {
      colWidths[5] = const pw.FixedColumnWidth(80);
      colWidths[6] = const pw.FixedColumnWidth(80);
    } else {
      colWidths[5] = const pw.FixedColumnWidth(80);
    }

    Map<int, pw.Alignment> alignments = {};
    for (int i = 0; i < headers.length; i++) {
      alignments[i] = pw.Alignment.center;
    }

    return pw.Align(
      alignment: pw.Alignment.topCenter,
      child: pw.TableHelper.fromTextArray(
        context: null,
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        tableWidth: pw.TableWidth.min,
        headerStyle: pw.TextStyle(
            color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.red),
        headerAlignments: alignments,
        headerCount: 1,
        headers: headers,
        data: tableData,
        cellDecoration: (index, data, rowNum) {
          if (rowNum == tableData.length) {
            return const pw.BoxDecoration(color: PdfColors.grey200);
          }
          return const pw.BoxDecoration();
        },
        columnWidths: colWidths,
        cellAlignments: alignments,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        cellStyle: const pw.TextStyle(fontSize: 12),
      ),
    );
  }
}
