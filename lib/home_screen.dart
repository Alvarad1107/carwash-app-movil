import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'login_screen.dart';

class VehiculoPatio {
  final int ordenId;
  final int vehiculoId;
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
  int fase;
  bool pagado;

  VehiculoPatio({
    required this.ordenId,
    required this.vehiculoId,
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
    this.fase = 0,
    this.pagado = false,
  });

  String get nombreCompletoCarro => '$marca $modelo'.trim();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color kRoyalBlue = Color(0xFF1422B8);

  // Se puede cambiar desde el ícono de engranaje en la pestaña "Perfil" por la IP de tu PC o VPS
  String _apiUrl = 'http://68.211.73.10:8000';  
  bool _cargandoApi = false;
  bool _conectadoConApi = false;

  int _selectedIndex = 0;
  String _busqueda = '';
  String _filtroControl = 'Todos';

  double _totalComisionesOperarios = 0.0;
  double _totalCobradoHoy = 0.0;
  int _cantidadLavadosComision = 0;

  static const List<String> _nombresFase = [
    'Pendiente',
    'En proceso',
    'Terminado'
  ];

  // Nombres exactos que espera el endpoint PATCH /ordenes/{id}/estado en FastAPI
  static const List<String> _estadosApi = [
    'Pendiente',
    'En proceso',
    'Listo para entrega'
  ];

  static const List<Color> _coloresFase = [
    Color(0xFFF59E0B),
    Color(0xFF2563EB),
    Color(0xFF16A34A),
  ];

  static const List<Color> _fondosFase = [
    Color(0xFFFEF3C7),
    Color(0xFFDBEAFE),
    Color(0xFFDCFCE7),
  ];

  static const List<IconData> _iconosFase = [
    Icons.hourglass_top_rounded,
    Icons.autorenew_rounded,
    Icons.check_circle_rounded,
  ];

  final int _totalBahias = 6;

  bool _bahiaOcupada(int numero) {
    return _vehiculos.any((v) => v.bahia == 'Bahia $numero' && v.fase == 1);
  }

  int? _primeraBahiaLibre() {
    for (int i = 1; i <= _totalBahias; i++) {
      if (!_bahiaOcupada(i)) return i;
    }
    return 1;
  }

  List<VehiculoPatio> _vehiculos = [
    VehiculoPatio(
      ordenId: 1,
      vehiculoId: 1,
      placa: 'P765765',
      marca: 'Toyota',
      modelo: 'Corolla',
      color: 'Rojo',
      categoria: 'Sedán',
      cliente: 'Julian Alexander Alvarado Moreno',
      correoCliente: 'alvaradomaster1107@gmail.com',
      telefonoCliente: '7898-9877',
      bahia: 'Bahia 1',
      servicio: 'Orden de Lavado',
      montoNumerico: 19.00,
      totalPagar: '\$19.00',
      fase: 2,
    ),
    VehiculoPatio(
      ordenId: 2,
      vehiculoId: 2,
      placa: 'P470937',
      marca: 'Toyota',
      modelo: '22R',
      color: 'Blanco',
      categoria: 'Pick Up',
      cliente: 'Erick Anibal Herrera Guevara',
      correoCliente: 'erickherrerashh@gmail.com',
      telefonoCliente: '6310-0933',
      bahia: 'Bahia 2',
      servicio: 'Orden de Lavado',
      montoNumerico: 8.00,
      totalPagar: '\$8.00',
      fase: 1,
    ),
    VehiculoPatio(
      ordenId: 3,
      vehiculoId: 3,
      placa: 'P675443',
      marca: 'Nissan',
      modelo: 'Rogue',
      color: 'Negro',
      categoria: 'Sedán',
      cliente: 'Brayan Edenilson Escamilla Rios',
      correoCliente: 'bescamillarios12@gmail.com',
      telefonoCliente: '7857-4566',
      bahia: 'Bahia 3',
      servicio: 'Orden de Lavado',
      montoNumerico: 19.00,
      totalPagar: '\$19.00',
      fase: 2,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _obtenerDatosDeApi();
  }

  String _nombreCategoria(int? catId) {
    switch (catId) {
      case 1:
        return 'Sedán';
      case 2:
        return 'Pick Up';
      case 3:
        return 'Carros Medianos';
      case 4:
        return 'Carros Grandes';
      case 5:
        return 'Microbús';
      default:
        return 'Sedán';
    }
  }

  Future<void> _obtenerDatosDeApi({bool mostrarMensaje = false}) async {
    setState(() => _cargandoApi = true);
    try {
      final resOrdenes = await http
          .get(Uri.parse('$_apiUrl/ordenes/'))
          .timeout(const Duration(seconds: 4));
      final resVehiculos = await http
          .get(Uri.parse('$_apiUrl/vehiculos/'))
          .timeout(const Duration(seconds: 4));
      final resClientes = await http
          .get(Uri.parse('$_apiUrl/clientes/'))
          .timeout(const Duration(seconds: 4));
      final resPagos = await http
          .get(Uri.parse('$_apiUrl/finanzas/pagos'))
          .timeout(const Duration(seconds: 4));
      final resComisiones = await http
          .get(Uri.parse('$_apiUrl/finanzas/comisiones'))
          .timeout(const Duration(seconds: 4));

      if (resOrdenes.statusCode == 200 && resVehiculos.statusCode == 200) {
        final List<dynamic> ordenesJson =
            jsonDecode(utf8.decode(resOrdenes.bodyBytes));
        final List<dynamic> vehiculosJson =
            jsonDecode(utf8.decode(resVehiculos.bodyBytes));
        final List<dynamic> clientesJson = resClientes.statusCode == 200
            ? jsonDecode(utf8.decode(resClientes.bodyBytes))
            : [];
        final List<dynamic> pagosJson = resPagos.statusCode == 200
            ? jsonDecode(utf8.decode(resPagos.bodyBytes))
            : [];
        final List<dynamic> comisionesJson = resComisiones.statusCode == 200
            ? jsonDecode(utf8.decode(resComisiones.bodyBytes))
            : [];

        final Map<int, Map<String, dynamic>> vehMap = {
          for (var v in vehiculosJson) (v['id'] as int): Map<String, dynamic>.from(v)
        };
        final Map<int, Map<String, dynamic>> cliMap = {
          for (var c in clientesJson) (c['id'] as int): Map<String, dynamic>.from(c)
        };
        final Set<int> ordenesPagadas = {
          for (var p in pagosJson) (p['orden_id'] as int)
        };

        double sumaPagos = 0.0;
        for (var p in pagosJson) {
          sumaPagos += double.tryParse(p['monto'].toString()) ?? 0.0;
        }

        double sumaComisiones = 0.0;
        for (var cm in comisionesJson) {
          sumaComisiones +=
              double.tryParse(cm['comision_calculada'].toString()) ?? 0.0;
        }

        final List<VehiculoPatio> listaConstruida = [];
        for (var o in ordenesJson) {
          final int oid = o['id'] ?? 1;
          final int vid = o['vehiculo_id'] ?? 1;
          final veh = vehMap[vid] ?? {};
          final cli = cliMap[veh['cliente_id']] ?? {};

          final estadoStr = (o['estado'] ?? 'Pendiente').toString().toLowerCase();
          int fase = 0;
          if (estadoStr.contains('proceso')) fase = 1;
          if (estadoStr.contains('listo') || estadoStr.contains('terminado')) {
            fase = 2;
          }

          final double total =
              double.tryParse((o['total_pagar'] ?? '0').toString()) ?? 0.0;
          final double montoMostrar = total > 0 ? total : 8.00;

          listaConstruida.add(
            VehiculoPatio(
              ordenId: oid,
              vehiculoId: vid,
              placa: (veh['placa'] ?? 'SIN-PLACA').toString(),
              marca: (veh['marca'] ?? 'Vehículo').toString(),
              modelo: (veh['modelo'] ?? '').toString(),
              color: (veh['color'] ?? 'N/A').toString(),
              categoria: _nombreCategoria(veh['categoria_vehiculo_id']),
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

        setState(() {
          if (listaConstruida.isNotEmpty) {
            _vehiculos = listaConstruida;
          }
          _totalCobradoHoy = sumaPagos;
          _totalComisionesOperarios = sumaComisiones;
          _cantidadLavadosComision = comisionesJson.length;
          _conectadoConApi = true;
        });

        if (mostrarMensaje && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF15803D),
              content: Text('Sincronizado en tiempo real con sprintwash_db'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {
      setState(() => _conectadoConApi = false);
      if (mostrarMensaje && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFB45309),
            content: Text('Sin conexión a $_apiUrl (Modo local activo)'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargandoApi = false);
      }
    }
  }

  Future<void> _cambiarEstado(VehiculoPatio v, int nuevaFase) async {
    setState(() {
      v.fase = nuevaFase;
    });

    try {
      await http
          .patch(
            Uri.parse('$_apiUrl/ordenes/${v.ordenId}/estado'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'estado': _estadosApi[nuevaFase],
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _coloresFase[v.fase],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          v.fase == 2
              ? '${v.nombreCompletoCarro} (${v.placa}) -> LISTO PARA ENTREGA\nPre-factura enviada a: ${v.correoCliente}'
              : '${v.nombreCompletoCarro} (${v.placa}) -> ${_nombresFase[v.fase].toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _abrirModalCobro(VehiculoPatio v) async {
    String metodoSeleccionado = 'Efectivo';
    bool seleccionoDosOperarios = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Cobrar Orden #${v.ordenId} (${v.placa})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cliente: ${v.cliente}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Total a cobrar: ${v.totalPagar}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kRoyalBlue,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: metodoSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Método de Pago',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                      DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta')),
                      DropdownMenuItem(
                        value: 'Transferencia',
                        child: Text('Transferencia / QR'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => metodoSeleccionado = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Lavado Simultáneo (2 Operarios)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Divide automáticamente la comisión en planilla',
                      style: TextStyle(fontSize: 11.5),
                    ),
                    value: seleccionoDosOperarios,
                    onChanged: (val) {
                      setDialogState(() => seleccionoDosOperarios = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await http.post(
                        Uri.parse('$_apiUrl/finanzas/pagos'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'orden_id': v.ordenId,
                          'cajero_id': 2,
                          'metodo_pago': metodoSeleccionado,
                          'monto': v.montoNumerico,
                        }),
                      );
                      await http.post(
                        Uri.parse('$_apiUrl/finanzas/asignar-operarios'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'orden_id': v.ordenId,
                          'operarios_ids': seleccionoDosOperarios ? [3, 4] : [3],
                          'comision_extra_manual': 0.0,
                        }),
                      );
                    } catch (_) {}
                    if (context.mounted) Navigator.pop(context);
                    await _obtenerDatosDeApi(mostrarMensaje: true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
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

  void _configurarUrlApi() {
    final urlCtrl = TextEditingController(text: _apiUrl);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Conexión API Sprint Wash',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dirección IP o VPS del servidor FastAPI (puerto 8000):',
                style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  hintText: 'http://127.0.0.1:8000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final limpio =
                    urlCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
                if (limpio.isNotEmpty) {
                  setState(() => _apiUrl = limpio);
                }
                Navigator.pop(context);
                _obtenerDatosDeApi(mostrarMensaje: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kRoyalBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Conectar'),
            ),
          ],
        );
      },
    );
  }

  void _abrirModalRecepcion() {
    final placaCtrl = TextEditingController();
    final marcaCtrl = TextEditingController();
    final modeloCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final clienteCtrl = TextEditingController();
    int categoriaIdSeleccionada = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 22,
                right: 22,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Recepción de Vehículo en Patio',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: placaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Placa (ej. P123456)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
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
                            labelText: 'Modelo (ej. Hilux)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: categoriaIdSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Categoría de Vehículo',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Sedán (\$4.00 Base)')),
                      DropdownMenuItem(value: 2, child: Text('Pick Up (\$8.00 Base)')),
                      DropdownMenuItem(value: 3, child: Text('Carros Medianos (\$6.00)')),
                      DropdownMenuItem(value: 4, child: Text('Carros Grandes (\$8.00)')),
                      DropdownMenuItem(value: 5, child: Text('Microbús (\$10.00)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => categoriaIdSeleccionada = val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: clienteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Cliente',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final placa = placaCtrl.text.trim().isEmpty
                          ? 'P-${DateTime.now().millisecondsSinceEpoch % 100000}'
                          : placaCtrl.text.trim().toUpperCase();
                      final marca = marcaCtrl.text.trim().isEmpty
                          ? 'Toyota'
                          : marcaCtrl.text.trim();
                      final modelo = modeloCtrl.text.trim().isEmpty
                          ? 'Corolla'
                          : modeloCtrl.text.trim();
                      final color = colorCtrl.text.trim().isEmpty
                          ? 'Gris'
                          : colorCtrl.text.trim();
                      final nombreCli = clienteCtrl.text.trim().isEmpty
                          ? 'Cliente Patio'
                          : clienteCtrl.text.trim();
                      final precioBase = categoriaIdSeleccionada == 2 ? 8.00 : 4.00;
                      final totalConIva =
                          double.parse((precioBase * 1.13).toStringAsFixed(2));

                      try {
                        int clienteId = 1;
                        final resCli = await http.post(
                          Uri.parse('$_apiUrl/clientes/'),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode({'nombre_completo': nombreCli}),
                        );
                        if (resCli.statusCode == 200) {
                          clienteId = jsonDecode(resCli.body)['id'] ?? 1;
                        }

                        final resVeh = await http.post(
                          Uri.parse('$_apiUrl/vehiculos/'),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode({
                            'cliente_id': clienteId,
                            'categoria_vehiculo_id': categoriaIdSeleccionada,
                            'placa': placa,
                            'marca': marca,
                            'modelo': modelo,
                            'color': color,
                          }),
                        );

                        if (resVeh.statusCode == 200) {
                          final int vehId = jsonDecode(resVeh.body)['id'];
                          final resOrd = await http.post(
                            Uri.parse('$_apiUrl/ordenes/'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({
                              'vehiculo_id': vehId,
                              'bahia_id': 1,
                              'estado': 'Pendiente',
                            }),
                          );
                          if (resOrd.statusCode == 200) {
                            final int ordId = jsonDecode(resOrd.body)['id'];
                            await http.patch(
                              Uri.parse('$_apiUrl/ordenes/$ordId'),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                'subtotal': precioBase,
                                'impuestos':
                                    double.parse((precioBase * 0.13).toStringAsFixed(2)),
                                'total_pagar': totalConIva,
                              }),
                            );
                          }
                        }
                      } catch (_) {}

                      if (context.mounted) Navigator.pop(context);
                      await _obtenerDatosDeApi(mostrarMensaje: true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kRoyalBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text(
                      'Registrar en Patio (Pendiente)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
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
      floatingActionButton: _selectedIndex < 2
          ? FloatingActionButton.extended(
              onPressed: _abrirModalRecepcion,
              backgroundColor: kRoyalBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Recibir',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildPantallaInicio(),
            _buildPantallaControlPatio(),
            _buildPantallaPerfil(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: kRoyalBlue,
          unselectedItemColor: const Color(0xFF9CA3AF),
          selectedFontSize: 11.5,
          unselectedFontSize: 11.5,
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
                icono: Icons.payments_outlined,
                activo: _selectedIndex == 1,
              ),
              label: 'Cobros e Historial',
            ),
            BottomNavigationBarItem(
              icon: _IconoBarraInferior(
                icono: Icons.person_outline_rounded,
                activo: _selectedIndex == 2,
              ),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPantallaInicio() {
    final ocupadas =
        List.generate(_totalBahias, (i) => _bahiaOcupada(i + 1))
            .where((b) => b)
            .length;
    final libres = _totalBahias - ocupadas;

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
                const Text(
                  'Operaciones de Patio',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF111827),
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
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF6B7280),
                        ),
                  tooltip: 'Sincronizar con API',
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (valor) => setState(() => _busqueda = valor),
              decoration: InputDecoration(
                hintText: 'Buscar vehículo por placa o cliente...',
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF6B7280),
                ),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1424B8), Color(0xFF0C178C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: kRoyalBlue.withAlpha(55),
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
                      const Text(
                        'Estado de bahías',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
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
                    '$ocupadas ocupadas',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: List.generate(_totalBahias, (i) {
                      final ocupada = _bahiaOcupada(i + 1);
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(
                              right: i < _totalBahias - 1 ? 6 : 0),
                          height: 46,
                          decoration: BoxDecoration(
                            color: ocupada
                                ? const Color(0xFFD93829)
                                : const Color(0xFF1E8E3E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'B${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Vehículos en Patio',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedIndex = 1),
                  child: const Text(
                    'Ver Cobros e Historial',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: kRoyalBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...vehiculosFiltrados.map((v) {
              final color = _coloresFase[v.fase];
              final fondo = _fondosFase[v.fase];
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD1D5DB)),
                          ),
                          child: Text(
                            v.placa,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${v.nombreCompletoCarro} • ${v.categoria}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${v.bahia} • ${v.totalPagar} ${v.pagado ? "(PAGADO)" : ""}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: v.pagado
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: v.pagado
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: fondo,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _nombresFase[v.fase],
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
                        color: Color(0xFF4B5563),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
                                backgroundColor:
                                    activo ? _coloresFase[i] : _fondosFase[i],
                                foregroundColor:
                                    activo ? Colors.white : _coloresFase[i],
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: activo ? 2 : 0,
                              ),
                              child: Text(
                                _nombresFase[i],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPantallaControlPatio() {
    final tabs = ['Todos', ..._nombresFase];
    final filtrados = _vehiculos.where((v) {
      if (_filtroControl == 'Todos') return true;
      return _nombresFase[v.fase] == _filtroControl;
    }).toList();

    return SingleChildScrollView(
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
                'Cobros e Historial',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              _BotonIconoBorde(
                icono: Icons.sync_rounded,
                onTap: () => _obtenerDatosDeApi(mostrarMensaje: true),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Tarjetas de Resumen Financiero y Comisiones del Operario (Sprint 3)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MI COMISIÓN (PLANILLA)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${_totalComisionesOperarios.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF15803D),
                        ),
                      ),
                      Text(
                        '$_cantidadLavadosComision servicios asignados',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF166534),
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
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CAJA DIARIA COBRADA',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: kRoyalBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${_totalCobradoHoy.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: kRoyalBlue,
                        ),
                      ),
                      Text(
                        '${_vehiculos.length} órdenes registradas',
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
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
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
                          color: activo ? kRoyalBlue : const Color(0xFF6B7280),
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
            'Historial de Servicios y Registro de Cobro',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const Text(
            'Toca "Cobrar" para registrar el pago y calcular comisión en planilla',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 12),
          ...filtrados.map((v) => _buildFilaOrden(v)),
        ],
      ),
    );
  }

  Widget _buildFilaOrden(VehiculoPatio v) {
    final color = _coloresFase[v.fase];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _fondosFase[v.fase],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _iconosFase[v.fase],
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${v.placa} • ${v.nombreCompletoCarro} (${v.categoria})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_nombresFase[v.fase]} • ${v.cliente}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                v.totalPagar,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => _abrirModalCobro(v),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: v.pagado ? const Color(0xFF16A34A) : kRoyalBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    v.pagado ? 'PAGADO' : 'Cobrar',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPantallaPerfil() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mi perfil',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              _BotonIconoBorde(
                icono: Icons.settings_outlined,
                onTap: _configurarUrlApi,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: kRoyalBlue,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'OP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operario / Supervisor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'supervisor@sprintwash.com',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'CONEXIÓN A SERVIDOR / VPS (sprintwash_db)',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                ListTile(
                  onTap: _configurarUrlApi,
                  leading: const Icon(Icons.dns_outlined, color: kRoyalBlue),
                  title: const Text(
                    'Servidor API Backend',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    _apiUrl,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFDF2F2),
                foregroundColor: const Color(0xFF991B1B),
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
          border: Border.all(color: const Color(0xFFE5E7EB)),
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
            color: activo ? const Color(0xFF1422B8) : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Icon(icono, size: 24),
      ],
    );
  }
}