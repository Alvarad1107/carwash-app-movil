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
  final String totalPagar;
  int fase;

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
    required this.totalPagar,
    this.fase = 0,
  });

  String get nombreCompletoCarro => '$marca $modelo';

  factory VehiculoPatio.fromJson(Map<String, dynamic> json, int index) {
    final estadoStr = (json['estado'] ?? 'Pendiente').toString().toLowerCase();
    int fase = 0;
    if (estadoStr.contains('proceso')) fase = 1;
    if (estadoStr.contains('terminado') ||
        estadoStr.contains('listo') ||
        estadoStr.contains('entregado')) {
      fase = 2;
    }

    final catId = json['categoria_vehiculo_id'];
    String categoriaNombre = (json['categoria'] ?? '').toString();
    if (categoriaNombre.isEmpty) {
      if (catId == 1) {
        categoriaNombre = 'Sedan';
      } else if (catId == 2) {
        categoriaNombre = 'Pick Up';
      } else if (catId == 3) {
        categoriaNombre = 'Carros Medianos';
      } else if (catId == 4) {
        categoriaNombre = 'Carros Grandes';
      } else if (catId == 5) {
        categoriaNombre = 'Microbus';
      } else {
        categoriaNombre = 'Sedan';
      }
    }

    final precioRaw = json['total_pagar'] ?? json['subtotal'] ?? '19.00';

    return VehiculoPatio(
      ordenId: json['orden_id'] ?? json['id'] ?? (index + 1),
      vehiculoId: json['vehiculo_id'] ?? json['id'] ?? (index + 1),
      placa: (json['placa'] ?? 'SIN-PLACA').toString(),
      marca: (json['marca'] ?? 'Toyota').toString(),
      modelo: (json['modelo'] ?? 'Corolla').toString(),
      color: (json['color'] ?? 'Rojo').toString(),
      categoria: categoriaNombre,
      cliente: (json['nombre_completo'] ??
              json['cliente'] ??
              'Cliente Sprint Wash')
          .toString(),
      correoCliente: (json['correo'] ?? 'cliente@sprintwash.com').toString(),
      telefonoCliente: (json['telefono'] ?? '7000-0000').toString(),
      bahia: json['bahia_id'] != null
          ? 'Bahia ${json['bahia_id']}'
          : (json['bahia'] ?? 'Bahia 1').toString(),
      servicio: (json['servicio'] ?? 'Lavado Basico + Lavado de Motor')
          .toString(),
      totalPagar: '\$$precioRaw',
      fase: fase,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color kRoyalBlue = Color(0xFF1422B8);

  String _apiUrl = 'http://10.0.2.2:8000';
  bool _cargandoApi = false;
  bool _conectadoConApi = false;

  int _selectedIndex = 0;
  String _busqueda = '';
  String _filtroControl = 'Todos';

  static const List<String> _nombresFase = [
    'Pendiente',
    'En proceso',
    'Terminado'
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
    return null;
  }

  List<VehiculoPatio> _vehiculos = [
    VehiculoPatio(
      ordenId: 1,
      vehiculoId: 1,
      placa: 'P765765',
      marca: 'Toyota',
      modelo: 'Corolla',
      color: 'Rojo',
      categoria: 'Sedan',
      cliente: 'Jualian Alexander Alvarador Moreno',
      correoCliente: 'alvaradomaster1107@gmail.com',
      telefonoCliente: '7898-9877',
      bahia: 'Bahia 1',
      servicio: 'Lavado Basico + Lavado de Motor',
      totalPagar: '\$19.00',
      fase: 0,
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
      correoCliente: 'erickherrerashh.@gmail.com',
      telefonoCliente: '63100933',
      bahia: 'Bahia 2',
      servicio: 'Lavado Basico (Pick Up)',
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
      servicio: 'Lavado Basico + Lavado de Motor',
      totalPagar: '\$19.00',
      fase: 2,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _obtenerDatosDeApi();
  }

  Future<void> _obtenerDatosDeApi({bool mostrarMensaje = false}) async {
    setState(() => _cargandoApi = true);

    try {
      final uri = Uri.parse('$_apiUrl/vehiculos');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> listaJson = decoded is List
            ? decoded
            : (decoded['data'] ?? decoded['vehiculos'] ?? []);

        if (listaJson.isNotEmpty) {
          setState(() {
            _vehiculos = List.generate(
              listaJson.length,
              (i) => VehiculoPatio.fromJson(
                Map<String, dynamic>.from(listaJson[i]),
                i,
              ),
            );
            _conectadoConApi = true;
          });
        } else {
          setState(() => _conectadoConApi = true);
        }

        if (mostrarMensaje && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF15803D),
              content: Text('Sincronizado con sprintwash_db vía API'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() => _conectadoConApi = false);
      }
    } catch (_) {
      setState(() => _conectadoConApi = false);
      if (mostrarMensaje && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFB45309),
            content: Text(
              'Mostrando los 3 vehículos de sprintwash_db en modo local',
            ),
            duration: Duration(seconds: 2),
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
          .put(
            Uri.parse('$_apiUrl/ordenes/${v.ordenId}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': v.ordenId,
              'vehiculo_id': v.vehiculoId,
              'placa': v.placa,
              'estado': _nombresFase[nuevaFase],
            }),
          )
          .timeout(const Duration(seconds: 2));
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
              ? '${v.nombreCompletoCarro} (${v.placa}) -> TERMINADO\nNotificación lista para: ${v.correoCliente}'
              : '${v.nombreCompletoCarro} (${v.placa}) -> ${_nombresFase[v.fase].toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
        ),
        duration: const Duration(seconds: 3),
      ),
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
                'Dirección IP del servidor FastAPI conectado a sprintwash_db:',
                style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  hintText: 'http://192.168.1.15:8000',
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
                final limpio = urlCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
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
    String categoriaSeleccionada = 'Sedan';

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
                    'Recepción de Vehiculo (sprintwash_db)',
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
                  DropdownButtonFormField<String>(
                    value: categoriaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Categoria (tabla categoria_vehiculos)',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Sedan',
                        child: Text('Sedan (\$4.00 Base)'),
                      ),
                      DropdownMenuItem(
                        value: 'Pick Up',
                        child: Text('Pick Up (\$8.00 Base)'),
                      ),
                      DropdownMenuItem(
                        value: 'Carros Medianos',
                        child: Text('Carros Medianos'),
                      ),
                      DropdownMenuItem(
                        value: 'Carros Grandes',
                        child: Text('Carros Grandes'),
                      ),
                      DropdownMenuItem(
                        value: 'Microbus',
                        child: Text('Microbus'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => categoriaSeleccionada = val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: clienteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cliente (tabla clientes)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (marcaCtrl.text.trim().isEmpty &&
                          modeloCtrl.text.trim().isEmpty) {
                        return;
                      }
                      final bahiaLibre = _primeraBahiaLibre();
                      if (bahiaLibre == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No hay bahías libres'),
                          ),
                        );
                        return;
                      }
                      final esPickUp = categoriaSeleccionada == 'Pick Up';
                      setState(() {
                        _vehiculos.insert(
                          0,
                          VehiculoPatio(
                            ordenId: _vehiculos.length + 1,
                            vehiculoId: _vehiculos.length + 1,
                            placa: placaCtrl.text.trim().isEmpty
                                ? 'P999000'
                                : placaCtrl.text.trim().toUpperCase(),
                            marca: marcaCtrl.text.trim().isEmpty
                                ? 'Toyota'
                                : marcaCtrl.text.trim(),
                            modelo: modeloCtrl.text.trim().isEmpty
                                ? 'Corolla'
                                : modeloCtrl.text.trim(),
                            color: colorCtrl.text.trim().isEmpty
                                ? 'Gris'
                                : colorCtrl.text.trim(),
                            categoria: categoriaSeleccionada,
                            cliente: clienteCtrl.text.trim().isEmpty
                                ? 'Cliente Nuevo'
                                : clienteCtrl.text.trim(),
                            correoCliente: 'bescamillarios12@gmail.com',
                            telefonoCliente: '7857-4566',
                            bahia: 'Bahia $bahiaLibre',
                            servicio: 'Lavado Básico',
                            totalPagar: esPickUp ? '\$8.00' : '\$4.00',
                            fase: 0,
                          ),
                        );
                      });
                      Navigator.pop(context);
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
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: _IconoBarraInferior(
                icono: Icons.bar_chart_rounded,
                activo: _selectedIndex == 1,
              ),
              label: 'Actividad',
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
            const Text(
              'Buenos días,',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (valor) => setState(() => _busqueda = valor),
              decoration: InputDecoration(
                hintText: 'Buscar vehiculo por placa (ej. P765765)...',
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
                  'Vehiculos en Patio',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedIndex = 1),
                  child: const Text(
                    'Ver todo',
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
                                '${v.nombreCompletoCarro} ·${v.categoria}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Color: ${v.color} • ${v.bahia} •${v.totalPagar}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
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
                    Text(
                      'Servicio: ${v.servicio}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
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
                'Control de Patio',
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
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  'Flujo diario de vehículos (sprintwash_db)',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${_vehiculos.length} órdenes hoy',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: kRoyalBlue,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final cantidad =
                        _vehiculos.where((v) => v.fase == i).length;
                    return Container(
                      margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _fondosFase[i],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$cantidad ${_nombresFase[i]}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _coloresFase[i],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Listado de Ordenes',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const Text(
            'Actualizado en tiempo real',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 16),
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
                  '${v.placa} · ${v.nombreCompletoCarro} (${v.color})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_nombresFase[v.fase]} · ${v.bahia} · ${v.servicio}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => _cambiarEstado(v, (v.fase + 1) % 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _nombresFase[v.fase],
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
                    'SU',
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
                        'Supervisor',
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
                      SizedBox(height: 6),
                      Text(
                        'Editar perfil',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: kRoyalBlue,
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
            'SISTEMA (sprintwash_db)',
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
                const Divider(height: 1),
                const ListTile(
                  leading:
                      Icon(Icons.verified_user_outlined, color: kRoyalBlue),
                  title: Text(
                    'Seguridad',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Contraseña y acceso',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded),
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