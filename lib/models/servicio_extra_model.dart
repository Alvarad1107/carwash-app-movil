/// Modelo para los servicios adicionales (Extras) de una orden en Sprint Wash.
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
      nombre: json['nombre']?.toString() ?? 'Servicio Adicional',
      precio: double.tryParse(
              (json['precio_fijo'] ?? json['precio'] ?? '0').toString()) ??
          0.0,
      comisionExtra:
          double.tryParse((json['comision_extra'] ?? '0').toString()) ?? 0.0,
    );
  }

  /// Lista oficial de servicios adicionales sincronizada con routers/finanzas.py
  static List<ServicioExtraModel> obtenerListaDefecto() {
    return [
      ServicioExtraModel(
        id: 1,
        nombre: 'Lavado Extra (Suciedad extrema/Lodo)',
        precio: 3.00,
      ),
      ServicioExtraModel(
        id: 2,
        nombre: 'Lavado de Motor',
        precio: 15.00,
      ),
      ServicioExtraModel(
        id: 3,
        nombre: 'Limpieza de Tapicería',
        precio: 35.00,
      ),
      ServicioExtraModel(
        id: 4,
        nombre: 'Restauración de Silvines',
        precio: 10.00,
      ),
      ServicioExtraModel(
        id: 5,
        nombre: 'Ducha de Chasis',
        precio: 5.00,
      ),
    ];
  }
}
