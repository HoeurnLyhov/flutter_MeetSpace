import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/copy.dart';
import '../core/repository.dart';
import '../core/session.dart';
import '../shared/widgets.dart';
import 'bookings.dart';

class MorePage extends StatefulWidget {
  final Session session;
  const MorePage({super.key, required this.session});
  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  bool busy = false;
  Object? error;
  Future<void> logout() async {
    if (!await confirm(
          context,
          context.t('signOut'),
          context.t('signOutHint'),
        ) ||
        !mounted) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.signOut();
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session, user = s.user!;
    return PageBody(
      children: [
        Heading(context.t('more')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 28,
                  child: Icon(Icons.person_outline),
                ),
                const SizedBox(height: 16),
                Text(
                  '${user['name']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text('${user['position'] ?? ''}'),
                Text('${user['department']?['name'] ?? ''}'),
                Text('${user['division']?['name'] ?? ''}'),
                const SizedBox(height: 6),
                Text('${user['email']}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (s.can('booking.approve'))
          Card(
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(context.t('approvals')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingsPage(session: s, approvals: true),
                ),
              ),
            ),
          ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.notifications_none),
            title: Text(context.t('notifications')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NotificationsPage(session: s)),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.translate),
            title: Text(context.t('language')),
            trailing: DropdownButton<String>(
              value: s.locale,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(
                  value: 'en',
                  child: Text(context.t('english')),
                ),
                DropdownMenuItem(value: 'km', child: Text(context.t('khmer'))),
              ],
              onChanged: (v) {
                if (v != null) s.setLocale(v);
              },
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(context.t('changePassword')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PasswordPage(session: s)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (error != null) Notice(Copy.of(context).error(error!), error: true),
        OutlinedButton.icon(
          onPressed: busy ? null : logout,
          icon: const Icon(Icons.logout),
          label: Text(context.t('signOut')),
        ),
      ],
    );
  }
}

class PasswordPage extends StatefulWidget {
  final Session session;
  const PasswordPage({super.key, required this.session});
  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final form = GlobalKey<FormState>();
  final old = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false;
  Object? error;
  @override
  void dispose() {
    old.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await MeetSpaceRepository(
        widget.session,
      ).password(old.text, password.text, confirmation.text);
      widget.session.expire();
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
        feedback(context, context.t('passwordChanged'));
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t('changePassword'))),
    body: PageBody(
      children: [
        Heading(
          context.t('changePassword'),
          subtitle: context.t('passwordHint'),
        ),
        Form(
          key: form,
          child: Column(
            children: [
              TextFormField(
                controller: old,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.t('currentPassword'),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? context.t('required') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.t('newPassword'),
                ),
                validator: (v) => v == null || v.length < 8
                    ? context.t('passwordPolicy')
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmation,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.t('confirmPassword'),
                ),
                validator: (v) =>
                    v != password.text ? context.t('passwordMismatch') : null,
              ),
            ],
          ),
        ),
        if (error != null) Notice(Copy.of(context).error(error!), error: true),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(context.t('savePassword')),
        ),
      ],
    ),
  );
}

class NotificationsPage extends StatefulWidget {
  final Session session;
  const NotificationsPage({super.key, required this.session});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Json>? items;
  int page = 1, total = 0, unread = 0;
  bool busy = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    widget.session.addListener(refresh);
    load();
  }

  void refresh() {
    if (mounted) load();
  }

  @override
  void dispose() {
    widget.session.removeListener(refresh);
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await MeetSpaceRepository(
        widget.session,
      ).notifications(more ? page + 1 : 1);
      if (mounted) {
        setState(() {
          items = more ? [...?items, ...rows(r)] : rows(r);
          page = more ? page + 1 : 1;
          total = r['meta']['total'];
          unread = r['meta']['unread'];
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> readAll() async {
    try {
      await MeetSpaceRepository(widget.session).readAll();
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> open(Json item) async {
    try {
      await MeetSpaceRepository(
        widget.session,
      ).readNotification('${item['id']}');
      if (!mounted) return;
      if (item['booking_id'] != null) {
        await openBooking(context, widget.session, '${item['booking_id']}');
      }
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t('notifications'))),
    body: PageBody(
      onRefresh: load,
      children: [
        Heading(
          context.t('notifications'),
          subtitle: '$unread ${context.t('unread')}',
        ),
        if (unread > 0)
          TextButton(
            onPressed: busy ? null : readAll,
            child: Text(context.t('markAllRead')),
          ),
        if (error != null)
          Failure(error!, load)
        else if (items == null)
          const Loading()
        else if (items!.isEmpty)
          Empty(context.t('noNotifications'))
        else
          ...items!.map(
            (n) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Icon(
                    n['read_at'] == null
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_none,
                  ),
                  title: Text(
                    n['event'] != null
                        ? context.t('notification_${n['event']}')
                        : '${n['title']}',
                    style: TextStyle(
                      fontWeight: n['read_at'] == null
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  subtitle: Text(
                    '${n['detail'] ?? ''}\n${dateLabel(widget.session, n['created_at'], 'd MMM, HH:mm')}',
                  ),
                  onTap: () => open(n),
                ),
              ),
            ),
          ),
        if ((items?.length ?? 0) < total)
          OutlinedButton(
            onPressed: busy ? null : () => load(more: true),
            child: Text(context.t('loadMore')),
          ),
      ],
    ),
  );
}
