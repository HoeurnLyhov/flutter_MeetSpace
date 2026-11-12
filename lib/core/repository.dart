import 'api.dart';
import 'session.dart';

class MeetSpaceRepository {
  final Session session;
  MeetSpaceRepository(this.session);
  Api get api => session.api;
  Future<Json> meetings(
    DateTime from,
    DateTime to, {
    String? department,
    String? room,
    int page = 1,
  }) async {
    final result = await api.request(
      'GET',
      '/mobile/meetings',
      query: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'page': page,
        'department_id': ?department,
        'room_id': ?room,
      },
    );
    session.timezone = result['meta']['timezone'] as String;
    return result;
  }

  Future<Json> bookings({
    int page = 1,
    String bucket = 'upcoming',
    String? status,
  }) => api.request(
    'GET',
    '/bookings',
    query: {'mine': 1, 'page': page, 'bucket': bucket, 'status': ?status},
  );
  Future<Json> booking(String id) => api.request('GET', '/bookings/$id');
  Future<Json> rooms({Json? filters}) =>
      api.request('GET', '/rooms', query: filters);
  Future<Json> roomSchedule(String id, DateTime from, DateTime to) =>
      api.request(
        'GET',
        '/rooms/$id/schedule',
        query: {
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
        },
      );
  Future<Json> resources() => api.request('GET', '/room-resources');
  Future<Json> save(Json values, {String? id, List<Upload> files = const []}) =>
      api.request(
        id == null ? 'POST' : 'PUT',
        id == null ? '/bookings' : '/bookings/$id',
        body: values,
        files: files,
      );
  Future<Json> action(String id, String action, [Json? body]) =>
      api.request('POST', '/bookings/$id/$action', body: body);
  Future<Json> approvals() => api.request('GET', '/bookings/approvals');
  Future<Json> notifications(int page) => api.request(
    'GET',
    '/notifications',
    query: {'page': page, 'booking_only': 1},
  );
  Future<void> readNotification(String id) =>
      api.request('PUT', '/notifications/$id/read');
  Future<void> readAll() => api.request(
    'PUT',
    '/notifications/read-all',
    body: {'booking_only': true},
  );
  Future<Json> directory(String search) =>
      api.request('GET', '/directory/users', query: {'search': search});
  Future<void> password(String old, String value, String confirmation) =>
      api.request(
        'PUT',
        '/auth/password',
        body: {
          'current_password': old,
          'new_password': value,
          'new_password_confirmation': confirmation,
        },
      );
}
