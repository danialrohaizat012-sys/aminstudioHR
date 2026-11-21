import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pejabat_hr/main.dart';
import 'package:pejabat_hr/screens/jobs_screen.dart';
import 'package:pejabat_hr/screens/roster_screen.dart';
import 'package:pejabat_hr/screens/team_calendar_screen.dart';
import 'package:pejabat_hr/services/punch_devices.dart';
import 'package:pejabat_hr/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1x1 transparent PNG, enough for Image.memory.
const _pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

class FakeDevices implements PunchDevices {
  FakeDevices({this.gpsOn = true});
  final bool gpsOn;
  @override
  Future<LocationFix> locate() async => gpsOn
      ? const LocationFix(lat: 6.1181, lng: 102.2420, accuracy: 10)
      : const LocationFix(error: 'Lokasi (GPS) telefon dimatikan. Hidupkan dan cuba lagi.');
  @override
  Future<String?> selfie() async => _pixel;
  @override
  Future<String?> receipt() async => _pixel;
  @override
  Future<String?> address(double lat, double lng) async => 'Jalan Kuala Krai, Kota Bharu, Kelantan';
  @override
  Future<String?> deviceName() async => 'Pixel 7';
  @override
  Future<String?> profilePhoto({required bool camera}) async => _pixel;
}

Future<void> enterPin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.byKey(ValueKey('pin-$d')));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    punchDevices = FakeDevices();
  });

  testWidgets('sign in as employee, then as HR manager', (tester) async {
    final store = HrStore();
    await store.load();
    await tester.pumpWidget(PejabatHrApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Log masuk sebagai'), findsOneWidget);
    await tester.tap(find.text('Hafiz Kamal'));
    await tester.pumpAndSettle();
    await enterPin(tester, '000000');
    expect(find.textContaining('PIN salah'), findsOneWidget);
    await enterPin(tester, HrStore.demoPin);
    // First sign-in on this device shows the short guide once.
    expect(find.text('Punch masuk di kedai'), findsOneWidget);
    await tester.tap(find.text('Seterusnya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Langkau'));
    await tester.pumpAndSettle();
    expect(find.text('Hai, Hafiz'), findsOneWidget);
    expect(store.toursSeen, contains('e2'));

    await store.signOut();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nurul Huda Ismail'));
    await tester.pumpAndSettle();
    await enterPin(tester, HrStore.demoPin);
    expect(find.text('Hari ini'), findsOneWidget);
  });

  testWidgets('employee punches in inside the shop area', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    final store = HrStore();
    await store.load();
    await store.signInForTest('admin');
    await store.setOffice(6.1180, 102.2420);
    store.toursSeen.add('e2');
    await store.signInForTest('e2'); // seed leaves Hafiz without a punch today
    await tester.pumpWidget(PejabatHrApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Punch masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Notis privasi punch'), findsOneWidget);
    await tester.tap(find.text('Setuju'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Dalam kawasan kedai'), findsOneWidget);

    // Selfie is required by default: the button stays disabled until taken.
    final punchBtn = find.ancestor(of: find.text('Punch masuk sekarang'), matching: find.byType(FilledButton));
    expect(tester.widget<FilledButton>(punchBtn).onPressed, isNull);
    await tester.tap(find.text('Ambil'));
    await tester.pump();
    expect(tester.widget<FilledButton>(punchBtn).onPressed, isNotNull);

    await tester.tap(find.text('Punch masuk sekarang'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Punch masuk berjaya'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    final rec = store.attendanceOn('e2', store.attendance.values
        .where((a) => a.empId == 'e2')
        .map((a) => a.date)
        .reduce((a, b) => a.compareTo(b) > 0 ? a : b))!;
    expect(rec.inMark?.distance, lessThan(20));
    expect(rec.inMark?.photo, isNotNull);
    expect(find.text('Punch keluar'), findsWidgets);
  });

  testWidgets('punch button stays locked while the phone location is off', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    punchDevices = FakeDevices(gpsOn: false);

    final store = HrStore();
    await store.load();
    store.toursSeen.add('e2');
    await store.signInForTest('e2');
    await tester.pumpWidget(PejabatHrApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Punch masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setuju'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Lokasi tidak tersedia'), findsOneWidget);
    await tester.tap(find.text('Ambil'));
    await tester.pump();
    final punchBtn = find.ancestor(of: find.text('Punch masuk sekarang'), matching: find.byType(FilledButton));
    expect(tester.widget<FilledButton>(punchBtn).onPressed, isNull);
    expect(find.textContaining('lokasi telefon dimatikan', skipOffstage: false), findsOneWidget);
  });

  for (final who in ['admin', 'e2']) {
    testWidgets('home fits a small phone at 150% text size ($who)', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = HrStore();
      await store.load();
      store.toursSeen.add('e2');
      await store.signInForTest(who);
      await tester.pumpWidget(PejabatHrApp(store: store));
      await tester.pumpAndSettle();
      // Scroll through the whole home page; any overflow throws.
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      if (who != 'admin') return;
      for (final screen in const [RosterScreen(), JobsScreen(), TeamCalendarScreen()]) {
        final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
        nav.push(MaterialPageRoute(builder: (_) => screen));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '${screen.runtimeType}');
        nav.pop();
        await tester.pumpAndSettle();
      }
    });
  }
}
