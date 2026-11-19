import 'package:flutter_test/flutter_test.dart';
import 'package:pejabat_hr/payroll.dart';

void main() {
  test('RM3,500 matches EPF, SOCSO and EIS table values', () {
    final s = statutory(3500);
    expect(s.epfEe, 385);
    expect(s.epfEr, 455);
    expect(s.socsoEe, 17.25);
    expect(s.eisEe, 6.90);
  });

  test('wages above RM5,000 use 12% employer EPF and the RM6,000 SOCSO cap', () {
    final s = statutory(8000);
    expect(s.epfEe, 880);
    expect(s.epfEr, 960);
    expect(s.socsoEe, 30);
    expect(s.eisEe, 12);
    expect(s.pcb, greaterThan(400));
  });

  test('low wages pay no PCB after the rebate', () {
    expect(statutory(2800).pcb, 0);
  });
}
