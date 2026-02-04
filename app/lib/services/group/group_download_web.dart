// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadTextFile({
  required String fileName,
  required String content,
  required String mimeType,
}) {
  final bytes = html.Blob([content], mimeType);
  final url = html.Url.createObjectUrlFromBlob(bytes);

  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();

  html.Url.revokeObjectUrl(url);
}
