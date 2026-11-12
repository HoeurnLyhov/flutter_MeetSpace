import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_meetspace/app.dart';
import 'package:flutter_meetspace/core/api.dart';
import 'package:flutter_meetspace/core/copy.dart';
import 'package:flutter_meetspace/core/session.dart';
import 'package:flutter_meetspace/features/booking_form.dart';

class MemoryCredentials implements Credentials {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

Json user({bool admin = false}) => {
  'id': 1,
  'name': 'Sophea Chan',
  'email': 'staff@example.test',
  'department': {'id': 1, 'name': 'Administration'},
  'division': {'name': 'Operations'},
  'position': 'Officer',
  'permissions': [
    'room.view',
    'booking.view',
    'booking.create',
    'booking.update',
    if (admin) 'booking.approve',
  ],
};
Json room() => {
  'id': 'ROOM1',
  'name': 'Council Room',
  'location': 'Building A, floor 2',
  'capacity': 12,
  'code': 'A-201',
  'opens_at': '08:00',
  'closes_at': '17:00',
  'turnover_buffer_minutes': 10,
  'resources': ['Projector', 'Whiteboard'],
  'status': 'available',
};
Json booking({String status = 'pending'}) => {
  'id': 'BOOK1',
  'title': 'Department planning',
  'reference': 'MS-001',
  'status': status,
  'start_at': '2026-11-05T03:00:00Z',
  'end_at': '2026-11-05T04:00:00Z',
  'room': room(),
  'organizer': {'id': 1, 'name': 'Sophea Chan', 'department': 'Administration'},
  'participant_count': 5,
  'purpose': 'Agree next month’s work plan.',
  'history': [],
  'attachments': [],
  'participants': [],
  'can_view_details': true,
};
http.Response response(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);
Session session({
  bool admin = false,
  Future<http.Response> Function(http.Request)? handler,
}) {
  final client = MockClient(
    handler ??
        (req) async {
          if (req.url.path.endsWith('/mobile/meetings')) {
            return response({
              'data': [booking(status: 'approved')],
              'meta': {
                'timezone': 'Asia/Phnom_Penh',
                'current_page': 1,
                'last_page': 1,
              },
              'filters': {
                'rooms': [room()],
                'departments': [
                  {'id': 1, 'name': 'Administration'},
                ],
              },
            });
          }
          if (req.url.path.endsWith('/auth/me')) {
            return response({'user': user(admin: admin)});
          }
          if (req.url.path.endsWith('/bookings/approvals')) {
            return response({
              'data': [booking()],
            });
          }
          if (req.url.path.endsWith('/bookings/BOOK1')) {
            return response({'data': booking()});
          }
          if (req.url.path.endsWith('/bookings') &&
              req.url.queryParameters['status'] == 'approved') {
            return response({'data': []});
          }
          if (req.url.path.endsWith('/bookings')) {
            return response({
              'data': [booking()],
              'meta': {'current_page': 1, 'last_page': 1},
            });
          }
          return response({'data': []});
        },
  );
  final s = Session(
    api: Api(client: client, baseUrl: 'https://api.example.test/api/v1'),
    credentials: MemoryCredentials(),
  );
  s.loading = false;
  s.user = user(admin: admin);
  s.api.token = 'test';
  return s;
}

Future<void> boot(
  WidgetTester tester,
  Session s, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.runAsync(Copy.preload);
  await tester.pumpWidget(MeetSpaceApp(session: s, restore: false));
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(tz.initializeTimeZones);
  testWidgets(
    'employee navigation contains booking scope and hides approvals',
    (tester) async {
      await boot(tester, session());
      expect(find.text('Today’s meetings'), findsOneWidget);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Approvals'), findsNothing);
      expect(find.text('Personal schedules'), findsNothing);
      expect(find.text('Change password'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('admin can reach approval review with all three decisions', (
    tester,
  ) async {
    final s = session(admin: true);
    await boot(tester, s);
    await tester.tap(find.text('Pending approvals'));
    await tester.pumpAndSettle();
    expect(find.text('Department planning'), findsOneWidget);
    await tester.tap(find.text('Department planning'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Request revision'), 250);
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsOneWidget);
    await tester.tap(find.text('Request revision'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('This field is required.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('sign-in validates fields and renders server errors', (
    tester,
  ) async {
    final s = session(
      handler: (_) async => response({
        'message': 'Incorrect credentials',
        'errors': {
          'email': ['Incorrect credentials'],
        },
      }, 422),
    );
    s.user = null;
    await boot(tester, s);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'employee@example.test',
    );
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).at(1))
          .focusNode
          .hasFocus,
      isTrue,
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect credentials'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('schedule supports date modes and department filter', (
    tester,
  ) async {
    await boot(tester, session());
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    expect(find.text('All departments'), findsOneWidget);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('Department planning'), findsOneWidget);
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Khmer mobile and tablet layouts remain usable', (tester) async {
    for (final size in [const Size(360, 800), const Size(1024, 900)]) {
      final s = session(admin: true);
      s.locale = 'km';
      await boot(tester, s, size: size);
      expect(find.text('កិច្ចប្រជុំថ្ងៃនេះ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('បន្ទប់'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('offline state exposes retry', (tester) async {
    await boot(
      tester,
      session(handler: (_) async => throw http.ClientException('offline')),
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('Cannot connect.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  test(
    'API sends bearer credentials and retains conflict validation',
    () async {
      final api = Api(
        baseUrl: 'https://example.test/api/v1',
        client: MockClient((req) async {
          expect(req.headers['Authorization'], 'Bearer secret');
          expect(jsonDecode(req.body)['decision'], 'approve');
          return response({
            'message': 'Conflict',
            'errors': {
              'room_id': ['Room is no longer available.'],
            },
          }, 422);
        }),
      )..token = 'secret';
      await expectLater(
        api.request(
          'POST',
          '/bookings/1/decision',
          body: {'decision': 'approve'},
        ),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.errors['room_id'][0],
            'conflict',
            'Room is no longer available.',
          ),
        ),
      );
    },
  );
  test('expired session drops current user and bearer token', () async {
    final s = session(
      handler: (_) async => response({'message': 'Unauthenticated'}, 401),
    );
    await expectLater(
      s.api.request('GET', '/auth/me'),
      throwsA(isA<ApiFailure>()),
    );
    expect(s.user, isNull);
    expect(s.api.token, isNull);
  });
  test('application timezone is independent of device timezone', () {
    final s = session();
    expect(s.local('2026-11-05T03:00:00Z').hour, 10);
    expect(s.wall(DateTime(2026, 11, 5), 10, 0).toUtc().hour, 3);
  });
  testWidgets('booking submission retains the form when availability changes', (
    tester,
  ) async {
    final s = session(
      handler: (req) async {
        if (req.method == 'POST' && req.url.path.endsWith('/bookings')) {
          final body = jsonDecode(req.body) as Json;
          expect(body['submit'], true);
          expect(body['title'], 'Room planning');
          return response({
            'message': 'Conflict',
            'errors': {
              'room_id': ['Room is no longer available.'],
            },
          }, 422);
        }
        return response({
          'data': [],
          'meta': {'timezone': 'Asia/Phnom_Penh'},
          'filters': {'rooms': [], 'departments': []},
        });
      },
    );
    await boot(tester, s);
    final context = tester.element(find.byType(NavigationBar));
    final start = s.wall(s.now.add(const Duration(days: 1)), 10, 0);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BookingFormPage(
          session: s,
          room: room(),
          start: start,
          end: start.add(const Duration(hours: 1)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Room planning');
    await tester.scrollUntilVisible(
      find.text('Review booking'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review booking'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Submit for approval'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Submit for approval'));
    await tester.pumpAndSettle();
    expect(find.text('Room is no longer available.'), findsOneWidget);
    expect(find.text('Edit details'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
