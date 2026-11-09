import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/inventario_model.dart';
import '../services/api_service.dart';

/// Pantalla de Inventario de Insumos en modo "Solo Lectura".
/// Consulta en tiempo real los insumos del VPS y muestra alertas visuales de stock.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ApiService _apiService = ApiService();
  List<InventarioModel> _insumos = [];
  bool _cargando = true;
  String? _error;
  String _filtroBusqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarInventario();
  }

  Future<void> _cargarInventario({bool mostrarSnack = false}) async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final insumos = await _apiService.obtenerInventario();
      if (mounted) {
        setState(() {
          _insumos = insumos;
          _cargando = false;
        });
        if (mostrarSnack) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF15803D),
              content: Text('Inventario actualizado desde el VPS'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _cargando = false;
        });
      }
    }
  }

  List<InventarioModel> get _insumosFiltrados {
    if (_filtroBusqueda.trim().isEmpty) return _insumos;
    final query = _filtroBusqueda.toLowerCase();
    return _insumos.where((item) {
      return item.nombreProducto.toLowerCase().contains(query) ||
          item.codigoSku.toLowerCase().contains(query) ||
          (item.proveedor?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final int totalCriticos = _insumos.where((i) => i.esStockCritico).length;
    final int totalBajos = _insumos.where((i) => i.esStockBajo).length;
    final int totalOptimos = _insumos.where((i) => !i.esStockCritico && !i.esStockBajo).length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _cargarInventario(mostrarSnack: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Almacén e Inventario',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Consulta de stock de insumos (Solo Lectura)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: _cargando ? null : () => _cargarInventario(mostrarSnack: true),
                      icon: _cargando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, color: AppColors.kRoyalBlue),
                      tooltip: 'Sincronizar con VPS',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Buscador
                TextField(
                  onChanged: (val) => setState(() => _filtroBusqueda = val),
                  decoration: InputDecoration(
                    hintText: 'Buscar insumo por nombre o SKU...',
                    hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13.5),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceGrey,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tarjetas KPI de Estado de Stock
                Row(
                  children: [
                    Expanded(
                      child: _buildKpiCard(
                        titulo: 'STOCK CRÍTICO',
                        valor: totalCriticos.toString(),
                        subtitulo: 'Reorden urgente',
                        colorFondo: const Color(0xFFFEE2E2),
                        colorTexto: const Color(0xFFB91C1C),
                        icono: Icons.warning_amber_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildKpiCard(
                        titulo: 'STOCK BAJO',
                        valor: totalBajos.toString(),
                        subtitulo: 'Próximo a agotar',
                        colorFondo: const Color(0xFFFEF3C7),
                        colorTexto: const Color(0xFFB45309),
                        icono: Icons.info_outline_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildKpiCard(
                        titulo: 'ÓPTIMO',
                        valor: totalOptimos.toString(),
                        subtitulo: 'Disponible',
                        colorFondo: const Color(0xFFDCFCE7),
                        colorTexto: const Color(0xFF15803D),
                        icono: Icons.check_circle_outline_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Contenido principal
                if (_cargando && _insumos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(strokeWidth: 3),
                          SizedBox(height: 16),
                          Text(
                            'Consultando insumos en el VPS...',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_error != null && _insumos.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 36),
                        const SizedBox(height: 10),
                        Text(
                          'Error al consultar el inventario:\n$_error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B)),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () => _cargarInventario(mostrarSnack: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.kRoyalBlue,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                else if (_insumosFiltrados.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'No se encontraron insumos con ese criterio',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Listado de Insumos (${_insumosFiltrados.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Solo Lectura',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._insumosFiltrados.map((item) => _buildInsumoCard(item)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String titulo,
    required String valor,
    required String subtitulo,
    required Color colorFondo,
    required Color colorTexto,
    required IconData icono,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: colorTexto,
                ),
              ),
              Icon(icono, size: 14, color: colorTexto),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: colorTexto,
            ),
          ),
          Text(
            subtitulo,
            style: TextStyle(
              fontSize: 9.5,
              color: colorTexto.withAlpha(200),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsumoCard(InventarioModel item) {
    // Definición de colores según el nivel de alerta
    final bool critico = item.esStockCritico;
    final bool bajo = item.esStockBajo;

    Color badgeBg;
    Color badgeText;
    String badgeLabel;
    IconData badgeIcon;
    Color borderColor;

    if (critico) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFFDC2626);
      badgeLabel = 'STOCK CRÍTICO';
      badgeIcon = Icons.warning_rounded;
      borderColor = const Color(0xFFF87171);
    } else if (bajo) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFFD97706);
      badgeLabel = 'STOCK BAJO';
      badgeIcon = Icons.info_rounded;
      borderColor = const Color(0xFFFBBF24);
    } else {
      badgeBg = const Color(0xFFDCFCE7);
      badgeText = const Color(0xFF16A34A);
      badgeLabel = 'STOCK ÓPTIMO';
      badgeIcon = Icons.check_circle_rounded;
      borderColor = const Color(0xFFE5E7EB);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: critico || bajo ? 1.5 : 1.0),
        boxShadow: [
          BoxShadow(
            color: (critico ? const Color(0xFFDC2626) : (bajo ? const Color(0xFFD97706) : Colors.black)).withAlpha(critico || bajo ? 35 : 12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: SKU y Badge de Alerta
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.codigoSku,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: badgeText),
                    const SizedBox(width: 4),
                    Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: badgeText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Nombre del producto
          Text(
            item.nombreProducto,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Proveedor y Unidad de medida
          Row(
            children: [
              Icon(Icons.category_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                item.unidadMedida,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (item.proveedor != null && item.proveedor!.isNotEmpty) ...[
                const SizedBox(width: 12),
                Icon(Icons.business_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.proveedor!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Comparador de Stock Actual vs Mínimo
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stock Disponible',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${item.cantidadActual} ${item.unidadMedida.toLowerCase()}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: critico ? const Color(0xFFDC2626) : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Nivel Mínimo Requerido',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${item.stockMinimo} ${item.unidadMedida.toLowerCase()}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
