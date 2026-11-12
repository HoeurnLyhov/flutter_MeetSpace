import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'api.dart';

Future<void> openAttachment(Api api, String booking, Json attachment) async {
  final bytes = await api.download(
    '/bookings/$booking/attachments/${attachment['id']}',
  );
  final directory = await getTemporaryDirectory();
  final name = '${attachment['name']}'
      .split(RegExp(r'[/\\]'))
      .last
      .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  final folder = Directory('${directory.path}/meetspace');
  await folder.create(recursive: true);
  final file = File('${folder.path}/${attachment['id']}-$name');
  await file.writeAsBytes(bytes, flush: true);
  final result = await OpenFilex.open(file.path);
  if (result.type != ResultType.done) throw const ApiFailure(0, 'noFileViewer');
}

Future<void> clearAttachments() async {
  final directory = await getTemporaryDirectory();
  final folder = Directory('${directory.path}/meetspace');
  if (await folder.exists()) await folder.delete(recursive: true);
}
