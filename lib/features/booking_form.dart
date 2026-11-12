import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api.dart';
import '../core/copy.dart';
import '../core/repository.dart';
import '../core/session.dart';
import '../shared/widgets.dart';
import 'bookings.dart';

class BookingFormPage extends StatefulWidget {
  final Session session;
  final Json room;
  final Json? booking;
  final DateTime start, end;
  const BookingFormPage({
    super.key,
    required this.session,
    required this.room,
    required this.start,
    required this.end,
    this.booking,
  });
  @override
  State<BookingFormPage> createState() => _BookingFormPageState();
}

class _BookingFormPageState extends State<BookingFormPage> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, purpose, count;
  late DateTime start, end;
  late Json room;
  final List<Upload> files = [];
  final Map<int, String> participants = {};
  bool busy = false, review = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    final b = widget.booking;
    title = TextEditingController(text: b?['title']);
    purpose = TextEditingController(text: b?['purpose']);
    count = TextEditingController(text: '${b?['participant_count'] ?? 1}');
    start = widget.start;
    end = widget.end;
    room = widget.room;
    for (final p in (b?['participants'] as List? ?? [])) {
      participants[p['user_id'] as int] = '${p['name']}';
    }
  }

  @override
  void dispose() {
    title.dispose();
    purpose.dispose();
    count.dispose();
    super.dispose();
  }

  Future<void> pick(bool first) async {
    final s = widget.session, value = first ? start : end;
    final date = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (time == null || !mounted) return;
    setState(() {
      final v = s.wall(date, time.hour, time.minute);
      if (first) {
        start = v;
        if (!end.isAfter(start)) end = start.add(const Duration(hours: 1));
      } else {
        end = v;
      }
    });
  }

  Future<void> changeRoom() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await MeetSpaceRepository(widget.session).rooms(
        filters: {
          'status': 'AVAILABLE',
          'start_at': start.toUtc().toIso8601String(),
          'end_at': end.toUtc().toIso8601String(),
          'capacity': int.tryParse(count.text) ?? 1,
        },
      );
      if (!mounted) return;
      final selected = await showModalBottomSheet<Json>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * .65,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Heading(ctx.t('chooseRoom')),
                if (rows(result).isEmpty) Empty(ctx.t('noRooms')),
                ...rows(result).map(
                  (r) => ListTile(
                    title: Text('${r['name']}'),
                    subtitle: Text('${r['location']} · ${r['capacity']}'),
                    onTap: () => Navigator.pop(ctx, r),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (selected != null && mounted) setState(() => room = selected);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> attach() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'png',
          'jpg',
          'jpeg',
        ],
      );
      if (result.isEmpty || !mounted) return;
      if (files.length + result.length > 5) {
        setState(() => error = const ApiFailure(422, 'attachmentRules'));
        return;
      }
      final picked = <Upload>[];
      for (final file in result) {
        final size = await file.length();
        if (size == null || size > 10 * 1024 * 1024) {
          throw const ApiFailure(422, 'attachmentRules');
        }
        picked.add(Upload(file.name, await file.readAsBytes()));
      }
      if (mounted) {
        setState(() {
          files.addAll(picked);
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> selectParticipants() async {
    final chosen = await Navigator.push<Map<int, String>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ParticipantPicker(session: widget.session, selected: participants),
      ),
    );
    if (chosen != null && mounted) {
      setState(() {
        participants.clear();
        participants.addAll(chosen);
        if ((int.tryParse(count.text) ?? 0) < participants.length + 1) {
          count.text = '${participants.length + 1}';
        }
      });
    }
  }

  Future<void> save(bool submit) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await MeetSpaceRepository(widget.session).save(
        {
          'room_id': room['id'],
          'title': title.text.trim(),
          'purpose': purpose.text.trim(),
          'participant_count': int.parse(count.text),
          'participant_ids': participants.keys.toList(),
          'start_at': start.toUtc().toIso8601String(),
          'end_at': end.toUtc().toIso8601String(),
          'submit': submit,
        },
        id: widget.booking?['id'],
        files: files,
      );
      widget.session.changed();
      if (mounted) {
        feedback(
          context,
          context.t(submit ? 'bookingSubmitted' : 'draftSaved'),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BookingDetailPage(
              session: widget.session,
              id: '${result['data']['id']}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            context.t(
              review
                  ? 'reviewBooking'
                  : widget.booking == null
                  ? 'createBooking'
                  : 'editBooking',
            ),
          ),
        ),
        body: PageBody(
          children: [
            Heading(
              context.t(review ? 'checkDetails' : 'meetingDetails'),
              subtitle: context.t('bookingIntro'),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.meeting_room_outlined),
                title: Text('${room['name']}'),
                subtitle: Text(
                  '${room['location']} · ${context.t('capacity')} ${room['capacity']}',
                ),
                trailing: !review
                    ? IconButton(
                        tooltip: context.t('changeRoom'),
                        onPressed: busy ? null : changeRoom,
                        icon: const Icon(Icons.swap_horiz),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            if (!review)
              Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: title,
                      maxLength: 180,
                      decoration: InputDecoration(
                        labelText: context.t('meetingTitle'),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? context.t('required')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: purpose,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 10000,
                      decoration: InputDecoration(
                        labelText: context.t('purpose'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => pick(true),
                      child: Text(
                        '${context.t('start')}: ${DateFormat('d MMM yyyy, HH:mm', s.locale).format(start)}',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => pick(false),
                      child: Text(
                        '${context.t('end')}: ${DateFormat('d MMM yyyy, HH:mm', s.locale).format(end)}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: count,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.t('attendeeCount'),
                        helperText: context.t('attendeeHint'),
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return n == null ||
                                n < 1 ||
                                n > (room['capacity'] as int) ||
                                n < participants.length + 1
                            ? context.t('capacityError')
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: selectParticipants,
                      icon: const Icon(Icons.people_outline),
                      label: Text(
                        '${context.t('staffAttendees')} (${participants.length})',
                      ),
                    ),
                    ...participants.values.map(
                      (name) => Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(name),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: attach,
                      icon: const Icon(Icons.attach_file),
                      label: Text(context.t('addAttachments')),
                    ),
                    Text(
                      context.t('attachmentRules'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    ...files.map(
                      (f) => ListTile(
                        title: Text(f.name),
                        trailing: IconButton(
                          tooltip: context.t('remove'),
                          onPressed: () => setState(() => files.remove(f)),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.text,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(purpose.text),
                      const Divider(),
                      Text('${context.t('organizer')}: ${s.user?['name']}'),
                      Text(
                        '${context.t('start')}: ${DateFormat('d MMM yyyy, HH:mm', s.locale).format(start)}',
                      ),
                      Text(
                        '${context.t('end')}: ${DateFormat('d MMM yyyy, HH:mm', s.locale).format(end)}',
                      ),
                      Text('${context.t('attendeeCount')}: ${count.text}'),
                      ...participants.values.map(Text.new),
                      ...files.map((f) => Text(f.name)),
                    ],
                  ),
                ),
              ),
            Notice(context.t('pendingHint')),
            if (error != null)
              Notice(Copy.of(context).error(error!), error: true),
            if (!review)
              FilledButton(
                onPressed: busy
                    ? null
                    : () {
                        if (!form.currentState!.validate()) return;
                        if (!end.isAfter(start) || start.isBefore(s.now)) {
                          setState(
                            () =>
                                error = const ApiFailure(422, 'validInterval'),
                          );
                          return;
                        }
                        setState(() {
                          review = true;
                          error = null;
                        });
                      },
                child: Text(context.t('reviewBooking')),
              )
            else ...[
              FilledButton(
                onPressed: busy ? null : () => save(true),
                child: Text(context.t(busy ? 'saving' : 'submitBooking')),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: busy ? null : () => save(false),
                child: Text(context.t('saveDraft')),
              ),
              TextButton(
                onPressed: busy ? null : () => setState(() => review = false),
                child: Text(context.t('editDetails')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ParticipantPicker extends StatefulWidget {
  final Session session;
  final Map<int, String> selected;
  const ParticipantPicker({
    super.key,
    required this.session,
    required this.selected,
  });
  @override
  State<ParticipantPicker> createState() => _ParticipantPickerState();
}

class _ParticipantPickerState extends State<ParticipantPicker> {
  final search = TextEditingController();
  late Map<int, String> selected;
  List<Json>? users;
  Object? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    selected = Map.of(widget.selected);
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final ticket = ++generation;
    try {
      final r = await MeetSpaceRepository(
        widget.session,
      ).directory(search.text);
      if (mounted && ticket == generation) {
        setState(() {
          users = rows(r);
          error = null;
        });
      }
    } catch (e) {
      if (mounted && ticket == generation) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.t('staffAttendees')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, selected),
          child: Text(context.t('done')),
        ),
      ],
    ),
    body: PageBody(
      children: [
        Notice(context.t('attendeesOnly')),
        TextField(
          controller: search,
          onSubmitted: (_) => load(),
          decoration: InputDecoration(
            labelText: context.t('searchStaff'),
            suffixIcon: IconButton(
              tooltip: context.t('search'),
              onPressed: load,
              icon: const Icon(Icons.search),
            ),
          ),
        ),
        if (error != null)
          Failure(error!, load)
        else if (users == null)
          const Loading()
        else
          ...users!.map(
            (u) => CheckboxListTile(
              title: Text('${u['name']}'),
              subtitle: Text('${u['position'] ?? ''}'),
              value: selected.containsKey(u['id']),
              onChanged: (v) => setState(() {
                if (v == true) {
                  selected[u['id'] as int] = '${u['name']}';
                } else {
                  selected.remove(u['id']);
                }
              }),
            ),
          ),
      ],
    ),
  );
}
