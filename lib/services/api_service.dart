import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_constants.dart';
import '../models/vehiculo_patio.dart';
import '../models/inventario_model.dart';
import '../models/servicio_extra_model.dart';
import '../screens/login_screen.dart';

/// Servicio centralizado para todas las llamadas HTTP a la API FastAPI.
/// Toda la información, catálogos, precios, bahías y operarios provienen 100% de la API REST.
class ApiService {
  String _apiUrl;

  // Cachés dinámicos de catálogos sincronizados desde la API
  List<Map<String, dynamic>> _categoriasCache = [];
  List<Map<String, dynamic>> _serviciosBaseCache = [];
  List<Map<String, dynamic>> _matrizPreciosCache = [];
  List<ServicioExtraModel> _serviciosAdicionalesCache = [];

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

  // ─── ZONA HORARIA EL SALVADOR (UTC-6) Y PLACAS SV ──────────

  /// Devuelve la fecha y hora actual exacta en El Salvador (UTC-6 fijo).
  static DateTime ahoraSV() {
    return DateTime.now().toUtc().subtract(const Duration(hours: 6));
  }

  /// Convierte una fecha ISO-8601 proveniente de la API (UTC) a hora de El Salvador (UTC-6).
  static DateTime fechaIsoASv(String? fechaStr) {
    if (fechaStr == null || fechaStr.trim().isEmpty) {
      return ahoraSV();
    }
    try {
      String raw = fechaStr.trim();
      final bool tieneZona =
          raw.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);
      if (!tieneZona) {
        raw = '${raw}Z';
      }
      final dtUtc = DateTime.parse(raw).toUtc();
      return dtUtc.subtract(const Duration(hours: 6));
    } catch (_) {
      return ahoraSV();
    }
  }

  /// Verifica si una fecha ISO pertenece al día de hoy en hora de El Salvador (UTC-6).
  static bool esFechaDeHoySV(String? fechaStr) {
    if (fechaStr == null || fechaStr.trim().isEmpty) return true;
    final dtSv = fechaIsoASv(fechaStr);
    final hoySv = ahoraSV();
    return dtSv.year == hoySv.year &&
        dtSv.month == hoySv.month &&
        dtSv.day == hoySv.day;
  }

  /// Verifica si una fecha ISO corresponde a un día futuro (> hoy) en hora de El Salvador.
  static bool esFechaFuturaSV(String? fechaStr) {
    if (fechaStr == null || fechaStr.trim().isEmpty) return false;
    final dtSv = fechaIsoASv(fechaStr);
    final hoySv = ahoraSV();
    final fechaOrden = DateTime(dtSv.year, dtSv.month, dtSv.day);
    final fechaHoy = DateTime(hoySv.year, hoySv.month, hoySv.day);
    return fechaOrden.isAfter(fechaHoy);
  }

  /// Formatea una fecha ISO a texto legible en hora de El Salvador (YYYY-MM-DD HH:MM).
  static String formatearFechaHoraSV(String? fechaStr) {
    final dt = fechaIsoASv(fechaStr);
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  /// Separa una placa salvadoreña en su prefijo oficial y su cuerpo alfanumérico.
  static Map<String, String> separarPlacaSV(String placaRaw) {
    final upper = placaRaw.trim().toUpperCase();
    if (upper.contains('-')) {
      final parts = upper.split('-');
      final pref = parts.first.replaceAll(RegExp(r'[^A-Z]'), '');
      final body =
          parts.sublist(1).join('').replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (AppConstants.prefijosPlacaSV.contains(pref)) {
        return {
          'prefijo': pref,
          'cuerpo': body.length > 6 ? body.substring(0, 6) : body,
        };
      }
    }

    final limpia = upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final regex = RegExp(
      r'^(PNC|AB|MB|RE|PR|CC|CD|MI|[PMACFTNOEDV])([A-Z0-9]{1,6})$',
    );
    final match = regex.firstMatch(limpia);
    if (match != null) {
      return {
        'prefijo': match.group(1)!,
        'cuerpo': match.group(2)!,
      };
    }

    return {
      'prefijo': 'P',
      'cuerpo': limpia.length > 6 ? limpia.substring(0, 6) : limpia,
    };
  }

  /// Normaliza una placa al formato oficial PREFIJO-CODIGO (ej. P-123456).
  static String normalizarPlacaSV(String placaRaw) {
    final partes = separarPlacaSV(placaRaw);
    final pref = partes['prefijo'] ?? 'P';
    final cuerpo = partes['cuerpo'] ?? '';
    if (cuerpo.isEmpty) return upperOrEmpty(placaRaw);
    return '$pref-$cuerpo';
  }

  static String upperOrEmpty(String s) => s.trim().toUpperCase();

  // ─── CATÁLOGOS DINÁMICOS 100% DESDE LA API ─────────────────

  /// Obtiene el nombre de una categoría consultando exclusivamente el catálogo de la API.
  String obtenerNombreCategoria(int? catId) {
    if (catId == null) return '';
    for (final c in _categoriasCache) {
      final int id = int.tryParse(c['id']?.toString() ?? '0') ?? 0;
      if (id == catId) {
        return (c['nombre'] ?? '').toString();
      }
    }
    return '';
  }

  /// Obtiene el precio exacto desde la matriz sincronizada (GET /servicios/matriz-precios).
  double obtenerPrecioMatriz(int categoriaId, [int servicioBaseId = 1]) {
    for (final m in _matrizPreciosCache) {
      final int cId =
          int.tryParse(m['categoria_vehiculo_id']?.toString() ?? '0') ?? 0;
      final int sId =
          int.tryParse(m['servicio_base_id']?.toString() ?? '0') ?? 0;
      if (cId == categoriaId && sId == servicioBaseId) {
        final double? p = double.tryParse(m['precio_base']?.toString() ?? '');
        if (p != null) return p;
      }
    }
    return 0.0;
  }

  // ─── AUTENTICACIÓN, NIVELES DE SEGURIDAD Y CUENTA ACTIVA ──

  /// Inicia sesión y guarda token + usuario_id + datos de usuario.
  /// Valida rol operativo/supervisor o administrador y bloquea acceso si el rol es CAJERO.
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final url = Uri.parse('$_apiUrl/auth/login');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'correo': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 6));

      final String rawBody = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        final data = jsonDecode(rawBody);
        final String rolStr = (data['rol'] ?? '').toString();
        if (rolStr.toUpperCase().contains('CAJERO')) {
          return {
            'success': false,
            'error':
                'Acceso denegado: El personal de Caja debe ingresar desde el Sistema Web.',
          };
        }

        final int userId =
            int.tryParse(data['usuario_id']?.toString() ?? '0') ?? 0;
        final String token = (data['access_token'] ?? '').toString();

        // Verificar en /finanzas/usuarios que el usuario tenga estado == 1 y rol permitido
        try {
          final resUsers = await http.get(
            Uri.parse('$_apiUrl/finanzas/usuarios'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 5));

          if (resUsers.statusCode == 200) {
            final List<dynamic> usuarios =
                jsonDecode(utf8.decode(resUsers.bodyBytes));
            for (final u in usuarios) {
              final int uid = int.tryParse(u['id']?.toString() ?? '0') ?? 0;
              if (uid == userId) {
                final int est =
                    int.tryParse(u['estado']?.toString() ?? '1') ?? 1;
                final int rolId =
                    int.tryParse(u['rol_id']?.toString() ?? '3') ?? 3;
                if (est == 0) {
                  return {
                    'success': false,
                    'error': 'Usuario inactivo. Contacte al administrador.',
                  };
                }
                if (rolId == 2) {
                  return {
                    'success': false,
                    'error':
                        'Acceso denegado: El personal de Caja debe ingresar desde el Sistema Web.',
                  };
                }
                break;
              }
            }
          }
        } catch (_) {}

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.tokenKey, token);
        await prefs.setInt(AppConstants.userIdKey, userId);
        await prefs.setString(
            AppConstants.userNombreKey, data['nombre'] ?? 'Usuario');
        await prefs.setString(AppConstants.userRolKey, rolStr);
        await prefs.setString(AppConstants.userCorreoKey, email);
        return {
          'success': true,
          'usuario_id': userId,
          'nombre': data['nombre'] ?? 'Usuario',
          'rol': rolStr,
        };
      }

      String detail = 'Correo o contraseña incorrectos';
      try {
        final errData = jsonDecode(rawBody);
        if (errData is Map && errData['detail'] != null) {
          detail = errData['detail'].toString();
        }
      } catch (_) {}

      return {'success': false, 'error': detail};
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión con el servidor: $e',
      };
    }
  }

  /// Consulta GET /finanzas/usuarios y verifica que el usuario tenga estado == 1
  /// y que su rol no haya cambiado a Cajero (rol_id == 2).
  Future<bool> verificarUsuarioActivo([BuildContext? context]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int userId = prefs.getInt(AppConstants.userIdKey) ?? 0;
      if (userId <= 0) return true;

      final headers = await getHeaders();
      final res = await http
          .get(Uri.parse('$_apiUrl/finanzas/usuarios'), headers: headers)
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final List<dynamic> usuarios = jsonDecode(utf8.decode(res.bodyBytes));
        for (final u in usuarios) {
          final int uid = int.tryParse(u['id']?.toString() ?? '0') ?? 0;
          if (uid == userId) {
            final int estado =
                int.tryParse(u['estado']?.toString() ?? '1') ?? 1;
            final int rolId = int.tryParse(u['rol_id']?.toString() ?? '3') ?? 3;
            if (estado == 0 || rolId == 2) {
              await logout();
              if (context != null && context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      estado == 0
                          ? '⚠️ Tu sesión ha sido cerrada porque tu cuenta fue desactivada por el Administrador.'
                          : '⚠️ Tu sesión ha sido cerrada porque el rol de Cajero es exclusivo del Sistema Web.',
                    ),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 5),
                  ),
                );
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
              return false;
            }
            break;
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('[ApiService] Error verificando estado de usuario: $e');
      return true;
    }
  }

  /// Cierra la sesión limpiando SharedPreferences.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ─── DATOS DEL PATIO Y DIRECTORIO LOCAL ──────────────────────

  /// Auxiliar seguro para consultar listas JSON de la API.
  Future<List<dynamic>> _getListaSegura(
      String endpoint, Map<String, String> headers) async {
    try {
      final res = await http
          .get(Uri.parse('$_apiUrl$endpoint'), headers: headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is List) return decoded;
      }
    } catch (e) {
      debugPrint('[ApiService] Advertencia consultando $endpoint: $e');
    }
    return [];
  }

  /// Auxiliar seguro para consultar objetos JSON (Map) de la API.
  Future<Map<String, dynamic>> _getMapaSeguro(
      String endpoint, Map<String, String> headers) async {
    try {
      final res = await http
          .get(Uri.parse('$_apiUrl$endpoint'), headers: headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      debugPrint('[ApiService] Advertencia consultando $endpoint: $e');
    }
    return {};
  }

  /// Obtiene el directorio completo de clientes y vehículos registrados.
  Future<Map<String, List<dynamic>>> obtenerDirectorio() async {
    try {
      final headers = await getHeaders();
      final resultados = await Future.wait([
        _getListaSegura('/clientes/', headers),
        _getListaSegura('/vehiculos/', headers),
      ]);

      return {
        'clientes': resultados[0],
        'vehiculos': resultados[1],
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
  Future<Map<String, dynamic>> getPerfilData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'usuario_id': prefs.getInt(AppConstants.userIdKey) ?? 0,
      'nombre': prefs.getString(AppConstants.userNombreKey) ?? 'Usuario',
      'rol': prefs.getString(AppConstants.userRolKey) ?? 'Sin Rol',
      'correo': prefs.getString(AppConstants.userCorreoKey) ?? 'Sin Correo',
    };
  }

  /// Obtiene todos los datos del patio, horario del servidor, catálogos dinámicos, bahías, pagos, comisiones y operarios activos.
  Future<Map<String, dynamic>> obtenerDatosPatio() async {
    final headers = await getHeaders();
    final prefs = await SharedPreferences.getInstance();
    final int currentUserId = prefs.getInt(AppConstants.userIdKey) ?? 0;

    // 0. Inicializar datos base y consultar usuarios primero para garantizar catálogos y cliente comodín en MySQL
    final usuariosInicial =
        await _getListaSegura('/finanzas/usuarios', headers);

    final resOrdenes = await http
        .get(Uri.parse('$_apiUrl/ordenes/'), headers: headers)
        .timeout(const Duration(seconds: 6));
    final resVehiculos = await http
        .get(Uri.parse('$_apiUrl/vehiculos/'), headers: headers)
        .timeout(const Duration(seconds: 6));

    if (resOrdenes.statusCode != 200 || resVehiculos.statusCode != 200) {
      String error = 'Error del servidor';
      try {
        final body = jsonDecode(utf8.decode(resOrdenes.bodyBytes));
        if (body['detail'] != null) error = body['detail'].toString();
      } catch (_) {}
      return {'success': false, 'error': error};
    }

    // Consultas dinámicas en paralelo para sincronización 100% desde los endpoints de la API
    final secundarios = await Future.wait([
      _getListaSegura('/clientes/', headers), // 0
      _getListaSegura('/bahias/', headers), // 1
      _getListaSegura('/categorias-vehiculos/', headers), // 2
      _getListaSegura('/servicios/base', headers), // 3
      _getListaSegura('/servicios/matriz-precios', headers), // 4
      _getListaSegura('/servicios/adicionales', headers), // 5
      _getListaSegura('/finanzas/pagos', headers), // 6
      _getListaSegura('/finanzas/comisiones', headers), // 7
    ]);
    final estadoHorarioMap =
        await _getMapaSeguro('/ordenes/estado-horario', headers);

    final ahoraLocal = ahoraSV();
    final bool recepcionAbierta =
        estadoHorarioMap.containsKey('recepcion_abierta')
            ? (estadoHorarioMap['recepcion_abierta'] == true)
            : (ahoraLocal.hour >= 7 && ahoraLocal.hour < 17);
    final bool enVentanaProrroga =
        estadoHorarioMap.containsKey('en_ventana_prorroga')
            ? (estadoHorarioMap['en_ventana_prorroga'] == true)
            : (ahoraLocal.hour == 16 && ahoraLocal.minute >= 45);
    final String horaSvStr = (estadoHorarioMap['hora_sv'] ??
            '${ahoraLocal.hour.toString().padLeft(2, '0')}:${ahoraLocal.minute.toString().padLeft(2, '0')}')
        .toString();
    final String mensajeHorario = (estadoHorarioMap['mensaje'] ??
            (!recepcionAbierta
                ? 'Recepción cerrada: Solo se permite registrar órdenes de 7:00 AM a 5:00 PM.'
                : (enVentanaProrroga
                    ? 'Aviso (4:45 PM - 5:00 PM): La orden se registrará pero aparecerá programada para el día siguiente.'
                    : 'Recepción abierta (7:00 AM - 5:00 PM).')))
        .toString();

    final List<dynamic> ordenesJson =
        jsonDecode(utf8.decode(resOrdenes.bodyBytes));
    final List<dynamic> vehiculosJson =
        jsonDecode(utf8.decode(resVehiculos.bodyBytes));
    final List<dynamic> clientesJson = secundarios[0];
    final List<dynamic> bahiasJson = secundarios[1];
    final List<dynamic> categoriasJson = secundarios[2];
    final List<dynamic> serviciosBaseJson = secundarios[3];
    final List<dynamic> matrizPreciosJson = secundarios[4];
    final List<dynamic> adicionalesJson = secundarios[5];
    final List<dynamic> pagosJson = secundarios[6];
    final List<dynamic> comisionesJson = secundarios[7];
    final List<dynamic> usuariosJson = usuariosInicial;

    // Verificar si el usuario logueado fue desactivado (estado == 0) o cambiado a Cajero (rol_id == 2)
    bool usuarioInactivo = false;
    if (currentUserId > 0 && usuariosJson.isNotEmpty) {
      for (final u in usuariosJson) {
        final int uid = int.tryParse(u['id']?.toString() ?? '0') ?? 0;
        if (uid == currentUserId) {
          final int est = int.tryParse(u['estado']?.toString() ?? '1') ?? 1;
          final int rolId = int.tryParse(u['rol_id']?.toString() ?? '3') ?? 3;
          if (est == 0 || rolId == 2) usuarioInactivo = true;
          break;
        }
      }
    }

    // Actualizar cachés de catálogos exclusivamente desde los endpoints de la API (cero datos locales)
    _categoriasCache =
        categoriasJson.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    _serviciosBaseCache = serviciosBaseJson
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    _matrizPreciosCache = matrizPreciosJson
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    _serviciosAdicionalesCache = adicionalesJson
        .map((e) =>
            ServicioExtraModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    // Mapas rápidos por ID
    final Map<int, Map<String, dynamic>> vehMap = {
      for (var v in vehiculosJson)
        (int.tryParse(v['id']?.toString() ?? '0') ?? 0):
            Map<String, dynamic>.from(v)
    };
    final Map<int, Map<String, dynamic>> cliMap = {
      for (var c in clientesJson)
        (int.tryParse(c['id']?.toString() ?? '0') ?? 0):
            Map<String, dynamic>.from(c)
    };
    final Map<int, String> catNombreMap = {
      for (var c in _categoriasCache)
        (int.tryParse(c['id']?.toString() ?? '0') ?? 0):
            (c['nombre'] ?? '').toString()
    };
    final Map<int, String> usrNombreMap = {
      for (var u in usuariosJson)
        (int.tryParse(u['id']?.toString() ?? '0') ?? 0):
            (u['nombre_completo'] ?? '').toString()
    };
    final Map<int, int> usrRolMap = {
      for (var u in usuariosJson)
        (int.tryParse(u['id']?.toString() ?? '0') ?? 0):
            (int.tryParse(u['rol_id']?.toString() ?? '3') ?? 3)
    };

    // Operarios activos reales (rol_id == 3 y estado == 1)
    final List<Map<String, dynamic>> operariosActivos = usuariosJson
        .where((u) {
          final int rolId = int.tryParse(u['rol_id']?.toString() ?? '0') ?? 0;
          final int estado = int.tryParse(u['estado']?.toString() ?? '0') ?? 0;
          return rolId == 3 && estado == 1;
        })
        .map((u) => Map<String, dynamic>.from(u as Map))
        .toList();

    // Órdenes pagadas reales desde GET /finanzas/pagos
    final Set<int> ordenesPagadas = {};
    final Set<int> pagosHoyOrdenIds = {};
    for (final p in pagosJson) {
      final int oid = int.tryParse(p['orden_id']?.toString() ?? '0') ?? 0;
      if (oid > 0) {
        ordenesPagadas.add(oid);
        if (esFechaDeHoySV(p['fecha_pago']?.toString())) {
          pagosHoyOrdenIds.add(oid);
        }
      }
    }

    // Órdenes con comisión cerrada desde GET /finanzas/comisiones
    final Set<int> ordenesComisionadasIds = {};
    final Map<int, List<String>> operariosPorOrden = {};
    final Map<int, double> comisionTotalPorOrden = {};

    for (final com in comisionesJson) {
      final int oid = int.tryParse(com['orden_id']?.toString() ?? '0') ?? 0;
      final int uid = int.tryParse(com['usuario_id']?.toString() ?? '0') ?? 0;
      final double montoCom =
          double.tryParse(com['comision_calculada']?.toString() ?? '0') ?? 0.0;
      if (oid > 0) {
        ordenesComisionadasIds.add(oid);
        final nombreOp = usrNombreMap[uid] ?? 'Operario #$uid';
        operariosPorOrden.putIfAbsent(oid, () => []).add(nombreOp);
        comisionTotalPorOrden[oid] =
            (comisionTotalPorOrden[oid] ?? 0.0) + montoCom;
      }
    }

    // Construir y filtrar órdenes del turno actual (Zona Horaria El Salvador UTC-6)
    final List<VehiculoPatio> listaConstruida = [];
    final Set<int> ordenesTurnoIds = {};
    int lavadosTerminadosHoy = 0;
    int vehiculosEnPatio = 0;

    for (final o in ordenesJson) {
      final int oid = int.tryParse(o['id']?.toString() ?? '0') ?? 0;
      final int vid = int.tryParse(o['vehiculo_id']?.toString() ?? '0') ?? 0;
      final int bahiaId = int.tryParse(o['bahia_id']?.toString() ?? '1') ?? 1;
      final int vecesPospuesta =
          int.tryParse(o['veces_pospuesta']?.toString() ?? '0') ?? 0;

      final String? createdAtStr = o['created_at']?.toString();

      // Excluir órdenes programadas o pospuestas para mañana (fecha local SV > hoy)
      if (esFechaFuturaSV(createdAtStr)) {
        continue;
      }

      final estadoStr = (o['estado'] ?? 'Pendiente').toString().toLowerCase();
      int fase = 0;
      if (estadoStr.contains('proceso')) fase = 1;
      if (estadoStr.contains('listo') ||
          estadoStr.contains('terminado') ||
          estadoStr.contains('pagado') ||
          estadoStr.contains('entregado')) {
        fase = 2;
      }

      final bool esDeHoy = esFechaDeHoySV(createdAtStr);
      final bool yaPagada = ordenesPagadas.contains(oid);
      final bool yaComisionada = ordenesComisionadasIds.contains(oid);

      // Filtro operativo estricto: mostrar únicamente las órdenes cuya fecha local en El Salvador sea HOY
      if (!esDeHoy) {
        continue;
      }

      ordenesTurnoIds.add(oid);
      if (fase == 0 || fase == 1) {
        vehiculosEnPatio++;
      } else if (fase == 2) {
        lavadosTerminadosHoy++;
      }

      final veh = vehMap[vid] ?? {};
      final int catId =
          int.tryParse(veh['categoria_vehiculo_id']?.toString() ?? '1') ?? 1;
      final int clienteOrdenId = int.tryParse(
              (o['cliente_id'] ?? veh['cliente_id'] ?? '0').toString()) ??
          0;
      final cli = cliMap[clienteOrdenId] ?? {};
      final String catNombre = catNombreMap[catId] ?? '';

      final double total =
          double.tryParse((o['total_pagar'] ?? '0').toString()) ?? 0.0;
      final double precioRespaldo = obtenerPrecioMatriz(catId, 1) * 1.13;
      final double montoMostrar =
          total > 0 ? total : double.parse(precioRespaldo.toStringAsFixed(2));

      final List<String> ops = operariosPorOrden[oid] ?? [];

      listaConstruida.add(
        VehiculoPatio(
          ordenId: oid,
          vehiculoId: vid,
          bahiaId: bahiaId,
          categoriaId: catId,
          placa: normalizarPlacaSV((veh['placa'] ?? 'SIN-PLACA').toString()),
          marca: (veh['marca'] ?? '').toString(),
          modelo: (veh['modelo'] ?? '').toString(),
          color: (veh['color'] ?? '').toString(),
          categoria: catNombre,
          cliente: (cli['nombre_completo'] ?? 'Cliente General').toString(),
          correoCliente: (cli['correo'] ?? '').toString(),
          telefonoCliente: (cli['telefono'] ?? '---').toString(),
          bahia: 'Bahía $bahiaId',
          servicio: 'Orden #${oid.toString().padLeft(4, '0')}',
          montoNumerico: montoMostrar,
          totalPagar: '\$${montoMostrar.toStringAsFixed(2)}',
          esDeHoy: esDeHoy,
          fechaHoraTexto: formatearFechaHoraSV(createdAtStr),
          operariosAsignados: ops.join(', '),
          comisionOrden: comisionTotalPorOrden[oid] ?? 0.0,
          vecesPospuesta: vecesPospuesta,
          fase: fase,
          pagado: yaPagada,
          comisionada: yaComisionada,
        ),
      );
    }

    // Ordenar tarjetas: primero órdenes activas (En proceso y Pendiente) y al final las Terminadas de hoy
    int prioridadFase(int f) {
      if (f == 1) return 0; // En proceso primero
      if (f == 0) return 1; // Pendiente segundo
      return 2; // Terminado al final
    }

    listaConstruida.sort((a, b) {
      final int cmpFase =
          prioridadFase(a.fase).compareTo(prioridadFase(b.fase));
      if (cmpFase != 0) return cmpFase;
      return b.ordenId.compareTo(a.ordenId);
    });

    // Calcular comisiones del turno actual para el operario logueado (y total planilla para supervisor)
    double miComisionHoy = 0.0;
    int misLavadosComision = 0;
    double totalComisionesTurno = 0.0;
    int totalAsignacionesTurno = 0;

    for (final com in comisionesJson) {
      final int oid = int.tryParse(com['orden_id']?.toString() ?? '0') ?? 0;
      if (!ordenesTurnoIds.contains(oid)) continue;

      final int uid = int.tryParse(com['usuario_id']?.toString() ?? '0') ?? 0;
      if (usrRolMap[uid] != null && usrRolMap[uid] != 3) continue;

      final double monto =
          double.tryParse(com['comision_calculada']?.toString() ?? '0') ?? 0.0;
      totalComisionesTurno += monto;
      totalAsignacionesTurno++;

      if (currentUserId > 0 && uid == currentUserId) {
        miComisionHoy += monto;
        misLavadosComision++;
      }
    }

    final bool esOperario =
        currentUserId > 0 && (usrRolMap[currentUserId] ?? 3) == 3;
    final bool esAdmin = currentUserId > 0 && usrRolMap[currentUserId] == 1;
    final double comisionMostrar = esAdmin
        ? totalComisionesTurno
        : (esOperario ? miComisionHoy : totalComisionesTurno);
    final int cantidadComisionMostrar = esAdmin
        ? totalAsignacionesTurno
        : (esOperario ? misLavadosComision : totalAsignacionesTurno);

    return {
      'success': true,
      'usuarioInactivo': usuarioInactivo,
      'recepcionAbierta': recepcionAbierta,
      'enVentanaProrroga': enVentanaProrroga,
      'horaSv': horaSvStr,
      'mensajeHorario': mensajeHorario,
      'vehiculos': listaConstruida,
      'lavadosTerminadosHoy': lavadosTerminadosHoy,
      'vehiculosEnPatio': vehiculosEnPatio,
      'totalComisionesOperarios': comisionMostrar,
      'miComisionHoy': miComisionHoy,
      'misLavadosComision': misLavadosComision,
      'totalComisionesPlanilla': totalComisionesTurno,
      'cantidadLavadosComision': cantidadComisionMostrar,
      'ordenesPagadasIds': ordenesPagadas,
      'ordenesComisionadasIds': ordenesComisionadasIds,
      'operariosActivos': operariosActivos,
      'bahias': bahiasJson,
      'categorias': _categoriasCache,
      'serviciosBase': _serviciosBaseCache,
      'matrizPrecios': _matrizPreciosCache,
      'serviciosAdicionales': _serviciosAdicionalesCache,
      'clientesDirectorio': clientesJson,
      'vehiculosDirectorio': vehiculosJson,
    };
  }

  // ─── OPERACIONES DE ÓRDENES Y COMISIONES ────────────────────

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

  /// Pospone una orden Pendiente para el día siguiente a las 7:00 AM (máximo 1 vez).
  Future<Map<String, dynamic>> posponerOrden(int ordenId) async {
    try {
      final headers = await getHeaders();
      final res = await http
          .post(
            Uri.parse('$_apiUrl/ordenes/$ordenId/posponer'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        return {'success': true};
      }

      String error = 'No se pudo posponer la orden';
      try {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        if (body['detail'] != null) error = body['detail'].toString();
      } catch (_) {}
      return {'success': false, 'error': error};
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  /// Asigna 1 o varios operarios a una orden terminada para cálculo y cierre de comisión.
  Future<Map<String, dynamic>> asignarOperarios({
    required int ordenId,
    required List<int> operariosIds,
  }) async {
    try {
      if (operariosIds.isEmpty) {
        return {
          'success': false,
          'error': 'Debe seleccionar al menos un operario activo.',
        };
      }

      final headers = await getHeaders();
      final res = await http
          .post(
            Uri.parse('$_apiUrl/finanzas/asignar-operarios'),
            headers: headers,
            body: jsonEncode({
              'orden_id': ordenId,
              'operarios_ids': operariosIds,
              'comision_extra_manual': 0.0,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        return {'success': true};
      }

      String error = 'No se pudo asignar operarios';
      try {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        if (body['detail'] != null) error = body['detail'].toString();
      } catch (_) {}
      return {'success': false, 'error': error};
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  // ─── RECEPCIÓN DE VEHÍCULO ──────────────────────────────────

  /// Crea un cliente en la API incluyendo teléfono (0000-0000) y correo electrónico.
  Future<Map<String, dynamic>> crearCliente(
    String nombre, [
    String? telefono,
    String? correo,
  ]) async {
    final headers = await getHeaders();
    final Map<String, dynamic> body = {
      'nombre_completo': nombre.trim(),
    };
    if (telefono != null && telefono.trim().isNotEmpty) {
      body['telefono'] = telefono.trim();
    }
    if (correo != null && correo.trim().isNotEmpty) {
      body['correo'] = correo.trim().toLowerCase();
    }

    final res = await http.post(
      Uri.parse('$_apiUrl/clientes/'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      final id = jsonDecode(utf8.decode(res.bodyBytes))['id'] ?? 1;
      return {'success': true, 'id': id};
    }

    String error = 'Error al crear cliente';
    try {
      error =
          jsonDecode(utf8.decode(res.bodyBytes))['detail']?.toString() ?? error;
    } catch (_) {}
    return {'success': false, 'error': error};
  }

  /// Actualiza teléfono o correo de un cliente existente si fueron completados en recepción.
  Future<void> actualizarClienteParcial({
    required int clienteId,
    String? nombre,
    String? telefono,
    String? correo,
  }) async {
    try {
      if (nombre != null && nombre.toUpperCase().contains('CONSUMIDOR FINAL')) {
        return;
      }
      final headers = await getHeaders();
      final Map<String, dynamic> body = {};
      if (nombre != null && nombre.trim().isNotEmpty) {
        body['nombre_completo'] = nombre.trim();
      }
      if (telefono != null && telefono.trim().isNotEmpty) {
        body['telefono'] = telefono.trim();
      }
      if (correo != null && correo.trim().isNotEmpty) {
        body['correo'] = correo.trim().toLowerCase();
      }
      if (body.isEmpty) return;

      await http
          .patch(
            Uri.parse('$_apiUrl/clientes/$clienteId'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint(
          '[ApiService] Advertencia actualizando cliente #$clienteId: $e');
    }
  }

  /// Actualiza categoría, marca, modelo, color y último cliente de un vehículo existente vía PATCH.
  Future<void> actualizarVehiculoParcial({
    required int vehiculoId,
    int? clienteId,
    required int categoriaId,
    required String marca,
    required String modelo,
    required String color,
  }) async {
    try {
      final headers = await getHeaders();
      final Map<String, dynamic> body = {
        'categoria_vehiculo_id': categoriaId,
        'marca': marca.trim(),
        'modelo': modelo.trim(),
        'color': color.trim(),
      };
      if (clienteId != null && clienteId > 0) {
        body['cliente_id'] = clienteId;
      }
      await http
          .patch(
            Uri.parse('$_apiUrl/vehiculos/$vehiculoId'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint(
          '[ApiService] Advertencia actualizando vehículo #$vehiculoId: $e');
    }
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
        'placa': normalizarPlacaSV(placa),
        'marca': marca.trim(),
        'modelo': modelo.trim(),
        'color': color.trim(),
      }),
    );

    if (res.statusCode == 200) {
      final id = jsonDecode(utf8.decode(res.bodyBytes))['id'];
      return {'success': true, 'id': id};
    }

    String error = 'Error al crear vehículo';
    try {
      error =
          jsonDecode(utf8.decode(res.bodyBytes))['detail']?.toString() ?? error;
    } catch (_) {}
    return {'success': false, 'error': error};
  }

  /// Crea una orden de lavado enviando vehiculo_id, cliente_id y bahia_id.
  Future<Map<String, dynamic>> crearOrden({
    required int vehiculoId,
    int? clienteId,
    required int bahiaId,
  }) async {
    final headers = await getHeaders();
    final Map<String, dynamic> body = {
      'vehiculo_id': vehiculoId,
      'bahia_id': bahiaId,
      'estado': 'Pendiente',
    };
    if (clienteId != null && clienteId > 0) {
      body['cliente_id'] = clienteId;
    }

    final res = await http.post(
      Uri.parse('$_apiUrl/ordenes/'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'success': true,
        'id': decoded['id'],
        'veces_pospuesta': decoded['veces_pospuesta'] ?? 0,
      };
    }

    String error = 'Error al crear orden';
    try {
      error =
          jsonDecode(utf8.decode(res.bodyBytes))['detail']?.toString() ?? error;
    } catch (_) {}
    return {'success': false, 'error': error};
  }

  /// Registra un servicio base y/o servicio adicional en /detalles-orden/.
  /// El backend recalcula automáticamente subtotal, IVA 13% y total_pagar.
  Future<bool> agregarDetalleOrden({
    required int ordenId,
    int? servicioBaseId,
    int? servicioAdicionalId,
  }) async {
    try {
      final headers = await getHeaders();
      final Map<String, dynamic> body = {'orden_id': ordenId};
      if (servicioBaseId != null) {
        body['servicio_base_id'] = servicioBaseId;
      }
      if (servicioAdicionalId != null) {
        body['servicio_adicional_id'] = servicioAdicionalId;
      }

      final res = await http.post(
        Uri.parse('$_apiUrl/detalles-orden/'),
        headers: headers,
        body: jsonEncode(body),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] Error agregando detalle: $e');
      return false;
    }
  }

  /// Flujo de recepción de vehículo en el patio 100% respaldado por la API:
  /// Soporta cliente existente, Consumidor Final o nueva persona autorizada por orden,
  /// conserva el propietario titular del vehículo si ya existe, y delega el cálculo de IVA 13% a /detalles-orden/.
  Future<Map<String, dynamic>> recibirVehiculo({
    int? clienteIdExistente,
    int? vehiculoIdExistente,
    required String placa,
    required String marca,
    required String modelo,
    required String color,
    required String nombreCliente,
    required String telefonoCliente,
    String? correoCliente,
    required int categoriaId,
    int servicioBaseId = 1,
    required int bahiaId,
    List<double> extras = const [],
    List<int> extrasIds = const [],
  }) async {
    try {
      int targetClienteId;
      int targetVehiculoId;
      final String placaNormalizada = normalizarPlacaSV(placa);

      // 1. Resolver el cliente o persona autorizada para esta orden
      if (clienteIdExistente != null && clienteIdExistente > 0) {
        targetClienteId = clienteIdExistente;
        await actualizarClienteParcial(
          clienteId: clienteIdExistente,
          nombre: nombreCliente,
          telefono: telefonoCliente,
          correo: correoCliente,
        );
      } else {
        final resCli = await crearCliente(
          nombreCliente,
          telefonoCliente,
          correoCliente,
        );
        if (resCli['success'] != true) return resCli;
        targetClienteId = resCli['id'];
      }

      // 2. Resolver el vehículo (si ya existe, actualizar datos técnicos conservando el titular original)
      if (vehiculoIdExistente != null && vehiculoIdExistente > 0) {
        targetVehiculoId = vehiculoIdExistente;
        await actualizarVehiculoParcial(
          vehiculoId: vehiculoIdExistente,
          categoriaId: categoriaId,
          marca: marca,
          modelo: modelo,
          color: color,
        );
      } else {
        final resVeh = await crearVehiculo(
          clienteId: targetClienteId,
          categoriaId: categoriaId,
          placa: placaNormalizada,
          marca: marca,
          modelo: modelo,
          color: color,
        );
        if (resVeh['success'] != true) return resVeh;
        targetVehiculoId = resVeh['id'];
      }

      // 3. Crear la orden enviando cliente_id para esta orden específica
      final resOrd = await crearOrden(
        vehiculoId: targetVehiculoId,
        clienteId: targetClienteId,
        bahiaId: bahiaId,
      );
      if (resOrd['success'] != true) return resOrd;

      final int ordenId = resOrd['id'];

      // 4. Registrar el servicio base en POST /detalles-orden/ (la API calcula subtotal, IVA 13% y total_pagar)
      await agregarDetalleOrden(
        ordenId: ordenId,
        servicioBaseId: servicioBaseId,
      );

      // 5. Registrar cada servicio adicional en POST /detalles-orden/
      for (final extraId in extrasIds) {
        await agregarDetalleOrden(
          ordenId: ordenId,
          servicioAdicionalId: extraId,
        );
      }

      return {
        'success': true,
        'orden_id': ordenId,
        'programada_manana': (resOrd['veces_pospuesta'] ?? 0) >= 1,
      };
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  // ─── INVENTARIO (CONSULTA EN TIEMPO REAL) ───────────────────

  /// Obtiene la lista completa de insumos del inventario desde el VPS.
  Future<List<InventarioModel>> obtenerInventario() async {
    final headers = await getHeaders();
    final response = await http
        .get(Uri.parse('$_apiUrl/inventario/'), headers: headers)
        .timeout(const Duration(seconds: 6));

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
      return list
          .map((item) => InventarioModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      String errorMsg =
          'Error al consultar inventario (${response.statusCode})';
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body['detail'] != null) errorMsg = body['detail'].toString();
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }
}
