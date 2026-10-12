// Reading themes (FR-027, FR-028, research R5).
//
// Pages are recoloured with a colour matrix. Sepia maps each channel linearly from
// ink (black) to paper (white), so colours keep their hue with a warm tint. Dark inverts
// lightness and rotates hue by 180°, which together keep each colour's hue while dark
// and light swap, then maps the result between the dark background and light text.
import 'package:flutter/painting.dart';

import '../../../core/db/app_database.dart';

class ReaderTheme {
  const ReaderTheme._({
    required this.name,
    required this.pageMatrix,
    required this.background,
    required this.barBackground,
    required this.barForeground,
    required this.highlight,
    required this.activeHighlight,
  });

  final ReadingTheme name;

  /// 3×3 colour transform plus offset (0–1): out = m · in + offset. Null for light.
  final ({List<double> m, List<double> offset})? pageMatrix;

  /// Around the pages.
  final Color background;
  final Color barBackground;
  final Color barForeground;

  /// Search highlights as they should look on screen.
  final Color highlight;
  final Color activeHighlight;

  static ReaderTheme of(ReadingTheme theme) => switch (theme) {
    ReadingTheme.light => _light,
    ReadingTheme.sepia => _sepia,
    ReadingTheme.dark => _dark,
  };

  static const _light = ReaderTheme._(
    name: ReadingTheme.light,
    pageMatrix: null,
    background: Color(0xFFE0E0E0),
    barBackground: Color(0xFFF5F5F5),
    barForeground: Color(0xFF212121),
    highlight: Color(0x66FFD54F),
    activeHighlight: Color(0x80FF9800),
  );

  static final _sepia = ReaderTheme._(
    name: ReadingTheme.sepia,
    pageMatrix: _channelRamp(const Color(0xFF5B4636), const Color(0xFFF4ECD8)),
    background: const Color(0xFFD9CDB4),
    barBackground: const Color(0xFFEADFC8),
    barForeground: const Color(0xFF3E2F22),
    highlight: const Color(0x66E6BE64),
    activeHighlight: const Color(0x80D78C3C),
  );

  static final _dark = ReaderTheme._(
    name: ReadingTheme.dark,
    pageMatrix: _invertKeepHue(const Color(0xFF1E1E1E), const Color(0xFFE0E0E0)),
    background: const Color(0xFF121212),
    barBackground: const Color(0xFF2A2A2A),
    barForeground: const Color(0xFFE0E0E0),
    highlight: const Color(0x808C6E14),
    activeHighlight: const Color(0x99A0641E),
  );

  /// out_c = ink_c + (paper_c − ink_c) · in_c, per channel.
  static ({List<double> m, List<double> offset}) _channelRamp(Color ink, Color paper) => (
    m: [paper.r - ink.r, 0, 0, 0, paper.g - ink.g, 0, 0, 0, paper.b - ink.b],
    offset: [ink.r, ink.g, ink.b],
  );

  /// CSS hue-rotate(180deg).
  static const _hue180 = [-0.574, 1.43, 0.144, 0.426, 0.43, 0.144, 0.426, 1.43, -0.856];

  /// out = text − (text − background) · H180 · in: white → background, black → text.
  static ({List<double> m, List<double> offset}) _invertKeepHue(Color background, Color text) {
    final k = text.r - background.r;
    return (m: [for (final v in _hue180) -k * v], offset: [text.r, text.g, text.b]);
  }

  /// The page recolouring for [ColorFiltered], or null for light.
  ColorFilter? get pageFilter {
    final p = pageMatrix;
    if (p == null) return null;
    final m = p.m, o = p.offset;
    return ColorFilter.matrix([
      m[0], m[1], m[2], 0, o[0] * 255, //
      m[3], m[4], m[5], 0, o[1] * 255,
      m[6], m[7], m[8], 0, o[2] * 255,
      0, 0, 0, 1, 0,
    ]);
  }

  /// [c] as it looks after the page filter (opaque colours).
  Color apply(Color c) {
    final p = pageMatrix;
    if (p == null) return c;
    final v = _mul(p.m, [c.r, c.g, c.b]);
    return Color.from(
      alpha: c.a,
      red: (v[0] + p.offset[0]).clamp(0.0, 1.0),
      green: (v[1] + p.offset[1]).clamp(0.0, 1.0),
      blue: (v[2] + p.offset[2]).clamp(0.0, 1.0),
    );
  }

  /// Highlights are painted inside the page filter, so they are painted in the colour
  /// the filter turns into [highlight] (research R5).
  Color get highlightPaintColor => _beforeFilter(highlight);
  Color get activeHighlightPaintColor => _beforeFilter(activeHighlight);

  Color _beforeFilter(Color intended) {
    final p = pageMatrix;
    if (p == null) return intended;
    final v = _mul(_inverse(p.m), [
      intended.r - p.offset[0],
      intended.g - p.offset[1],
      intended.b - p.offset[2],
    ]);
    return Color.from(
      alpha: intended.a,
      red: v[0].clamp(0.0, 1.0),
      green: v[1].clamp(0.0, 1.0),
      blue: v[2].clamp(0.0, 1.0),
    );
  }

  static List<double> _mul(List<double> m, List<double> v) => [
    m[0] * v[0] + m[1] * v[1] + m[2] * v[2],
    m[3] * v[0] + m[4] * v[1] + m[5] * v[2],
    m[6] * v[0] + m[7] * v[1] + m[8] * v[2],
  ];

  static List<double> _inverse(List<double> m) {
    final a = m[0], b = m[1], c = m[2], d = m[3], e = m[4], f = m[5], g = m[6], h = m[7];
    final i = m[8];
    final det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
    return [
      (e * i - f * h) / det, (c * h - b * i) / det, (b * f - c * e) / det, //
      (f * g - d * i) / det, (a * i - c * g) / det, (c * d - a * f) / det,
      (d * h - e * g) / det, (b * g - a * h) / det, (a * e - b * d) / det,
    ];
  }
}
