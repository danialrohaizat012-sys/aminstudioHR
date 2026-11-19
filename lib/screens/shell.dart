import 'package:material_ui/material_ui.dart';

import '../store.dart';
import 'admin_home.dart';
import 'approvals_screen.dart';
import 'attendance_screen.dart';
import 'employee_home.dart';
import 'payroll_screen.dart';
import 'payslips_screen.dart';
import 'people_screen.dart';
import 'profile_screen.dart';
import 'requests_screen.dart';

/// Bottom-navigation shell. Employees and HR managers get different tabs.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  void go(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    // During sign-out the old shell is still animating out; render nothing
    // rather than building screens that need a signed-in user.
    if (store.me == null) return const SizedBox.shrink();
    final admin = store.isAdmin;
    final pendingCount = store.pending().length;

    final pages = admin
        ? <Widget>[
            AdminHome(onGo: go),
            const ApprovalsScreen(),
            const PeopleScreen(),
            const PayrollScreen(),
            const ProfileScreen(),
          ]
        : <Widget>[
            EmployeeHome(onGo: go),
            const AttendanceScreen(),
            const RequestsScreen(),
            const PayslipsScreen(),
            const ProfileScreen(),
          ];

    final destinations = admin
        ? [
            const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Utama'),
            NavigationDestination(
              icon: Badge(isLabelVisible: pendingCount > 0, label: Text('$pendingCount'), child: const Icon(Icons.inbox_outlined)),
              selectedIcon: Badge(isLabelVisible: pendingCount > 0, label: Text('$pendingCount'), child: const Icon(Icons.inbox)),
              label: 'Kelulusan',
            ),
            const NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Pekerja'),
            const NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: 'Gaji'),
            const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
          ]
        : const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Utama'),
            NavigationDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule), label: 'Hadir'),
            NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Mohon'),
            NavigationDestination(icon: Icon(Icons.receipt_outlined), selectedIcon: Icon(Icons.receipt), label: 'Slip'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
          ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: go,
        destinations: destinations,
      ),
    );
  }
}
