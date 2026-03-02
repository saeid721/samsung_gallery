import 'dart:convert';
import 'media_model.dart';

// ── Story type — affects card visual style ──────────────────
enum StoryType {
  monthly,    // "March 2024" — auto-generated from monthly grouping
  yearly,     // "Best of 2023" — top photos across a full year
  location,   // "Paris Trip" — grouped by GPS location cluster
  person,     // "With Mom" — photos featuring a specific face cluster
  custom,     // User-created story
}

class MemoryStory {
  /// Unique ID — for monthly stories this is "YYYY-MM" (e.g. "2024-03").
  final String id;

  /// Display title, e.g. "2 Years Ago — March 2022", "Paris Trip".
  final String title;

  /// Optional subtitle shown below the title on the card.
  final String? subtitle;

  /// The photo displayed as the story card cover.
  final MediaItem coverItem;

  /// All photos included in this story (max 12 for monthly).
  final List<MediaItem> items;

  /// Date of the earliest photo in the story.
  final DateTime createdAt;

  /// Story category — affects card colour/icon in MemoriesView.
  final StoryType type;

  /// Whether the user has manually dismissed/hidden this story.
  final bool isDismissed;

  const MemoryStory({
    required this.id,
    required this.title,
    this.subtitle,
    required this.coverItem,
    required this.items,
    required this.createdAt,
    this.type = StoryType.monthly,
    this.isDismissed = false,
  });

  /// Number of photos in this story.
  int get photoCount => items.length;

  /// Duration range string shown on the card, e.g. "Mar 3 – Mar 12".
  String get dateRangeLabel {
    if (items.isEmpty) return '';
    final sorted = [...items]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final first = sorted.first.createdAt;
    final last = sorted.last.createdAt;

    if (first.year == last.year && first.month == last.month) {
      // Same month: "Mar 3 – 12"
      return '${_monthAbbr(first.month)} ${first.day} – ${last.day}';
    }
    // Different months: "Mar 3 – Apr 12"
    return '${_monthAbbr(first.month)} ${first.day} – '
        '${_monthAbbr(last.month)} ${last.day}';
  }

  /// How long ago this story is, for the card badge.
  /// e.g. "Today", "3 days ago", "2 years ago"
  String get timeAgoLabel {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    final years = (diff.inDays / 365).floor();
    return '$years ${years == 1 ? 'year' : 'years'} ago';
  }

  // ── Immutable update helpers ────────────────────────────────

  MemoryStory copyWith({
    String? title,
    String? subtitle,
    MediaItem? coverItem,
    List<MediaItem>? items,
    bool? isDismissed,
  }) =>
      MemoryStory(
        id: id,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        coverItem: coverItem ?? this.coverItem,
        items: items ?? this.items,
        createdAt: createdAt,
        type: type,
        isDismissed: isDismissed ?? this.isDismissed,
      );

  MemoryStory dismiss() => copyWith(isDismissed: true);

  // ── JSON serialization ───────────────────────────────────────
  // Note: items list stores only asset IDs to keep storage lean.
  // Full MediaItem objects are re-hydrated at display time.

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'coverAssetId': coverItem.id,
    'assetIds': items.map((i) => i.id).toList(),
    'createdAt': createdAt.toIso8601String(),
    'type': type.name,
    'isDismissed': isDismissed,
  };

  /// Lightweight JSON — only IDs, no MediaItem objects.
  /// Re-hydrate with MediaRepository.getItemsByIds() before display.
  String toJsonString() => jsonEncode(toJson());

  static Map<String, dynamic> decodeJson(String raw) =>
      jsonDecode(raw) as Map<String, dynamic>;

  // ── Private helpers ─────────────────────────────────────────

  static String _monthAbbr(int month) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ][month];
}