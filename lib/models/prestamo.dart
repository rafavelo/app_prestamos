import 'package:cloud_firestore/cloud_firestore.dart';
import 'pago.dart';

class Prestamo {
  String id;
  String usuarioId;
  String nombre;
  String? telefono;
  double montoOriginal;
  double? montoInicialEstatico;
  double montoPagadoCapital;
  double interesCobradoAcumulado;
  int plazoDias;
  double tasaInteres;
  DateTime fechaDesembolso;
  DateTime fechaCreacion;
  bool estaCancelado;
  DateTime? fechaCancelacion;
  List<Pago> pagos;

  Prestamo({
    required this.id,
    required this.usuarioId,
    required this.nombre,
    this.telefono,
    required this.montoOriginal,
    this.montoInicialEstatico,
    this.montoPagadoCapital = 0.0,
    this.interesCobradoAcumulado = 0.0,
    required this.plazoDias,
    required this.tasaInteres,
    required this.fechaDesembolso,
    required this.fechaCreacion,
    this.estaCancelado = false,
    this.fechaCancelacion,
    List<Pago>? pagos,
  }) : pagos = pagos ?? [];

  double get saldoCapital => montoOriginal - montoPagadoCapital;
  double get interesPendienteTotal => saldoCapital * (tasaInteres / 100);
  int get diasTranscurridos {
    final dias = DateTime.now().difference(fechaDesembolso).inDays;
    return dias < 0 ? 0 : dias;
  }
  double get valorDiaInteres => interesPendienteTotal / plazoDias;
  double get interesAcumuladoAlDia {
    if (estaCancelado || saldoCapital <= 0) return 0;
    return valorDiaInteres * diasTranscurridos;
  }
  double get montoLiquidarFull => saldoCapital + interesPendienteTotal;

  Map<String, dynamic> toMap() {
    return {
      'usuarioId': usuarioId,
      'nombre': nombre,
      'telefono': telefono,
      'montoOriginal': montoOriginal,
      'montoInicialEstatico': montoInicialEstatico,
      'montoPagadoCapital': montoPagadoCapital,
      'interesCobradoAcumulado': interesCobradoAcumulado,
      'plazoDias': plazoDias,
      'tasaInteres': tasaInteres,
      'fechaDesembolso': Timestamp.fromDate(fechaDesembolso),
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'estaCancelado': estaCancelado,
      'fechaCancelacion':
          fechaCancelacion != null ? Timestamp.fromDate(fechaCancelacion!) : null,
      'pagos': pagos.map((e) => e.toMap()).toList(),
    };
  }

  factory Prestamo.fromMap(Map<String, dynamic> map, String docId) {
    return Prestamo(
      id: docId,
      usuarioId: map['usuarioId'] ?? '',
      nombre: map['nombre'] ?? 'Sin Nombre',
      telefono: map['telefono'],
      montoOriginal: (map['montoOriginal'] ?? 0).toDouble(),
      montoInicialEstatico: map['montoInicialEstatico']?.toDouble() ??
          (map['montoOriginal'] ?? 0).toDouble(),
      montoPagadoCapital: (map['montoPagadoCapital'] ?? 0).toDouble(),
      interesCobradoAcumulado: (map['interesCobradoAcumulado'] ?? 0).toDouble(),
      plazoDias: map['plazoDias'] ?? 30,
      tasaInteres: (map['tasaInteres'] ?? 0).toDouble(),
      fechaDesembolso: (map['fechaDesembolso'] as Timestamp).toDate(),
      fechaCreacion: (map['fechaCreacion'] as Timestamp).toDate(),
      estaCancelado: map['estaCancelado'] ?? false,
      fechaCancelacion: map['fechaCancelacion'] != null
          ? (map['fechaCancelacion'] as Timestamp).toDate()
          : null,
      pagos: map['pagos'] != null
          ? (map['pagos'] as List).map((e) => Pago.fromMap(e)).toList()
          : [],
    );
  }
}
