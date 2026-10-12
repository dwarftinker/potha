// Fills an in-memory database with [count] books with small covers, for performance
// tests (SC-003, SC-004).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/features/library/domain/text_fold.dart';

Future<Uint8List> _coverPng(int i) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 360, 540),
    Paint()..color = Colors.primaries[i % Colors.primaries.length],
  );
  final image = await recorder.endRecording().toImage(360, 540);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<AppDatabase> seededDatabase(int count) async {
  final db = AppDatabase(NativeDatabase.memory());
  final covers = [for (var i = 0; i < 12; i++) await _coverPng(i)];
  await db.batch((b) {
    for (var i = 0; i < count; i++) {
      final title = 'Book $i';
      final author = 'Author ${i % 37}';
      b.insert(
        db.books,
        BooksCompanion.insert(
          id: 'book-$i',
          format: 'pdf',
          title: title,
          author: Value(author),
          sortTitle: sortTitle(title),
          searchKey: searchKey(title, author),
          originalFileName: 'book-$i.pdf',
          contentHash: 'hash-$i',
          sizeBytes: 1000,
          pageCount: 300,
          isPasswordProtected: false,
          addedAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
        ),
      );
      b.insert(
        db.bookCovers,
        BookCoversCompanion.insert(bookId: 'book-$i', image: covers[i % 12]),
      );
    }
  });
  return db;
}
