// Export dart:io File and SocketException for mobile/desktop platforms
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

export 'dart:io' show File, SocketException;

// Helper function untuk create File dari bytes (untuk mobile)
// Di mobile, kita tidak perlu bytes karena File sudah langsung dari path
io.File createFileFromBytes(String path, Uint8List bytes) {
  return io.File(path);
}

Future<io.File> createFileFromDemoAsset(String fileName, Uint8List bytes) async {
  final directory = await getTemporaryDirectory();
  final file = io.File(
    '${directory.path}${io.Platform.pathSeparator}$fileName',
  );
  return file.writeAsBytes(bytes, flush: true);
}
