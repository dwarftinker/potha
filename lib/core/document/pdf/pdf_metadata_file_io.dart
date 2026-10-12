// Reads PDF metadata straight from a file on a background isolate, in cached blocks,
// so even 500 MB books are never loaded into memory whole.
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../document_format.dart';
import 'pdf_metadata_reader.dart';

Future<DocumentMetadata> readMetadataFromPath(String path) =>
    Isolate.run(() {
      final file = File(path).openSync();
      try {
        return PdfMetadataReader.readSource(_FileByteSource(file));
      } finally {
        file.closeSync();
      }
    });

class _FileByteSource implements PdfByteSource {
  _FileByteSource(this._file) : length = _file.lengthSync();

  static const _blockSize = 64 * 1024;
  static const _maxBlocks = 64;

  final RandomAccessFile _file;
  final _blocks = <int, Uint8List>{};

  @override
  final int length;

  Uint8List _block(int index) {
    final cached = _blocks.remove(index);
    if (cached != null) return _blocks[index] = cached; // move to most recent
    if (_blocks.length >= _maxBlocks) _blocks.remove(_blocks.keys.first);
    _file.setPositionSync(index * _blockSize);
    return _blocks[index] = _file.readSync(_blockSize);
  }

  @override
  int operator [](int index) {
    if (index < 0 || index >= length) throw RangeError.index(index, this);
    return _block(index ~/ _blockSize)[index % _blockSize];
  }

  @override
  Uint8List range(int start, int end) {
    if (start < 0 || end > length || start > end) throw RangeError.range(start, 0, length);
    _file.setPositionSync(start);
    return _file.readSync(end - start);
  }
}
