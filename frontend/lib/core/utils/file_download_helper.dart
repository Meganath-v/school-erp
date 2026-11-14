import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart';

void downloadBinaryFile(List<int> bytes, String fileName, String mimeType) {
  saveBinaryFile(bytes, fileName, mimeType);
}

void triggerBrowserPrint() {
  callBrowserPrint();
}
