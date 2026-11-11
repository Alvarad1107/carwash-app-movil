/// Constantes globales de la aplicación Sprint Wash.
class AppConstants {
  AppConstants._();

  // Nombre de la app
  static const String appName = 'Sprint Wash';
  static const String appVersion = '1.0.0';

  // API — VPS de producción
  static const String defaultApiUrl = 'http://68.211.73.10:8000';

  // SharedPreferences keys
  static const String tokenKey = 'jwt_token';
  static const String userIdKey = 'user_id';
  static const String userNombreKey = 'user_nombre';
  static const String userRolKey = 'user_rol';
  static const String userCorreoKey = 'user_correo';

  // 19 Prefijos oficiales de placas salvadoreñas
  static const List<String> prefijosPlacaSV = [
    'P',
    'M',
    'A',
    'C',
    'F',
    'T',
    'N',
    'O',
    'E',
    'D',
    'V',
    'AB',
    'MB',
    'RE',
    'PR',
    'CC',
    'CD',
    'MI',
    'PNC',
  ];

  // Fases / estados de una orden en el patio
  static const List<String> nombresFase = [
    'Pendiente',
    'En proceso',
    'Terminado'
  ];
  static const List<String> estadosApi = [
    'Pendiente',
    'En proceso',
    'Listo para entrega'
  ];

  // Total de bahías en el patio
  static const int totalBahias = 6;
}
