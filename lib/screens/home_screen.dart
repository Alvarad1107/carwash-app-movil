import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../models/vehiculo_patio.dart';
import '../models/servicio_extra_model.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'inventory_screen.dart';

/// Formateador para cuerpo de placa salvadoreña: solo alfanuméricos en mayúscula (máx. 6).
class _CuerpoPlacaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final limpio =
        newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final truncado = limpio.length > 6 ? limpio.substring(0, 6) : limpio;
    return TextEditingValue(
      text: truncado,
      selection: TextSelection.collapsed(offset: truncado.length),
    );
  }
}

/// Formateador automático de teléfono salvadoreño: 8 dígitos con máscara 0000-0000.
class _TelefonoSVInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    final truncado = digitos.length > 8 ? digitos.substring(0, 8) : digitos;
    String formateado;
    if (truncado.length > 4) {
      formateado = '${truncado.substring(0, 4)}-${truncado.substring(4)}';
    } else {
      formateado = truncado;
    }
    return TextEditingValue(
      text: formateado,
      selection: TextSelection.collapsed(offset: formateado.length),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiService = ApiService();

  bool _cargandoApi = false;
  bool _conectadoConApi = false;
  int _perfilUsuarioId = 0;
  String _perfilNombre = 'Cargando...';
  String _perfilRol = '';
  String _perfilCorreo = '';

  int _selectedIndex = 0;
  String _busqueda = '';
  String _filtroControl = 'Todos';

  double _totalComisionesOperarios = 0.0;
  int _cantidadLavadosComision = 0;
  int _lavadosTerminadosHoy = 0;
  int _vehiculosEnPatio = 0;

  // Estado de horario oficial de recepción en El Salvador desde GET /ordenes/estado-horario
  bool _recepcionAbierta = true;
  bool _enVentanaProrroga = false;
  String _horaSv = '';
  String _mensajeHorario = '';

  // Catálogos y listas en memoria RAM sincronizadas 100% desde la API REST
  List<dynamic> _listaClientesLocal = [];
  List<dynamic> _listaVehiculosLocal = [];
  List<dynamic> _bahiasApi = [];
  List<Map<String, dynamic>> _categoriasApi = [];
  List<Map<String, dynamic>> _serviciosBaseApi = [];
  List<ServicioExtraModel> _serviciosAdicionalesApi = [];
  List<Map<String, dynamic>> _operariosActivos = [];
  Set<int> _ordenesComisionadasIds = {};

  static const List<IconData> _iconosFase = [
    Icons.hourglass_top_rounded,
    Icons.autorenew_rounded,
    Icons.check_circle_rounded,
  ];

  List<VehiculoPatio> _vehiculos = [];

  /// Determina si una bahía está en estado "Mantenimiento" según GET /bahias/
  bool _bahiaEnMantenimiento(int numero) {
    for (final b in _bahiasApi) {
      final int bid = int.tryParse(b['id']?.toString() ?? '0') ?? 0;
      if (bid == numero) {
        final String est = (b['estado'] ?? '').toString().toLowerCase();
        return est.contains('mantenimiento');
      }
    }
    return false;
  }

  /// Determina si una bahía está ocupada por un vehículo en proceso o pendiente hoy
  bool _bahiaOcupada(int numero) {
    return _vehiculos.any((v) =>
        (v.bahiaId == numero ||
            v.bahia == 'Bahia $numero' ||
            v.bahia == 'Bahía $numero') &&
        (v.fase == 1 || v.fase == 0));
  }

  /// Busca de forma inteligente la primera bahía libre según las bahías reales de GET /bahias/
  int? _primeraBahiaLibre() {
    if (_bahiasApi.isNotEmpty) {
      for (final b in _bahiasApi) {
        final int bid = int.tryParse(b['id']?.toString() ?? '0') ?? 0;
        if (bid > 0 && !_bahiaOcupada(bid) && !_bahiaEnMantenimiento(bid)) {
          return bid;
        }
      }
      return null;
    }
    for (int i = 1; i <= AppConstants.totalBahias; i++) {
      if (!_bahiaOcupada(i) && !_bahiaEnMantenimiento(i)) return i;
    }
    return null;
  }

  /// Busca si una placa ya tiene una orden activa en patio (Pendiente o En proceso)
  VehiculoPatio? _buscarOrdenActivaPorPlaca(String placaCompleta) {
    final norm = ApiService.normalizarPlacaSV(placaCompleta);
    for (final v in _vehiculos) {
      if ((v.fase == 0 || v.fase == 1) &&
          ApiService.normalizarPlacaSV(v.placa) == norm) {
        return v;
      }
    }
    return null;
  }

  /// Formatea cualquier teléfono a 0000-0000 si tiene 8 dígitos
  String _formatearTelefonoSV(String raw) {
    final digitos = raw.replaceAll(RegExp(r'\D'), '');
    if (digitos.length >= 8) {
      final d8 = digitos.substring(digitos.length - 8);
      return '${d8.substring(0, 4)}-${d8.substring(4)}';
    }
    return raw.trim();
  }

  @override
  void initState() {
    super.initState();
    _cargarDatosPerfil();
    _obtenerDatosDeApi();
  }

  Future<void> _cargarDatosPerfil() async {
    final perfil = await _apiService.getPerfilData();
    if (!mounted) return;
    setState(() {
      _perfilUsuarioId = (perfil['usuario_id'] as int?) ?? 0;
      _perfilNombre = (perfil['nombre'] ?? 'Usuario').toString();
      _perfilRol = (perfil['rol'] ?? 'Sin Rol').toString();
      _perfilCorreo = (perfil['correo'] ?? 'Sin Correo').toString();
    });
  }

  Future<void> _obtenerDatosDeApi({bool mostrarMensaje = false}) async {
    setState(() => _cargandoApi = true);
    try {
      // Candado de seguridad: verificar si el usuario fue desactivado o cambiado de rol por el Administrador
      final activo = await _apiService.verificarUsuarioActivo(context);
      if (!activo || !mounted) return;

      final result = await _apiService.obtenerDatosPatio();
      if (!mounted) return;

      if (result['usuarioInactivo'] == true) {
        await _apiService.verificarUsuarioActivo(context);
        return;
      }

      if (result['success'] == true) {
        setState(() {
          _vehiculos = result['vehiculos'] as List<VehiculoPatio>;
          _lavadosTerminadosHoy = (result['lavadosTerminadosHoy'] as int?) ?? 0;
          _vehiculosEnPatio = (result['vehiculosEnPatio'] as int?) ?? 0;
          _totalComisionesOperarios =
              (result['totalComisionesOperarios'] as num?)?.toDouble() ?? 0.0;
          _cantidadLavadosComision =
              (result['cantidadLavadosComision'] as int?) ?? 0;
          _ordenesComisionadasIds =
              (result['ordenesComisionadasIds'] as Set<int>?) ?? {};
          _operariosActivos =
              (result['operariosActivos'] as List<Map<String, dynamic>>?) ?? [];
          _bahiasApi = (result['bahias'] as List<dynamic>?) ?? [];
          _categoriasApi =
              (result['categorias'] as List<Map<String, dynamic>>?) ?? [];
          _serviciosBaseApi =
              (result['serviciosBase'] as List<Map<String, dynamic>>?) ?? [];
          _serviciosAdicionalesApi =
              (result['serviciosAdicionales'] as List<ServicioExtraModel>?) ??
                  [];
          _listaClientesLocal =
              (result['clientesDirectorio'] as List<dynamic>?) ?? [];
          _listaVehiculosLocal =
              (result['vehiculosDirectorio'] as List<dynamic>?) ?? [];
          _recepcionAbierta = (result['recepcionAbierta'] as bool?) ?? true;
          _enVentanaProrroga = (result['enVentanaProrroga'] as bool?) ?? false;
          _horaSv = (result['horaSv'] ?? '').toString();
          _mensajeHorario = (result['mensajeHorario'] ?? '').toString();
          _conectadoConApi = true;
        });

        if (mostrarMensaje && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF15803D),
              content:
                  Text('Sincronizado en tiempo real con VPS de Sprint Wash'),
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
      if (mounted) setState(() => _conectadoConApi = false);
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

  /// Muestra el AlertDialog de confirmación obligatoria (TDR 4.1 y 4.4)
  /// antes de avanzar el estado de la orden de forma unidireccional (0 -> 1 -> 2).
  Future<void> _confirmarCambioEstado(VehiculoPatio v, int nuevaFase) async {
    // Regla de flujo secuencial estricto de un paso a la vez
    if (nuevaFase != v.fase + 1) return;

    final String titulo = nuevaFase == 1
        ? 'Confirmar inicio de lavado'
        : 'Confirmar lavado terminado';
    final String mensaje = nuevaFase == 1
        ? '¿Iniciar lavado de ${v.placa} en ${v.bahia}?'
        : '¿Marcar lavado de ${v.placa} como TERMINADO? Se liberará la ${v.bahia} y se enviará automáticamente el correo con la pre-factura al cliente.';

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(
              nuevaFase == 1
                  ? Icons.play_circle_fill_rounded
                  : Icons.check_circle_rounded,
              color: AppColors.coloresFase[nuevaFase],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                titulo,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          mensaje,
          style: const TextStyle(
              fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coloresFase[nuevaFase],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(nuevaFase == 1 ? 'Sí, iniciar' : 'Sí, terminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _cambiarEstado(v, nuevaFase);
    }
  }

  Future<void> _cambiarEstado(VehiculoPatio v, int nuevaFase) async {
    if (nuevaFase != v.fase + 1) return;
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              v.fase == 2
                  ? '${v.nombreCompletoCarro} (${v.placa}) -> LISTO PARA ENTREGA\nBahía liberada y pre-factura enviada'
                  : '${v.nombreCompletoCarro} (${v.placa}) -> ${AppConstants.nombresFase[v.fase].toUpperCase()}',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        await _obtenerDatosDeApi();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error de conexión al actualizar estado')),
        );
      }
    }
  }

  /// Posponer una orden Pendiente para mañana a primera hora (07:00 AM SV).
  /// Solo permitido 1 vez por orden para liberar la bahía física de hoy.
  Future<void> _confirmarPosponerOrden(VehiculoPatio v) async {
    if (v.fase != 0 || v.vecesPospuesta >= 1) return;

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.event_repeat_rounded, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Posponer orden para mañana',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Posponer la orden #${v.ordenId} (${v.placa}) para mañana a las 07:00 AM?\n\n'
          '• Se liberará la ${v.bahia} en el turno de hoy.\n'
          '• Esta acción solo se permite realizar 1 vez por orden.',
          style: const TextStyle(
            fontSize: 13.5,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sí, posponer (1/1)'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final res = await _apiService.posponerOrden(v.ordenId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Orden #${v.ordenId} (${v.placa}) pospuesta para mañana a las 7:00 AM. ${v.bahia} liberada hoy.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      await _obtenerDatosDeApi();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          content: Text('Error: ${res['error']}'),
        ),
      );
    }
  }

  /// Cancela una orden en estado Pendiente y libera su bahía física hoy.
  Future<void> _confirmarCancelarOrden(VehiculoPatio v) async {
    if (v.fase != 0) return;

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cancelar orden de lavado',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Cancelar la orden #${v.ordenId} (${v.placa})?\n\n'
          '• Se liberará la ${v.bahia} inmediatamente.\n'
          '• Solo se permite cancelar órdenes en estado Pendiente.\n'
          '• Esta acción es irreversible.',
          style: const TextStyle(
            fontSize: 13.5,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sí, cancelar orden'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final res = await _apiService.cancelarOrden(v.ordenId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Orden #${v.ordenId} (${v.placa}) cancelada correctamente. ${v.bahia} liberada.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      await _obtenerDatosDeApi();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          content: Text('Error: ${res['error']}'),
        ),
      );
    }
  }

  /// Modal para asignar 1 operario (Lavado Individual) o 2+ operarios (Lavado Simultáneo)
  /// a una orden terminada (fase == 2), respetando el candado de inmutabilidad.
  Future<void> _abrirModalAsignarOperarios(VehiculoPatio v) async {
    if (v.fase != 2) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Operación bloqueada: El lavado debe estar Terminado antes de asignar operarios.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (v.comisionada || _ordenesComisionadasIds.contains(v.ordenId)) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🔒 Comisión cerrada: La comisión de esta orden ya fue distribuida y es inmutable.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 100% API REST: Sin respaldos quemados de operarios
    final List<Map<String, dynamic>> operariosDisponibles = _operariosActivos;
    if (operariosDisponibles.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ No hay operarios activos disponibles en la API (/finanzas/usuarios).',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final Set<int> seleccionados = {};
    // Preseleccionar al operario logueado si está en la lista de operarios activos
    for (final op in operariosDisponibles) {
      final int opId = int.tryParse(op['id']?.toString() ?? '0') ?? 0;
      if (opId == _perfilUsuarioId && opId > 0) {
        seleccionados.add(opId);
      }
    }
    if (seleccionados.isEmpty && operariosDisponibles.isNotEmpty) {
      final int primerId =
          int.tryParse(operariosDisponibles.first['id']?.toString() ?? '0') ??
              0;
      if (primerId > 0) seleccionados.add(primerId);
    }

    bool enviando = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final bool esSimultaneo = seleccionados.length >= 2;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Asignar Operarios • Orden #${v.ordenId}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${v.placa} • ${v.nombreCompletoCarro} (${v.color} • ${v.categoria})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: esSimultaneo
                              ? const Color(0xFFDBEAFE)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              esSimultaneo
                                  ? Icons.groups_rounded
                                  : Icons.person_rounded,
                              size: 18,
                              color: esSimultaneo
                                  ? AppColors.kRoyalBlue
                                  : AppColors.successDark,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                seleccionados.isEmpty
                                    ? 'Selecciona al menos 1 operario activo'
                                    : esSimultaneo
                                        ? 'Lavado Simultáneo (${seleccionados.length} operarios: división equitativa automática)'
                                        : 'Lavado Individual (100% de comisión al operario)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: esSimultaneo
                                      ? AppColors.kRoyalBlue
                                      : AppColors.successDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Operarios Activos en Turno:',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: operariosDisponibles.map((op) {
                            final int opId =
                                int.tryParse(op['id']?.toString() ?? '0') ?? 0;
                            final String nombreOp =
                                (op['nombre_completo'] ?? 'Operario #$opId')
                                    .toString();
                            final bool marcado = seleccionados.contains(opId);

                            return CheckboxListTile(
                              dense: true,
                              activeColor: AppColors.kRoyalBlue,
                              value: marcado,
                              title: Text(
                                nombreOp,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                opId == _perfilUsuarioId
                                    ? 'Operario en sesión actual'
                                    : 'Operario activo',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textMuted),
                              ),
                              onChanged: enviando
                                  ? null
                                  : (val) {
                                      setDialogState(() {
                                        if (val == true) {
                                          seleccionados.add(opId);
                                        } else {
                                          seleccionados.remove(opId);
                                        }
                                      });
                                    },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Nota: Una vez cerrada la comisión en planilla, quedará bloqueada contra modificaciones.',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: enviando ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: (enviando || seleccionados.isEmpty)
                      ? null
                      : () async {
                          setDialogState(() => enviando = true);
                          final res = await _apiService.asignarOperarios(
                            ordenId: v.ordenId,
                            operariosIds: seleccionados.toList(),
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);

                          if (res['success'] == true) {
                            setState(() {
                              v.comisionada = true;
                              _ordenesComisionadasIds.add(v.ordenId);
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppColors.success,
                                  content: Text(
                                    'Comisión distribuida y cerrada en planilla correctamente',
                                  ),
                                ),
                              );
                            }
                            await _obtenerDatosDeApi();
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.redAccent,
                                  content: Text('Error: ${res['error']}'),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kRoyalBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Cerrar Comisión'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Modal de Recepción de Vehículo 100% conectado a la API REST:
  /// - Valida horario oficial de recepción en El Salvador (7:00 AM - 5:00 PM) y ventana 4:45 PM - 5:00 PM.
  /// - Selector de placa SV (19 prefijos + máx 6 alfanuméricos) y bloqueo de orden duplicada.
  /// - Catálogos dinámicos desde la API (Categorías, Servicios Base, Matriz de Precios y Extras).
  /// - Atajo rápido "Consumidor Final" y preservación del dueño titular del vehículo.
  void _abrirModalRecepcion() {
    // 1. Validar horario oficial de recepción en El Salvador (7:00 AM - 5:00 PM)
    if (!_recepcionAbierta) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _mensajeHorario.isNotEmpty
                ? '⛔ $_mensajeHorario'
                : '⛔ Recepción cerrada: El horario para recibir vehículos es de 7:00 AM a 5:00 PM.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final int? bahiaLibre = _primeraBahiaLibre();
    if (bahiaLibre == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Todas las bahías disponibles están ocupadas o en mantenimiento. Finaliza o pospone un lavado antes de recibir otro vehículo.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_categoriasApi.isEmpty || _serviciosBaseApi.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Sincronizando catálogos desde la API REST. Intenta de nuevo en unos segundos.',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _obtenerDatosDeApi();
      return;
    }

    int? vehiculoIdExistente;
    int? vehiculoClienteIdExistente;
    int? clienteIdExistente;

    String prefijoSeleccionado = 'P';
    TextEditingController? cuerpoPlacaCtrl;
    TextEditingController? clienteInputCtrl;
    final marcaCtrl = TextEditingController();
    final modeloCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final correoCtrl = TextEditingController();

    int categoriaIdSeleccionada =
        int.tryParse(_categoriasApi.first['id']?.toString() ?? '1') ?? 1;
    int servicioBaseIdSeleccionado =
        int.tryParse(_serviciosBaseApi.first['id']?.toString() ?? '1') ?? 1;

    final List<ServicioExtraModel> extras = _serviciosAdicionalesApi
        .map((e) => ServicioExtraModel(
              id: e.id,
              nombre: e.nombre,
              precio: e.precio,
              comisionExtra: e.comisionExtra,
              seleccionado: false,
            ))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final String cuerpoActual = (cuerpoPlacaCtrl?.text ?? '')
                .trim()
                .toUpperCase()
                .replaceAll(RegExp(r'[^A-Z0-9]'), '');
            final String placaCompletaActual = cuerpoActual.isNotEmpty
                ? '$prefijoSeleccionado-$cuerpoActual'
                : '';

            // Verificar si el vehículo ya tiene una orden activa en patio (fase 0 o 1)
            final VehiculoPatio? ordenActivaPatio =
                placaCompletaActual.isNotEmpty
                    ? _buscarOrdenActivaPorPlaca(placaCompletaActual)
                    : null;

            // Cálculo dinámico de precios según Matriz de la API + Extras + 13% IVA
            final double precioBaseEst = _apiService.obtenerPrecioMatriz(
              categoriaIdSeleccionada,
              servicioBaseIdSeleccionado,
            );
            final double totalExtrasEst = extras
                .where((e) => e.seleccionado)
                .fold(0.0, (acc, e) => acc + e.precio);
            final double subtotalEst = precioBaseEst + totalExtrasEst;
            final double totalConIvaEst = subtotalEst * 1.13;

            void sincronizarVehiculoPorPlaca(String placaCompleta) {
              final norm = ApiService.normalizarPlacaSV(placaCompleta);
              Map<String, dynamic>? encontrado;
              for (final v in _listaVehiculosLocal) {
                if (ApiService.normalizarPlacaSV(
                        (v['placa'] ?? '').toString()) ==
                    norm) {
                  encontrado = Map<String, dynamic>.from(v as Map);
                  break;
                }
              }
              if (encontrado != null) {
                vehiculoIdExistente = encontrado['id'];
                marcaCtrl.text = (encontrado['marca'] ?? '').toString();
                modeloCtrl.text = (encontrado['modelo'] ?? '').toString();
                final String colorBd = (encontrado['color'] ?? '').toString();
                colorCtrl.text =
                    (colorBd.toUpperCase() == 'N/A') ? '' : colorBd;

                final int? catId = int.tryParse(
                  encontrado['categoria_vehiculo_id']?.toString() ?? '',
                );
                if (catId != null &&
                    _categoriasApi.any((c) =>
                        (int.tryParse(c['id']?.toString() ?? '0') ?? 0) ==
                        catId)) {
                  categoriaIdSeleccionada = catId;
                }

                final clienteId = encontrado['cliente_id'];
                vehiculoClienteIdExistente =
                    int.tryParse(clienteId?.toString() ?? '');
                if (vehiculoClienteIdExistente != null) {
                  final cliente = _listaClientesLocal.firstWhere(
                    (c) => c['id'] == vehiculoClienteIdExistente,
                    orElse: () => null,
                  );
                  if (cliente != null) {
                    // Al elegir una placa, cargar siempre su cliente dueño con teléfono y correo
                    clienteIdExistente = cliente['id'];
                    clienteInputCtrl?.text =
                        (cliente['nombre_completo'] ?? '').toString();
                    telefonoCtrl.text = _formatearTelefonoSV(
                      (cliente['telefono'] ?? '').toString(),
                    );
                    correoCtrl.text = (cliente['correo'] ?? '').toString();
                  }
                }
              } else {
                vehiculoIdExistente = null;
                vehiculoClienteIdExistente = null;
              }
            }

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
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.meeting_room_rounded,
                                size: 14,
                                color: Color(0xFF15803D),
                              ),
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
                    const SizedBox(height: 10),

                    // Banner de advertencia en ventana 4:45 PM - 5:00 PM SV
                    if (_enVentanaProrroga)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 18,
                              color: Color(0xFFB45309),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Aviso ($_horaSv SV • 4:45 PM - 5:00 PM): Esta orden se programará automáticamente para mañana a las 7:00 AM.',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF92400E),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Alerta Roja Inmediata si el vehículo ya está en lavado en patio
                    if (ordenActivaPatio != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF87171)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.block_rounded,
                              size: 18,
                              color: Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Este vehículo ya está en lavado en ${ordenActivaPatio.bahia} (${AppConstants.nombresFase[ordenActivaPatio.fase]}).',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF991B1B),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (vehiculoIdExistente != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 15,
                              color: Color(0xFF15803D),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Vehículo registrado (#$vehiculoIdExistente • $placaCompletaActual)',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF166534),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Selector de Prefijo SV (19 opciones) + Cuerpo Alfanumérico (máx 6) + Color obligatorio
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 88,
                          child: DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: prefijoSeleccionado,
                            isDense: true,
                            decoration: const InputDecoration(
                              labelText: 'Prefijo',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 15),
                              border: OutlineInputBorder(),
                            ),
                            items: AppConstants.prefijosPlacaSV
                                .map(
                                  (p) => DropdownMenuItem<String>(
                                    value: p,
                                    child: Text(
                                      p,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  prefijoSeleccionado = val;
                                  final c = (cuerpoPlacaCtrl?.text ?? '')
                                      .trim()
                                      .toUpperCase();
                                  if (c.isNotEmpty) {
                                    sincronizarVehiculoPorPlaca(
                                        '$prefijoSeleccionado-$c');
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Autocomplete<Map<String, dynamic>>(
                            displayStringForOption: (option) {
                              final partes = ApiService.separarPlacaSV(
                                (option['placa'] ?? '').toString(),
                              );
                              return partes['cuerpo'] ?? '';
                            },
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                              final raw =
                                  textEditingValue.text.trim().toUpperCase();
                              if (raw.isEmpty) {
                                return const Iterable<
                                    Map<String, dynamic>>.empty();
                              }
                              return _listaVehiculosLocal.where((v) {
                                final placaNorm = ApiService.normalizarPlacaSV(
                                  (v['placa'] ?? '').toString(),
                                );
                                return placaNorm.contains(raw) ||
                                    placaNorm.replaceAll('-', '').contains(raw);
                              }).cast<Map<String, dynamic>>();
                            },
                            onSelected: (Map<String, dynamic> vehiculo) {
                              final partes = ApiService.separarPlacaSV(
                                (vehiculo['placa'] ?? '').toString(),
                              );
                              setModalState(() {
                                prefijoSeleccionado = partes['prefijo'] ?? 'P';
                                cuerpoPlacaCtrl?.text = partes['cuerpo'] ?? '';
                                sincronizarVehiculoPorPlaca(
                                  '${partes['prefijo'] ?? 'P'}-${partes['cuerpo'] ?? ''}',
                                );
                              });
                            },
                            fieldViewBuilder: (
                              context,
                              textEditingController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              cuerpoPlacaCtrl = textEditingController;
                              return TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                textCapitalization:
                                    TextCapitalization.characters,
                                inputFormatters: [_CuerpoPlacaInputFormatter()],
                                onChanged: (val) {
                                  setModalState(() {
                                    final limpio = val.trim().toUpperCase();
                                    if (limpio.isNotEmpty) {
                                      sincronizarVehiculoPorPlaca(
                                        '$prefijoSeleccionado-$limpio',
                                      );
                                    } else {
                                      vehiculoIdExistente = null;
                                    }
                                  });
                                },
                                decoration: InputDecoration(
                                  labelText: 'Placa (ej. 123456) *',
                                  hintText: '3 a 6 alfanum.',
                                  suffixIcon: vehiculoIdExistente != null
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF16A34A),
                                          size: 18,
                                        )
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
                                    width:
                                        MediaQuery.of(context).size.width - 140,
                                    constraints:
                                        const BoxConstraints(maxHeight: 180),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFFE5E7EB)),
                                    ),
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(
                                              height: 1,
                                              color: Color(0xFFF3F4F6)),
                                      itemBuilder: (context, index) {
                                        final opt = options.elementAt(index);
                                        final String p =
                                            ApiService.normalizarPlacaSV(
                                          (opt['placa'] ?? '').toString(),
                                        );
                                        final String m =
                                            (opt['marca'] ?? '').toString();
                                        final String mod =
                                            (opt['modelo'] ?? '').toString();
                                        final String col =
                                            (opt['color'] ?? '').toString();
                                        final activo =
                                            _buscarOrdenActivaPorPlaca(p) !=
                                                null;
                                        return InkWell(
                                          onTap: () => onSelected(opt),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 7,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: activo
                                                        ? const Color(
                                                            0xFFFEE2E2)
                                                        : const Color(
                                                            0xFFF3F4F6),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    border: Border.all(
                                                      color: activo
                                                          ? const Color(
                                                              0xFFF87171)
                                                          : const Color(
                                                              0xFFD1D5DB),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    p,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                      color: activo
                                                          ? const Color(
                                                              0xFFDC2626)
                                                          : AppColors
                                                              .textPrimary,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    activo
                                                        ? '$m $mod ($col • En lavado)'
                                                        : '$m $mod ($col)'
                                                            .trim(),
                                                    style: const TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
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
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: colorCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Color *',
                              hintText: 'Ej. Blanco',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Marca y Modelo obligatorios
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: marcaCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Marca *',
                              hintText: 'Ej. Toyota',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: modeloCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Modelo *',
                              hintText: 'Ej. Corolla',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Selector de Categoría de Vehículo 100% desde _categoriasApi
                    DropdownButtonFormField<int>(
                      // ignore: deprecated_member_use
                      value: categoriaIdSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Categoría de Vehículo (Tabla 5.1)',
                        border: OutlineInputBorder(),
                      ),
                      items: _categoriasApi.map((c) {
                        final int catId =
                            int.tryParse(c['id']?.toString() ?? '1') ?? 1;
                        final String nombreCat =
                            (c['nombre'] ?? 'Categoría #$catId').toString();
                        final double pBase = _apiService.obtenerPrecioMatriz(
                          catId,
                          servicioBaseIdSeleccionado,
                        );
                        return DropdownMenuItem<int>(
                          value: catId,
                          child: Text(
                              '$nombreCat (\$${pBase.toStringAsFixed(2)})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => categoriaIdSeleccionada = val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // Selector de Servicio Base 100% desde _serviciosBaseApi
                    DropdownButtonFormField<int>(
                      // ignore: deprecated_member_use
                      value: servicioBaseIdSeleccionado,
                      decoration: const InputDecoration(
                        labelText: 'Servicio Base (Tabla 5.1)',
                        prefixIcon:
                            Icon(Icons.local_car_wash_rounded, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      items: _serviciosBaseApi.map((sb) {
                        final int sbId =
                            int.tryParse(sb['id']?.toString() ?? '1') ?? 1;
                        final String sbNombre =
                            (sb['nombre'] ?? 'Servicio #$sbId').toString();
                        final double precioSb = _apiService.obtenerPrecioMatriz(
                          categoriaIdSeleccionada,
                          sbId,
                        );
                        return DropdownMenuItem<int>(
                          value: sbId,
                          child: Text(
                              '$sbNombre (\$${precioSb.toStringAsFixed(2)})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => servicioBaseIdSeleccionado = val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // Autocompletado de Cliente
                    Autocomplete<Map<String, dynamic>>(
                      displayStringForOption: (option) =>
                          (option['nombre_completo'] ?? '').toString(),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.trim().isEmpty) {
                          return const Iterable<Map<String, dynamic>>.empty();
                        }
                        final query =
                            textEditingValue.text.trim().toLowerCase();
                        return _listaClientesLocal.where((c) {
                          final nombre = (c['nombre_completo'] ?? '')
                              .toString()
                              .toLowerCase();
                          return nombre.contains(query);
                        }).cast<Map<String, dynamic>>();
                      },
                      onSelected: (Map<String, dynamic> cliente) {
                        setModalState(() {
                          if (vehiculoIdExistente != null) {
                            prefijoSeleccionado = 'P';
                            cuerpoPlacaCtrl?.clear();
                            marcaCtrl.clear();
                            modeloCtrl.clear();
                            colorCtrl.clear();
                            vehiculoIdExistente = null;
                            vehiculoClienteIdExistente = null;
                          }
                          clienteIdExistente = cliente['id'];
                          telefonoCtrl.text = _formatearTelefonoSV(
                            (cliente['telefono'] ?? '').toString(),
                          );
                          correoCtrl.text =
                              (cliente['correo'] ?? '').toString().trim();
                        });
                      },
                      fieldViewBuilder: (
                        context,
                        textEditingController,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        clienteInputCtrl = textEditingController;
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          onChanged: (val) {
                            if (clienteIdExistente != null) {
                              setModalState(() {
                                clienteIdExistente = null;
                                telefonoCtrl.clear();
                                correoCtrl.clear();
                                if (vehiculoIdExistente != null) {
                                  prefijoSeleccionado = 'P';
                                  cuerpoPlacaCtrl?.clear();
                                  marcaCtrl.clear();
                                  modeloCtrl.clear();
                                  colorCtrl.clear();
                                  vehiculoIdExistente = null;
                                  vehiculoClienteIdExistente = null;
                                }
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Nombre del Cliente *',
                            hintText: 'Buscar o escribir cliente...',
                            prefixIcon: const Icon(Icons.person_outline_rounded,
                                size: 20),
                            suffixIcon: clienteIdExistente != null
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF16A34A),
                                    size: 18,
                                  )
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
                                border:
                                    Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: ListView.separated(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                shrinkWrap: true,
                                itemCount: options.length,
                                separatorBuilder: (_, __) => const Divider(
                                    height: 1, color: Color(0xFFF3F4F6)),
                                itemBuilder: (context, index) {
                                  final opt = options.elementAt(index);
                                  final String nombre =
                                      (opt['nombre_completo'] ?? '').toString();
                                  final String tel =
                                      (opt['telefono'] ?? '').toString();
                                  final String cor =
                                      (opt['correo'] ?? '').toString();
                                  return InkWell(
                                    onTap: () => onSelected(opt),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          const CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Color(0xFFEFF6FF),
                                            child: Icon(
                                              Icons.person,
                                              size: 14,
                                              color: AppColors.kRoyalBlue,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  nombre,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                if (tel.isNotEmpty ||
                                                    cor.isNotEmpty)
                                                  Text(
                                                    [
                                                      if (tel.isNotEmpty)
                                                        'Tel: $tel',
                                                      if (cor.isNotEmpty) cor,
                                                    ].join(' • '),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          AppColors.textMuted,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 12,
                                            color: AppColors.textMuted,
                                          ),
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

                    // Teléfono con máscara 0000-0000 y Correo Electrónico (TDR 4.3 y 4.4)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: telefonoCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 9,
                            inputFormatters: [_TelefonoSVInputFormatter()],
                            decoration: const InputDecoration(
                              counterText: '',
                              labelText: 'Teléfono * (0000-0000)',
                              prefixIcon: Icon(Icons.phone_outlined, size: 19),
                              hintText: '7777-8888',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: correoCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo (Pre-factura)',
                              prefixIcon: Icon(Icons.email_outlined, size: 19),
                              hintText: 'cliente@correo.com',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
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
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 0),
                            title: Text(
                              extra.nombre,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
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

                    // Resumen de Precio Estimado (Base Matriz + Extras + IVA 13%)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
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
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                'Subtotal: \$${subtotalEst.toStringAsFixed(2)} (IVA: 13%)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
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

                    // Botón de Envío (bloqueado si el vehículo ya tiene orden activa en patio)
                    ElevatedButton.icon(
                      onPressed: ordenActivaPatio != null
                          ? null
                          : () async {
                              void mostrarAlerta(String mensaje) {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: const Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: Color(0xFFD97706),
                                          size: 24,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Dato requerido o inválido',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    content: Text(
                                      mensaje,
                                      style: const TextStyle(fontSize: 13.5),
                                    ),
                                    actions: [
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.kRoyalBlue,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: const Text('Entendido'),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final String cuerpo =
                                  (cuerpoPlacaCtrl?.text ?? '')
                                      .trim()
                                      .toUpperCase()
                                      .replaceAll(RegExp(r'[^A-Z0-9]'), '');
                              final String nombreCli =
                                  (clienteInputCtrl?.text ?? '').trim();
                              final String telefonoCli =
                                  telefonoCtrl.text.trim();
                              final String correoCli =
                                  correoCtrl.text.trim().toLowerCase();
                              final String marca = marcaCtrl.text.trim();
                              final String modelo = modeloCtrl.text.trim();
                              final String color = colorCtrl.text.trim();

                              // 1. Validar Placa Salvadoreña Estricta
                              if (!RegExp(r'^[A-Z0-9]{3,6}$')
                                  .hasMatch(cuerpo)) {
                                mostrarAlerta(
                                  'Ingresa de 3 a 6 caracteres alfanuméricos para la placa (Ej. P-123456).',
                                );
                                return;
                              }

                              final String placaCompleta =
                                  '$prefijoSeleccionado-$cuerpo';
                              final VehiculoPatio? yaEnLavado =
                                  _buscarOrdenActivaPorPlaca(placaCompleta);
                              if (yaEnLavado != null) {
                                mostrarAlerta(
                                  'Este vehículo ya está en lavado en ${yaEnLavado.bahia}.',
                                );
                                return;
                              }

                              // 2. Validar Marca, Modelo y Color obligatorios (sin valores por defecto quemados)
                              if (marca.isEmpty ||
                                  modelo.isEmpty ||
                                  color.isEmpty ||
                                  color.toUpperCase() == 'N/A') {
                                mostrarAlerta(
                                  'Marca, Modelo y Color del vehículo son obligatorios.',
                                );
                                return;
                              }

                              // 3. Validar Nombre del Cliente
                              if (nombreCli.isEmpty) {
                                mostrarAlerta(
                                  'El nombre del cliente es obligatorio.',
                                );
                                return;
                              }

                              // 4. Validar Teléfono 0000-0000 y duplicados
                              if (!RegExp(r'^\d{4}-\d{4}$')
                                  .hasMatch(telefonoCli)) {
                                mostrarAlerta(
                                  'El teléfono debe tener 8 dígitos en formato 0000-0000.',
                                );
                                return;
                              }

                              if (telefonoCli != '0000-0000') {
                                for (final c in _listaClientesLocal) {
                                  final int cid = int.tryParse(
                                          c['id']?.toString() ?? '0') ??
                                      0;
                                  final String telC = _formatearTelefonoSV(
                                    (c['telefono'] ?? '').toString(),
                                  );
                                  if (telC == telefonoCli &&
                                      cid != (clienteIdExistente ?? -1)) {
                                    mostrarAlerta(
                                      'El teléfono $telefonoCli ya pertenece a otro cliente (${c['nombre_completo']}).',
                                    );
                                    return;
                                  }
                                }
                              }

                              // 5. Validar Correo Electrónico (si se ingresó) y duplicados
                              if (correoCli.isNotEmpty) {
                                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(correoCli)) {
                                  mostrarAlerta(
                                    'El formato del correo electrónico no es válido.',
                                  );
                                  return;
                                }

                                for (final c in _listaClientesLocal) {
                                  final int cid = int.tryParse(
                                          c['id']?.toString() ?? '0') ??
                                      0;
                                  final String corC = (c['correo'] ?? '')
                                      .toString()
                                      .trim()
                                      .toLowerCase();
                                  if (corC.isNotEmpty &&
                                      corC == correoCli &&
                                      cid != (clienteIdExistente ?? -1)) {
                                    mostrarAlerta(
                                      'El correo $correoCli ya está registrado con otro cliente (${c['nombre_completo']}).',
                                    );
                                    return;
                                  }
                                }
                              }

                              // 6. Confirmación obligatoria en ventana 4:45 PM - 5:00 PM
                              if (_enVentanaProrroga) {
                                final bool? confProrroga =
                                    await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    title: const Row(
                                      children: [
                                        Icon(Icons.schedule_rounded,
                                            color: Color(0xFFD97706)),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Programación para mañana',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    content: const Text(
                                      'Son entre las 4:45 PM y 5:00 PM. La orden se registrará pero quedará programada automáticamente para mañana a las 07:00 AM sin ocupar bahía hoy.\n\n¿Deseas continuar?',
                                      style: TextStyle(fontSize: 13.5),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFD97706),
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text(
                                            'Sí, programar para mañana'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confProrroga != true) return;
                              }

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
                                placa: placaCompleta,
                                marca: marca,
                                modelo: modelo,
                                color: color,
                                nombreCliente: nombreCli,
                                telefonoCliente: telefonoCli,
                                correoCliente:
                                    correoCli.isNotEmpty ? correoCli : null,
                                categoriaId: categoriaIdSeleccionada,
                                servicioBaseId: servicioBaseIdSeleccionado,
                                bahiaId: bahiaLibre,
                                extras: extrasPrecios,
                                extrasIds: extrasIds,
                              );

                              if (result['success'] != true) {
                                if (context.mounted) {
                                  mostrarAlerta(
                                    'Error al registrar orden: ${result['error']}',
                                  );
                                }
                                return;
                              }

                              if (context.mounted) Navigator.pop(context);
                              await _obtenerDatosDeApi(mostrarMensaje: true);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kRoyalBlue,
                        disabledBackgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.add_task_rounded),
                      label: Text(
                        ordenActivaPatio != null
                            ? 'Vehículo ya activo en ${ordenActivaPatio.bahia}'
                            : _enVentanaProrroga
                                ? 'Programar para Mañana 7:00 AM'
                                : 'Registrar en Bahía $bahiaLibre (Pendiente)',
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
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _abrirModalRecepcion,
              backgroundColor: _recepcionAbierta
                  ? AppColors.kRoyalBlue
                  : Colors.grey.shade600,
              foregroundColor: Colors.white,
              icon: Icon(_recepcionAbierta
                  ? Icons.add_rounded
                  : Icons.lock_clock_rounded),
              label: Text(
                _recepcionAbierta ? 'Recibir' : 'Cerrado (7AM-5PM)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
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
          onTap: (index) {
            setState(() => _selectedIndex = index);
            _apiService.verificarUsuarioActivo(context);
          },
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.kRoyalBlue,
          unselectedItemColor: AppColors.textHint,
          selectedFontSize: 11.5,
          unselectedFontSize: 11.5,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: _IconoBarraInferior(
                icono: Icons.home_outlined,
                activo: _selectedIndex == 0,
              ),
              label: 'Patio',
            ),
            BottomNavigationBarItem(
              icon: _IconoBarraInferior(
                icono: Icons.badge_outlined,
                activo: _selectedIndex == 1,
              ),
              label: 'Planilla',
            ),
            BottomNavigationBarItem(
              icon: _IconoBarraInferior(
                icono: Icons.inventory_2_outlined,
                activo: _selectedIndex == 2,
              ),
              label: 'Inventario',
            ),
            BottomNavigationBarItem(
              icon: _IconoBarraInferior(
                icono: Icons.person_outline_rounded,
                activo: _selectedIndex == 3,
              ),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  // ─── PESTAÑA 0: PATIO ─────────────────────────────────────

  Widget _buildPantallaInicio() {
    final int totalBahias =
        _bahiasApi.isNotEmpty ? _bahiasApi.length : AppConstants.totalBahias;
    final ocupadas = List.generate(totalBahias, (i) => _bahiaOcupada(i + 1))
        .where((b) => b)
        .length;
    final enMantenimiento = List.generate(
      totalBahias,
      (i) => !_bahiaOcupada(i + 1) && _bahiaEnMantenimiento(i + 1),
    ).where((b) => b).length;
    final libres = totalBahias - ocupadas - enMantenimiento;

    final vehiculosFiltrados = _vehiculos.where((v) {
      if (_busqueda.isEmpty) return true;
      final q = _busqueda.toLowerCase();
      return v.placa.toLowerCase().contains(q) ||
          v.nombreCompletoCarro.toLowerCase().contains(q) ||
          v.color.toLowerCase().contains(q) ||
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
                const Text(
                  'Operaciones de Patio',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  onPressed: () => _obtenerDatosDeApi(mostrarMensaje: true),
                  icon: _cargandoApi
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.sync_rounded,
                          color: _conectadoConApi
                              ? AppColors.success
                              : AppColors.textMuted,
                        ),
                  tooltip: 'Sincronizar con API',
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (valor) => setState(() => _busqueda = valor),
              decoration: InputDecoration(
                hintText: 'Buscar vehículo por placa, color o cliente...',
                hintStyle:
                    const TextStyle(color: AppColors.textHint, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfaceGrey,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
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
                boxShadow: [
                  BoxShadow(
                    color: AppColors.kRoyalBlue.withAlpha(55),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _horaSv.isNotEmpty
                            ? 'Estado de bahías (Hoy • $_horaSv SV)'
                            : 'Estado de bahías (Turno Hoy)',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF228B22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          '$libres libres',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    enMantenimiento > 0
                        ? '$ocupadas ocupadas • $enMantenimiento mant.'
                        : '$ocupadas ocupadas',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: List.generate(totalBahias, (i) {
                      final int numBahia = i + 1;
                      final bool ocupada = _bahiaOcupada(numBahia);
                      final bool mant =
                          !ocupada && _bahiaEnMantenimiento(numBahia);
                      final Color colorCaja = ocupada
                          ? AppColors.bahiaOcupada
                          : mant
                              ? const Color(0xFFD97706)
                              : AppColors.bahiaLibre;
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(
                              right: i < totalBahias - 1 ? 6 : 0),
                          height: 46,
                          decoration: BoxDecoration(
                            color: colorCaja,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            mant ? 'B$numBahia•M' : 'B$numBahia',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
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
                Text(
                  'Vehículos en Patio (${vehiculosFiltrados.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedIndex = 1),
                  child: const Text(
                    'Ver Planilla y Turno',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kRoyalBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (vehiculosFiltrados.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No hay vehículos registrados en el turno actual.',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 13.5),
                  ),
                ),
              )
            else
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
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(70),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(
                  v.placa,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${v.nombreCompletoCarro} (${v.color}) • ${v.categoria}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${v.bahia} • ${v.pagado ? "COBRADO EN CAJA" : "PENDIENTE EN CAJA"}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: v.pagado
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                        if (v.vecesPospuesta >= 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: const Color(0xFFF59E0B)),
                            ),
                            child: const Text(
                              'POSPUESTA 1/1',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: fondo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  AppConstants.nombresFase[v.fase],
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Cliente: ${v.cliente} (${v.telefonoCliente})',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          // Botones con Flujo Unidireccional Estricto (0 -> 1 -> 2)
          Row(
            children: List.generate(3, (i) {
              final bool activo = v.fase == i;
              final bool puedeAvanzar = i == v.fase + 1;
              final VoidCallback? accionBoton = puedeAvanzar
                  ? () => _confirmarCambioEstado(v, i)
                  : null;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  child: ElevatedButton(
                    onPressed: accionBoton,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activo
                          ? AppColors.coloresFase[i]
                          : AppColors.fondosFase[i],
                      foregroundColor:
                          activo ? Colors.white : AppColors.coloresFase[i],
                      disabledBackgroundColor: activo
                          ? AppColors.coloresFase[i]
                          : AppColors.surfaceGrey,
                      disabledForegroundColor:
                          activo ? Colors.white : AppColors.textHint,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: activo ? 2 : 0,
                    ),
                    child: Text(
                      AppConstants.nombresFase[i],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              );
            }),
          ),
          // Acciones de orden Pendiente: Posponer a mañana (1 vez) y Cancelar orden
          if (v.fase == 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (v.vecesPospuesta == 0) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmarPosponerOrden(v),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB45309),
                        side: const BorderSide(color: Color(0xFFF59E0B)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.event_repeat_rounded, size: 15),
                      label: const Text(
                        'Posponer a mañana (1 vez)',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmarCancelarOrden(v),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 15),
                    label: const Text(
                      'Cancelar orden',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── PESTAÑA 1: PLANILLA Y TURNO OPERATIVO ────────────────

  Widget _buildPantallaControlPatio() {
    final tabs = ['Todos', ...AppConstants.nombresFase];
    final filtrados = _vehiculos.where((v) {
      if (_filtroControl == 'Todos') return true;
      return AppConstants.nombresFase[v.fase] == _filtroControl;
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
                _BotonIconoBorde(
                  icono: Icons.chevron_left_rounded,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                const Text(
                  'Planilla y Turno',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                _BotonIconoBorde(
                  icono: Icons.sync_rounded,
                  onTap: () => _obtenerDatosDeApi(mostrarMensaje: true),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Cards de resumen operativo (Sin información sensible de Caja)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.fondosFase[2],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MI COMISIÓN / PLANILLA DE HOY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.successDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_totalComisionesOperarios.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.successDark,
                          ),
                        ),
                        Text(
                          '$_cantidadLavadosComision servicios asignados',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.successText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.fondosFase[1],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LAVADOS TERMINADOS HOY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.kRoyalBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_lavadosTerminadosHoy completados',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.kRoyalBlue,
                          ),
                        ),
                        Text(
                          '$_vehiculosEnPatio en patio actualmente',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
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
              decoration: BoxDecoration(
                color: AppColors.surfaceGrey,
                borderRadius: BorderRadius.circular(14),
              ),
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
                            fontWeight:
                                activo ? FontWeight.w700 : FontWeight.w500,
                            color: activo
                                ? AppColors.kRoyalBlue
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Asignación de Operarios y Estado en Caja',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Text(
              'El cobro monetario es exclusivo de Caja Web. Asigna operarios al terminar el lavado.',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
            const SizedBox(height: 12),
            ...filtrados.map((v) => _buildFilaOrden(v)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilaOrden(VehiculoPatio v) {
    final color = AppColors.coloresFase[v.fase];
    final bool terminada = v.fase == 2;
    final bool comisionCerrada =
        v.comisionada || _ordenesComisionadasIds.contains(v.ordenId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.fondosFase[v.fase],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconosFase[v.fase], color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${v.placa} • ${v.nombreCompletoCarro} (${v.color} • ${v.categoria})',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${AppConstants.nombresFase[v.fase]} • ${v.cliente}',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted),
                ),
                if (v.operariosAsignados.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Operarios: ${v.operariosAsignados}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.kRoyalBlue,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Estado informativo de pago en Caja Web
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: v.pagado
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  v.pagado ? 'COBRADO EN CAJA' : 'PENDIENTE EN CAJA',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: v.pagado
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB45309),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (!terminada)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'EN LAVADO',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (comisionCerrada)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 12, color: Color(0xFF15803D)),
                      SizedBox(width: 4),
                      Text(
                        'COMISIÓN CERRADA',
                        style: TextStyle(
                          color: Color(0xFF15803D),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: () => _abrirModalAsignarOperarios(v),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.kRoyalBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.group_add_rounded,
                            size: 13, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Asignar Operarios',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
          const Text(
            'Mi perfil',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Tarjeta de perfil
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfaceGrey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.kRoyalBlue,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _perfilNombre.length >= 2
                        ? _perfilNombre.substring(0, 2).toUpperCase()
                        : 'US',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _perfilNombre,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _perfilRol,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.kRoyalBlue,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _perfilCorreo,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (_perfilUsuarioId > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          'ID Empleado: #$_perfilUsuarioId • Cuenta Activa',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.successDark,
                          ),
                        ),
                      ],
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
                if (mounted) {
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Cerrar sesión',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
