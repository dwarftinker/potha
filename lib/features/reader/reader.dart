// The reader (feature 002). Loaded as a deferred library on the web, so the library
// screen and the first page load stay small (002 research R13, 001 research R10).
import 'package:flutter/widgets.dart';

import 'ui/reader_screen.dart';

export 'ui/reader_screen.dart' show documentViewFactoriesProvider;

Widget buildReader(String bookId) => ReaderScreen(bookId: bookId);
