import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_colors.dart';
import '../core/formatters.dart';
import '../models/cliente_ranking.dart';
import '../models/prestamo.dart';
import 'pantalla_historial_individual.dart';

class PantallaRankingClientes extends StatefulWidget {
  const PantallaRankingClientes({super.key});
  @override
  State<PantallaRankingClientes> createState() => _PantallaRankingClientesState();
}

class _PantallaRankingClientesState extends State<PantallaRankingClientes> {
  int _mesSeleccionado = DateTime.now().month;
  int _anioSeleccionado = DateTime.now().year;
  bool _buscando = false;
  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _meses = [
    "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
    "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
  ];
  final List<int> _anios = [0, ...List.generate(10, (index) => 2024 + index)];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final Color colorFondoFiltro =
        esOscuro ? const Color(0xFF2A2A3E) : Colors.white;
    final Color colorTextoFiltro = esOscuro ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: _buscando
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Buscar cliente...",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white60),
                ),
                onChanged: (v) => setState(() {}),
              )
            : const Text("Top Clientes",
                style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_buscando ? Icons.close : Icons.search_rounded),
            onPressed: () => setState(() {
              _buscando = !_buscando;
              if (!_buscando) _searchCtrl.clear();
            }),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          color: Theme.of(context).appBarTheme.backgroundColor,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: colorFondoFiltro,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              const Icon(Icons.filter_list_rounded,
                  color: Colors.amber, size: 20),
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
                              )),
                    ],
                    onChanged: (val) => setState(() => _mesSeleccionado = val!),
                  ),
                ),
              ),
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
                            child: Text(
                                anio == 0 ? "Histórico" : anio.toString(),
                                style: TextStyle(color: colorTextoFiltro)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _anioSeleccionado = val!;
                      if (_anioSeleccionado == 0) _mesSeleccionado = 0;
                    });
                  },
                ),
              ),
            ]),
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('prestamos')
                .where('usuarioId', isEqualTo: user?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No hay datos registrados."));
              }

              Map<String, ClienteRanking> rankingMap = {};
              double sumaCapitalGeneral = 0;
              double sumaInteresGeneral = 0;

              for (var doc in snapshot.data!.docs) {
                final p = Prestamo.fromMap(
                    doc.data() as Map<String, dynamic>, doc.id);
                DateTime fecha = p.fechaDesembolso;
                bool pasaFiltroAnio =
                    _anioSeleccionado == 0 || fecha.year == _anioSeleccionado;
                bool pasaFiltroMes =
                    _mesSeleccionado == 0 || fecha.month == _mesSeleccionado;
                if (pasaFiltroAnio && pasaFiltroMes) {
                  String nombreKey = p.nombre.trim().toUpperCase();
                  if (!rankingMap.containsKey(nombreKey)) {
                    rankingMap[nombreKey] =
                        ClienteRanking(nombre: p.nombre.trim());
                  }
                  double capitalPrestado =
                      p.montoInicialEstatico ?? p.montoOriginal;
                  double interesGenerado =
                      capitalPrestado * (p.tasaInteres / 100);
                  rankingMap[nombreKey]!.capitalTotal += capitalPrestado;
                  rankingMap[nombreKey]!.interesTotal += interesGenerado;
                  rankingMap[nombreKey]!.cantidadPrestamos += 1;
                  sumaCapitalGeneral += capitalPrestado;
                  sumaInteresGeneral += interesGenerado;
                }
              }

              List<ClienteRanking> listaRanking = rankingMap.values.toList();
              if (_searchCtrl.text.isNotEmpty) {
                String query = _searchCtrl.text.toLowerCase();
                listaRanking = listaRanking
                    .where((c) => c.nombre.toLowerCase().contains(query))
                    .toList();
              }
              listaRanking
                  .sort((a, b) => b.capitalTotal.compareTo(a.capitalTotal));

              if (listaRanking.isEmpty) {
                return Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(Icons.search_off_rounded,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text("Sin resultados para este período",
                          style: TextStyle(color: Colors.grey.shade500)),
                    ]));
              }

              return Column(children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: esOscuro
                        ? Colors.amber.withOpacity(0.1)
                        : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(children: [
                          const Text("TOTAL CAPITAL",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          Text("S/. ${moneyFormat.format(sumaCapitalGeneral)}",
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87)),
                        ]),
                        Container(
                            width: 1, height: 30, color: Colors.amber.shade200),
                        Column(children: [
                          const Text("TOTAL INTERÉS",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          Text("S/. ${moneyFormat.format(sumaInteresGeneral)}",
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.success)),
                        ]),
                      ]),
                ),

                Expanded(
                  child: ListView.builder(
                    itemCount: listaRanking.length,
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                    itemBuilder: (ctx, i) {
                      final cliente = listaRanking[i];
                      bool esTop1 = i == 0;
                      bool esTop3 = i < 3;

                      return Card(
                        elevation: esTop1 ? 3 : 1,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: esTop1
                                ? Colors.amber
                                : (esTop3
                                    ? Colors.amber.withOpacity(0.3)
                                    : Colors.transparent),
                            width: esTop1 ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => PantallaHistorialIndividual(
                                      nombreCliente: cliente.nombre))),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: esTop1
                                      ? Colors.amber
                                      : (esTop3
                                          ? Colors.amber.withOpacity(0.15)
                                          : (esOscuro
                                              ? AppColors.primary.withOpacity(0.2)
                                              : AppColors.primary.withOpacity(0.08))),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text("#${i + 1}",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: esTop1
                                              ? Colors.white
                                              : AppColors.primary)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(cliente.nombre,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      Text(
                                          "${cliente.cantidadPrestamos} préstamo(s)",
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey)),
                                    ]),
                              ),
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                        "S/. ${moneyFormat.format(cliente.capitalTotal)}",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    Text(
                                        "Int: S/. ${moneyFormat.format(cliente.interesTotal)}",
                                        style: const TextStyle(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                  ]),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
