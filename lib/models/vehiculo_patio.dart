/// Modelo que representa un vehículo en el patio de lavado.
/// Agrupa datos de la orden, vehículo y cliente en una sola entidad para la UI.
class VehiculoPatio {
  final int ordenId;
  final int vehiculoId;
  final String placa;
  final String marca;
  final String modelo;
  final String color;
  final String categoria;
  final String cliente;
  final String correoCliente;
  final String telefonoCliente;
  final String bahia;
  final String servicio;
  final double montoNumerico;
  final String totalPagar;
  int fase; // 0=Pendiente, 1=En proceso, 2=Terminado
  bool pagado;

  VehiculoPatio({
    required this.ordenId,
    required this.vehiculoId,
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.color,
    required this.categoria,
    required this.cliente,
    required this.correoCliente,
    required this.telefonoCliente,
    required this.bahia,
    required this.servicio,
    required this.montoNumerico,
    required this.totalPagar,
    this.fase = 0,
    this.pagado = false,
  });

  /// Nombre completo del vehículo (marca + modelo).
  String get nombreCompletoCarro => '$marca $modelo'.trim();
}
