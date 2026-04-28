class ClienteRanking {
  String nombre;
  double capitalTotal;
  double interesTotal;
  int cantidadPrestamos;

  ClienteRanking({
    required this.nombre,
    this.capitalTotal = 0.0,
    this.interesTotal = 0.0,
    this.cantidadPrestamos = 0,
  });
}
