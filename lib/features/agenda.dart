import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api.dart';
import '../core/copy.dart';
import '../core/repository.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../shared/widgets.dart';
import 'bookings.dart';
import 'settings.dart';

class HomePage extends StatefulWidget {
  final Session session;
  final void Function(int) navigate;
  const HomePage({super.key, required this.session, required this.navigate});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Json>? meetings;
  int? pending;
  Json? next;
  List<Json> updates = [];
  Object? error;
  int seen = -1;
  int generation = 0;
  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (seen != widget.session.revision) load();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final s = widget.session;
    final ticket = ++generation;
    seen = s.revision;
    try {
      final start = s.wall(s.now, 0, 0);
      final repo = MeetSpaceRepository(s);
      final results = await Future.wait([
        repo.meetings(start, s.wall(start.add(const Duration(days: 1)), 0, 0)),
        repo.bookings(status: 'approved'),
        repo.notifications(1),
        if (s.can('booking.approve')) repo.approvals(),
      ]);
      final result = results[0];
      final count = s.can('booking.approve')
          ? rows(results[3]).where((b) => b['status'] == 'pending').length
          : null;
      final upcoming = rows(results[1]);
      final notices = rows(results[2]);
      if (mounted && ticket == generation) {
        setState(() {
          meetings = rows(result);
          pending = count;
          next = upcoming.isEmpty ? null : upcoming.first;
          updates = notices.take(3).toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted && ticket == generation) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return PageBody(
      onRefresh: load,
      children: [
        Heading(
          context.t('home'),
          subtitle:
              '${s.user?['name']} · ${s.user?['department']?['name'] ?? ''}',
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Civic.navy,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, d MMMM', s.locale).format(s.now),
                style: const TextStyle(color: Color(0xFFBCD2E5)),
              ),
              const SizedBox(height: 12),
              Text(
                context.t('makeRoom'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.t('homeIntro'),
                style: const TextStyle(color: Color(0xFFDCE7F1), height: 1.5),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => widget.navigate(2),
                icon: const Icon(Icons.search),
                label: Text(context.t('findRoom')),
              ),
            ],
          ),
        ),
        if (pending != null) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.fact_check_outlined, color: Civic.teal),
              title: Text(context.t('pendingApprovals')),
              subtitle: Text('$pending ${context.t('requests')}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingsPage(session: s, approvals: true),
                ),
              ),
            ),
          ),
        ],
        if (next != null) ...[
          Heading(context.t('nextBooking')),
          MeetingCard(
            session: s,
            item: next!,
            onTap: () => openBooking(context, s, '${next!['id']}'),
          ),
        ],
        Row(
          children: [
            Expanded(child: Heading(context.t('todayMeetings'))),
            TextButton(
              onPressed: () => widget.navigate(1),
              child: Text(context.t('viewAll')),
            ),
          ],
        ),
        if (error != null)
          Failure(error!, load)
        else if (meetings == null)
          const Loading()
        else if (meetings!.isEmpty)
          Empty(context.t('noMeetings'))
        else
          ...meetings!
              .take(6)
              .map(
                (item) => MeetingCard(
                  session: s,
                  item: item,
                  onTap: item['can_view_details'] == true
                      ? () => openBooking(context, s, '${item['id']}')
                      : null,
                ),
              ),
        if (updates.isNotEmpty) ...[
          Heading(context.t('recentUpdates')),
          ...updates.map(
            (n) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_none),
              title: Text(
                n['event'] == null
                    ? '${n['title']}'
                    : context.t('notification_${n['event']}'),
              ),
              subtitle: Text(
                '${n['detail'] ?? ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationsPage(session: s),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          '${context.t('timezone')}: ${s.timezone}',
          style: const TextStyle(color: Civic.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class AgendaPage extends StatefulWidget {
  final Session session;
  const AgendaPage({super.key, required this.session});
  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  late DateTime selected;
  String mode = 'today';
  String? department, room;
  List<Json> items = [], rooms = [], departments = [];
  bool loading = true;
  int page = 1, lastPage = 1, generation = 0, seen = -1;
  Object? error;
  @override
  void initState() {
    super.initState();
    selected = widget.session.now;
    load();
  }

  @override
  void didUpdateWidget(AgendaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (seen != widget.session.revision) load();
  }

  (DateTime, DateTime) range() {
    final s = widget.session;
    var start = s.wall(selected, 0, 0);
    if (mode == 'week') {
      start = s.wall(start.subtract(Duration(days: start.weekday - 1)), 0, 0);
    }
    if (mode == 'month') {
      start = s.wall(DateTime(selected.year, selected.month), 0, 0);
    }
    final end = mode == 'month'
        ? s.wall(DateTime(start.year, start.month + 1), 0, 0)
        : s.wall(start.add(Duration(days: mode == 'week' ? 7 : 1)), 0, 0);
    return (start, end);
  }

  Future<void> load({bool more = false}) async {
    final ticket = ++generation;
    seen = widget.session.revision;
    if (!more) page = 1;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final (from, to) = range();
      final result = await MeetSpaceRepository(widget.session).meetings(
        from,
        to,
        department: department,
        room: room,
        page: more ? page + 1 : 1,
      );
      if (!mounted || ticket != generation) return;
      setState(() {
        items = more ? [...items, ...rows(result)] : rows(result);
        rooms = (result['filters']['rooms'] as List).cast<Json>();
        departments = (result['filters']['departments'] as List).cast<Json>();
        page = result['meta']['current_page'];
        lastPage = result['meta']['last_page'];
      });
    } catch (e) {
      if (mounted && ticket == generation) setState(() => error = e);
    } finally {
      if (mounted && ticket == generation) setState(() => loading = false);
    }
  }

  Future<void> pick() async {
    final day = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (day != null && mounted) {
      setState(() => selected = day);
      load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final grouped = <Widget>[];
    String? previous;
    for (final item in items) {
      final label = dateLabel(s, item['start_at']);
      if (label != previous) {
        grouped.add(
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 10),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
      previous = label;
      grouped.add(
        MeetingCard(
          session: s,
          item: item,
          onTap: item['can_view_details'] == true
              ? () => openBooking(context, s, '${item['id']}')
              : null,
        ),
      );
    }
    return PageBody(
      onRefresh: load,
      children: [
        Heading(context.t('schedule'), subtitle: context.t('scheduleIntro')),
        SegmentedButton<String>(
          segments: ['today', 'week', 'month']
              .map((v) => ButtonSegment(value: v, label: Text(context.t(v))))
              .toList(),
          selected: {mode},
          onSelectionChanged: (v) {
            setState(() {
              mode = v.first;
              if (mode == 'today') selected = s.now;
            });
            load();
          },
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: pick,
          icon: const Icon(Icons.date_range),
          label: Text(
            DateFormat(
              mode == 'month' ? 'MMMM yyyy' : 'd MMM yyyy',
              s.locale,
            ).format(selected),
          ),
        ),
        if (mode == 'month')
          CalendarDatePicker(
            initialDate: selected,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            onDateChanged: (v) {
              setState(() {
                selected = v;
                mode = 'today';
              });
              load();
            },
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: department,
          isExpanded: true,
          decoration: InputDecoration(labelText: context.t('department')),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(context.t('allDepartments')),
            ),
            ...departments.map(
              (d) => DropdownMenuItem(
                value: '${d['id']}',
                child: Text('${d['name']}', overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => department = v);
            load();
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: room,
          isExpanded: true,
          decoration: InputDecoration(labelText: context.t('room')),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(context.t('allRooms')),
            ),
            ...rooms.map(
              (r) => DropdownMenuItem(
                value: '${r['id']}',
                child: Text('${r['name']}', overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => room = v);
            load();
          },
        ),
        if (error != null)
          Failure(error!, load)
        else ...[
          if (loading && items.isEmpty)
            const Loading()
          else if (items.isEmpty)
            Empty(context.t('noMeetings'))
          else
            ...grouped,
          if (page < lastPage)
            OutlinedButton(
              onPressed: loading ? null : () => load(more: true),
              child: Text(context.t('loadMore')),
            ),
        ],
        const SizedBox(height: 16),
        Text(
          '${context.t('timezone')}: ${s.timezone}',
          style: const TextStyle(color: Civic.muted),
        ),
      ],
    );
  }
}
