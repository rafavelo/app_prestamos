import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_colors.dart';
import '../core/formatters.dart';
import '../models/prestamo.dart';

class PantallaHistorialIndividual extends StatelessWidget {
  final String nombreCliente;
  const PantallaHistorialIndividual({super.key, required this.nombreCliente});

  static const List<String> _nombresMeses = [
    "", "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
    "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("Expediente: $nombreCliente",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('prestamos')
            .where('usuarioId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Sin datos registrados."));
          }

          double totalGlobalCapital = 0;
          double totalGlobalInteres = 0;
          int totalPrestamos = 0;
          Map<int, Map<int, Map<String, double>>> dataArbol = {};
          Map<int, Map<String, double>> totalesAnio = {};

          for (var doc in snapshot.data!.docs) {
            final p = Prestamo.fromMap(
                doc.data() as Map<String, dynamic>, doc.id);
            if (p.nombre.trim().toUpperCase() ==
                nombreCliente.trim().toUpperCase()) {
              int anio = p.fechaDesembolso.year;
              int mes = p.fechaDesembolso.month;
              double cap = p.montoInicialEstatico ?? p.montoOriginal;
              double intTotal = cap * (p.tasaInteres / 100);

              dataArbol.putIfAbsent(anio, () => {});
              dataArbol[anio]!.putIfAbsent(
                  mes, () => {'capital': 0.0, 'interes': 0.0, 'cantidad': 0.0});
              totalesAnio.putIfAbsent(
                  anio, () => {'capital': 0.0, 'interes': 0.0, 'cantidad': 0.0});

              dataArbol[anio]![mes]!['capital'] =
                  dataArbol[anio]![mes]!['capital']! + cap;
              dataArbol[anio]![mes]!['interes'] =
                  dataArbol[anio]![mes]!['interes']! + intTotal;
              dataArbol[anio]![mes]!['cantidad'] =
                  dataArbol[anio]![mes]!['cantidad']! + 1;

              totalesAnio[anio]!['capital'] =
                  totalesAnio[anio]!['capital']! + cap;
              totalesAnio[anio]!['interes'] =
                  totalesAnio[anio]!['interes']! + intTotal;
              totalesAnio[anio]!['cantidad'] =
                  totalesAnio[anio]!['cantidad']! + 1;

              totalGlobalCapital += cap;
              totalGlobalInteres += intTotal;
              totalPrestamos++;
            }
          }

          if (totalPrestamos == 0) {
            return const Center(
                child: Text("No se encontraron registros de este cliente."));
          }

          List<int> aniosOrdenados = dataArbol.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return Column(children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  child: Text(
                    nombreCliente.isNotEmpty
                        ? nombreCliente[0].toUpperCase()
                        : "?",
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text(nombreCliente,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  Column(children: [
                    const Text("Capital Entregado",
                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Text("S/. ${moneyFormat.format(totalGlobalCapital)}",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                  ]),
                  Container(width: 1, height: 30, color: Colors.white24),
                  Column(children: [
                    const Text("Interés Generado",
                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Text("S/. ${moneyFormat.format(totalGlobalInteres)}",
                        style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                  ]),
                ]),
                const SizedBox(height: 8),
                Text("$totalPrestamos préstamos en total",
                    style: const TextStyle(color: Colors.white30, fontSize: 12)),
              ]),
            ),

            Expanded(
              child: ListView.builder(
                itemCount: aniosOrdenados.length,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                itemBuilder: (ctx, i) {
                  int anio = aniosOrdenados[i];
                  Map<int, Map<String, double>> mesesDeEsteAnio =
                      dataArbol[anio]!;
                  List<int> mesesOrdenados = mesesDeEsteAnio.keys.toList()
                    ..sort((a, b) => b.compareTo(a));
                  double capAnio = totalesAnio[anio]!['capital']!;
                  int cantAnio = totalesAnio[anio]!['cantidad']!.toInt();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                      initiallyExpanded: i == 0,
                      iconColor: AppColors.primary,
                      textColor: AppColors.primary,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(anio.toString().substring(2),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 14)),
                        ),
                      ),
                      title: Text("Año $anio",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Text(
                          "$cantAnio préstamo(s)  ·  S/. ${moneyFormat.format(capAnio)}",
                          style: const TextStyle(fontSize: 12)),
                      children: mesesOrdenados.map((mes) {
                        double capMes = mesesDeEsteAnio[mes]!['capital']!;
                        double intMes = mesesDeEsteAnio[mes]!['interes']!;
                        int cantMes =
                            mesesDeEsteAnio[mes]!['cantidad']!.toInt();
                        return Container(
                          decoration: BoxDecoration(
                              border: Border(
                                  top: BorderSide(
                                      color: Colors.grey.shade100))),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 4),
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: esOscuro
                                  ? AppColors.primary.withOpacity(0.2)
                                  : AppColors.primary.withOpacity(0.08),
                              child: const Icon(Icons.calendar_month_rounded,
                                  size: 16, color: AppColors.primary),
                            ),
                            title: Text(_nombresMeses[mes],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text("$cantMes préstamo(s)",
                                style: const TextStyle(fontSize: 11)),
                            trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("S/. ${moneyFormat.format(capMes)}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  Text(
                                      "Int: S/. ${moneyFormat.format(intMes)}",
                                      style: TextStyle(
                                          color: esOscuro
                                              ? Colors.greenAccent
                                              : AppColors.success,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ]),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}
