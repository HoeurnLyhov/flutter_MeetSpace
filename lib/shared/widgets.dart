import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api.dart';
import '../core/copy.dart';
import '../core/session.dart';
import '../core/theme.dart';

class PageBody extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  const PageBody({super.key, required this.children, this.onRefresh});
  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
    return onRefresh == null
        ? body
        : RefreshIndicator(onRefresh: onRefresh!, child: body);
  }
}

class Heading extends StatelessWidget {
  final String title;
  final String? subtitle;
  const Heading(this.title, {super.key, this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(color: Civic.muted, height: 1.5),
          ),
        ],
      ],
    ),
  );
}

class Notice extends StatelessWidget {
  final String text;
  final bool error;
  const Notice(this.text, {super.key, this.error = false});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFFEEEE) : const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? Icons.error_outline : Icons.info_outline,
            color: error ? Colors.red.shade800 : Civic.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: error ? Colors.red.shade900 : Civic.ink,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class Failure extends StatelessWidget {
  final Object error;
  final VoidCallback retry;
  const Failure(this.error, this.retry, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Notice(Copy.of(context).error(error), error: true),
      OutlinedButton.icon(
        onPressed: retry,
        icon: const Icon(Icons.refresh),
        label: Text(context.t('retry')),
      ),
    ],
  );
}

class Empty extends StatelessWidget {
  final String title;
  const Empty(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Column(
      children: [
        const Icon(
          Icons.event_available_outlined,
          color: Civic.muted,
          size: 44,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Civic.muted),
        ),
      ],
    ),
  );
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: context.t('loading'),
    child: const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' || 'available' || 'completed' => Civic.teal,
      'rejected' || 'cancelled' || 'unavailable' => const Color(0xFFAC2430),
      'pending' ||
      'revision_requested' ||
      'overtime' ||
      'reserved' => const Color(0xFF885B00),
      _ => Civic.blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        context.t(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

String dateLabel(Session s, dynamic value, [String pattern = 'EEE, d MMM']) =>
    DateFormat(pattern, s.locale).format(s.local(value));
String timeRange(Session s, Json item) =>
    '${dateLabel(s, item['start_at'], 'HH:mm')} – ${dateLabel(s, item['end_at'], 'HH:mm')}';

class MeetingCard extends StatelessWidget {
  final Session session;
  final Json item;
  final VoidCallback? onTap;
  const MeetingCard({
    super.key,
    required this.session,
    required this.item,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    timeRange(session, item),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Civic.blue,
                    ),
                  ),
                  StatusBadge(
                    '${item['operational_status'] ?? item['status']}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${item['title']}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '${item['room']?['name'] ?? item['location'] ?? ''}',
                style: const TextStyle(color: Civic.muted),
              ),
              if (item['organizer'] is Map) ...[
                const SizedBox(height: 6),
                Text(
                  [
                    item['organizer']['name'],
                    item['organizer']['department'],
                  ].where((v) => v != null).join(' · '),
                  style: const TextStyle(color: Civic.muted),
                ),
              ],
              if (onTap != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.arrow_forward, size: 20, color: Civic.blue),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String description,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('back')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('confirm')),
          ),
        ],
      ),
    ) ??
    false;
void feedback(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
