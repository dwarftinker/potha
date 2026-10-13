// Opens web links from a book in the browser, after the reader confirms (002 FR-025).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

abstract interface class LinkOpener {
  /// Opens [uri] outside the app; false if nothing could open it.
  Future<bool> open(Uri uri);
}

class UrlLauncherLinkOpener implements LinkOpener {
  const UrlLauncherLinkOpener();

  @override
  Future<bool> open(Uri uri) async {
    try {
      // The browser on phones, a new tab on the web.
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

final linkOpenerProvider = Provider<LinkOpener>((ref) => const UrlLauncherLinkOpener());
