// Best-effort reader for a PDF's title and author (research R1).
//
// pdfrx does not expose document metadata, so this reads the Info dictionary itself:
// classic xref tables, cross-reference streams and Flate-compressed object streams,
// with an XMP (dc:title / dc:creator) fallback. Encrypted files return nothing.
// It never throws; any problem means "no metadata".
//
// TODO(pdfrx): replace with a pdfrx metadata API once one exists (tasks.md T077).
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../document_format.dart';

class PdfMetadataReader {
  PdfMetadataReader._();

  static DocumentMetadata read(Uint8List bytes) => readSource(MemoryByteSource(bytes));

  /// Reads from any random-access source, e.g. a file read in blocks so large books
  /// are never loaded into memory whole.
  static DocumentMetadata readSource(PdfByteSource source) {
    try {
      return _Reader(source).read();
    } catch (_) {
      return DocumentMetadata.empty;
    }
  }
}

/// Random access to the bytes of a PDF.
abstract class PdfByteSource {
  int get length;
  int operator [](int index);

  /// Bytes in [start, end).
  Uint8List range(int start, int end);
}

class MemoryByteSource implements PdfByteSource {
  MemoryByteSource(this.bytes);
  final Uint8List bytes;

  @override
  int get length => bytes.length;
  @override
  int operator [](int index) => bytes[index];
  @override
  Uint8List range(int start, int end) => Uint8List.sublistView(bytes, start, end);
}

// ---------------------------------------------------------------------------
// Object model

class _Ref {
  const _Ref(this.number);
  final int number;
}

class _Name {
  const _Name(this.value);
  final String value;
}

class _Keyword {
  const _Keyword(this.value);
  final String value;
}

class _PdfString {
  const _PdfString(this.bytes);
  final Uint8List bytes;
}

class _Stream {
  const _Stream(this.dict, this.raw);
  final Map<String, Object?> dict;
  final Uint8List raw;
}

class _XrefEntry {
  const _XrefEntry.offset(this.offset)
      : streamNumber = null,
        index = null;
  const _XrefEntry.compressed(int this.streamNumber, int this.index) : offset = null;
  const _XrefEntry.free()
      : offset = null,
        streamNumber = null,
        index = null;

  final int? offset;
  final int? streamNumber;
  final int? index;
}

class _PdfFormatException implements Exception {
  const _PdfFormatException(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Lexer / parser

bool _isWhite(int c) => c == 0 || c == 9 || c == 10 || c == 12 || c == 13 || c == 32;
bool _isDelimiter(int c) =>
    c == 0x28 || c == 0x29 || c == 0x3C || c == 0x3E || c == 0x5B || c == 0x5D ||
    c == 0x7B || c == 0x7D || c == 0x2F || c == 0x25;

class _Parser {
  _Parser(this.bytes, [this.pos = 0]);

  _Parser.memory(Uint8List data, [int pos = 0]) : this(MemoryByteSource(data), pos);

  final PdfByteSource bytes;
  int pos;

  bool get atEnd => pos >= bytes.length;

  void skipWhite() {
    while (pos < bytes.length) {
      final c = bytes[pos];
      if (_isWhite(c)) {
        pos++;
      } else if (c == 0x25) {
        while (pos < bytes.length && bytes[pos] != 10 && bytes[pos] != 13) {
          pos++;
        }
      } else {
        break;
      }
    }
  }

  bool startsWith(String token) {
    if (pos + token.length > bytes.length) return false;
    for (var i = 0; i < token.length; i++) {
      if (bytes[pos + i] != token.codeUnitAt(i)) return false;
    }
    return true;
  }

  String _readRegular() {
    final start = pos;
    while (pos < bytes.length && !_isWhite(bytes[pos]) && !_isDelimiter(bytes[pos])) {
      pos++;
    }
    return latin1.decode(bytes.range(start, pos));
  }

  Object? parse() {
    skipWhite();
    if (atEnd) throw const _PdfFormatException('Unexpected end');
    final c = bytes[pos];
    switch (c) {
      case 0x2F: // /
        pos++;
        return _Name(_decodeName(_readRegular()));
      case 0x3C: // <
        if (pos + 1 < bytes.length && bytes[pos + 1] == 0x3C) return _parseDict();
        return _parseHexString();
      case 0x5B: // [
        pos++;
        final list = <Object?>[];
        while (true) {
          skipWhite();
          if (atEnd) throw const _PdfFormatException('Unterminated array');
          if (bytes[pos] == 0x5D) {
            pos++;
            return list;
          }
          list.add(parse());
        }
      case 0x28: // (
        return _parseLiteralString();
    }
    if ((c >= 0x30 && c <= 0x39) || c == 0x2B || c == 0x2D || c == 0x2E) {
      return _parseNumberOrRef();
    }
    final word = _readRegular();
    if (word.isEmpty) {
      pos++;
      throw _PdfFormatException('Unexpected byte $c');
    }
    return switch (word) {
      'true' => true,
      'false' => false,
      'null' => null,
      _ => _Keyword(word),
    };
  }

  Map<String, Object?> _parseDict() {
    pos += 2;
    final dict = <String, Object?>{};
    while (true) {
      skipWhite();
      if (startsWith('>>')) {
        pos += 2;
        return dict;
      }
      final key = parse();
      if (key is! _Name) throw const _PdfFormatException('Dictionary key is not a name');
      dict[key.value] = parse();
    }
  }

  num _parseNumber() {
    final text = _readRegular();
    return num.tryParse(text) ?? (throw _PdfFormatException('Bad number $text'));
  }

  Object _parseNumberOrRef() {
    final first = _parseNumber();
    if (first is! int || first < 0) return first;
    final save = pos;
    skipWhite();
    if (!atEnd && bytes[pos] >= 0x30 && bytes[pos] <= 0x39) {
      final gen = _parseNumber();
      skipWhite();
      if (gen is int && !atEnd && bytes[pos] == 0x52 /* R */ &&
          (pos + 1 >= bytes.length ||
              _isWhite(bytes[pos + 1]) ||
              _isDelimiter(bytes[pos + 1]))) {
        pos++;
        return _Ref(first);
      }
    }
    pos = save;
    return first;
  }

  _PdfString _parseHexString() {
    pos++;
    final digits = StringBuffer();
    while (pos < bytes.length && bytes[pos] != 0x3E) {
      if (!_isWhite(bytes[pos])) digits.writeCharCode(bytes[pos]);
      pos++;
    }
    pos++;
    var hex = digits.toString();
    if (hex.length.isOdd) hex += '0';
    return _PdfString(Uint8List.fromList([
      for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
    ]));
  }

  _PdfString _parseLiteralString() {
    pos++;
    final out = BytesBuilder(copy: false);
    var depth = 1;
    while (pos < bytes.length) {
      final c = bytes[pos++];
      if (c == 0x5C) {
        if (pos >= bytes.length) break;
        final e = bytes[pos++];
        switch (e) {
          case 0x6E:
            out.addByte(10);
          case 0x72:
            out.addByte(13);
          case 0x74:
            out.addByte(9);
          case 0x62:
            out.addByte(8);
          case 0x66:
            out.addByte(12);
          case 0x0D: // line continuation
            if (pos < bytes.length && bytes[pos] == 0x0A) pos++;
          case 0x0A:
            break;
          default:
            if (e >= 0x30 && e <= 0x37) {
              var value = e - 0x30;
              for (var i = 0; i < 2 && pos < bytes.length; i++) {
                final d = bytes[pos];
                if (d < 0x30 || d > 0x37) break;
                value = value * 8 + d - 0x30;
                pos++;
              }
              out.addByte(value & 0xFF);
            } else {
              out.addByte(e); // \( \) \\ and unknown escapes
            }
        }
      } else if (c == 0x28) {
        depth++;
        out.addByte(c);
      } else if (c == 0x29) {
        if (--depth == 0) break;
        out.addByte(c);
      } else {
        out.addByte(c);
      }
    }
    return _PdfString(out.toBytes());
  }

  static String _decodeName(String raw) => raw.replaceAllMapped(
      RegExp(r'#([0-9A-Fa-f]{2})'), (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)));
}

// ---------------------------------------------------------------------------
// Document reader

class _Reader {
  _Reader(this.bytes);

  final PdfByteSource bytes;
  final _entries = <int, _XrefEntry>{};
  final _trailer = <String, Object?>{};
  final _objectCache = <int, Object?>{};
  final _objectStreams = <int, List<Object?>>{};
  final _resolving = <int>{};

  DocumentMetadata read() {
    if (_indexOf('%PDF-', 0, limit: 1024) < 0) return DocumentMetadata.empty;

    String? title;
    String? author;
    final startxref = _lastIndexOf('startxref', within: 1 << 20);
    if (startxref >= 0) {
      final p = _Parser(bytes, startxref + 'startxref'.length);
      final offset = p.parse();
      if (offset is int) _loadXref(offset, {});
      if (_trailer.containsKey('Encrypt')) return DocumentMetadata.empty;

      final info = _resolve(_trailer['Info']);
      if (info is Map<String, Object?>) {
        title = _text(_resolve(info['Title']));
        author = _text(_resolve(info['Author']));
      }
    }

    if (title == null || author == null) {
      final xmp = _xmpPacket();
      if (xmp != null) {
        title ??= _xmpField(xmp, 'title');
        author ??= _xmpField(xmp, 'creator');
      }
    }
    return DocumentMetadata(title: title, author: author);
  }

  // -- byte search ----------------------------------------------------------

  int _indexOf(String token, int start, {int? limit}) {
    final end = limit == null ? bytes.length : (limit < bytes.length ? limit : bytes.length);
    outer:
    for (var i = start; i <= end - token.length; i++) {
      for (var j = 0; j < token.length; j++) {
        if (bytes[i + j] != token.codeUnitAt(j)) continue outer;
      }
      return i;
    }
    return -1;
  }

  int _lastIndexOf(String token, {required int within}) {
    final stop = bytes.length - within < 0 ? 0 : bytes.length - within;
    outer:
    for (var i = bytes.length - token.length; i >= stop; i--) {
      for (var j = 0; j < token.length; j++) {
        if (bytes[i + j] != token.codeUnitAt(j)) continue outer;
      }
      return i;
    }
    return -1;
  }

  // -- cross-reference ------------------------------------------------------

  void _loadXref(int offset, Set<int> seen) {
    if (offset < 0 || offset >= bytes.length || !seen.add(offset)) return;
    final p = _Parser(bytes, offset)..skipWhite();
    Map<String, Object?> trailer;
    if (p.startsWith('xref')) {
      p.pos += 4;
      while (true) {
        p.skipWhite();
        if (p.startsWith('trailer')) {
          p.pos += 'trailer'.length;
          trailer = p.parse() as Map<String, Object?>;
          break;
        }
        final start = p.parse() as int;
        final count = p.parse() as int;
        for (var i = 0; i < count; i++) {
          final off = p.parse() as int;
          p.parse(); // generation
          final kind = p.parse() as _Keyword;
          _entries.putIfAbsent(start + i,
              () => kind.value == 'n' ? _XrefEntry.offset(off) : const _XrefEntry.free());
        }
      }
      final hybrid = trailer['XRefStm'];
      if (hybrid is int) _loadXref(hybrid, seen);
    } else {
      final stream = _parseIndirect(offset);
      if (stream is! _Stream || (stream.dict['Type'] as _Name?)?.value != 'XRef') {
        throw const _PdfFormatException('No xref at offset');
      }
      _readXrefStream(stream);
      trailer = stream.dict;
    }
    for (final entry in trailer.entries) {
      _trailer.putIfAbsent(entry.key, () => entry.value);
    }
    final prev = trailer['Prev'];
    if (prev is int) _loadXref(prev, seen);
  }

  void _readXrefStream(_Stream stream) {
    final data = _decode(stream);
    final widths = (stream.dict['W'] as List).cast<int>();
    final size = stream.dict['Size'] as int;
    final index = (stream.dict['Index'] as List?)?.cast<int>() ?? [0, size];
    final rowLength = widths.fold<int>(0, (a, b) => a + b);
    var pos = 0;

    int field(int width, int defaultValue) {
      if (width == 0) return defaultValue;
      var value = 0;
      for (var i = 0; i < width; i++) {
        value = (value << 8) | data[pos++];
      }
      return value;
    }

    for (var s = 0; s + 1 < index.length; s += 2) {
      for (var i = 0; i < index[s + 1]; i++) {
        if (pos + rowLength > data.length) return;
        final type = field(widths[0], 1);
        final a = field(widths[1], 0);
        final b = field(widths[2], 0);
        final number = index[s] + i;
        _entries.putIfAbsent(
          number,
          () => switch (type) {
            1 => _XrefEntry.offset(a),
            2 => _XrefEntry.compressed(a, b),
            _ => const _XrefEntry.free(),
          },
        );
      }
    }
  }

  // -- objects --------------------------------------------------------------

  Object? _resolve(Object? value) {
    var current = value;
    for (var depth = 0; current is _Ref && depth < 16; depth++) {
      current = _object(current.number);
    }
    return current is _Ref ? null : current;
  }

  Object? _object(int number) {
    if (_objectCache.containsKey(number)) return _objectCache[number];
    if (!_resolving.add(number)) return null; // cycle
    try {
      final entry = _entries[number];
      Object? value;
      if (entry?.offset != null) {
        value = _parseIndirect(entry!.offset!);
      } else if (entry?.streamNumber != null) {
        final objects = _objectStreams[entry!.streamNumber!] ??=
            _readObjectStream(entry.streamNumber!);
        value = entry.index! < objects.length ? objects[entry.index!] : null;
      }
      return _objectCache[number] = value;
    } finally {
      _resolving.remove(number);
    }
  }

  List<Object?> _readObjectStream(int number) {
    final stream = _object(number);
    if (stream is! _Stream) return const [];
    final data = _decode(stream);
    final count = stream.dict['N'] as int;
    final first = stream.dict['First'] as int;
    final header = _Parser.memory(data);
    final offsets = <int>[];
    for (var i = 0; i < count; i++) {
      header.parse(); // object number
      offsets.add(header.parse() as int);
    }
    return [for (final off in offsets) _Parser.memory(data, first + off).parse()];
  }

  /// Parses "N G obj <object> [stream ... endstream]" at [offset].
  Object? _parseIndirect(int offset) {
    final p = _Parser(bytes, offset);
    p.parse(); // number
    p.parse(); // generation
    final keyword = p.parse();
    if (keyword is! _Keyword || keyword.value != 'obj') {
      throw const _PdfFormatException('Expected obj');
    }
    final value = p.parse();
    if (value is! Map<String, Object?>) return value;
    p.skipWhite();
    if (!p.startsWith('stream')) return value;
    p.pos += 'stream'.length;
    if (p.pos < bytes.length && bytes[p.pos] == 13) p.pos++;
    if (p.pos < bytes.length && bytes[p.pos] == 10) p.pos++;
    final start = p.pos;
    final declared = _resolve(value['Length']);
    var end = declared is int ? start + declared : -1;
    if (end < start || end > bytes.length) {
      end = _indexOf('endstream', start);
      if (end < 0) throw const _PdfFormatException('Unterminated stream');
    }
    return _Stream(value, bytes.range(start, end));
  }

  // -- stream filters -------------------------------------------------------

  Uint8List _decode(_Stream stream) {
    final filter = _resolve(stream.dict['Filter']);
    final filters = switch (filter) {
      null => const <Object?>[],
      List<Object?> list => list,
      _ => [filter],
    };
    final rawParams = _resolve(stream.dict['DecodeParms']);
    var data = stream.raw;
    for (var i = 0; i < filters.length; i++) {
      final name = (filters[i] as _Name).value;
      if (name != 'FlateDecode') throw _PdfFormatException('Unsupported filter $name');
      data = const ZLibDecoder().decodeBytes(data);
      final params = rawParams is List ? rawParams[i] : rawParams;
      if (params is Map<String, Object?>) data = _unpredict(data, params);
    }
    return data;
  }

  static Uint8List _unpredict(Uint8List data, Map<String, Object?> params) {
    final predictor = params['Predictor'] as int? ?? 1;
    if (predictor < 10) {
      if (predictor == 1) return data;
      throw const _PdfFormatException('Unsupported predictor');
    }
    final columns = params['Columns'] as int? ?? 1;
    final colors = params['Colors'] as int? ?? 1;
    final bits = params['BitsPerComponent'] as int? ?? 8;
    final bpp = ((colors * bits) / 8).ceil().clamp(1, 8);
    final rowLength = (columns * colors * bits / 8).ceil();
    final out = BytesBuilder(copy: false);
    var previous = Uint8List(rowLength);
    for (var pos = 0; pos + rowLength < data.length + 1 && pos < data.length; pos += rowLength + 1) {
      final type = data[pos];
      final row = Uint8List(rowLength);
      for (var i = 0; i < rowLength && pos + 1 + i < data.length; i++) {
        final raw = data[pos + 1 + i];
        final left = i >= bpp ? row[i - bpp] : 0;
        final up = previous[i];
        final upLeft = i >= bpp ? previous[i - bpp] : 0;
        row[i] = switch (type) {
          0 => raw,
          1 => raw + left,
          2 => raw + up,
          3 => raw + ((left + up) >> 1),
          4 => raw + _paeth(left, up, upLeft),
          _ => throw const _PdfFormatException('Bad PNG filter'),
        } & 0xFF;
      }
      out.add(row);
      previous = row;
    }
    return out.toBytes();
  }

  static int _paeth(int a, int b, int c) {
    final p = a + b - c;
    final pa = (p - a).abs(), pb = (p - b).abs(), pc = (p - c).abs();
    if (pa <= pb && pa <= pc) return a;
    return pb <= pc ? b : c;
  }

  // -- text -----------------------------------------------------------------

  static String? _text(Object? value) {
    if (value is! _PdfString) return null;
    final text = _decodeText(value.bytes).replaceAll('\u0000', '').trim();
    return text.isEmpty ? null : text;
  }

  static String _decodeText(Uint8List b) {
    if (b.length >= 2 && b[0] == 0xFE && b[1] == 0xFF) {
      final units = <int>[
        for (var i = 2; i + 1 < b.length; i += 2) (b[i] << 8) | b[i + 1],
      ];
      return String.fromCharCodes(units);
    }
    if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) {
      return utf8.decode(b.sublist(3), allowMalformed: true);
    }
    return String.fromCharCodes([for (final c in b) _pdfDocEncoding[c] ?? c]);
  }

  /// PDFDocEncoding differs from Latin-1 in 0x80–0xA0.
  static const _pdfDocEncoding = {
    0x80: 0x2022, 0x81: 0x2020, 0x82: 0x2021, 0x83: 0x2026, 0x84: 0x2014,
    0x85: 0x2013, 0x86: 0x0192, 0x87: 0x2044, 0x88: 0x2039, 0x89: 0x203A,
    0x8A: 0x2212, 0x8B: 0x2030, 0x8C: 0x201E, 0x8D: 0x201C, 0x8E: 0x201D,
    0x8F: 0x2018, 0x90: 0x2019, 0x91: 0x201A, 0x92: 0x2122, 0x93: 0xFB01,
    0x94: 0xFB02, 0x95: 0x0141, 0x96: 0x0152, 0x97: 0x0160, 0x98: 0x0178,
    0x99: 0x017D, 0x9A: 0x0131, 0x9B: 0x0142, 0x9C: 0x0153, 0x9D: 0x0161,
    0x9E: 0x017E, 0xA0: 0x20AC,
  };

  // -- XMP ------------------------------------------------------------------

  String? _xmpPacket() {
    // Preferred: the catalog's Metadata stream (may be compressed).
    try {
      final root = _resolve(_trailer['Root']);
      if (root is Map<String, Object?>) {
        final meta = _resolve(root['Metadata']);
        if (meta is _Stream) return utf8.decode(_decode(meta), allowMalformed: true);
      }
    } catch (_) {
      // Fall through to scanning the raw bytes.
    }
    // Uncompressed XMP is normally near the start; don't scan whole large books.
    const scanLimit = 8 << 20;
    final start = _indexOf('<x:xmpmeta', 0, limit: scanLimit);
    if (start < 0) return null;
    final end = _indexOf('</x:xmpmeta>', start, limit: start + (1 << 20));
    if (end < 0) return null;
    return utf8.decode(bytes.range(start, end + '</x:xmpmeta>'.length),
        allowMalformed: true);
  }

  static String? _xmpField(String xmp, String field) {
    final block =
        RegExp('<dc:$field\\b[^>]*>(.*?)</dc:$field>', dotAll: true).firstMatch(xmp)?[1];
    if (block == null) return null;
    final items = [
      for (final m in RegExp(r'<rdf:li\b[^>]*>(.*?)</rdf:li>', dotAll: true).allMatches(block))
        _xmlText(m[1]!),
    ].where((s) => s.isNotEmpty).toList();
    final text = items.isEmpty ? _xmlText(block) : items.join(', ');
    return text.isEmpty ? null : text;
  }

  static String _xmlText(String raw) => raw
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAllMapped(RegExp(r'&(#x[0-9A-Fa-f]+|#\d+|amp|lt|gt|quot|apos);'), (m) {
        final e = m[1]!;
        if (e.startsWith('#x')) return String.fromCharCode(int.parse(e.substring(2), radix: 16));
        if (e.startsWith('#')) return String.fromCharCode(int.parse(e.substring(1)));
        return const {'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'"}[e]!;
      })
      .trim();
}
