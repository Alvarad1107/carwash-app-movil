/// Modelo de datos para insumos del Inventario (Sprint Wash).
class InventarioModel {
  final int id;
  final String codigoSku;
  final String nombreProducto;
  final int cantidadActual;
  final int stockMinimo;
  final String unidadMedida;
  final double costoUnitario;
  final String? proveedor;

  InventarioModel({
    required this.id,
    required this.codigoSku,
    required this.nombreProducto,
    required this.cantidadActual,
    required this.stockMinimo,
    required this.unidadMedida,
    required this.costoUnitario,
    this.proveedor,
  });

  factory InventarioModel.fromJson(Map<String, dynamic> json) {
    return InventarioModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      codigoSku: json['codigo_sku']?.toString() ?? '',
      nombreProducto:
          json['nombre_producto']?.toString() ?? 'Producto sin nombre',
      cantidadActual: json['cantidad_actual'] is int
          ? json['cantidad_actual']
          : int.tryParse(json['cantidad_actual']?.toString() ?? '0') ?? 0,
      stockMinimo: json['stock_minimo'] is int
          ? json['stock_minimo']
          : int.tryParse(json['stock_minimo']?.toString() ?? '0') ?? 0,
      unidadMedida: json['unidad_medida']?.toString() ?? 'Unidades',
      costoUnitario: json['costo_unitario'] != null
          ? double.tryParse(json['costo_unitario'].toString()) ?? 0.0
          : 0.0,
      proveedor: json['proveedor']?.toString(),
    );
  }

  /// Alerta crítica: cantidad actual menor o igual al stock mínimo
  bool get esStockCritico => cantidadActual <= stockMinimo;

  /// Alerta preventiva: stock bajo pero aún no en nivel crítico (hasta 3 unidades por encima)
  bool get esStockBajo =>
      !esStockCritico && cantidadActual <= (stockMinimo + 3);
}
