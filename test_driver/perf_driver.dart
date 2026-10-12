// Summarises the timelines recorded by integration_test/scroll_perf_test.dart and fails
// if more than 1% of frames take longer than 16 ms to build or rasterise (SC-003).
import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
      responseDataCallback: (data) async {
        if (data == null) return;
        for (final key in ['grid_scroll', 'list_scroll']) {
          final timeline = driver.Timeline.fromJson(data[key] as Map<String, dynamic>);
          final summary = driver.TimelineSummary.summarize(timeline);
          await summary.writeTimelineToFile(key, pretty: true, includeSummary: true);
          final json = summary.summaryJson;
          final frames = (json['frame_count'] as num).toInt();
          final slowBuild = (json['missed_frame_build_budget_count'] as num).toInt();
          final slowRaster = (json['missed_frame_rasterizer_budget_count'] as num).toInt();
          final slow = slowBuild > slowRaster ? slowBuild : slowRaster;
          final ratio = frames == 0 ? 0 : slow / frames;
          // ignore: avoid_print
          print('$key: $slow of $frames frames over budget (${(ratio * 100).toStringAsFixed(2)}%)');
          if (ratio > 0.01) throw StateError('$key: more than 1% of frames over 16 ms');
        }
      },
    );
