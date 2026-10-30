import 'package:flutter_test/flutter_test.dart';
import 'package:optiruta/core/utils/fecha_utils.dart';

void main() {
  test('formatearDuracion muestra horas y minutos sin redondear a la hora', () {
    expect(formatearDuracion(45), '45 min');
    expect(formatearDuracion(340), '5 h 40 min');
    expect(formatearDuracion(360), '6 h');
  });
}
