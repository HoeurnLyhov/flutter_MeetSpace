import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api.dart';
import '../core/copy.dart';
import '../core/repository.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../shared/widgets.dart';
import 'booking_form.dart';

class RoomsPage extends StatefulWidget {
  final Session session;
  const RoomsPage({super.key, required this.session});
  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  final search = TextEditingController(), capacity = TextEditingController();
  final form = GlobalKey<FormState>();
  late DateTime start, end;
  List<Json>? items;
  List<Json> resources = [];
  String? resource;
  bool loading = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    final s = widget.session;
    start = s.wall(
      s.now.add(const Duration(hours: 1)),
      s.now.add(const Duration(hours: 1)).hour,
      0,
    );
    end = start.add(const Duration(hours: 1));
    loadResources();
  }

  @override
  void dispose() {
    search.dispose();
    capacity.dispose();
    super.dispose();
  }

  Future<void> loadResources() async {
    try {
      final r = await MeetSpaceRepository(widget.session).resources();
      if (mounted) setState(() => resources = rows(r));
    } catch (_) {
      /* Search remains usable without an equipment filter. */
    }
  }

  Future<void> load() async {
    if (loading || !form.currentState!.validate()) return;
    setState(() {
      loading = true;
      error = null;
      items = null;
    });
    try {
      final r = await MeetSpaceRepository(widget.session).rooms(
        filters: {
          'status': 'AVAILABLE',
          'start_at': start.toUtc().toIso8601String(),
          'end_at': end.toUtc().toIso8601String(),
          if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
          if (capacity.text.isNotEmpty) 'capacity': capacity.text,
          if (resource != null) 'resource_id': resource,
        },
      );
      if (mounted) setState(() => items = rows(r));
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pick(bool isStart) async {
    final s = widget.session;
    final value = isStart ? start : end;
    final date = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(s.now.year, s.now.month, s.now.day),
      lastDate: DateTime(s.now.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (time == null || !mounted) return;
    setState(() {
      final v = s.wall(date, time.hour, time.minute);
      if (isStart) {
        start = v;
        if (!end.isAfter(start)) end = start.add(const Duration(hours: 1));
      } else {
        end = v;
      }
      items = null;
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    if (!s.can('room.view')) {
      return PageBody(children: [Notice(context.t('forbidden'), error: true)]);
    }
    return PageBody(
      children: [
        Heading(context.t('rooms'), subtitle: context.t('roomsIntro')),
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: search,
                decoration: InputDecoration(
                  labelText: context.t('roomOrLocation'),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => pick(true),
                icon: const Icon(Icons.event),
                label: Text(
                  '${context.t('start')}: ${DateFormat('d MMM, HH:mm', s.locale).format(start)}',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => pick(false),
                icon: const Icon(Icons.schedule),
                label: Text(
                  '${context.t('end')}: ${DateFormat('d MMM, HH:mm', s.locale).format(end)}',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: capacity,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.t('minimumCapacity'),
                ),
                validator: (v) =>
                    v!.isNotEmpty &&
                        (int.tryParse(v) == null || int.parse(v) < 1)
                    ? context.t('validCount')
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: resource,
                isExpanded: true,
                decoration: InputDecoration(labelText: context.t('equipment')),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(context.t('anyEquipment')),
                  ),
                  ...resources.map(
                    (r) => DropdownMenuItem(
                      value: '${r['id']}',
                      child: Text('${r['name']}'),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() {
                  resource = v;
                  items = null;
                }),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: loading
                    ? null
                    : () {
                        if (!end.isAfter(start) || start.isBefore(s.now)) {
                          setState(
                            () =>
                                error = const ApiFailure(422, 'validInterval'),
                          );
                          return;
                        }
                        load();
                      },
                icon: const Icon(Icons.search),
                label: Text(context.t('findRoom')),
              ),
            ],
          ),
        ),
        Notice(
          '${context.t('availabilityHint')}\n${context.t('timezone')}: ${s.timezone}',
        ),
        if (error != null) Failure(error!, load),
        if (loading) const Loading(),
        if (items == null && !loading && error == null)
          Empty(context.t('searchRoomsHint')),
        if (items != null) ...[
          Heading('${items!.length} ${context.t('roomsFound')}'),
          if (items!.isEmpty) Empty(context.t('noRooms')),
          ...items!.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.meeting_room_outlined,
                            color: Civic.teal,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${r['name']}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${r['location']} · ${context.t('capacity')} ${r['capacity']}',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (r['resources'] as List)
                            .map(
                              (v) => Chip(
                                label: Text('$v'),
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RoomDetailPage(
                              session: s,
                              room: r,
                              start: start,
                              end: end,
                            ),
                          ),
                        ),
                        child: Text(context.t('viewRoom')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class RoomDetailPage extends StatefulWidget {
  final Session session;
  final Json room;
  final DateTime start, end;
  const RoomDetailPage({
    super.key,
    required this.session,
    required this.room,
    required this.start,
    required this.end,
  });
  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  List<Json>? items;
  Object? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await MeetSpaceRepository(
        widget.session,
      ).roomSchedule('${widget.room['id']}', widget.start, widget.end);
      if (mounted) {
        setState(() {
          items = rows(r);
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.room;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('roomDetails'))),
      body: PageBody(
        onRefresh: load,
        children: [
          Heading('${r['name']}', subtitle: '${r['code']} · ${r['location']}'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge('${r['status']}'),
                  const SizedBox(height: 16),
                  Text('${context.t('capacity')}: ${r['capacity']}'),
                  const SizedBox(height: 8),
                  Text(
                    '${context.t('operatingHours')}: ${r['opens_at']} – ${r['closes_at']}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${context.t('buffer')}: ${r['turnover_buffer_minutes']} ${context.t('minutes')}',
                  ),
                  if (r['description'] != null) ...[
                    const Divider(),
                    Text('${r['description']}'),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: (r['resources'] as List)
                        .map((v) => Chip(label: Text('$v')))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (widget.session.can('booking.create'))
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingFormPage(
                    session: widget.session,
                    room: r,
                    start: widget.start,
                    end: widget.end,
                  ),
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(context.t('bookRoom')),
            ),
          Heading(context.t('roomSchedule')),
          if (error != null)
            Failure(error!, load)
          else if (items == null)
            const Loading()
          else if (items!.isEmpty)
            Empty(context.t('noMeetings'))
          else
            ...items!.map(
              (i) => Card(
                child: ListTile(
                  title: Text('${i['title']}'),
                  subtitle: Text(
                    '${dateLabel(widget.session, i['start_at'])} · ${timeRange(widget.session, i)}',
                  ),
                  trailing: StatusBadge('${i['status']}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
