import '../models/cita.dart';
import '../models/dashboard_resumen.dart';
import '../models/usuario.dart';

class DemoData {
  DemoData._();

  static const emailDemo = 'gestor@cecar.edu.co';
  static const usuarioDemo = 'admin';
  static const claveDemo = 'Kallos2026';

  static const usuario = Usuario(
    id: 1,
    usuario: usuarioDemo,
    nombre: 'Laura Martínez',
    rol: 'Admin',
    sede: 'Salón Central',
  );

  static final List<Cita> citas = [
    const Cita(
      id: 1,
      horaInicio: '10:00',
      horaFin: '10:45',
      cliente: 'Mateo Rivas',
      servicio: 'Corte & Barba Ritual',
      profesional: 'Carlos Mendoza',
      estado: EstadoCita.enCurso,
    ),
    const Cita(
      id: 2,
      horaInicio: '11:00',
      horaFin: '12:00',
      cliente: 'Elena Valdés',
      servicio: 'Coloración Orgánica',
      profesional: 'Sofía Ortega',
      estado: EstadoCita.confirmada,
    ),
    const Cita(
      id: 3,
      horaInicio: '12:15',
      horaFin: '13:00',
      cliente: 'Lucía Gómez',
      servicio: 'Tratamiento Capilar Hidratante',
      profesional: 'Andrea Suárez',
      estado: EstadoCita.pendiente,
    ),
    const Cita(
      id: 4,
      horaInicio: '14:00',
      horaFin: '15:00',
      cliente: 'Camila Torres',
      servicio: 'Manicure Spa',
      profesional: 'Sofía Ortega',
      estado: EstadoCita.pendiente,
    ),
  ];

  static DashboardResumen resumen() {
    final libres = citas.any((c) => c.estado == EstadoCita.enCurso) ? 1 : 2;
    return DashboardResumen(
      reservasHoy: 18,
      ocupacionAgenda: 85,
      variacionVsAyer: 3,
      ingresosEstimados: 1450,
      metaDiaria: 1200,
      equipoEnTurno: 5,
      equipoTotal: 6,
      especialistasLibres: libres,
    );
  }
}
