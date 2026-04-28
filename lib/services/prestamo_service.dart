import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/pago.dart';
import '../models/prestamo.dart';

class PrestamoService {
  static final _col = FirebaseFirestore.instance.collection('prestamos');

  // ── Streams ────────────────────────────────────────────────────────────────

  static Stream<List<Prestamo>> streamPrestamos(String userId) {
    return _col
        .where('usuarioId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Prestamo.fromMap(d.data(), d.id))
            .toList());
  }

  static Stream<List<Prestamo>> streamActivos(String userId) {
    return _col
        .where('usuarioId', isEqualTo: userId)
        .where('estaCancelado', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Prestamo.fromMap(d.data(), d.id))
            .toList());
  }

  // ── CRUD básico ────────────────────────────────────────────────────────────

  static Future<void> eliminar(String id) => _col.doc(id).delete();

  static Future<void> actualizar(Prestamo p) => _col.doc(p.id).update(p.toMap());

  // ── Lógica de pagos ────────────────────────────────────────────────────────

  /// Registra un pago completo o parcial y devuelve el mensaje de confirmación.
  static Future<String> procesarPago(
    Prestamo p, {
    required bool esPagoTotal,
    required double abonoCapital,
    required double interesDelPago,
    required bool renovarFecha,
    DateTime? fechaPersonalizada,
  }) async {
    final fechaAnterior = p.fechaDesembolso;
    p.pagos.add(Pago(
      fecha: DateTime.now(),
      montoCapital: esPagoTotal ? p.saldoCapital : abonoCapital,
      montoInteres: interesDelPago,
      fechaDesembolsoAnterior: fechaAnterior,
    ));
    p.interesCobradoAcumulado += interesDelPago;

    if (esPagoTotal) {
      p.montoPagadoCapital = p.montoOriginal;
      p.estaCancelado = true;
      p.fechaCancelacion = DateTime.now();
    } else {
      p.montoPagadoCapital += abonoCapital;
      if (p.saldoCapital <= 0.01) {
        p.montoPagadoCapital = p.montoOriginal;
        p.estaCancelado = true;
        p.fechaCancelacion = DateTime.now();
      } else if (renovarFecha) {
        p.fechaDesembolso = fechaPersonalizada ?? _avanzarUnMes(fechaAnterior);
      }
    }

    await actualizar(p);

    String mensaje = "✓ Pago registrado correctamente.";
    if (!esPagoTotal && renovarFecha && !p.estaCancelado) {
      mensaje += " Ciclo renovado al ${DateFormat('dd/MM').format(p.fechaDesembolso)}.";
    }
    return mensaje;
  }

  /// Añade capital al préstamo y registra el movimiento en el historial.
  static Future<void> ampliarCapital(
    Prestamo p, {
    required double extra,
    required bool reiniciarFecha,
  }) async {
    final saldoAntes = p.saldoCapital;
    final fechaPrevia = p.fechaDesembolso;
    p.montoOriginal += extra;
    p.montoInicialEstatico ??= (p.montoOriginal - extra);
    if (reiniciarFecha) p.fechaDesembolso = DateTime.now();
    p.pagos.add(Pago(
      fecha: DateTime.now(),
      montoCapital: -extra,
      montoInteres: 0,
      saldoAnterior: saldoAntes,
      fechaDesembolsoAnterior: fechaPrevia,
    ));
    await actualizar(p);
  }

  /// Deshace el último movimiento del préstamo restaurando el estado anterior.
  static Future<void> revertirPago(Prestamo p, Pago pago) async {
    if (pago.montoCapital < 0) {
      p.montoOriginal += pago.montoCapital;
      p.montoInicialEstatico =
          (p.montoInicialEstatico ?? p.montoOriginal) + pago.montoCapital;
    } else {
      p.montoPagadoCapital -= pago.montoCapital;
      p.interesCobradoAcumulado -= pago.montoInteres;
    }
    if (pago.fechaDesembolsoAnterior != null) {
      p.fechaDesembolso = pago.fechaDesembolsoAnterior!;
    }
    p.estaCancelado = false;
    p.fechaCancelacion = null;
    p.pagos.removeWhere((e) => e.fecha == pago.fecha);
    await actualizar(p);
  }

  // ── Helpers privados ───────────────────────────────────────────────────────

  static DateTime _avanzarUnMes(DateTime fecha) {
    int nuevoMes = fecha.month + 1;
    int nuevoAnio = fecha.year;
    if (nuevoMes > 12) {
      nuevoMes = 1;
      nuevoAnio++;
    }
    final ultimoDia = DateTime(nuevoAnio, nuevoMes + 1, 0).day;
    final nuevoDia = fecha.day > ultimoDia ? ultimoDia : fecha.day;
    return DateTime(nuevoAnio, nuevoMes, nuevoDia, fecha.hour, fecha.minute);
  }
}
