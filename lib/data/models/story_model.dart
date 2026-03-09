import 'dart:convert';
import 'media_model.dart';

// ── Transition style between slides ───────────────────────────
enum StoryTransition {
  fade,       // Cross-fade (default)
  slide,      // Slide left
  zoom,       // Scale in from center
  dissolve,   // Pixel dissolve
}

// ── Music mood (maps to bundled audio tracks) ─────────────────
enum StoryMusic {
  none,
  upbeat,
  calm,
  cinematic,
  nostalgic,
}

// ── Story display theme ────────────────────────────────────────
enum StoryTheme {
  dark,    // Black background + white text (default)
  light,   // White background + dark text
  vivid,   // Coloured gradient extracted from cover photo
}

// ══════════════════════════════════════════════════════════════
// STORY MODEL
// ══════════════════════════════════════════════════════════════

class StoryModel {
  /// UUID  — unique across all stories.
  final String id;

  /// User-assigned name, e.g. "Summer 2024", "Mum's Birthday".
  final String title;

  /// Optional longer description shown on the cover screen.
  final String? description;

  /// Asset ID of the cover photo (must be in [items]).
  final String coverAssetId;

  /// Ordered list of media items in this story.
  /// Order is preserved — user can drag-reorder in editor.
  final List<MediaItem> items;

  /// When this story was created.
  final DateTime createdAt;

  /// Last edit time.
  final DateTime updatedAt;

  /// Slide transition animation.
  final StoryTransition transition;

  /// Background music selection.
  final StoryMusic music;

  /// Visual theme.
  final StoryTheme theme;

  /// Duration each slide is shown (in slideshow mode).
  final Duration slideDuration;

  /// Whether the story has been shared / exported.
  final bool isShared;

  const StoryModel({
    required this.id,
    required this.title,
    this.description,
    required this.coverAssetId,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.transition   = StoryTransition.fade,
    this.music        = StoryMusic.calm,
    this.theme        = StoryTheme.dark,
    this.slideDuration = const Duration(seconds: 5),
    this.isShared     = false,
  });

  // ── Derived getters ─────────────────────────────────────────

  int    get photoCount  => items.length;
  bool   get isEmpty     => items.isEmpty;

  /// Cover item (falls back to first item if coverAssetId not found).
  MediaItem? get coverItem =>
      items.firstWhereOrNull((i) => i.id == coverAssetId) ??
          (items.isNotEmpty ? items.first : null);

  /// Estimated video export duration.
  Duration get totalDuration =>
      Duration(seconds: slideDuration.inSeconds * items.length);

  /// Human-readable "5 photos · 25 sec" label.
  String get summaryLabel {
    final secs = totalDuration.inSeconds;
    return '$photoCount photo${photoCount == 1 ? '' : 's'}  ·  ${secs}s';
  }

  /// Date range string — "Mar 3 – Apr 12, 2024".
  String get dateRangeLabel {
    if (items.isEmpty) return '';
    final sorted = [...items]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final first = sorted.first.createdAt;
    final last  = sorted.last.createdAt;

    String fmt(DateTime d) =>
        '${_mo(d.month)} ${d.day}${first.year != last.year ? ', ${d.year}' : ''}';

    if (first.year == last.year &&
        first.month == last.month &&
        first.day == last.day) {
      return fmt(first);
    }
    return '${fmt(first)} – ${fmt(last)}';
  }

  // ── Immutable update helpers ────────────────────────────────

  StoryModel copyWith({
    String?           title,
    String?           description,
    String?           coverAssetId,
    List<MediaItem>?  items,
    StoryTransition?  transition,
    StoryMusic?       music,
    StoryTheme?       theme,
    Duration?         slideDuration,
    bool?             isShared,
  }) =>
      StoryModel(
        id:            id,
        title:         title         ?? this.title,
        description:   description   ?? this.description,
        coverAssetId:  coverAssetId  ?? this.coverAssetId,
        items:         items         ?? this.items,
        createdAt:     createdAt,
        updatedAt:     DateTime.now(),
        transition:    transition    ?? this.transition,
        music:         music         ?? this.music,
        theme:         theme         ?? this.theme,
        slideDuration: slideDuration ?? this.slideDuration,
        isShared:      isShared      ?? this.isShared,
      );

  // ── JSON ────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id':            id,
    'title':         title,
    'description':   description,
    'coverAssetId':  coverAssetId,
    'assetIds':      items.map((i) => i.id).toList(),
    'createdAt':     createdAt.toIso8601String(),
    'updatedAt':     updatedAt.toIso8601String(),
    'transition':    transition.name,
    'music':         music.name,
    'theme':         theme.name,
    'slideDurationMs': slideDuration.inMilliseconds,
    'isShared':      isShared,
  };

  String toJsonString() => jsonEncode(toJson());

  /// Decode only IDs — re-hydrate MediaItems via MediaRepository.
  static Map<String, dynamic> decodeJson(String raw) =>
      jsonDecode(raw) as Map<String, dynamic>;

  static String _mo(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ][m];
}

// ── Dart List convenience (mirrors Kotlin firstOrNull) ─────────
extension _ListExt<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}