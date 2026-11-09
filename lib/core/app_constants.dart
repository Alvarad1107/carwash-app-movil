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
  static const String userNombreKey = 'user_nombre';
  static const String userRolKey = 'user_rol';
  static const String userCorreoKey = 'user_correo';

  // Fases / estados de una orden en el patio
  static const List<String> nombresFase = ['Pendiente', 'En proceso', 'Terminado'];
  static const List<String> estadosApi = ['Pendiente', 'En proceso', 'Listo para entrega'];

  // Total de bahías en el patio
  static const int totalBahias = 6;

  // IDs para roles/asignaciones
  static const int cajeroIdDefault = 2;
  static const List<int> operarioSimple = [3];
  static const List<int> operarioDoble = [3, 4];
}
