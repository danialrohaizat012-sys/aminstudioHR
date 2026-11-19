// Malaysian statutory contributions and monthly pay computation.
//
// These are estimates that follow the published methods (EPF Third Schedule
// rounding, SOCSO/EIS RM100 brackets with a RM6,000 ceiling, a simplified
// annualised PCB for a resident individual). Check against the official
// KWSP/PERKESO tables and the LHDN PCB calculator before paying salaries.

import 'dart:math' as math;

class Statutory {
  const Statutory({
    required this.epfEe,
    required this.epfEr,
    required this.socsoEe,
    required this.socsoEr,
    required this.eisEe,
    required this.eisEr,
    required this.pcb,
  });

  final double epfEe, epfEr, socsoEe, socsoEr, eisEe, eisEr, pcb;
}

double _up05(double v) => (v * 20 - 1e-9).ceilToDouble() / 20;

Statutory statutory(double gross) {
  final g = math.max(0.0, gross);

  // EPF: wage rounded up to the next RM20 (<= RM5,000) or RM100 (> RM5,000),
  // contributions rounded up to the next ringgit.
  final double ew = g <= 10
      ? 0
      : g <= 5000
          ? (g / 20).ceil() * 20.0
          : (g / 100).ceil() * 100.0;
  final epfEe = (ew * 0.11).ceilToDouble();
  final epfEr = (ew * (g <= 5000 ? 0.13 : 0.12)).ceilToDouble();

  // SOCSO & EIS: RM100 brackets computed on the bracket midpoint, RM6,000 cap.
  final double sw = g <= 0
      ? 0
      : g >= 6000
          ? 6000
          : g <= 30
              ? g
              : (g / 100).ceil() * 100.0 - 50;
  final socsoEe = _up05(sw * 0.005);
  final socsoEr = _up05(sw * 0.0175);
  final eisEe = _up05(sw * 0.002);
  final eisEr = _up05(sw * 0.002);

  // PCB: simplified annual computation (self relief RM9,000, EPF relief up to
  // RM4,000, RM400 rebate when chargeable income <= RM35,000).
  final chargeable =
      math.max(0.0, g * 12 - math.min(epfEe * 12, 4000.0) - 9000);
  const brackets = <List<double>>[
    [5000, 0],
    [20000, .01],
    [35000, .03],
    [50000, .06],
    [70000, .11],
    [100000, .19],
    [400000, .25],
    [600000, .26],
    [2000000, .28],
    [double.infinity, .30],
  ];
  var tax = 0.0, prev = 0.0;
  for (final b in brackets) {
    if (chargeable > prev) tax += (math.min(chargeable, b[0]) - prev) * b[1];
    prev = b[0];
  }
  if (chargeable <= 35000) tax = math.max(0, tax - 400);
  final pcb = (tax / 12 * 20).floorToDouble() / 20;

  return Statutory(
    epfEe: epfEe,
    epfEr: epfEr,
    socsoEe: socsoEe,
    socsoEr: socsoEr,
    eisEe: eisEe,
    eisEr: eisEr,
    pcb: pcb,
  );
}

/// Ordinary rate of pay per hour under the Employment Act: monthly / 26 / 8.
double hourlyOrp(double monthlyBasic) => monthlyBasic / 26 / 8;

double round2(double v) => (v * 100).roundToDouble() / 100;
