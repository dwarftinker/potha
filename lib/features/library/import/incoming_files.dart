// Files sent to Potha from other apps via Open with / Share to (FR-002).
import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'import_source.dart';

bool _isPdf(SharedMediaFile f) =>
    f.mimeType == 'application/pdf' || f.path.toLowerCase().endsWith('.pdf');

/// Calls [onFiles] with PDFs received at launch and while running (Android, iOS).
/// Returns a function that stops listening.
void Function() listenForIncomingFiles(void Function(List<ImportSource>) onFiles) {
  final intents = ReceiveSharingIntent.instance;

  Future<void> handle(List<SharedMediaFile> shared) async {
    final pdfs = shared.where(_isPdf).toList();
    if (pdfs.isEmpty) return;
    onFiles(await Future.wait(pdfs.map((f) => ImportSource.fromXFile(XFile(f.path)))));
    await intents.reset();
  }

  final sub = intents.getMediaStream().listen(handle, onError: (_) {});
  intents.getInitialMedia().then(handle, onError: (_) {});
  return sub.cancel;
}
