import 'package:flutter_test/flutter_test.dart';
import 'package:kallos/utils/validadores.dart';

void main() {
  test('Validación del usuario/correo', () {
    expect(Validadores.usuario(''), isNotNull);
    expect(Validadores.usuario('correo@mal'), isNotNull);
    expect(Validadores.usuario('gestor@cecar.edu.co'), isNull);
    expect(Validadores.usuario('gestor@gmail.com'), isNotNull);
    expect(Validadores.usuario('1104259632'), isNull);
    expect(Validadores.usuario('ad'), isNotNull);
    expect(Validadores.usuario('admin'), isNull);
  });

  test('Validación de la contraseña', () {
    expect(Validadores.clave(''), isNotNull);
    expect(Validadores.clave('12345'), isNotNull);
    expect(Validadores.clave('Kallos2026'), isNull);
  });
}
