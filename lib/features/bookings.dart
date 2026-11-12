import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/attachments.dart';
import '../core/copy.dart';
import '../core/repository.dart';
import '../core/session.dart';
import '../shared/widgets.dart';
import 'booking_form.dart';

Future<void> openBooking(BuildContext context, Session session, String id) =>
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingDetailPage(session: session, id: id),
      ),
    );

class BookingsPage extends StatefulWidget {
  final Session session;
  final bool approvals;
  const BookingsPage({
    super.key,
    required this.session,
    this.approvals = false,
  });
  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  List<Json>? items;
  Object? error;
  bool loading = false;
  int page = 1, lastPage = 1, generation = 0, seen = -1;
  String filter = 'upcoming';
  @override
  void initState() {
    super.initState();
    if (widget.approvals) widget.session.addListener(refresh);
    load();
  }

  void refresh() {
    if (mounted && !loading) load();
  }

  @override
  void dispose() {
    if (widget.approvals) widget.session.removeListener(refresh);
    super.dispose();
  }

  @override
  void didUpdateWidget(BookingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (seen != widget.session.revision) load();
  }

  Future<void> load({bool more = false}) async {
    final ticket = ++generation;
    seen = widget.session.revision;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final repo = MeetSpaceRepository(widget.session);
      final r = widget.approvals
          ? await repo.approvals()
          : await repo.bookings(page: more ? page + 1 : 1, bucket: filter);
      if (mounted && generation == ticket) {
        setState(() {
          items = more ? [...?items, ...rows(r)] : rows(r);
          page = r['meta']?['current_page'] ?? 1;
          lastPage = r['meta']?['last_page'] ?? 1;
        });
      }
    } catch (e) {
      if (mounted && generation == ticket) setState(() => error = e);
    } finally {
      if (mounted && generation == ticket) setState(() => loading = false);
    }
  }

  bool matches(Json b) {
    final status = '${b['status']}';
    if (widget.approvals) return status == 'pending';
    if (filter == 'ongoing') return status == 'in_progress';
    final previous =
        ['completed', 'cancelled', 'rejected'].contains(status) ||
        widget.session.local(b['end_at']).isBefore(widget.session.now) &&
            status != 'in_progress';
    return filter == 'previous'
        ? previous
        : !previous && status != 'in_progress';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.approvals
        ? (items ?? []).where(matches).toList()
        : items ?? [];
    final body = PageBody(
      onRefresh: load,
      children: [
        Heading(
          context.t(widget.approvals ? 'approvals' : 'myBookings'),
          subtitle: context.t(
            widget.approvals ? 'approvalsIntro' : 'myBookingsIntro',
          ),
        ),
        if (!widget.approvals) ...[
          SegmentedButton<String>(
            segments: ['upcoming', 'ongoing', 'previous']
                .map((v) => ButtonSegment(value: v, label: Text(context.t(v))))
                .toList(),
            selected: {filter},
            onSelectionChanged: (v) {
              setState(() {
                filter = v.first;
                items = null;
              });
              load();
            },
          ),
          const SizedBox(height: 16),
        ],
        if (error != null)
          Failure(error!, load)
        else if (items == null)
          const Loading()
        else ...[
          if (filtered.isEmpty)
            Empty(context.t(widget.approvals ? 'noApprovals' : 'noBookings')),
          ...filtered.map(
            (b) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel(widget.session, b['start_at']),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                if (widget.approvals && b['submitted_at'] != null)
                  Text(
                    '${context.t('submitted')}: ${dateLabel(widget.session, b['submitted_at'], 'd MMM, HH:mm')}',
                  ),
                MeetingCard(
                  session: widget.session,
                  item: b,
                  onTap: () async {
                    await openBooking(context, widget.session, '${b['id']}');
                    if (mounted) load();
                  },
                ),
              ],
            ),
          ),
          if (page < lastPage)
            OutlinedButton(
              onPressed: loading ? null : () => load(more: true),
              child: Text(context.t('loadMore')),
            ),
        ],
      ],
    );
    return widget.approvals
        ? Scaffold(
            appBar: AppBar(title: Text(context.t('approvals'))),
            body: body,
          )
        : body;
  }
}

class BookingDetailPage extends StatefulWidget {
  final Session session;
  final String id;
  const BookingDetailPage({super.key, required this.session, required this.id});
  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  Json? booking;
  bool busy = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await MeetSpaceRepository(widget.session).booking(widget.id);
      if (mounted) {
        setState(() {
          booking = r['data'] as Json;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> action(String action, [Json? payload]) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await MeetSpaceRepository(
        widget.session,
      ).action(widget.id, action, payload);
      widget.session.changed();
      await load();
      if (mounted) feedback(context, context.t('actionSaved'));
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> decision(String value) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => ReasonDialog(
        title: value == 'approve'
            ? 'approve'
            : value == 'reject'
            ? 'reject'
            : 'requestRevision',
        required: value != 'approve',
      ),
    );
    if (note != null && mounted) {
      action('decision', {'decision': value, 'note': note});
    }
  }

  Future<void> cancel() async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) =>
          const ReasonDialog(title: 'cancelBooking', required: false),
    );
    if (note != null && mounted) action('cancel', {'reason': note});
  }

  Future<void> extend() async {
    final old = widget.session.local(booking!['end_at']);
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(old.add(const Duration(minutes: 30))),
    );
    if (time == null || !mounted) return;
    final end = widget.session.wall(old, time.hour, time.minute);
    if (!end.isAfter(old)) {
      feedback(context, context.t('laterEnd'));
      return;
    }
    if (await confirm(
          context,
          context.t('extend'),
          '${context.t('newEnd')}: ${dateLabel(widget.session, end.toIso8601String(), 'd MMM, HH:mm')}',
        ) &&
        mounted) {
      action('extend', {'end_at': end.toUtc().toIso8601String()});
    }
  }

  Future<void> download(Json attachment) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await openAttachment(widget.session.api, widget.id, attachment);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session, b = booking;
    if (s.user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final owner = b?['organizer']?['id'] == s.user?['id'];
    final status = '${b?['status']}';
    return Scaffold(
      appBar: AppBar(title: Text(context.t('bookingDetails'))),
      body: PageBody(
        onRefresh: load,
        children: [
          if (b == null && error == null) const Loading(),
          if (error != null) Failure(error!, load),
          if (b != null) ...[
            Heading('${b['title']}', subtitle: '${b['reference']}'),
            StatusBadge('${b['operational_status'] ?? status}'),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${b['room']?['name']}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('${b['room']?['location']}'),
                    const Divider(),
                    Text('${dateLabel(s, b['start_at'])} · ${timeRange(s, b)}'),
                    const SizedBox(height: 8),
                    Text(
                      '${context.t('organizer')}: ${b['organizer']?['name']}',
                    ),
                    Text(
                      '${context.t('department')}: ${b['organizer']?['department'] ?? ''}',
                    ),
                    Text(
                      '${context.t('attendeeCount')}: ${b['participant_count']}',
                    ),
                    const SizedBox(height: 12),
                    Text('${b['purpose'] ?? ''}'),
                  ],
                ),
              ),
            ),
            if (['draft', 'pending', 'revision_requested'].contains(status))
              Notice(context.t('pendingHint')),
            if (b['approval_note'] != null)
              Notice('${context.t('decisionNote')}: ${b['approval_note']}'),
            if (owner &&
                s.can('booking.create') &&
                [
                  'draft',
                  'revision_requested',
                  'pending',
                ].contains(status)) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingFormPage(
                              session: s,
                              room: b['room'] as Json,
                              booking: b,
                              start: s.local(b['start_at']),
                              end: s.local(b['end_at']),
                            ),
                          ),
                        );
                        if (mounted) load();
                      },
                icon: const Icon(Icons.edit_outlined),
                label: Text(
                  context.t(
                    status == 'revision_requested'
                        ? 'reviseResubmit'
                        : 'editBooking',
                  ),
                ),
              ),
            ],
            if (owner && s.can('booking.create') && status == 'draft') ...[
              const SizedBox(height: 10),
              FilledButton(
                onPressed: busy ? null : () => action('submit'),
                child: Text(context.t('submitBooking')),
              ),
            ],
            if (s.can('booking.approve') && status == 'pending') ...[
              Heading(context.t('reviewRequest')),
              Notice(context.t('approvalHint')),
              FilledButton(
                onPressed: busy ? null : () => decision('approve'),
                child: Text(context.t('approve')),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: busy ? null : () => decision('revision_requested'),
                child: Text(context.t('requestRevision')),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: busy ? null : () => decision('reject'),
                child: Text(context.t('reject')),
              ),
            ],
            if (owner &&
                status == 'approved' &&
                !s.now.isBefore(
                  s.local(b['start_at']).subtract(const Duration(minutes: 15)),
                ) &&
                s.now.isBefore(s.local(b['end_at']))) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy ? null : () => action('check-in'),
                child: Text(context.t('checkIn')),
              ),
            ],
            if (owner && status == 'in_progress') ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (await confirm(
                              context,
                              context.t('checkOut'),
                              context.t('checkOutHint'),
                            ) &&
                            mounted) {
                          action('check-out');
                        }
                      },
                child: Text(context.t('checkOut')),
              ),
            ],
            if (owner && ['approved', 'in_progress'].contains(status)) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: busy ? null : extend,
                child: Text(context.t('extend')),
              ),
            ],
            if (owner &&
                s.can('booking.update') &&
                [
                  'draft',
                  'pending',
                  'revision_requested',
                  'approved',
                ].contains(status))
              TextButton(
                onPressed: busy ? null : cancel,
                child: Text(context.t('cancelBooking')),
              ),
            if ((b['participants'] as List? ?? []).isNotEmpty) ...[
              Heading(context.t('staffAttendees')),
              ...(b['participants'] as List).map(
                (p) => ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text('${p['name']}'),
                ),
              ),
            ],
            if ((b['attachments'] as List? ?? []).isNotEmpty) ...[
              Heading(context.t('attachments')),
              ...(b['attachments'] as List).cast<Json>().map(
                (a) => ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text('${a['name']}'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: busy ? null : () => download(a),
                ),
              ),
            ],
            Heading(context.t('history')),
            if ((b['history'] as List? ?? []).isEmpty)
              Empty(context.t('noHistory')),
            ...(b['history'] as List? ?? []).map(
              (h) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: Text(context.t('${h['action']}')),
                subtitle: Text(
                  '${dateLabel(s, h['created_at'], 'd MMM yyyy, HH:mm')}${h['note'] == null ? '' : '\n${h['note']}'}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ReasonDialog extends StatefulWidget {
  final String title;
  final bool required;
  const ReasonDialog({super.key, required this.title, required this.required});
  @override
  State<ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<ReasonDialog> {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.t(widget.title)),
    content: Form(
      key: form,
      child: TextFormField(
        controller: controller,
        autofocus: true,
        minLines: 3,
        maxLines: 6,
        maxLength: 5000,
        decoration: InputDecoration(
          labelText: context.t(
            widget.required ? 'reasonRequired' : 'noteOptional',
          ),
        ),
        validator: (v) => widget.required && (v == null || v.trim().isEmpty)
            ? context.t('required')
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.t('back')),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, controller.text.trim());
          }
        },
        child: Text(context.t('confirm')),
      ),
    ],
  );
}
