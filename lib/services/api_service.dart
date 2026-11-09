import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_constants.dart';
import '../models/vehiculo_patio.dart';
import '../models/inventario_model.dart';
import '../models/servicio_extra_model.dart';

/// Servicio centralizado para todas las llamadas HTTP a la API FastAPI.
class ApiService {
  String _apiUrl;

  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() : _apiUrl = AppConstants.defaultApiUrl;

  /// URL actual de la API.
  String get apiUrl => _apiUrl;

  /// Cambia la URL base de la API.
  void setApiUrl(String url) {
    _apiUrl = url.replaceAll(RegExp(r'/$'), '');
  }

  /// Obtiene los headers con JWT desde SharedPreferences.
  Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey) ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Nombre de categoría a partir de su ID según tabla oficial.
  static String nombreCategoria(int? catId) {
    switch (catId) {
      case 6: return 'Motocicleta';
      case 1: return 'Sedán';
      case 2: return 'Pick Up';
      case 3: return 'Carros Medianos';
      case 4: return 'Carros Grandes';
      case 5: return 'Microbús';
      default: return 'Sedán';
    }
  }

  /// Precio base según categoría según tabla de precios oficial Sprint Wash.
  static double precioBaseCategoria(int catId) {
    switch (catId) {
      case 6: return 1.50; // Motocicleta ($1.50)
      case 1: return 4.00; // Sedán ($4.00)
      case 2: return 8.00; // Pick Up ($8.00)
      case 3: return 6.00; // Carros Medianos ($6.00)
      case 4: return 8.00; // Carros Grandes ($8.00)
      case 5: return 10.00; // Microbús ($10.00)
      default: return 4.00;
    }
  }

  // ─── AUTENTICACIÓN ──────────────────────────────────────────

  /// Inicia sesión y guarda token + datos de usuario.
  Future<bool> login(String email, String password) async {
    final url = Uri.parse('$_apiUrl/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'correo': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.tokenKey, data['access_token']);
      await prefs.setString(AppConstants.userNombreKey, data['nombre'] ?? 'Usuario');
      await prefs.setString(AppConstants.userRolKey, data['rol'] ?? 'Sin rol');
      await prefs.setString(AppConstants.userCorreoKey, email);
      return true;
    }
    return false;
  }

  /// Cierra la sesión limpiando SharedPreferences.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ─── DATOS DEL PATIO Y DIRECTORIO LOCAL ──────────────────────

  /// Obtiene el directorio completo de clientes y vehículos registrados
  /// para funcionar como caché local (memoria RAM) y autocompletado predictivo instantáneo.
  Future<Map<String, List<dynamic>>> obtenerDirectorio() async {
    try {
      final headers = await getHeaders();
      final resClientes = await http
          .get(Uri.parse('$_apiUrl/clientes/'), headers: headers)
          .timeout(const Duration(seconds: 4));
      final resVehiculos = await http
          .get(Uri.parse('$_apiUrl/vehiculos/'), headers: headers)
          .timeout(const Duration(seconds: 4));

      final List<dynamic> clientes = resClientes.statusCode == 200
          ? jsonDecode(utf8.decode(resClientes.bodyBytes))
          : [];
      final List<dynamic> vehiculos = resVehiculos.statusCode == 200
          ? jsonDecode(utf8.decode(resVehiculos.bodyBytes))
          : [];

      return {
        'clientes': clientes,
        'vehiculos': vehiculos,
      };
    } catch (e) {
      debugPrint('[ApiService] Error al obtener directorio: $e');
      return {
        'clientes': [],
        'vehiculos': [],
      };
    }
  }

  /// Obtiene datos de perfil del usuario almacenados localmente.
  Future<Map<String, String>> getPerfilData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'nombre': prefs.getString(AppConstants.userNombreKey) ?? 'Usuario',
      'rol': prefs.getString(AppConstants.userRolKey) ?? 'Sin Rol',
      'correo': prefs.getString(AppConstants.userCorreoKey) ?? 'Sin Correo',
    };
  }

  /// Obtiene todos los datos del patio: vehículos, comisiones, caja.
  Future<Map<String, dynamic>> obtenerDatosPatio() async {
    final headers = await getHeaders();

    final resOrdenes = await http
        .get(Uri.parse('$_apiUrl/ordenes/'), headers: headers)
        .timeout(const Duration(seconds: 4));
    final resVehiculos = await http
        .get(Uri.parse('$_apiUrl/vehiculos/'), headers: headers)
        .timeout(const Duration(seconds: 4));
    final resClientes = await http
        .get(Uri.parse('$_apiUrl/clientes/'), headers: headers)
        .timeout(const Duration(seconds: 4));
    final resCaja = await http
        .get(Uri.parse('$_apiUrl/reportes/caja/hoy'), headers: headers)
        .timeout(const Duration(seconds: 4));
    final resPlanillas = await http
        .get(Uri.parse('$_apiUrl/reportes/planillas/hoy'), headers: headers)
        .timeout(const Duration(seconds: 4));

    if (resOrdenes.statusCode != 200 || resVehiculos.statusCode != 200) {
      String error = 'Error del servidor';
      try {
        final body = jsonDecode(resOrdenes.body);
        if (body['detail'] != null) error = body['detail'].toString();
      } catch (_) {}
      return {'success': false, 'error': error};
    }

    final List<dynamic> ordenesJson = jsonDecode(utf8.decode(resOrdenes.bodyBytes));
    final List<dynamic> vehiculosJson = jsonDecode(utf8.decode(resVehiculos.bodyBytes));
    final List<dynamic> clientesJson =
        resClientes.statusCode == 200 ? jsonDecode(utf8.decode(resClientes.bodyBytes)) : [];

    final Map<String, dynamic> cajaJson =
        resCaja.statusCode == 200 ? jsonDecode(utf8.decode(resCaja.bodyBytes)) : {};
    final Map<String, dynamic> planillasJson =
        resPlanillas.statusCode == 200 ? jsonDecode(utf8.decode(resPlanillas.bodyBytes)) : {};

    final Map<int, Map<String, dynamic>> vehMap = {
      for (var v in vehiculosJson) (v['id'] as int): Map<String, dynamic>.from(v)
    };
    final Map<int, Map<String, dynamic>> cliMap = {
      for (var c in clientesJson) (c['id'] as int): Map<String, dynamic>.from(c)
    };

    final List<dynamic> planillaOperarios = planillasJson['planilla_operarios'] ?? [];
    double sumaPagos = double.tryParse((cajaJson['total_ingresos'] ?? 0).toString()) ?? 0.0;

    double sumaComisiones = 0.0;
    for (var op in planillaOperarios) {
      sumaComisiones += double.tryParse((op['total_a_pagar'] ?? 0).toString()) ?? 0.0;
    }

    final Set<int> ordenesPagadas = {};
    final List<VehiculoPatio> listaConstruida = [];

    for (var o in ordenesJson) {
      final int oid = o['id'] ?? 1;
      final int vid = o['vehiculo_id'] ?? 1;
      final veh = vehMap[vid] ?? {};
      final cli = cliMap[veh['cliente_id']] ?? {};

      final estadoStr = (o['estado'] ?? 'Pendiente').toString().toLowerCase();
      int fase = 0;
      if (estadoStr.contains('proceso')) fase = 1;
      if (estadoStr.contains('listo') || estadoStr.contains('terminado')) fase = 2;

      final double total = double.tryParse((o['total_pagar'] ?? '0').toString()) ?? 0.0;
      final double montoMostrar = total > 0 ? total : 8.00;

      listaConstruida.add(
        VehiculoPatio(
          ordenId: oid,
          vehiculoId: vid,
          placa: (veh['placa'] ?? 'SIN-PLACA').toString(),
          marca: (veh['marca'] ?? 'Vehículo').toString(),
          modelo: (veh['modelo'] ?? '').toString(),
          color: (veh['color'] ?? 'N/A').toString(),
          categoria: nombreCategoria(veh['categoria_vehiculo_id']),
          cliente: (cli['nombre_completo'] ?? 'Cliente General').toString(),
          correoCliente: (cli['correo'] ?? 'Sin correo').toString(),
          telefonoCliente: (cli['telefono'] ?? '---').toString(),
          bahia: 'Bahia ${o['bahia_id'] ?? 1}',
          servicio: 'Orden de Lavado #$oid',
          montoNumerico: montoMostrar,
          totalPagar: '\$${montoMostrar.toStringAsFixed(2)}',
          fase: fase,
          pagado: ordenesPagadas.contains(oid),
        ),
      );
    }

    return {
      'success': true,
      'vehiculos': listaConstruida,
      'totalCobradoHoy': sumaPagos,
      'totalComisionesOperarios': sumaComisiones,
      'cantidadLavadosComision': planillaOperarios.length,
      'clientesDirectorio': clientesJson,
      'vehiculosDirectorio': vehiculosJson,
    };
  }

  // ─── OPERACIONES DE ORDENES ─────────────────────────────────

  /// Cambia el estado de una orden.
  Future<bool> cambiarEstadoOrden(int ordenId, String nuevoEstado) async {
    final headers = await getHeaders();
    final response = await http
        .patch(
          Uri.parse('$_apiUrl/ordenes/$ordenId/estado'),
          headers: headers,
          body: jsonEncode({'estado': nuevoEstado}),
        )
        .timeout(const Duration(seconds: 8));
    return response.statusCode == 200;
  }

  /// Registra un pago para una orden.
  Future<Map<String, dynamic>> registrarPago({
    required int ordenId,
    required String metodoPago,
    required double monto,
  }) async {
    final headers = await getHeaders();
    final resPago = await http.post(
      Uri.parse('$_apiUrl/finanzas/pagos'),
      headers: headers,
      body: jsonEncode({
        'orden_id': ordenId,
        'cajero_id': AppConstants.cajeroIdDefault,
        'metodo_pago': metodoPago,
        'monto': monto,
      }),
    );

    if (resPago.statusCode != 200) {
      String error = 'Error al registrar pago';
      try {
        final body = jsonDecode(resPago.body);
        if (body['detail'] != null) error = body['detail'].toString();
      } catch (_) {}
      return {'success': false, 'error': error};
    }
    return {'success': true};
  }

  /// Asigna operarios a una orden para comisión.
  Future<bool> asignarOperarios({
    required int ordenId,
    required bool dosOperarios,
  }) async {
    final headers = await getHeaders();
    final res = await http.post(
      Uri.parse('$_apiUrl/finanzas/asignar-operarios'),
      headers: headers,
      body: jsonEncode({
        'orden_id': ordenId,
        'operarios_ids': dosOperarios ? AppConstants.operarioDoble : AppConstants.operarioSimple,
        'comision_extra_manual': 0.0,
      }),
    );
    return res.statusCode == 200;
  }

  // ─── RECEPCIÓN DE VEHÍCULO ──────────────────────────────────

  /// Crea un cliente en la API incluyendo teléfono.
  Future<Map<String, dynamic>> crearCliente(String nombre, [String? telefono]) async {
    final headers = await getHeaders();
    final Map<String, dynamic> body = {
      'nombre_completo': nombre,
    };
    if (telefono != null && telefono.trim().isNotEmpty) {
      body['telefono'] = telefono.trim();
    }

    final res = await http.post(
      Uri.parse('$_apiUrl/clientes/'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      final id = jsonDecode(res.body)['id'] ?? 1;
      return {'success': true, 'id': id};
    }

    String error = 'Error al crear cliente';
    try {
      error = jsonDecode(res.body)['detail']?.toString() ?? error;
    } catch (_) {}
    return {'success': false, 'error': error};
  }

  /// Crea un vehículo en la API.
  Future<Map<String, dynamic>> crearVehiculo({
    required int clienteId,
    required int categoriaId,
    required String placa,
    required String marca,
    required String modelo,
    required String color,
  }) async {
    final headers = await getHeaders();
    final res = await http.post(
      Uri.parse('$_apiUrl/vehiculos/'),
      headers: headers,
      body: jsonEncode({
        'cliente_id': clienteId,
        'categoria_vehiculo_id': categoriaId,
        'placa': placa,
        'marca': marca,
        'modelo': modelo,
        'color': color,
      }),
    );

    if (res.statusCode == 200) {
      final id = jsonDecode(res.body)['id'];
      return {'success': true, 'id': id};
    }

    String error = 'Error al crear vehículo';
    try {
      error = jsonDecode(res.body)['detail']?.toString() ?? error;
    } catch (_) {}
    return {'success': false, 'error': error};
  }

  /// Crea una orden de lavado con bahía específica.
  Future<Map<String, dynamic>> crearOrden({
    required int vehiculoId,
    required int bahiaId,
  }) async {
    final headers = await getHeaders();
    final res = await http.post(
      Uri.parse('$_apiUrl/ordenes/'),
      headers: headers,
      body: jsonEncode({
        'vehiculo_id': vehiculoId,
        'bahia_id': bahiaId,
        'estado': 'Pendiente',
      }),
    );

    if (res.statusCode == 200) {
      final id = jsonDecode(res.body)['id'];
      return {'success': true, 'id': id};
    }

    String error = 'Error al crear orden';
    try {
      error = jsonDecode(res.body)['detail']?.toString() ?? error;
    } catch (_) {}
    return {'success': false, 'error': error};
  }

  /// Registra un servicio adicional en /detalles-orden/ para comisiones.
  Future<bool> agregarDetalleOrden({
    required int ordenId,
    required int servicioAdicionalId,
  }) async {
    try {
      final headers = await getHeaders();
      final res = await http.post(
        Uri.parse('$_apiUrl/detalles-orden/'),
        headers: headers,
        body: jsonEncode({
          'orden_id': ordenId,
          'servicio_adicional_id': servicioAdicionalId,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] Error agregando detalle: $e');
      return false;
    }
  }

  /// Actualiza los totales de una orden vía PATCH.
  Future<bool> actualizarTotalesOrden({
    required int ordenId,
    required double subtotal,
    required double impuestos,
    required double totalPagar,
  }) async {
    final headers = await getHeaders();
    final res = await http.patch(
      Uri.parse('$_apiUrl/ordenes/$ordenId'),
      headers: headers,
      body: jsonEncode({
        'subtotal': subtotal,
        'impuestos': impuestos,
        'total_pagar': totalPagar,
      }),
    );
    return res.statusCode == 200;
  }

  /// Flujo condicional inteligente de recepción de vehículo en el patio.
  /// Evita duplicar clientes y vehículos si ya existen en la base de datos de producción.
  Future<Map<String, dynamic>> recibirVehiculo({
    int? clienteIdExistente,
    int? vehiculoIdExistente,
    required String placa,
    required String marca,
    required String modelo,
    required String color,
    required String nombreCliente,
    required String telefonoCliente,
    required int categoriaId,
    required int bahiaId,
    List<double> extras = const [],
    List<int> extrasIds = const [],
  }) async {
    try {
      int targetVehiculoId;

      // LÓGICA CONDICIONAL PARA EVITAR DUPLICADOS:
      // 1. Si vehiculoIdExistente no es nulo: Omite la creación del cliente y del vehículo.
      //    Pasa directamente a crear la orden usando ese ID existente.
      if (vehiculoIdExistente != null) {
        targetVehiculoId = vehiculoIdExistente;
      }
      // 2. Si clienteIdExistente no es nulo pero el vehículo es nuevo:
      //    Omite crear el cliente, haz el POST /vehiculos/ asociándolo a ese clienteId.
      else if (clienteIdExistente != null) {
        final resVeh = await crearVehiculo(
          clienteId: clienteIdExistente,
          categoriaId: categoriaId,
          placa: placa,
          marca: marca,
          modelo: modelo,
          color: color,
        );
        if (resVeh['success'] != true) return resVeh;
        targetVehiculoId = resVeh['id'];
      }
      // 3. Si ambos son nulos: Ejecuta el flujo completo (Crear Cliente -> Crear Vehículo -> Crear Orden)
      else {
        final resCli = await crearCliente(nombreCliente, telefonoCliente);
        if (resCli['success'] != true) return resCli;

        final resVeh = await crearVehiculo(
          clienteId: resCli['id'],
          categoriaId: categoriaId,
          placa: placa,
          marca: marca,
          modelo: modelo,
          color: color,
        );
        if (resVeh['success'] != true) return resVeh;
        targetVehiculoId = resVeh['id'];
      }

      // Crear orden con el vehiculo_id (nuevo o existente) y la bahía libre asignada
      final resOrd = await crearOrden(
        vehiculoId: targetVehiculoId,
        bahiaId: bahiaId,
      );
      if (resOrd['success'] != true) return resOrd;

      final int ordenId = resOrd['id'];

      // Registrar los servicios adicionales en /detalles-orden/ para comisiones
      for (final extraId in extrasIds) {
        await agregarDetalleOrden(
          ordenId: ordenId,
          servicioAdicionalId: extraId,
        );
      }

      // CÁLCULO CON EXTRAS:
      // Suma el precioBase más la suma de la lista de extras antes de calcular el 13% de IVA y el total final.
      final double precioBase = precioBaseCategoria(categoriaId);
      final double sumaExtras = extras.fold(0.0, (acc, e) => acc + e);
      final double subtotal = double.parse((precioBase + sumaExtras).toStringAsFixed(2));
      final double impuestos = double.parse((subtotal * 0.13).toStringAsFixed(2));
      final double totalPagar = double.parse((subtotal + impuestos).toStringAsFixed(2));

      // Enviar PATCH con los totales consolidados a la orden
      await actualizarTotalesOrden(
        ordenId: ordenId,
        subtotal: subtotal,
        impuestos: impuestos,
        totalPagar: totalPagar,
      );

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  // ─── INVENTARIO (SOLO LECTURA) ──────────────────────────────

  /// Obtiene la lista completa de insumos del inventario desde el VPS.
  Future<List<InventarioModel>> obtenerInventario() async {
    final headers = await getHeaders();
    final response = await http
        .get(Uri.parse('$_apiUrl/inventario/'), headers: headers)
        .timeout(const Duration(seconds: 6));

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
      return list.map((item) => InventarioModel.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      String errorMsg = 'Error al consultar inventario (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body['detail'] != null) errorMsg = body['detail'].toString();
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }
}
