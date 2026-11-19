import 'package:flutter_test/flutter_test.dart';
import 'package:pejabat_hr/main.dart';
import 'package:pejabat_hr/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('sign in as employee, then as HR manager', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = HrStore();
    await store.load();
    await tester.pumpWidget(PejabatHrApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Log masuk sebagai'), findsOneWidget);
    await tester.tap(find.text('Hafiz Kamal'));
    await tester.pumpAndSettle();
    expect(find.text('Hai, Hafiz'), findsOneWidget);
    expect(find.text('Mohon cuti'), findsOneWidget);

    await store.signOut();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nurul Huda Ismail'));
    await tester.pumpAndSettle();
    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('Kelulusan'), findsWidgets);
  });
}
