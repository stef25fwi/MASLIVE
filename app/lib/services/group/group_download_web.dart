import 'package:web/web.dart' as web;

void downloadTextFile({
  required String fileName,
  required String content,
  required String mimeType,
}) {
  final blob = web.Blob(
    [content] as dynamic,
    web.BlobPropertyBag(type: mimeType),
  );

  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..setAttribute('download', fileName)
    ..style.display = 'none';

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();

  web.URL.revokeObjectURL(url);
}
