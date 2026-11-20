enum Entorno { produccion, local }

class ApiConfig {
  ApiConfig._();

  static const Entorno entorno = Entorno.produccion;

  static const bool modoDemo = false;

  static const bool mostrarLogs = true;

  static const Duration timeout = Duration(seconds: 20);

  static String get baseUrl {
    switch (entorno) {
      case Entorno.produccion:
        return 'https://api.ehily.cecar.cloud/api';
      case Entorno.local:
        return 'http://localhost:5000/api';
    }
  }

  static const String sesion = '/sesion';
  static const String reservas = '/reservas';
  static String reserva(int id) => '/reservas/$id';
  static const String profesionales = '/profesionales';
  static const String servicios = '/servicios';
  static const String clientes = '/clientes';
  static const String especialidades = '/especialidades';
  static const String horariosLaboral = '/horarios-laboral';
  static const String agenda = '/agenda';
  static const String liquidaciones = '/liquidaciones-comisiones';
  static const String comisiones = '/comisiones';

  static const Map<String, String> correosInstitucionales = {
    'luis.beniteza@cecar.edu.co': '1104259632',
  };

  static const String dominioCorreo = '@cecar.edu.co';

  static const String aperturaSalon = '08:00';
  static const String cierreSalon = '18:00';

  static const double metaDiaria = 500000;

  static const int turnosPorProfesional = 8;

  static const Map<int, String?> estadosReserva = {
    0: null,
    1: 'Cancelada',
    2: 'Finalizada',
    3: null,
  };

  static const int duracionPorDefecto = 45;
}
