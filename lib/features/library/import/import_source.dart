// One file to import, whatever it came from: the file picker, drag and drop, or
// Open with / Share to. See contracts/storage-and-import.md.
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';

class ImportSource {
  const ImportSource({required this.name, required this.size, required this.openRead});

  final String name;

  /// Null if unknown up front.
  final int? size;
  final Stream<List<int>> Function() openRead;

  static Future<ImportSource> fromPlatformFile(PlatformFile file) async => ImportSource(
        name: file.name,
        size: await file.length(),
        openRead: file.readAsByteStream,
      );

  /// Dropped files (desktop_drop) and files received from other apps.
  static Future<ImportSource> fromXFile(XFile file) async {
    int? size;
    try {
      size = await file.length();
    } catch (_) {}
    return ImportSource(name: file.name, size: size, openRead: file.openRead);
  }
}
