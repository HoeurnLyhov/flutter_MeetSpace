import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'app.dart';
import 'core/session.dart';
import 'core/copy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await Copy.preload();
  runApp(MeetSpaceApp(session: Session()));
}
