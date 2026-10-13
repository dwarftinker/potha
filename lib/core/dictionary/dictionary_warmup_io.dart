import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dictionary_store.dart';

/// Android and iOS: unpack after the first frame, so startup isn't delayed.
void startDictionaryUnpack(ProviderContainer container) => WidgetsBinding.instance
    .addPostFrameCallback((_) => container.read(dictionaryStoreProvider).ensureStarted());
