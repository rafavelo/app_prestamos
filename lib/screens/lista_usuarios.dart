import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../core/app_colors.dart';
import '../core/formatters.dart';
import '../models/pago.dart';
import '../models/prestamo.dart';
import '../services/prestamo_service.dart';
import 'formulario_prestamo.dart';

class ListaUsuarios extends StatefulWidget {
  final bool modoEdicion;
  final bool modoEliminar;
  const ListaUsuarios({super.key, this.modoEdicion = false, this.modoEliminar = false});
  @override
  State<ListaUsuarios> createState() => _ListaUsuariosState();
}

class _ListaUsuariosState extends State<ListaUsuarios> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filtroActual = "Todos";
  bool _buscando = false;
  bool _mostrarBalance = true;
  late Stream<List<Prestamo>> _streamPrestamos;
  int _itemsVisibles = 20;
  static const int _pagSize = 20;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _streamPrestamos = PrestamoService.streamPrestamos(uid);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _eliminar(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmar Eliminación"),
        content: const Text("¿Eliminar este préstamo permanentemente?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              PrestamoService.eliminar(id);
            },
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminacion(Prestamo p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmar Eliminación"),
        content: Text(
            "¿Eliminar el préstamo de ${p.nombre}?\n\nEsto borrará todo su historial de pagos."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              PrestamoService.eliminar(p.id);
            },
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
  }

  void _confirmarRevertirPago(Prestamo p, Pago pago) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ Deshacer Movimiento"),
        content: const Text(
            "¿Revertir este último movimiento?\n\nSe restaurarán los montos y fechas al estado anterior."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await PrestamoService.revertirPago(p, pago);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Movimiento revertido correctamente"),
                  backgroundColor: AppColors.warning,
                ));
              }
            },
            child: const Text("Sí, Revertir"),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirWhatsApp(Prestamo p) async {
    String numero = p.telefono ?? "";
    numero = numero.replaceAll(RegExp(r'[^0-9]'), '');
    if (numero.length == 9) numero = "51$numero";
    String estado = p.diasTranscurridos > p.plazoDias ? "vencido" : "pendiente";
    String mensaje =
        "Hola ${p.nombre.split(' ')[0]}, te recordamos que tienes un saldo $estado de S/. ${moneyFormat.format(p.montoLiquidarFull)}. ¡Saludos!";
    final url =
        Uri.parse("https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("No se pudo abrir WhatsApp"),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<List<Prestamo>>(
      stream: _streamPrestamos,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: Center(child: Text("Error: ${snapshot.error}")),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final listaCompleta = List<Prestamo>.from(snapshot.data ?? [])
          ..sort((a, b) => a.fechaDesembolso.compareTo(b.fechaDesembolso));

        double saldoCalle = 0;
        double interesPendiente = 0;
        double totalGananciaMes = 0;
        double totalRecuperadoMes = 0;
        int usuariosActivos = 0;
        DateTime ahora = DateTime.now();
        for (var p in listaCompleta) {
          for (var pago in p.pagos) {
            if (pago.fecha.month == ahora.month && pago.fecha.year == ahora.year) {
              totalGananciaMes += pago.montoInteres;
              if (pago.montoCapital > 0) totalRecuperadoMes += pago.montoCapital;
            }
          }
          if (!p.estaCancelado) {
            saldoCalle += p.saldoCapital;
            interesPendiente += p.interesPendienteTotal;
            usuariosActivos++;
          }
        }

        List<Prestamo> listaFiltrada = List.from(listaCompleta);
        if (_searchCtrl.text.isNotEmpty) {
          listaFiltrada = listaFiltrada
              .where((p) =>
                  p.nombre.toLowerCase().contains(_searchCtrl.text.toLowerCase()))
              .toList();
        }
        if (_filtroActual == "Cancelados") {
          listaFiltrada = listaFiltrada.where((p) => p.estaCancelado).toList();
        } else if (_filtroActual == "Vencidos") {
          listaFiltrada = listaFiltrada
              .where((p) => !p.estaCancelado && p.diasTranscurridos > p.plazoDias)
              .toList();
        } else if (_filtroActual == "Activos") {
          listaFiltrada = listaFiltrada
              .where((p) => !p.estaCancelado && p.diasTranscurridos <= p.plazoDias)
              .toList();
        } else if (!widget.modoEliminar) {
          listaFiltrada = listaFiltrada.where((p) => !p.estaCancelado).toList();
        }

        bool soloVer = !widget.modoEdicion && !widget.modoEliminar;

        int totalVencidos =
            listaCompleta.where((p) => !p.estaCancelado && p.diasTranscurridos > p.plazoDias).length;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: _buscando ? Theme.of(context).cardColor : null,
            iconTheme: IconThemeData(
                color: _buscando ? Theme.of(context).iconTheme.color : Colors.white),
            title: _buscando
                ? TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                    decoration: const InputDecoration(
                      hintText: "Buscar cliente...",
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => setState(() => _itemsVisibles = _pagSize),
                  )
                : Text(
                    widget.modoEliminar
                        ? 'Eliminar Préstamo'
                        : (widget.modoEdicion ? 'Editar Préstamo' : 'Ver y Cobrar'),
                    style: const TextStyle(color: Colors.white),
                  ),
            actions: [
              IconButton(
                icon: Icon(_buscando ? Icons.close : Icons.search_rounded),
                tooltip: _buscando ? "Cerrar" : "Buscar",
                onPressed: () => setState(() {
                  _buscando = !_buscando;
                  if (!_buscando) _searchCtrl.clear();
                }),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(children: [
            if (soloVer) ...[
              if (!_buscando)
                _buildBalancePanel(
                  esOscuro,
                  saldoCalle,
                  interesPendiente,
                  totalGananciaMes,
                  totalRecuperadoMes,
                  usuariosActivos,
                ),
              Container(
                color: esOscuro ? Colors.black : Theme.of(context).cardColor,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _buildFilterChip("Todos", AppColors.primary),
                    _buildFilterChip("Activos", AppColors.success),
                    _buildFilterChip(
                        "Vencidos${totalVencidos > 0 ? ' · $totalVencidos' : ''}",
                        AppColors.danger,
                        filtroKey: "Vencidos"),
                    _buildFilterChip("Cancelados", Colors.grey),
                  ]),
                ),
              ),
            ],
            Expanded(
              child: listaFiltrada.isEmpty
                  ? _buildEmptyState()
                  : _buildListaPaginada(listaFiltrada),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildListaPaginada(List<Prestamo> lista) {
    final visibles = lista.take(_itemsVisibles).toList();
    final hayMas = lista.length > _itemsVisibles;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: visibles.length + (hayMas ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == visibles.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton.icon(
              icon: const Icon(Icons.expand_more_rounded),
              label: Text(
                  "Cargar más (${lista.length - _itemsVisibles} restantes)"),
              onPressed: () =>
                  setState(() => _itemsVisibles += _pagSize),
            ),
          );
        }
        return _construirTarjeta(visibles[i]);
      },
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 32, bottom: 20),
        child: Column(children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text("Sin resultados",
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          Text("Prueba con otro filtro o nombre",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ]),
      ),
    );
  }

  Widget _buildBalancePanel(
    bool esOscuro,
    double saldoCalle,
    double interesPendiente,
    double totalGananciaMes,
    double totalRecuperadoMes,
    int usuariosActivos,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: esOscuro ? Colors.black : Theme.of(context).cardColor,
      child: Column(children: [
        // ── Header ────────────────────────────────────────────────────────
        InkWell(
          onTap: () => setState(() => _mostrarBalance = !_mostrarBalance),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: AppColors.primary, size: 19),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Balance Financiero",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text("$usuariosActivos préstamos activos",
                    style: TextStyle(
                        fontSize: 11,
                        color: esOscuro
                            ? Colors.white38
                            : Colors.grey.shade500)),
              ]),
              const Spacer(),
              // KPI rápido: total expuesto
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  "S/. ${moneyFormat.format(saldoCalle + interesPendiente)}",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: esOscuro ? Colors.white : AppColors.primary),
                ),
                Text("total por cobrar",
                    style: TextStyle(
                        fontSize: 10,
                        color: esOscuro
                            ? Colors.white38
                            : Colors.grey.shade500)),
              ]),
              const SizedBox(width: 6),
              Icon(
                _mostrarBalance
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: Colors.grey,
              ),
            ]),
          ),
        ),

        if (_mostrarBalance) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 5),
            child: Row(children: [
              Expanded(
                child: _buildBalanceItem("Capital Activo", saldoCalle,
                    AppColors.primary, Icons.account_balance_rounded),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildBalanceItem("Interés por Cobrar", interesPendiente,
                    AppColors.warning, Icons.timer_outlined),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(children: [
              Expanded(
                child: _buildBalanceItem("Ganancia Cobrada", totalGananciaMes,
                    AppColors.success, Icons.trending_up_rounded),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildBalanceItem("Capital Recuperado", totalRecuperadoMes,
                    AppColors.teal, Icons.savings_rounded),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildBalanceItem(
      String titulo, double monto, Color color, IconData icono) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      decoration: BoxDecoration(
        color: esOscuro ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: esOscuro
              ? Colors.white.withOpacity(0.07)
              : color.withOpacity(0.2),
        ),
        boxShadow: esOscuro
            ? []
            : [BoxShadow(color: color.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Text(titulo,
                style: TextStyle(
                    fontSize: 10.5,
                    color: esOscuro ? Colors.white54 : Colors.grey.shade500,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withOpacity(esOscuro ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icono, size: 14, color: color),
          ),
        ]),
        const SizedBox(height: 3),
        Text(
          "S/. ${moneyFormat.format(monto)}",
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: esOscuro ? Colors.white : color),
          overflow: TextOverflow.ellipsis,
        ),
      ]),
    );
  }

  Widget _buildFilterChip(String label, Color color, {String? filtroKey}) {
    final labelBase = label.split(' ').first;
    final isSelected = _filtroActual == labelBase ||
        _filtroActual == label ||
        (filtroKey != null && _filtroActual == filtroKey);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() {
          _filtroActual = filtroKey ?? labelBase;
          _itemsVisibles = _pagSize;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isSelected ? color : Colors.grey.withOpacity(0.4),
                width: isSelected ? 1.5 : 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? color : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirTarjeta(Prestamo p) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    // ── Tarjeta cancelada (compacta) ──────────────────────────────────────
    if (p.estaCancelado) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        color: esOscuro ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: AppColors.success.withOpacity(0.15),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 22),
          ),
          title: Text(p.nombre,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: esOscuro ? Colors.white54 : Colors.black54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("CANCELADO",
                style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
            Text("Ganancia: S/. ${moneyFormat.format(p.interesCobradoAcumulado)}",
                style: TextStyle(
                    fontSize: 12,
                    color: esOscuro ? Colors.white38 : Colors.black38)),
          ]),
          trailing: widget.modoEliminar
              ? IconButton(
                  icon: const Icon(Icons.delete_rounded, color: AppColors.danger),
                  onPressed: () => _eliminar(p.id))
              : null,
        ),
      );
    }

    final bool esAtrasado = p.diasTranscurridos > p.plazoDias;
    final Color colorEstado = esAtrasado ? AppColors.danger : AppColors.success;
    const Color colorFooter = AppColors.teal;
    final String textoEstado = esAtrasado
        ? "VENCIDO · ${p.diasTranscurridos - p.plazoDias}d"
        : "DÍA ${p.diasTranscurridos}/${p.plazoDias}";
    final bool modoAccion = widget.modoEdicion || widget.modoEliminar;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      color: esOscuro ? const Color(0xFF1C1C1C) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: esOscuro
              ? Colors.white.withOpacity(0.22)
              : colorEstado.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Stack(children: [
        // ── Badge esquina superior derecha ─────────────────────────────────
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorEstado.withOpacity(esOscuro ? 0.2 : 0.18),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(12),
              ),
              border: Border.all(color: colorEstado.withOpacity(esOscuro ? 0.5 : 0.65), width: 1.2),
            ),
            child: Text(textoEstado,
                style: TextStyle(
                    fontSize: 12,
                    color: esOscuro ? colorEstado : colorEstado.withOpacity(0.85),
                    fontWeight: FontWeight.bold)),
          ),
        ),

        Column(children: [
        // ── Header: nombre + fecha ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 130, 8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 17),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  "Desde ${DateFormat('dd/MM/yyyy').format(p.fechaDesembolso)}  ·  ${p.plazoDias}d",
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                ),
              ]),
            ),
          ]),
        ),

        // ── Datos principales: capital e interés acumulado ─────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(children: [
            Expanded(
              child: _tarjetaDato(
                "Capital pendiente",
                "S/. ${moneyFormat.format(p.saldoCapital)}",
                AppColors.primary,
                Icons.account_balance_rounded,
                esOscuro,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _tarjetaDato(
                "Interés (día ${p.diasTranscurridos})",
                "S/. ${moneyFormat.format(p.interesAcumuladoAlDia)}",
                AppColors.warning,
                Icons.trending_up_rounded,
                esOscuro,
              ),
            ),
          ]),
        ),

        // ── Info secundaria ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: esOscuro ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: esOscuro ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
            ),
            child: Row(children: [
              Expanded(child: _infoSecundaria("Entregado",
                  "S/. ${moneyFormat.format(p.montoInicialEstatico ?? p.montoOriginal)}")),
              Container(width: 1, height: 28, color: esOscuro ? Colors.white12 : Colors.grey.shade300),
              Expanded(child: _infoSecundaria("Tasa interés",
                  "${moneyFormat.format(p.tasaInteres)}%")),
              Container(width: 1, height: 28, color: esOscuro ? Colors.white12 : Colors.grey.shade300),
              Expanded(child: _infoSecundaria("Interés total",
                  "S/. ${moneyFormat.format(p.interesPendienteTotal)}")),
            ]),
          ),
        ),

        // ── Footer: total a cobrar ──────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: esOscuro
                ? const Color(0xFF1C1C1C)
                : colorFooter.withOpacity(0.1),
            border: Border(
              top: BorderSide(color: colorFooter.withOpacity(esOscuro ? 0.15 : 0.3), width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("A COBRAR HOY",
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.3,
                      color: esOscuro ? Colors.white60 : colorFooter)),
              Text("S/. ${moneyFormat.format(p.saldoCapital + p.interesAcumuladoAlDia)}",
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                      color: esOscuro ? Colors.white : colorFooter)),
            ],
          ),
        ),

        if (!modoAccion) _buildActionButtons(p, esOscuro),

        if (modoAccion)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
            child: widget.modoEliminar
                ? SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_rounded,
                          color: AppColors.danger),
                      label: const Text("Eliminar Préstamo",
                          style: TextStyle(color: AppColors.danger)),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.danger)),
                      onPressed: () => _confirmarEliminacion(p),
                    ),
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit_rounded, color: Colors.white),
                      label: const Text("Editar Préstamo",
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  FormularioPrestamo(prestamoExistente: p))),
                    ),
                  ),
          ),
        ]),
      ]),
    );
  }

  Widget _infoSecundaria(String label, String valor) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(label,
          style: TextStyle(
              fontSize: 10,
              color: esOscuro ? Colors.white38 : Colors.grey.shade500,
              fontWeight: FontWeight.w500)),
      const SizedBox(height: 2),
      Text(valor,
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: esOscuro ? Colors.white70 : Colors.grey.shade800),
          overflow: TextOverflow.ellipsis),
    ]);
  }

  Widget _tarjetaDato(String label, String valor, Color color, IconData icono,
      bool esOscuro) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: esOscuro ? const Color(0xFF1C1C1C) : color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: esOscuro
              ? Colors.white.withOpacity(0.07)
              : color.withOpacity(0.3),
          width: 1.2,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    color: esOscuro ? Colors.white54 : color.withOpacity(0.75),
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color.withOpacity(esOscuro ? 0.2 : 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icono, size: 13, color: color),
          ),
        ]),
        const SizedBox(height: 2),
        Text(valor,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: esOscuro ? Colors.white : color),
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _buildActionButtons(Prestamo p, bool esOscuro) {
    return Row(children: [
        _ActionButton(
          icon: Icons.payments_rounded,
          label: 'Cobrar',
          color: AppColors.success,
          onTap: () => _mostrarDialogoPago(p),
        ),
        Container(width: 0.5, height: 44, color: Colors.grey.shade200),
        _ActionButton(
          icon: Icons.add_circle_rounded,
          label: 'Ampliar',
          color: AppColors.teal,
          onTap: () => _mostrarDialogoAumentarCapital(p),
        ),
        Container(width: 0.5, height: 44, color: Colors.grey.shade200),
        _ActionButton(
          icon: Icons.receipt_long_rounded,
          label: 'Historial',
          color: AppColors.purple,
          onTap: () => _verDetallePagos(p),
        ),
        if (p.telefono != null && p.telefono!.isNotEmpty) ...[
          Container(width: 0.5, height: 44, color: Colors.grey.shade200),
          _ActionButton(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            color: AppColors.success,
            onTap: () => _abrirWhatsApp(p),
          ),
        ],
    ]);
  }

  void _mostrarDialogoPago(Prestamo p) {
    FocusScope.of(context).unfocus();
    final montoAmortizarCtrl = TextEditingController();
    final diasManualesCtrl =
        TextEditingController(text: p.diasTranscurridos.toString());
    bool cobrarSoloInteresDiario = false;
    bool cobrarInteresEnEstePago = true;
    bool renovarCiclo = true;
    DateTime? fechaSeleccionada;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          double interesTotalFijo = p.interesPendienteTotal;
          double valorDia = p.interesPendienteTotal / p.plazoDias;
          int diasInput = int.tryParse(diasManualesCtrl.text) ?? 0;
          double interesDiarioCalculado = valorDia * diasInput;
          double interesCalculadoBase =
              cobrarSoloInteresDiario ? interesDiarioCalculado : interesTotalFijo;
          double interesAplicable =
              cobrarInteresEnEstePago ? interesCalculadoBase : 0.0;
          double totalLiquidar = p.saldoCapital + interesAplicable;

          DateTime fechaBase = p.fechaDesembolso;
          int nuevoMes = fechaBase.month + 1;
          int nuevoAnio = fechaBase.year;
          if (nuevoMes > 12) {
            nuevoMes = 1;
            nuevoAnio++;
          }
          int ultimoDia = DateTime(nuevoAnio, nuevoMes + 1, 0).day;
          int nuevoDia =
              fechaBase.day > ultimoDia ? ultimoDia : fechaBase.day;
          DateTime fechaEjemplo = DateTime(nuevoAnio, nuevoMes, nuevoDia);
          final esOscuro = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.payments_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text("Cobrar: ${p.nombre}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16)),
              ),
            ]),
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // ── Renovar ciclo ──────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.only(left: 4, right: 12, top: 4, bottom: 4),
                  decoration: BoxDecoration(
                    color: renovarCiclo
                        ? AppColors.primary.withOpacity(0.08)
                        : Colors.grey.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: renovarCiclo
                          ? AppColors.primary.withOpacity(0.5)
                          : Colors.grey.withOpacity(0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(children: [
                    Checkbox(
                      value: renovarCiclo,
                      activeColor: AppColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => setState(() {
                        renovarCiclo = v!;
                        if (!v) fechaSeleccionada = null;
                      }),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("Renovar ciclo",
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: renovarCiclo ? AppColors.primary : Colors.grey)),
                        Text(
                          renovarCiclo
                              ? "Nueva fecha: ${DateFormat('dd/MM/yyyy').format(fechaSeleccionada ?? fechaEjemplo)}"
                              : "Fecha actual: ${DateFormat('dd/MM/yyyy').format(p.fechaDesembolso)}",
                          style: TextStyle(
                              fontSize: 11,
                              color: renovarCiclo
                                  ? (esOscuro ? Colors.white54 : Colors.grey.shade600)
                                  : Colors.grey.shade400),
                        ),
                      ]),
                    ),
                    if (renovarCiclo)
                      IconButton(
                        icon: const Icon(Icons.edit_calendar_rounded, color: AppColors.primary, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: "Cambiar fecha",
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: fechaSeleccionada ?? fechaEjemplo,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                          );
                          if (picked != null) setState(() => fechaSeleccionada = picked);
                        },
                      ),
                  ]),
                ),

                // ── Días a cobrar ──────────────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                  Expanded(
                    child: !cobrarSoloInteresDiario
                        ? Text("Días a cobrar: ${p.diasTranscurridos}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
                        : Row(children: [
                            const Text("Días:", style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 55,
                              height: 36,
                              child: TextField(
                                controller: diasManualesCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                                    border: OutlineInputBorder()),
                                onChanged: (v) => setState(() {}),
                              ),
                            ),
                          ]),
                  ),
                  Row(children: [
                    Text("Manual", style: TextStyle(fontSize: 12, color: esOscuro ? Colors.white54 : Colors.grey.shade600)),
                    Checkbox(
                      value: cobrarSoloInteresDiario,
                      activeColor: AppColors.warning,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => setState(() {
                        cobrarSoloInteresDiario = v!;
                        if (!v) diasManualesCtrl.text = p.diasTranscurridos.toString();
                      }),
                    ),
                  ]),
                ]),

                Divider(color: Colors.grey.withOpacity(0.2), thickness: 0.5, height: 12),

                // ── Saldo Capital + Interés a cobrar ───────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: esOscuro ? const Color(0xFF1C1C1C) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(esOscuro ? 0.15 : 0.2)),
                  ),
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text("Saldo Capital",
                            style: TextStyle(fontSize: 13, color: esOscuro ? Colors.white54 : Colors.grey.shade600)),
                        Text("S/. ${moneyFormat.format(p.saldoCapital)}",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                                color: esOscuro ? Colors.white : AppColors.primary)),
                      ]),
                    ),
                    Divider(height: 1, thickness: 0.5, color: Colors.grey.withOpacity(esOscuro ? 0.15 : 0.2)),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, right: 12, top: 2, bottom: 2),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Row(children: [
                          Checkbox(
                            value: cobrarInteresEnEstePago,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            onChanged: (v) => setState(() => cobrarInteresEnEstePago = v!),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            cobrarInteresEnEstePago ? "Interés a cobrar:" : "Sin Interés",
                            style: TextStyle(fontSize: 13, color: esOscuro ? Colors.white54 : Colors.grey.shade600),
                          ),
                        ]),
                        Text(
                          "S/. ${moneyFormat.format(interesAplicable)}",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cobrarInteresEnEstePago ? AppColors.warning : Colors.grey,
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),

                Divider(color: Colors.grey.withOpacity(0.2), thickness: 0.5, height: 16),

                // ── Total ──────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: esOscuro ? const Color(0xFF1C1C1C) : AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text("TOTAL",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                            color: esOscuro ? Colors.white60 : Colors.grey.shade700)),
                    Text("S/. ${moneyFormat.format(totalLiquidar)}",
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18,
                            color: esOscuro ? Colors.white : AppColors.primary)),
                  ]),
                ),
                const SizedBox(height: 14),

                // ── Pagar todo ─────────────────────────────────────────────
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _confirmarPago(
                    ctx, p, true, 0, interesAplicable, renovarCiclo, fechaSeleccionada, totalLiquidar,
                  ),
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text("PAGAR TODO", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),

                // ── Pagar solo interés ─────────────────────────────────────
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: esOscuro ? AppColors.warning.withOpacity(0.15) : Colors.orange.shade50,
                    foregroundColor: AppColors.warning,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: AppColors.warning.withOpacity(0.5)),
                    ),
                  ),
                  onPressed: () => _confirmarPago(
                    ctx, p, false, 0, interesAplicable, renovarCiclo, fechaSeleccionada, interesAplicable,
                  ),
                  icon: const Icon(Icons.attach_money_rounded),
                  label: const Text("PAGAR SOLO INTERÉS", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 14),

                // ── Amortizar capital ──────────────────────────────────────
                Row(children: [
                  Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text("Amortizar capital",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
                ]),
                const SizedBox(height: 8),

                TextField(
                  controller: montoAmortizarCtrl,
                  inputFormatters: [CurrencyInputFormatter()],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: "Monto a amortizar",
                    prefixText: "S/. ",
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => montoAmortizarCtrl.clear(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Botones de acción ──────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: BorderSide(color: Colors.grey.withOpacity(0.4)),
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Cancelar"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        String limpio = montoAmortizarCtrl.text.replaceAll(',', '');
                        double abonoCapital = double.tryParse(limpio) ?? 0;
                        if (abonoCapital > 0 && abonoCapital <= p.saldoCapital) {
                          _confirmarPago(
                            ctx, p, false, abonoCapital, interesAplicable, renovarCiclo,
                            fechaSeleccionada, abonoCapital + interesAplicable,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text("Ingresa un monto válido"),
                            backgroundColor: AppColors.warning,
                          ));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Registrar Abono"),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        });
      },
    );
  }

  void _confirmarPago(
    BuildContext ctx,
    Prestamo p,
    bool esPagoTotal,
    double abonoCapital,
    double interesAplicable,
    bool renovarFecha,
    DateTime? fechaPersonalizada,
    double totalRecibir,
  ) {
    String desc = esPagoTotal
        ? "Cancelación total del préstamo"
        : (abonoCapital == 0 ? "Pago solo de interés" : "Amortización de capital");
    showDialog(
      context: context,
      builder: (ctxConfirm) => AlertDialog(
        title: const Text("⚠️ Confirmar Cobro"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(desc, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (abonoCapital > 0)
            _filaResumen("Capital:", "S/. ${moneyFormat.format(abonoCapital)}"),
          if (interesAplicable > 0)
            _filaResumen("Interés:", "S/. ${moneyFormat.format(interesAplicable)}"),
          const Divider(),
          _filaResumen("TOTAL A RECIBIR:", "S/. ${moneyFormat.format(totalRecibir)}",
              bold: true),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctxConfirm),
              child: const Text("Corregir")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctxConfirm);
              Navigator.pop(ctx);
              _procesarPagoFirebase(
                  p, esPagoTotal, abonoCapital, interesAplicable, renovarFecha, fechaPersonalizada);
            },
            child: const Text("SÍ, COBRAR"),
          ),
        ],
      ),
    );
  }

  Widget _filaResumen(String label, String valor,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        Text(valor,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: color)),
      ]),
    );
  }

  void _mostrarDialogoAumentarCapital(Prestamo p) {
    FocusScope.of(context).unfocus();
    final montoExtraCtrl = TextEditingController();
    bool reiniciarFecha = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text("Ampliar Capital"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Saldo actual:",
                        style: TextStyle(fontSize: 13)),
                    Text("S/. ${moneyFormat.format(p.saldoCapital)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.teal)),
                  ]),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: montoExtraCtrl,
              inputFormatters: [CurrencyInputFormatter()],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "Monto a Ampliar",
                prefixText: "S/. ",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => montoExtraCtrl.clear(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text("¿Renovar fecha a hoy?",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: const Text("Reinicia el conteo de días desde hoy",
                  style: TextStyle(fontSize: 12)),
              value: reiniciarFecha,
              dense: true,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) => setState(() => reiniciarFecha = val!),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () async {
                String limpio = montoExtraCtrl.text.replaceAll(',', '');
                double extra = double.tryParse(limpio) ?? 0;
                if (extra > 0) {
                  showDialog(
                    context: context,
                    builder: (ctxConfirm) => AlertDialog(
                      title: const Text("⚠️ Confirmar Ampliación"),
                      content: Text(
                          "Capital anterior: S/. ${moneyFormat.format(p.saldoCapital)}\n"
                          "(+) Ampliación: S/. ${moneyFormat.format(extra)}\n"
                          "Nuevo capital: S/. ${moneyFormat.format(p.saldoCapital + extra)}\n\n"
                          "¿Es correcto?"),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctxConfirm),
                            child: const Text("Corregir")),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white),
                          onPressed: () async {
                            Navigator.pop(ctxConfirm);
                            Navigator.pop(ctx);
                            await PrestamoService.ampliarCapital(
                              p,
                              extra: extra,
                              reiniciarFecha: reiniciarFecha,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  "Capital ampliado en S/. ${moneyFormat.format(extra)}"),
                              backgroundColor: AppColors.success,
                            ));
                          },
                          child: const Text("SÍ, AMPLIAR"),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: const Text("Ampliar"),
            ),
          ],
        ),
      ),
    );
  }

  void _verDetallePagos(Prestamo p) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        double totalCapitalPagado = 0;
        double totalInteresPagado = 0;
        List<Pago> pagosOrdenados = List.from(p.pagos);
        pagosOrdenados.sort((a, b) => b.fecha.compareTo(a.fecha));
        for (var pago in p.pagos) {
          if (pago.montoCapital > 0) totalCapitalPagado += pago.montoCapital;
          totalInteresPagado += pago.montoInteres;
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.92,
          builder: (context, scrollController) => Column(children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text("Historial: ${p.nombre}",
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
            const Divider(),
            Expanded(
              child: pagosOrdenados.isEmpty
                  ? const Center(child: Text("Sin movimientos registrados."))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: pagosOrdenados.length,
                      itemBuilder: (ctx, i) {
                        final pago = pagosOrdenados[i];
                        bool esAmpliacion = pago.montoCapital < 0;
                        bool esCancelacion =
                            p.estaCancelado && i == 0 && !esAmpliacion;

                        if (esAmpliacion) {
                          double aumento = pago.montoCapital.abs();
                          double anterior = pago.saldoAnterior ?? 0.0;
                          double nuevoTotal = anterior + aumento;
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("AMPLIACIÓN DE CAPITAL",
                                            style: TextStyle(
                                                color: Colors.orange.shade800,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                        Row(children: [
                                          Text(
                                              DateFormat('dd/MM/yyyy')
                                                  .format(pago.fecha),
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey)),
                                          if (i == 0) ...[
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () =>
                                                  _confirmarRevertirPago(p, pago),
                                              child: const Icon(Icons.undo_rounded,
                                                  color: AppColors.danger, size: 18),
                                            ),
                                          ],
                                        ]),
                                      ]),
                                  const Divider(
                                      height: 12, color: Colors.orangeAccent),
                                  _filaResumen("Capital anterior:",
                                      "S/. ${moneyFormat.format(anterior)}"),
                                  _filaResumen("(+) Ampliación:",
                                      "S/. ${moneyFormat.format(aumento)}",
                                      color: Colors.deepOrange),
                                  const Divider(height: 8),
                                  _filaResumen("Nuevo capital:",
                                      "S/. ${moneyFormat.format(nuevoTotal)}",
                                      bold: true),
                                ]),
                          );
                        }

                        bool esAmortizacion =
                            pago.montoInteres == 0 && pago.montoCapital > 0;
                        IconData icono = esCancelacion
                            ? Icons.check_circle_rounded
                            : (esAmortizacion
                                ? Icons.savings_rounded
                                : Icons.monetization_on_rounded);
                        Color colorIcono = esCancelacion
                            ? AppColors.success
                            : (esAmortizacion ? Colors.blue : AppColors.success);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: colorIcono.withOpacity(0.1),
                            child: Icon(icono, color: colorIcono, size: 20),
                          ),
                          title: Text(
                            esCancelacion
                                ? "CUENTA CANCELADA"
                                : DateFormat('dd/MM/yyyy – HH:mm').format(pago.fecha),
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: esCancelacion
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: esCancelacion ? AppColors.success : null),
                          ),
                          subtitle: Text(
                            "Cap: S/. ${moneyFormat.format(pago.montoCapital)}  |  Int: S/. ${moneyFormat.format(pago.montoInteres)}",
                            style: TextStyle(
                                fontSize: 12,
                                color: esAmortizacion ? Colors.blue : null),
                          ),
                          trailing: i == 0
                              ? IconButton(
                                  icon: const Icon(Icons.undo_rounded,
                                      color: AppColors.danger),
                                  tooltip: "Deshacer movimiento",
                                  onPressed: () => _confirmarRevertirPago(p, pago),
                                )
                              : null,
                        );
                      },
                    ),
            ),
            const Divider(),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                Column(children: [
                  const Text("Total Cobrado (Cap)",
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text("S/. ${moneyFormat.format(totalCapitalPagado)}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ]),
                Container(width: 1, height: 30, color: Colors.grey.shade300),
                Column(children: [
                  const Text("Total Cobrado (Int)",
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text("S/. ${moneyFormat.format(totalInteresPagado)}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.success)),
                ]),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Future<void> _procesarPagoFirebase(
    Prestamo p,
    bool esPagoTotal,
    double abonoCapital,
    double interesDelPago,
    bool renovarFecha,
    DateTime? fechaPersonalizada,
  ) async {
    final mensaje = await PrestamoService.procesarPago(
      p,
      esPagoTotal: esPagoTotal,
      abonoCapital: abonoCapital,
      interesDelPago: interesDelPago,
      renovarFecha: renovarFecha,
      fechaPersonalizada: fechaPersonalizada,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje), backgroundColor: AppColors.success));
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 21, color: color),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
