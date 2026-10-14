{{flutter_js}}
{{flutter_build_config}}

// No serviceWorkerSettings: Flutter's service worker is deprecated (its build output only
// unregisters itself). Potha registers its own, web/potha_sw.js.
_flutter.loader.load();

// Registered after the first frame, so caching the app doesn't compete with starting it.
// CanvasKit loaded before the worker existed; the worker is told which variant, to keep it.
if ('serviceWorker' in navigator) {
  window.addEventListener(
    'flutter-first-frame',
    async () => {
      try {
        await navigator.serviceWorker.register('potha_sw.js');
        const registration = await navigator.serviceWorker.ready;
        const canvasKit = new URL('canvaskit/', document.baseURI).href;
        const urls = performance
          .getEntriesByType('resource')
          .map((entry) => entry.name)
          .filter((name) => name.startsWith(canvasKit));
        registration.active?.postMessage({ type: 'cache-loaded', urls });
      } catch (e) {
        // Unfilled under `flutter run`, or no secure context: the app works, online only.
        console.info('Potha: no offline cache:', e);
      }
    },
    { once: true },
  );
}
