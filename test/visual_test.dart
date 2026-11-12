import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'widget_test.dart' as fixtures;

void main() {
  setUpAll(tz.initializeTimeZones);
  testWidgets(
    'capture mobile and tablet layouts for visual review',
    (tester) async {
      await tester.runAsync(() async {
        for (final name in ['NotoSans', 'NotoSansKhmer']) {
          final loader = FontLoader(
            name == 'NotoSans' ? 'Noto Sans' : 'Noto Sans Khmer',
          );
          loader.addFont(rootBundle.load('assets/fonts/$name.ttf'));
          await loader.load();
        }
        final icons = FontLoader('MaterialIcons');
        icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
      final s = fixtures.session(admin: true);
      await fixtures.boot(tester, s);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('previews/home-en.png'),
      );
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('previews/schedule-en.png'),
      );
      await tester.tap(find.text('Rooms'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('previews/rooms-en.png'),
      );
      await tester.pumpWidget(const SizedBox());
      final khmer = fixtures.session(admin: true)..locale = 'km';
      await fixtures.boot(tester, khmer, size: const Size(390, 844));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('previews/home-km.png'),
      );
      await tester.pumpWidget(const SizedBox());
      await fixtures.boot(
        tester,
        fixtures.session(admin: true),
        size: const Size(1200, 900),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('previews/tablet-en.png'),
      );
      await tester.pumpWidget(const SizedBox());
    },
    skip: !const bool.fromEnvironment('VISUAL_QA'),
  );
}
