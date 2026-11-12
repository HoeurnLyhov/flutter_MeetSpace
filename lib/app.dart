import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/copy.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'features/auth.dart';
import 'features/shell.dart';
import 'shared/widgets.dart';

class MeetSpaceApp extends StatefulWidget {
  final Session session;
  final bool restore;
  const MeetSpaceApp({super.key, required this.session, this.restore = true});
  @override
  State<MeetSpaceApp> createState() => _MeetSpaceAppState();
}

class _MeetSpaceAppState extends State<MeetSpaceApp> {
  @override
  void initState() {
    super.initState();
    if (widget.restore) widget.session.restore();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) => MaterialApp(
      key: ValueKey(widget.session.user?['id'] ?? 'signed-out'),
      title: 'MeetSpace',
      debugShowCheckedModeBanner: false,
      theme: Civic.theme(),
      locale: Locale(widget.session.locale),
      supportedLocales: const [Locale('en'), Locale('km')],
      localizationsDelegates: const [
        Copy.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) {
          final s = widget.session;
          if (s.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (s.restoreError != null) {
            return Scaffold(
              body: SafeArea(
                child: PageBody(
                  children: [
                    Heading(context.t('welcome')),
                    Failure(s.restoreError!, s.restore),
                  ],
                ),
              ),
            );
          }
          if (s.user == null) return SignInPage(session: s);
          return Shell(key: ValueKey(s.user!['id']), session: s);
        },
      ),
    ),
  );
}
