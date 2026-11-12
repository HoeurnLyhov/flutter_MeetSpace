import 'dart:async';
import 'package:flutter/material.dart';
import '../core/copy.dart';
import '../core/session.dart';
import '../core/theme.dart';
import 'agenda.dart';
import 'bookings.dart';
import 'rooms.dart';
import 'settings.dart';

class Shell extends StatefulWidget {
  final Session session;
  const Shell({super.key, required this.session});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int index = 0;
  Timer? timer;
  final labels = const ['home', 'schedule', 'rooms', 'myBookings', 'more'];
  final icons = const [
    Icons.home_outlined,
    Icons.calendar_month_outlined,
    Icons.meeting_room_outlined,
    Icons.bookmark_border,
    Icons.grid_view_outlined,
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    startTimer();
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) widget.session.changed();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.session.changed();
      startTimer();
    } else {
      timer?.cancel();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void select(int value) => setState(() => index = value);
  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final page = switch (index) {
      0 => HomePage(session: s, navigate: select),
      1 => AgendaPage(session: s),
      2 => RoomsPage(session: s),
      3 => BookingsPage(session: s),
      _ => MorePage(session: s),
    };
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.meeting_room, color: Civic.blue),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'MeetSpace',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.t('switchLanguage'),
            onPressed: () => s.setLocale(s.locale == 'en' ? 'km' : 'en'),
            icon: const Icon(Icons.translate),
          ),
          IconButton(
            tooltip: context.t('notifications'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NotificationsPage(session: s)),
            ),
            icon: const Icon(Icons.notifications_none),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              destinations: List.generate(
                labels.length,
                (i) => NavigationRailDestination(
                  icon: Icon(icons[i]),
                  label: Text(context.t(labels[i])),
                ),
              ),
            ),
          Expanded(child: page),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              height: s.locale == 'km' ? 104 : 88,
              selectedIndex: index,
              onDestinationSelected: select,
              destinations: List.generate(
                labels.length,
                (i) => NavigationDestination(
                  icon: Icon(icons[i]),
                  label: context.t(labels[i]),
                ),
              ),
            ),
    );
  }
}
