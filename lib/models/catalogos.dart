import '../utils/json_utils.dart';

class Especialidad {
  final int id;
  final String nombre;
  final bool activa;
  const Especialidad({required this.id, required this.nombre, this.activa = true});

  factory Especialidad.fromJson(Map<String, dynamic> j) => Especialidad(
        id: Json.entero(j, ['id']),
        nombre: Json.texto(j, ['nombre', 'descripcion']),
        activa: Json.valor(j, ['activa', 'activo', 'estado']) != false,
      );
}

class Servicio {
  final int id;
  final String nombre;
  final String descripcion;
  final double precio;
  final int duracion;
  final bool activo;
  final int especialidadId;

  const Servicio({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.duracion,
    required this.activo,
    required this.especialidadId,
  });

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'precio': precio,
        'descripcion': descripcion,
        'duracion': duracion,
        'activo': activo,
        'especialidad': especialidadId,
        'especialidadId': especialidadId,
      };

  Map<String, dynamic> toCache() => {...toJson(), 'id': id};

  Servicio copyWith({bool? activo}) => Servicio(
        id: id,
        nombre: nombre,
        descripcion: descripcion,
        precio: precio,
        duracion: duracion,
        activo: activo ?? this.activo,
        especialidadId: especialidadId,
      );

  factory Servicio.fromJson(Map<String, dynamic> j) => Servicio(
        id: Json.entero(j, ['id']),
        nombre: Json.texto(j, ['nombre']),
        descripcion: Json.texto(j, ['descripcion']),
        precio: Json.decimal(j, ['precio', 'valor']),
        duracion: Json.entero(j, ['duracion', 'duracionMinutos'], 30),
        activo: Json.valor(j, ['activo']) != false,
        especialidadId: Json.entero(j, ['especialidadId']),
      );
}

class Profesional {
  final int id;
  final String documento;
  final String nombres;
  final String apellidos;
  final String fechaNacimiento;
  final double porcentaje;
  final bool estado;
  final int especialidadId;
  final String especialidad;

  const Profesional({
    required this.id,
    required this.documento,
    required this.nombres,
    required this.apellidos,
    required this.fechaNacimiento,
    required this.porcentaje,
    required this.estado,
    required this.especialidadId,
    required this.especialidad,
  });

  String get nombreCompleto => '$nombres $apellidos'.trim();

  String get nombreCorto {
    final a = apellidos.trim();
    return a.isEmpty ? nombres : '$nombres ${a[0].toUpperCase()}.';
  }

  factory Profesional.fromJson(Map<String, dynamic> j) {
    final esp = Json.mapa(j, ['especialidad']);
    final estado = Json.valor(j, ['estado', 'activo']);
    final fn = Json.texto(j, ['fechaNacimiento']);
    return Profesional(
      id: Json.entero(j, ['id']),
      documento: Json.texto(j, ['documento']),
      nombres: Json.texto(j, ['nombres']),
      apellidos: Json.texto(j, ['apellidos']),
      fechaNacimiento: fn.length >= 10 ? fn.substring(0, 10) : fn,
      porcentaje: Json.decimal(j, ['porcentaje']),
      estado: estado == null || estado == true || estado.toString() == 'true',
      especialidadId: Json.entero(j, ['especialidadId']) != 0
          ? Json.entero(j, ['especialidadId'])
          : Json.entero(esp, ['id']),
      especialidad: Json.texto(esp, ['nombre']),
    );
  }

  Map<String, dynamic> toJson() => {
        'documento': documento,
        'nombres': nombres,
        'apellidos': apellidos,
        'fechaNacimiento': fechaNacimiento,
        'porcentaje': porcentaje,
        'estado': estado,
        'especialidad': especialidadId,
        'especialidadId': especialidadId,
      };

  Map<String, dynamic> toCache() => {
        ...toJson(),
        'id': id,
        'especialidad': {'id': especialidadId, 'nombre': especialidad},
      };

  Profesional copyWith({bool? estado}) => Profesional(
        id: id,
        documento: documento,
        nombres: nombres,
        apellidos: apellidos,
        fechaNacimiento: fechaNacimiento,
        porcentaje: porcentaje,
        estado: estado ?? this.estado,
        especialidadId: especialidadId,
        especialidad: especialidad,
      );
}

class Cliente {
  final int id;
  final String documento;
  final String nombres;
  final String apellidos;
  final String fechaNacimiento;
  final String celular;
  final String correo;

  const Cliente({
    required this.id,
    required this.documento,
    required this.nombres,
    required this.apellidos,
    required this.fechaNacimiento,
    required this.celular,
    required this.correo,
  });

  String get nombreCompleto => '$nombres $apellidos'.trim();

  factory Cliente.fromJson(Map<String, dynamic> j) {
    final fn = Json.texto(j, ['fechaNacimiento']);
    return Cliente(
      id: Json.entero(j, ['id']),
      documento: Json.texto(j, ['documento']),
      nombres: Json.texto(j, ['nombres']),
      apellidos: Json.texto(j, ['apellidos']),
      fechaNacimiento: fn.length >= 10 ? fn.substring(0, 10) : fn,
      celular: Json.texto(j, ['celular', 'telefono']),
      correo: Json.texto(j, ['correo', 'email']),
    );
  }

  Map<String, dynamic> toJson() => {
        'documento': documento,
        'nombres': nombres,
        'apellidos': apellidos,
        if (fechaNacimiento.isNotEmpty) 'fechaNacimiento': fechaNacimiento,
        'celular': celular,
        'correo': correo,
      };
}

class HorarioLaboral {
  final int id;
  final int profesionalId;
  final int diaSemana;
  final String horaInicio;
  final String horaFin;
  final bool tieneAlmuerzo;
  final String inicioAlmuerzo;
  final String finAlmuerzo;

  const HorarioLaboral({
    required this.id,
    required this.profesionalId,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    required this.tieneAlmuerzo,
    required this.inicioAlmuerzo,
    required this.finAlmuerzo,
  });

  static String _h(dynamic v) {
    final s = v?.toString() ?? '';
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  factory HorarioLaboral.fromJson(Map<String, dynamic> j) => HorarioLaboral(
        id: Json.entero(j, ['id']),
        profesionalId: Json.entero(j, ['profesionalId']),
        diaSemana: Json.entero(j, ['diaSemana', 'dia']),
        horaInicio: _h(Json.valor(j, ['horaInicio'])),
        horaFin: _h(Json.valor(j, ['horaFin'])),
        tieneAlmuerzo: Json.valor(j, ['tieneAlmuerzo']) == true,
        inicioAlmuerzo: _h(Json.valor(j, ['horaInicioAlmuerzo'])),
        finAlmuerzo: _h(Json.valor(j, ['horaFinAlmuerzo'])),
      );

  Map<String, dynamic> toJson() => {
        'profesionalId': profesionalId,
        'diaSemana': diaSemana,
        'horaInicio': '$horaInicio:00',
        'horaFin': '$horaFin:00',
        'tieneAlmuerzo': tieneAlmuerzo,
        if (tieneAlmuerzo) 'horaInicioAlmuerzo': '$inicioAlmuerzo:00',
        if (tieneAlmuerzo) 'horaFinAlmuerzo': '$finAlmuerzo:00',
      };

  static int diaApi(DateTime f) => f.weekday % 7;
}
