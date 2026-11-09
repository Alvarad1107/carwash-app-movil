/// Modelo para los servicios adicionales (Extras) de una orden en Sprint Wash.
class ServicioExtraModel {
  final int id;
  final String nombre;
  final double precio;
  bool seleccionado;

  ServicioExtraModel({
    required this.id,
    required this.nombre,
    required this.precio,
    this.seleccionado = false,
  });

  /// Lista oficial de servicios adicionales según requerimientos
  static List<ServicioExtraModel> obtenerListaDefecto() {
    return [
      ServicioExtraModel(
        id: 1,
        nombre: 'Lavado Extra',
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
        nombre: 'Restauración Silvines',
        precio: 10.00,
      ),
      ServicioExtraModel(
        id: 5,
        nombre: 'Ducha Chasis',
        precio: 5.00,
      ),
    ];
  }
}
