/// Modelo para los servicios adicionales (Extras) de una orden en Sprint Wash.
/// Todos los servicios adicionales se consumen 100% desde GET /servicios/adicionales.
class ServicioExtraModel {
  final int id;
  final String nombre;
  final double precio;
  final double comisionExtra;
  bool seleccionado;

  ServicioExtraModel({
    required this.id,
    required this.nombre,
    required this.precio,
    this.comisionExtra = 0.0,
    this.seleccionado = false,
  });

  factory ServicioExtraModel.fromJson(Map<String, dynamic> json) {
    return ServicioExtraModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nombre: json['nombre']?.toString() ?? '',
      precio: double.tryParse(
              (json['precio_fijo'] ?? json['precio'] ?? '0').toString()) ??
          0.0,
      comisionExtra:
          double.tryParse((json['comision_extra'] ?? '0').toString()) ?? 0.0,
    );
  }
}
