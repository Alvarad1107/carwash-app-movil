/// Modelo que representa un vehículo en el patio de lavado.
/// Agrupa datos de la orden, vehículo y cliente en una sola entidad para la UI.
class VehiculoPatio {
  final int ordenId;
  final int vehiculoId;
  final int bahiaId;
  final int categoriaId;
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
  final bool esDeHoy;
  final String fechaHoraTexto;
  final String operariosAsignados;
  final double comisionOrden;
  int fase; // 0=Pendiente, 1=En proceso, 2=Terminado
  bool pagado;
  bool comisionada;

  VehiculoPatio({
    required this.ordenId,
    required this.vehiculoId,
    this.bahiaId = 1,
    this.categoriaId = 1,
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
    this.esDeHoy = true,
    this.fechaHoraTexto = '',
    this.operariosAsignados = '',
    this.comisionOrden = 0.0,
    this.fase = 0,
    this.pagado = false,
    this.comisionada = false,
  });

  /// Nombre completo del vehículo (marca + modelo).
  String get nombreCompletoCarro => '$marca $modelo'.trim();
}
