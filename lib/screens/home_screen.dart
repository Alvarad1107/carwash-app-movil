import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../models/vehiculo_patio.dart';
import '../models/servicio_extra_model.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'inventory_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiService = ApiService();

  bool _cargandoApi = false;
  bool _conectadoConApi = false;
  String _perfilNombre = 'Cargando...';
  String _perfilRol = '';
  String _perfilCorreo = '';

  int _selectedIndex = 0;
  String _busqueda = '';
  String _filtroControl = 'Todos';

  double _totalComisionesOperarios = 0.0;
  double _totalCobradoHoy = 0.0;
  int _cantidadLavadosComision = 0;

  // Listas en memoria RAM para autocompletado predictivo instantáneo
  List<dynamic> _listaClientesLocal = [];
  List<dynamic> _listaVehiculosLocal = [];

  static const List<IconData> _iconosFase = [
    Icons.hourglass_top_rounded,
    Icons.autorenew_rounded,
    Icons.check_circle_rounded,
  ];

  List<VehiculoPatio> _vehiculos = [];

  /// Determina si una bahía está ocupada por un vehículo en proceso o pendiente
  bool _bahiaOcupada(int numero) {
    return _vehiculos.any((v) =>
        (v.bahia == 'Bahia $numero' || v.bahia == 'Bahía $numero') &&
        (v.fase == 1 || v.fase == 0));
  }

  /// Busca de forma inteligente la primera bahía libre (1 a 6) para evitar bloqueos
  int? _primeraBahiaLibre() {
    for (int i = 1; i <= AppConstants.totalBahias; i++) {
      if (!_bahiaOcupada(i)) return i;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _cargarDatosPerfil();
    _obtenerDatosDeApi();
  }

  Future<void> _cargarDatosPerfil() async {
    final perfil = await _apiService.getPerfilData();
    setState(() {
      _perfilNombre = perfil['nombre']!;
      _perfilRol = perfil['rol']!;
      _perfilCorreo = perfil['correo']!;
    });
  }

  Future<void> _obtenerDatosDeApi({bool mostrarMensaje = false}) async {
    setState(() => _cargandoApi = true);
    try {
      final result = await _apiService.obtenerDatosPatio();

      // Cargar directorio de clientes y vehículos para autocompletado en memoria RAM
      final directorio = await _apiService.obtenerDirectorio();

      if (result['success'] == true) {
        setState(() {
          _vehiculos = result['vehiculos'];
          _totalCobradoHoy = result['totalCobradoHoy'];
          _totalComisionesOperarios = result['totalComisionesOperarios'];
          _cantidadLavadosComision = result['cantidadLavadosComision'];
          _listaClientesLocal = directorio['clientes'] ?? [];
          _listaVehiculosLocal = directorio['vehiculos'] ?? [];
          _conectadoConApi = true;
        });

        if (mostrarMensaje && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF15803D),
              content: Text('Sincronizado en tiempo real con VPS de Sprint Wash'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${result['error']}'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      setState(() => _conectadoConApi = false);
      if (mostrarMensaje && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.warning,
            content: Text('Sin conexión a ${_apiService.apiUrl}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoApi = false);
    }
  }

  Future<void> _cambiarEstado(VehiculoPatio v, int nuevaFase) async {
    try {
      final success = await _apiService.cambiarEstadoOrden(
        v.ordenId,
        AppConstants.estadosApi[nuevaFase],
      );

      if (success) {
        setState(() => v.fase = nuevaFase);
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.coloresFase[v.fase],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              v.fase == 2
                  ? '${v.nombreCompletoCarro} (${v.placa}) -> LISTO PARA ENTREGA\nPre-factura enviada'
                  : '${v.nombreCompletoCarro} (${v.placa}) -> ${AppConstants.nombresFase[v.fase].toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión')),
        );
      }
    }
  }

  Future<void> _abrirModalCobro(VehiculoPatio v) async {
    if (v.fase != 2) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ No se permite cobrar: El vehículo aún no está finalizado.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    String metodoSeleccionado = 'Efectivo';
    bool seleccionoDosOperarios = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Cobrar Orden #${v.ordenId} (${v.placa})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cliente: ${v.cliente}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text(
                    'Total a cobrar: ${v.totalPagar}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.kRoyalBlue),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: metodoSeleccionado,
                    decoration: const InputDecoration(labelText: 'Método de Pago', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                      DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta')),
                      DropdownMenuItem(value: 'Transferencia', child: Text('Transferencia / QR')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => metodoSeleccionado = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lavado Simultáneo (2 Operarios)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Divide automáticamente la comisión en planilla', style: TextStyle(fontSize: 11.5)),
                    value: seleccionoDosOperarios,
                    onChanged: (val) => setDialogState(() => seleccionoDosOperarios = val),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final resPago = await _apiService.registrarPago(
                        ordenId: v.ordenId,
                        metodoPago: metodoSeleccionado,
                        monto: v.montoNumerico,
                      );

                      if (resPago['success'] != true) {
                        if (context.mounted) Navigator.pop(context);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${resPago['error']}'), backgroundColor: Colors.redAccent),
                          );
                        }
                        return;
                      }

                      await _apiService.asignarOperarios(
                        ordenId: v.ordenId,
                        dosOperarios: seleccionoDosOperarios,
                      );

                      if (context.mounted) Navigator.pop(context);
                      await _obtenerDatosDeApi(mostrarMensaje: true);
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Error de conexión')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirmar Cobro'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Modal de Recepción de Vehículo refactorizado con autocompletado predictivo de placas y clientes,
  /// catálogo oficial actualizado, servicios extras, teléfono obligatorio y asignación inteligente de bahías.
  void _abrirModalRecepcion() {
    // Asignación inteligente: buscar primera bahía libre entre las 6 disponibles
    final int? bahiaLibre = _primeraBahiaLibre();
    if (bahiaLibre == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Todas las bahías (1 a 6) están ocupadas. No es posible recibir más vehículos hasta que se libere una bahía.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Variables de control de duplicados y autocompletado
    int? vehiculoIdExistente;
    int? clienteIdExistente;

    // Controladores de texto
    TextEditingController? placaInputCtrl;
    TextEditingController? clienteInputCtrl;
    final marcaCtrl = TextEditingController();
    final modeloCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();

    // Catálogo de categorías oficiales:
    // Motocicleta ($1.50) [6], Sedán ($4.00) [1], Pick Up ($8.00) [2],
    // Carros Medianos ($6.00) [3], Carros Grandes ($8.00) [4], Microbús ($10.00) [5]
    int categoriaIdSeleccionada = 1;

    // Catálogo oficial de servicios adicionales (Extras)
    final List<ServicioExtraModel> extras = ServicioExtraModel.obtenerListaDefecto();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Cálculo dinámico de totales estimados en vivo
            final double precioBaseEst = ApiService.precioBaseCategoria(categoriaIdSeleccionada);
            final double totalExtrasEst = extras.where((e) => e.seleccionado).fold(0.0, (acc, e) => acc + e.precio);
            final double subtotalEst = precioBaseEst + totalExtrasEst;
            final double totalConIvaEst = subtotalEst * 1.13;

            return Padding(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Título y Bahía Inteligente Asignada
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recepción de Vehículo',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.meeting_room_rounded, size: 14, color: Color(0xFF15803D)),
                              const SizedBox(width: 4),
                              Text(
                                'Bahía $bahiaLibre (Libre)',
                                style: const TextStyle(
                                  color: Color(0xFF15803D),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Badges informativos de autocompletado si se detectó registro existente
                    if (vehiculoIdExistente != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF15803D)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Vehículo existente (#$vehiculoIdExistente) - No se duplicará en base de datos',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (clienteIdExistente != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF93C5FD)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_pin_rounded, size: 15, color: AppColors.kRoyalBlue),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Cliente existente (#$clienteIdExistente) - El nuevo auto se asociará a este cliente',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Autocompletado de Placa (Widget nativo Autocomplete) y Color
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Autocomplete<Map<String, dynamic>>(
                            displayStringForOption: (option) => (option['placa'] ?? '').toString(),
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.trim().isEmpty) {
                                return const Iterable<Map<String, dynamic>>.empty();
                              }
                              final query = textEditingValue.text.trim().toUpperCase();
                              return _listaVehiculosLocal.where((v) {
                                final placa = (v['placa'] ?? '').toString().toUpperCase();
                                return placa.contains(query);
                              }).cast<Map<String, dynamic>>();
                            },
                            onSelected: (Map<String, dynamic> vehiculo) {
                              setModalState(() {
                                vehiculoIdExistente = vehiculo['id'];
                                marcaCtrl.text = (vehiculo['marca'] ?? '').toString();
                                modeloCtrl.text = (vehiculo['modelo'] ?? '').toString();
                                colorCtrl.text = (vehiculo['color'] ?? '').toString();

                                final catId = vehiculo['categoria_vehiculo_id'];
                                if (catId != null && (catId == 1 || catId == 2 || catId == 3 || catId == 4 || catId == 5 || catId == 6)) {
                                  categoriaIdSeleccionada = catId;
                                }

                                // Buscar automáticamente al cliente dueño en la lista local de clientes
                                final clienteId = vehiculo['cliente_id'];
                                if (clienteId != null) {
                                  final cliente = _listaClientesLocal.firstWhere(
                                    (c) => c['id'] == clienteId,
                                    orElse: () => null,
                                  );
                                  if (cliente != null) {
                                    clienteIdExistente = cliente['id'];
                                    clienteInputCtrl?.text = (cliente['nombre_completo'] ?? '').toString();
                                    telefonoCtrl.text = (cliente['telefono'] ?? '').toString();
                                  }
                                }
                              });
                            },
                            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                              placaInputCtrl = textEditingController;
                              return TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                textCapitalization: TextCapitalization.characters,
                                onChanged: (val) {
                                  if (vehiculoIdExistente != null) {
                                    setModalState(() => vehiculoIdExistente = null);
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: 'Placa (ej. P123456) *',
                                  hintText: 'Escribe para buscar...',
                                  prefixIcon: const Icon(Icons.credit_card_rounded, size: 20),
                                  suffixIcon: vehiculoIdExistente != null
                                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18)
                                      : null,
                                  border: const OutlineInputBorder(),
                                ),
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 6,
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white,
                                  child: Container(
                                    width: MediaQuery.of(context).size.width - 44,
                                    constraints: const BoxConstraints(maxHeight: 180),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE5E7EB)),
                                    ),
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                                      itemBuilder: (context, index) {
                                        final opt = options.elementAt(index);
                                        final String p = (opt['placa'] ?? '').toString();
                                        final String m = (opt['marca'] ?? '').toString();
                                        final String mod = (opt['modelo'] ?? '').toString();
                                        return InkWell(
                                          onTap: () => onSelected(opt),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF3F4F6),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: const Color(0xFFD1D5DB)),
                                                  ),
                                                  child: Text(
                                                    p,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    '$m $mod'.trim(),
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: colorCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Color (ej. Rojo)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Marca y Modelo
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: marcaCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Marca (ej. Toyota)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: modeloCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Modelo (ej. Corolla)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Catálogo de Categorías Actualizado según tabla oficial
                    DropdownButtonFormField<int>(
                      value: categoriaIdSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Categoría de Vehículo',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 6,
                          child: Text('Motocicleta (\$1.50)'),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text('Sedán (\$4.00)'),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text('Pick Up (\$8.00)'),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text('Carros Medianos (\$6.00)'),
                        ),
                        DropdownMenuItem(
                          value: 4,
                          child: Text('Carros Grandes (\$8.00)'),
                        ),
                        DropdownMenuItem(
                          value: 5,
                          child: Text('Microbús (\$10.00)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => categoriaIdSeleccionada = val);
                      },
                    ),
                    const SizedBox(height: 10),

                    // Autocompletado de Cliente (Widget nativo Autocomplete)
                    Autocomplete<Map<String, dynamic>>(
                      displayStringForOption: (option) => (option['nombre_completo'] ?? '').toString(),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.trim().isEmpty) {
                          return const Iterable<Map<String, dynamic>>.empty();
                        }
                        final query = textEditingValue.text.trim().toLowerCase();
                        return _listaClientesLocal.where((c) {
                          final nombre = (c['nombre_completo'] ?? '').toString().toLowerCase();
                          return nombre.contains(query);
                        }).cast<Map<String, dynamic>>();
                      },
                      onSelected: (Map<String, dynamic> cliente) {
                        setModalState(() {
                          clienteIdExistente = cliente['id'];
                          if (cliente['telefono'] != null && cliente['telefono'].toString().trim().isNotEmpty) {
                            telefonoCtrl.text = cliente['telefono'].toString();
                          }
                        });
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        clienteInputCtrl = textEditingController;
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          onChanged: (val) {
                            if (clienteIdExistente != null) {
                              setModalState(() => clienteIdExistente = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Nombre del Cliente *',
                            hintText: 'Buscar o escribir cliente...',
                            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                            suffixIcon: clienteIdExistente != null
                                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18)
                                : null,
                            border: const OutlineInputBorder(),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 6,
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                            child: Container(
                              width: MediaQuery.of(context).size.width - 44,
                              constraints: const BoxConstraints(maxHeight: 180),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                shrinkWrap: true,
                                itemCount: options.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                                itemBuilder: (context, index) {
                                  final opt = options.elementAt(index);
                                  final String nombre = (opt['nombre_completo'] ?? '').toString();
                                  final String tel = (opt['telefono'] ?? '').toString();
                                  return InkWell(
                                    onTap: () => onSelected(opt),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      child: Row(
                                        children: [
                                          const CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Color(0xFFEFF6FF),
                                            child: Icon(Icons.person, size: 14, color: AppColors.kRoyalBlue),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  nombre,
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                                ),
                                                if (tel.isNotEmpty)
                                                  Text(
                                                    'Tel: $tel',
                                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // Teléfono del Cliente (Campo Nuevo Obligatorio)
                    TextField(
                      controller: telefonoCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono del Cliente * (Obligatorio)',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        hintText: 'Ej. 7000-0000 o 5551234567',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Sección de Servicios Adicionales (Extras)
                    const Text(
                      'Servicios Adicionales (Extras):',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: extras.map((extra) {
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            title: Text(
                              extra.nombre,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '+\$${extra.precio.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.kRoyalBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            value: extra.seleccionado,
                            activeColor: AppColors.kRoyalBlue,
                            onChanged: (bool? val) {
                              setModalState(() {
                                extra.seleccionado = val ?? false;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Resumen de Precio Estimado (Base + Extras + IVA 13%)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Base: \$${precioBaseEst.toStringAsFixed(2)} + Extras: \$${totalExtrasEst.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              Text(
                                'Subtotal: \$${subtotalEst.toStringAsFixed(2)} (IVA: 13%)',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                          Text(
                            '\$${totalConIvaEst.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.kRoyalBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Botón de Envío
                    ElevatedButton.icon(
                      onPressed: () async {
                        final String placa = (placaInputCtrl?.text ?? '').trim().toUpperCase();
                        final String nombreCli = (clienteInputCtrl?.text ?? '').trim();
                        final String telefonoCli = telefonoCtrl.text.trim();

                        // Validaciones estrictas
                        if (placa.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('⚠️ La placa del vehículo es obligatoria.'),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        if (nombreCli.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('⚠️ El nombre del cliente es obligatorio.'),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        if (telefonoCli.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('⚠️ El teléfono del cliente es obligatorio.'),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        final marca = marcaCtrl.text.trim().isEmpty ? 'Toyota' : marcaCtrl.text.trim();
                        final modelo = modeloCtrl.text.trim().isEmpty ? 'Corolla' : modeloCtrl.text.trim();
                        final color = colorCtrl.text.trim().isEmpty ? 'Gris' : colorCtrl.text.trim();

                        final List<double> extrasPrecios = extras
                            .where((e) => e.seleccionado)
                            .map((e) => e.precio)
                            .toList();
                        final List<int> extrasIds = extras
                            .where((e) => e.seleccionado)
                            .map((e) => e.id)
                            .toList();

                        final result = await _apiService.recibirVehiculo(
                          clienteIdExistente: clienteIdExistente,
                          vehiculoIdExistente: vehiculoIdExistente,
                          placa: placa,
                          marca: marca,
                          modelo: modelo,
                          color: color,
                          nombreCliente: nombreCli,
                          telefonoCliente: telefonoCli,
                          categoriaId: categoriaIdSeleccionada,
                          bahiaId: bahiaLibre,
                          extras: extrasPrecios,
                          extrasIds: extrasIds,
                        );

                        if (result['success'] != true && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${result['error']}'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }

                        if (context.mounted) Navigator.pop(context);
                        await _obtenerDatosDeApi(mostrarMensaje: true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kRoyalBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.add_task_rounded),
                      label: Text(
                        'Registrar en Bahía $bahiaLibre (Pendiente)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // El botón flotante de recepción solo se muestra en la pestaña de Patio
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _abrirModalRecepcion,
              backgroundColor: AppColors.kRoyalBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Recibir', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildPantallaInicio(),
            _buildPantallaControlPatio(),
            const InventoryScreen(),
            _buildPantallaPerfil(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.kRoyalBlue,
          unselectedItemColor: AppColors.textHint,
          selectedFontSize: 11.5,
          unselectedFontSize: 11.5,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: _IconoBarraInferior(icono: Icons.home_outlined, activo: _selectedIndex == 0),
              label: 'Patio',
            ),
            BottomNavigationBarItem(
              icon: _IconoBarraInferior(icono: Icons.payments_outlined, activo: _selectedIndex == 1),
              label: 'Cobros',
            ),
            BottomNavigationBarItem(
              icon: _IconoBarraInferior(icono: Icons.inventory_2_outlined, activo: _selectedIndex == 2),
              label: 'Inventario',
            ),
            BottomNavigationBarItem(
              icon: _IconoBarraInferior(icono: Icons.person_outline_rounded, activo: _selectedIndex == 3),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  // ─── PESTAÑA 0: PATIO ─────────────────────────────────────

  Widget _buildPantallaInicio() {
    final totalBahias = AppConstants.totalBahias;
    final ocupadas = List.generate(totalBahias, (i) => _bahiaOcupada(i + 1)).where((b) => b).length;
    final libres = totalBahias - ocupadas;

    final vehiculosFiltrados = _vehiculos.where((v) {
      if (_busqueda.isEmpty) return true;
      final q = _busqueda.toLowerCase();
      return v.placa.toLowerCase().contains(q) ||
          v.nombreCompletoCarro.toLowerCase().contains(q) ||
          v.cliente.toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: () => _obtenerDatosDeApi(mostrarMensaje: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Operaciones de Patio', style: TextStyle(fontSize: 18, color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                IconButton(
                  onPressed: () => _obtenerDatosDeApi(mostrarMensaje: true),
                  icon: _cargandoApi
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.sync_rounded, color: _conectadoConApi ? AppColors.success : AppColors.textMuted),
                  tooltip: 'Sincronizar con API',
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (valor) => setState(() => _busqueda = valor),
              decoration: InputDecoration(
                hintText: 'Buscar vehículo por placa o cliente...',
                hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfaceGrey,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 18),

            // Card de bahías
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1424B8), AppColors.kRoyalBlueDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: AppColors.kRoyalBlue.withAlpha(55), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estado de bahías', style: TextStyle(color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w500)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF228B22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text('$libres libres', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('$ocupadas ocupadas', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  Row(
                    children: List.generate(totalBahias, (i) {
                      final ocupada = _bahiaOcupada(i + 1);
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(right: i < totalBahias - 1 ? 6 : 0),
                          height: 46,
                          decoration: BoxDecoration(
                            color: ocupada ? AppColors.bahiaOcupada : AppColors.bahiaLibre,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text('B${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Lista de vehículos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Vehículos en Patio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                GestureDetector(
                  onTap: () => setState(() => _selectedIndex = 1),
                  child: const Text('Ver Cobros e Historial', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.kRoyalBlue)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...vehiculosFiltrados.map((v) => _buildVehiculoCard(v)),
          ],
        ),
      ),
    );
  }

  Widget _buildVehiculoCard(VehiculoPatio v) {
    final color = AppColors.coloresFase[v.fase];
    final fondo = AppColors.fondosFase[v.fase];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 1.6),
        boxShadow: [BoxShadow(color: color.withAlpha(70), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(v.placa, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${v.nombreCompletoCarro} • ${v.categoria}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      '${v.bahia} • ${v.totalPagar} ${v.pagado ? "(PAGADO)" : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: v.pagado ? FontWeight.bold : FontWeight.normal,
                        color: v.pagado ? AppColors.success : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(10)),
                child: Text(AppConstants.nombresFase[v.fase], style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Cliente: ${v.cliente} (${v.telefonoCliente})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Row(
            children: List.generate(3, (i) {
              final activo = v.fase == i;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  child: ElevatedButton(
                    onPressed: () => _cambiarEstado(v, i),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activo ? AppColors.coloresFase[i] : AppColors.fondosFase[i],
                      foregroundColor: activo ? Colors.white : AppColors.coloresFase[i],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: activo ? 2 : 0,
                    ),
                    child: Text(AppConstants.nombresFase[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── PESTAÑA 1: COBROS E HISTORIAL ────────────────────────

  Widget _buildPantallaControlPatio() {
    final tabs = ['Todos', ...AppConstants.nombresFase];
    final filtrados = _vehiculos.where((v) {
      if (_filtroControl == 'Todos') return true;
      return AppConstants.nombresFase[v.fase] == _filtroControl;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BotonIconoBorde(icono: Icons.chevron_left_rounded, onTap: () => setState(() => _selectedIndex = 0)),
              const Text('Cobros e Historial', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              _BotonIconoBorde(icono: Icons.sync_rounded, onTap: () => _obtenerDatosDeApi(mostrarMensaje: true)),
            ],
          ),
          const SizedBox(height: 18),

          // Cards de resumen
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.fondosFase[2], borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MI COMISIÓN (PLANILLA)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.successDark)),
                      const SizedBox(height: 4),
                      Text('\$${_totalComisionesOperarios.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.successDark)),
                      Text('$_cantidadLavadosComision servicios asignados', style: const TextStyle(fontSize: 11, color: AppColors.successText)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.fondosFase[1], borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CAJA DIARIA COBRADA', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.kRoyalBlue)),
                      const SizedBox(height: 4),
                      Text('\$${_totalCobradoHoy.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.kRoyalBlue)),
                      Text('${_vehiculos.length} órdenes registradas', style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filtros
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.surfaceGrey, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: tabs.map((t) {
                final activo = _filtroControl == t;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _filtroControl = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: activo ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                          color: activo ? AppColors.kRoyalBlue : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Historial de Servicios y Registro de Cobro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Text('Toca "Cobrar" para registrar el pago y calcular comisión en planilla', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
          const SizedBox(height: 12),
          ...filtrados.map((v) => _buildFilaOrden(v)),
        ],
      ),
    );
  }

  Widget _buildFilaOrden(VehiculoPatio v) {
    final color = AppColors.coloresFase[v.fase];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: AppColors.fondosFase[v.fase], borderRadius: BorderRadius.circular(12)),
            child: Icon(_iconosFase[v.fase], color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${v.placa} • ${v.nombreCompletoCarro} (${v.categoria})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('${AppConstants.nombresFase[v.fase]} • ${v.cliente}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(v.totalPagar, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => _abrirModalCobro(v),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: v.pagado ? AppColors.success : AppColors.kRoyalBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    v.pagado ? 'PAGADO' : 'Cobrar',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── PESTAÑA 3: PERFIL ────────────────────────────────────

  Widget _buildPantallaPerfil() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mi perfil', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 20),

          // Tarjeta de perfil
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.surfaceGrey, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: AppColors.kRoyalBlue, borderRadius: BorderRadius.circular(18)),
                  alignment: Alignment.center,
                  child: Text(
                    _perfilNombre.length >= 2 ? _perfilNombre.substring(0, 2).toUpperCase() : 'US',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_perfilNombre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(_perfilRol, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.kRoyalBlue)),
                      const SizedBox(height: 2),
                      Text(_perfilCorreo, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // Botón cerrar sesión
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () async {
                await _apiService.logout();
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: AppColors.errorBg,
                foregroundColor: AppColors.errorText,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── WIDGETS AUXILIARES ─────────────────────────────────────

class _BotonIconoBorde extends StatelessWidget {
  final IconData icono;
  final VoidCallback onTap;

  const _BotonIconoBorde({required this.icono, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icono, size: 22),
      ),
    );
  }
}

class _IconoBarraInferior extends StatelessWidget {
  final IconData icono;
  final bool activo;

  const _IconoBarraInferior({required this.icono, required this.activo});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 2.5,
          margin: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(
            color: activo ? AppColors.kRoyalBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Icon(icono, size: 24),
      ],
    );
  }
}
