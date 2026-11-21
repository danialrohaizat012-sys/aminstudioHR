import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../store.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
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

  // Sign out after a period without touches, so a phone left on the counter
  // does not stay signed in to someone's payslips or the manager view.
  static const idle = Duration(minutes: 10);
  Timer? _idle;

  @override
  void initState() {
    super.initState();
    _bump();
  }

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  void _bump() {
    _idle?.cancel();
    _idle = Timer(idle, () {
      if (!mounted) return;
      final store = StoreScope.of(context);
      final messenger = ScaffoldMessenger.of(context);
      store.signOut();
      messenger.showSnackBar(const SnackBar(
          content: Text('Dilog keluar kerana tiada aktiviti selama 10 minit')));
    });
  }

  void go(int i) {
    setState(() => index = i);
    final store = StoreScope.of(context);
    // Opening Permohonan clears the "new decision" badge.
    if (!store.isAdmin && i == 2) store.markDecisionsSeen();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    // During sign-out the old shell is still animating out; render nothing
    // rather than building screens that need a signed-in user.
    if (store.me == null) return const SizedBox.shrink();
    final admin = store.isAdmin;
    final pendingCount = store.pending().where((r) => r.empId != store.me!.id).length;
    final unseen = admin ? 0 : store.unseenDecisions().length;

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

    // (icon, selected icon, short label for the phone bar, full label for the
    // desktop rail, badge count)
    final items = admin
        ? <(IconData, IconData, String, String, int)>[
            (Icons.home_outlined, Icons.home, 'Utama', 'Utama', 0),
            (
              Icons.inbox_outlined,
              Icons.inbox,
              'Kelulusan',
              'Kelulusan',
              pendingCount
            ),
            (Icons.people_outline, Icons.people, 'Pekerja', 'Pekerja', 0),
            (Icons.payments_outlined, Icons.payments, 'Gaji', 'Penggajian', 0),
            (Icons.person_outline, Icons.person, 'Profil', 'Profil', 0),
          ]
        : <(IconData, IconData, String, String, int)>[
            (Icons.home_outlined, Icons.home, 'Utama', 'Utama', 0),
            (Icons.schedule_outlined, Icons.schedule, 'Hadir', 'Kehadiran', 0),
            (Icons.assignment_outlined, Icons.assignment, 'Mohon', 'Permohonan', unseen),
            (Icons.receipt_outlined, Icons.receipt, 'Slip', 'Slip gaji', 0),
            (Icons.person_outline, Icons.person, 'Profil', 'Profil', 0),
          ];
    Widget badged(IconData icon, int n) =>
        Badge(isLabelVisible: n > 0, label: Text('$n'), child: Icon(icon));

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _bump(),
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 840;
        final body = IndexedStack(index: index, children: pages);
        if (!wide) {
          return Scaffold(
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: go,
              destinations: [
                for (final it in items)
                  NavigationDestination(
                      icon: badged(it.$1, it.$5),
                      selectedIcon: badged(it.$2, it.$5),
                      label: it.$3),
              ],
            ),
          );
        }
        // Tablets and desktop: a navigation rail on the left, labels shown
        // in full once there is room.
        final extended = box.maxWidth >= 1200;
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          body: Row(children: [
            NavigationRail(
              extended: extended,
              minExtendedWidth: 232,
              backgroundColor: cs.surface,
              selectedIndex: index,
              onDestinationSelected: go,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
                child: extended
                    ? const BrandLockup(markSize: 40)
                    : const BrandMark(size: 44),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: extended
                        ? Text(store.me!.name,
                            style: Theme.of(context).textTheme.bodySmall)
                        : Avatar(store.me, radius: 16),
                  ),
                ),
              ),
              destinations: [
                for (final it in items)
                  NavigationRailDestination(
                    icon: badged(it.$1, it.$5),
                    selectedIcon: badged(it.$2, it.$5),
                    label: Text(it.$4),
                  ),
              ],
            ),
            VerticalDivider(width: 1, color: cs.outlineVariant),
            Expanded(child: body),
          ]),
        );
      }),
    );
  }
}
