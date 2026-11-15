// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void saveBinaryFile(List<int> bytes, String fileName, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

void callBrowserPrint() {
  html.window.print();
}

