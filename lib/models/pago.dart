import 'package:cloud_firestore/cloud_firestore.dart';

class Pago {
  DateTime fecha;
  double montoCapital;
  double montoInteres;
  double? saldoAnterior;
  DateTime? fechaDesembolsoAnterior;

  Pago({
    required this.fecha,
    required this.montoCapital,
    required this.montoInteres,
    this.saldoAnterior,
    this.fechaDesembolsoAnterior,
  });

  Map<String, dynamic> toMap() {
    var map = {
      'fecha': Timestamp.fromDate(fecha),
      'montoCapital': montoCapital,
      'montoInteres': montoInteres,
      'saldoAnterior': saldoAnterior,
    };
    if (fechaDesembolsoAnterior != null) {
      map['fechaDesembolsoAnterior'] = Timestamp.fromDate(fechaDesembolsoAnterior!);
    }
    return map;
  }

  factory Pago.fromMap(Map<String, dynamic> map) {
    return Pago(
      fecha: (map['fecha'] as Timestamp).toDate(),
      montoCapital: (map['montoCapital'] ?? 0).toDouble(),
      montoInteres: (map['montoInteres'] ?? 0).toDouble(),
      saldoAnterior: map['saldoAnterior']?.toDouble(),
      fechaDesembolsoAnterior: map['fechaDesembolsoAnterior'] != null
          ? (map['fechaDesembolsoAnterior'] as Timestamp).toDate()
          : null,
    );
  }
}
