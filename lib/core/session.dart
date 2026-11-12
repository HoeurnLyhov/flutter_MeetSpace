import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/timezone.dart' as tz;
import 'api.dart';
import 'attachments.dart';

abstract class Credentials {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureCredentials implements Credentials {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

class Session extends ChangeNotifier {
  final Api api;
  final Credentials credentials;
  Json? user;
  String locale = 'en';
  String timezone = const String.fromEnvironment(
    'APP_TIMEZONE',
    defaultValue: 'Asia/Phnom_Penh',
  );
  bool loading = true;
  Object? restoreError;
  int revision = 0;
  Session({Api? api, Credentials? credentials})
    : api = api ?? Api(),
      credentials = credentials ?? SecureCredentials() {
    this.api.onUnauthorized = expire;
  }
  bool can(String permission) =>
      (user?['permissions'] as List? ?? []).contains(permission);
  tz.Location get location => tz.getLocation(timezone);
  DateTime get now => tz.TZDateTime.now(location);
  DateTime local(dynamic value) =>
      tz.TZDateTime.from(DateTime.parse('$value'), location);
  DateTime wall(DateTime date, int hour, int minute) =>
      tz.TZDateTime(location, date.year, date.month, date.day, hour, minute);
  Future<void> restore() async {
    loading = true;
    restoreError = null;
    notifyListeners();
    try {
      locale = await credentials.read('locale') ?? 'en';
      api.token = await credentials.read('token');
      if (api.token != null) {
        final result = await api.request('GET', '/auth/me');
        user = result['user'] as Json;
        timezone = result['timezone'] as String? ?? timezone;
      }
    } on ApiFailure catch (e) {
      if (e.status != 401) restoreError = e;
    } catch (e) {
      restoreError = e;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    final response = await api.request(
      'POST',
      '/auth/sign-in',
      body: {
        'email': email.trim(),
        'password': password,
        'device_name': 'MeetSpace Mobile',
      },
    );
    final token = response['token'] as String;
    await credentials.write('token', token);
    api.token = token;
    user = response['user'] as Json;
    timezone = response['timezone'] as String? ?? timezone;
    restoreError = null;
    changed();
  }

  Future<void> setLocale(String value) async {
    await credentials.write('locale', value);
    locale = value;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await api.request('POST', '/auth/sign-out');
    } finally {
      await credentials.delete('token');
      api.token = null;
      user = null;
      changed();
      await clearAttachments().catchError((Object _) {});
    }
  }

  void expire() {
    api.token = null;
    user = null;
    credentials.delete('token').catchError((Object _) {});
    clearAttachments().catchError((Object _) {});
    changed();
  }

  void changed() {
    revision++;
    notifyListeners();
  }
}
