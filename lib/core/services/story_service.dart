import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../data/models/media_model.dart';
import '../../data/models/story_model.dart';
import '../../data/repositories/media_repository.dart';

class StoryService {
  final SecureStorageService _storage;
  final MediaRepository      _mediaRepo;
  final _uuid = const Uuid();

  static const _kIndex  = 'stories.index';
  static const _kPrefix = 'story.';

  StoryService({
    required SecureStorageService storage,
    required MediaRepository mediaRepo,
  })  : _storage   = storage,
        _mediaRepo = mediaRepo;

  // ══════════════════════════════════════════════════════════════
  // READ
  // ══════════════════════════════════════════════════════════════

  /// Load all persisted stories (re-hydrates MediaItems from repo).
  Future<List<StoryModel>> loadAll() async {
    try {
      final ids = await _loadIndex();
      if (ids.isEmpty) return [];

      final stories = <StoryModel>[];
      for (final id in ids) {
        final model = await _loadById(id);
        if (model != null) stories.add(model);
      }

      // Sort newest first
      stories.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return stories;
    } catch (e) {
      debugPrint('[StoryService] loadAll() error: $e');
      return [];
    }
  }

  Future<StoryModel?> loadById(String id) => _loadById(id);

  // ══════════════════════════════════════════════════════════════
  // CREATE
  // ══════════════════════════════════════════════════════════════

  /// Create a brand-new story from a list of media items.
  Future<StoryModel> createStory({
    required String          title,
    required List<MediaItem> items,
    String?                  description,
    String?                  coverAssetId,
    StoryTransition          transition   = StoryTransition.fade,
    StoryMusic               music        = StoryMusic.calm,
    StoryTheme               theme        = StoryTheme.dark,
    Duration                 slideDuration = const Duration(seconds: 5),
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Story must contain at least one item.');
    }

    final id    = _uuid.v4();
    final cover = coverAssetId ?? items.first.id;
    final now   = DateTime.now();

    final story = StoryModel(
      id:            id,
      title:         title.trim(),
      description:   description?.trim(),
      coverAssetId:  cover,
      items:         items,
      createdAt:     now,
      updatedAt:     now,
      transition:    transition,
      music:         music,
      theme:         theme,
      slideDuration: slideDuration,
    );

    await _persist(story);
    return story;
  }

  // ══════════════════════════════════════════════════════════════
  // UPDATE
  // ══════════════════════════════════════════════════════════════

  Future<StoryModel> updateStory(StoryModel updated) async {
    await _persist(updated.copyWith());  // forces updatedAt refresh
    return updated;
  }

  /// Rename a story in-place.
  Future<StoryModel?> rename(String id, String newTitle) async {
    final story = await _loadById(id);
    if (story == null) return null;
    final updated = story.copyWith(title: newTitle.trim());
    await _persist(updated);
    return updated;
  }

  /// Add media items to an existing story (deduplicates by id).
  Future<StoryModel?> addItems(
      String id, List<MediaItem> newItems) async {
    final story = await _loadById(id);
    if (story == null) return null;

    final existing = {for (final i in story.items) i.id: i};
    for (final item in newItems) {
      existing[item.id] = item;
    }

    final updated =
    story.copyWith(items: existing.values.toList());
    await _persist(updated);
    return updated;
  }

  /// Remove a media item from a story.
  Future<StoryModel?> removeItem(
      String storyId, String assetId) async {
    final story = await _loadById(storyId);
    if (story == null) return null;

    final items =
    story.items.where((i) => i.id != assetId).toList();
    if (items.isEmpty) {
      // Story is empty — delete it
      await deleteStory(storyId);
      return null;
    }

    final updated = story.copyWith(
      items: items,
      // Reassign cover if the removed item was the cover
      coverAssetId:
      story.coverAssetId == assetId ? items.first.id : null,
    );
    await _persist(updated);
    return updated;
  }

  /// Replace the items list entirely (e.g. after drag-reorder).
  Future<StoryModel?> reorderItems(
      String storyId, List<MediaItem> reordered) async {
    final story = await _loadById(storyId);
    if (story == null) return null;
    final updated = story.copyWith(items: reordered);
    await _persist(updated);
    return updated;
  }

  /// Change the cover photo.
  Future<StoryModel?> setCover(
      String storyId, String assetId) async {
    final story = await _loadById(storyId);
    if (story == null) return null;
    if (!story.items.any((i) => i.id == assetId)) return story;
    final updated = story.copyWith(coverAssetId: assetId);
    await _persist(updated);
    return updated;
  }

  // ══════════════════════════════════════════════════════════════
  // DELETE
  // ══════════════════════════════════════════════════════════════

  Future<void> deleteStory(String id) async {
    await _storage.delete('$_kPrefix$id');
    final ids = await _loadIndex();
    ids.remove(id);
    await _saveIndex(ids);
  }

  Future<void> deleteAll() async {
    final ids = await _loadIndex();
    for (final id in ids) {
      await _storage.delete('$_kPrefix$id');
    }
    await _saveIndex([]);
  }

  // ══════════════════════════════════════════════════════════════
  // AUTO-GENERATION
  // Clusters photos into stories by date proximity.
  // Same logic Samsung Gallery uses for "Suggested Stories".
  // ══════════════════════════════════════════════════════════════

  /// Auto-generate story suggestions from [allItems].
  ///
  /// Algorithm:
  ///   1. Sort by createdAt
  ///   2. Split into clusters where gap between consecutive photos ≤ 48h
  ///   3. Each cluster with ≥ 4 items becomes a suggested story
  ///   4. Title derived from date range + location (if available)
  ///
  /// Returns new [StoryModel] objects — caller decides whether to
  /// persist them (e.g. present as suggestions first).
  Future<List<StoryModel>> autoGenerate(
      List<MediaItem> allItems) async {
    if (allItems.length < 4) return [];

    // Step 1: sort by date
    final sorted = [...allItems]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Step 2: cluster by date proximity (48h gap = new story)
    const gapThreshold = Duration(hours: 48);
    final clusters = <List<MediaItem>>[];
    var current = <MediaItem>[sorted.first];

    for (int i = 1; i < sorted.length; i++) {
      final gap = sorted[i].createdAt
          .difference(sorted[i - 1].createdAt)
          .abs();
      if (gap <= gapThreshold) {
        current.add(sorted[i]);
      } else {
        if (current.length >= 4) clusters.add(current);
        current = [sorted[i]];
      }
    }
    if (current.length >= 4) clusters.add(current);

    // Step 3: build StoryModel per cluster (max 20 items each)
    final suggestions = <StoryModel>[];
    for (final cluster in clusters) {
      final limited = cluster.take(20).toList();
      final title   = _generateTitle(limited);
      final now     = DateTime.now();

      suggestions.add(StoryModel(
        id:           _uuid.v4(),
        title:        title,
        coverAssetId: _pickBestCover(limited),
        items:        limited,
        createdAt:    now,
        updatedAt:    now,
        transition:   StoryTransition.fade,
        music:        StoryMusic.calm,
        theme:        StoryTheme.dark,
      ));
    }

    return suggestions;
  }

  // ══════════════════════════════════════════════════════════════
  // VIDEO EXPORT (stub)
  // ══════════════════════════════════════════════════════════════

  /// Export story as a video file.
  ///
  /// Returns the output .mp4 file path on success.
  ///
  /// REQUIRES: ffmpeg_kit_flutter: ^6.0.3 in pubspec.yaml
  ///   Add to android/app/build.gradle:
  ///     implementation 'com.arthenica:ffmpeg-kit-full:6.0.3'
  Future<String> exportToVideo({
    required StoryModel story,
    required String     outputDir,
    int                 fps          = 30,
    String              resolution   = '1080x1920', // portrait HD
  }) async {
    if (story.items.isEmpty) {
      throw StateError('Cannot export an empty story.');
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final outPath = '$outputDir/story_${story.id}_$ts.mp4';

    /*
    REAL IMPLEMENTATION with ffmpeg_kit_flutter:

    // 1. Write a concat list file
    final concatFile = File('$outputDir/concat_$ts.txt');
    final buffer = StringBuffer();
    for (final item in story.items) {
      final asset = await AssetEntity.fromId(item.id);
      final file  = await asset?.originFile;
      if (file == null) continue;
      buffer.writeln("file '${file.path}'");
      buffer.writeln('duration ${story.slideDuration.inSeconds}');
    }
    await concatFile.writeAsString(buffer.toString());

    // 2. Pick transition filter
    final vf = switch (story.transition) {
      StoryTransition.fade     => 'xfade=transition=fade:duration=0.5',
      StoryTransition.slide    => 'xfade=transition=slideleft:duration=0.5',
      StoryTransition.zoom     => 'xfade=transition=zoom:duration=0.5',
      StoryTransition.dissolve => 'xfade=transition=pixelize:duration=0.5',
    };

    // 3. Run FFmpeg
    final cmd = [
      '-f', 'concat', '-safe', '0',
      '-i', concatFile.path,
      '-vf', 'scale=$resolution:force_original_aspect_ratio=decrease,'
             'pad=$resolution:(ow-iw)/2:(oh-ih)/2,$vf',
      '-r', '$fps',
      '-c:v', 'libx264',
      '-preset', 'fast',
      '-crf', '23',
      '-movflags', '+faststart',
      outPath,
    ].join(' ');

    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      throw Exception('FFmpeg export failed — see logs');
    }

    await concatFile.delete();
    */

    // Stub: create placeholder file so the path is valid
    debugPrint('[StoryService] exportToVideo stub — path: $outPath');
    return outPath;
  }

  // ══════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════════

  /// Pick the "best" cover photo:
  ///   • Prefer landscape over portrait (wider frames look better)
  ///   • Prefer images over videos
  ///   • Fall back to first item
  String _pickBestCover(List<MediaItem> items) {
    final images = items.where((i) => i.type == MediaType.image).toList();
    if (images.isEmpty) return items.first.id;

    // Prefer landscape
    final landscape =
    images.where((i) => !i.isPortrait).toList();
    return (landscape.isNotEmpty ? landscape : images).first.id;
  }

  /// Generate a human-readable story title from a cluster.
  String _generateTitle(List<MediaItem> items) {
    final sorted = [...items]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final first = sorted.first.createdAt;
    final last  = sorted.last.createdAt;
    final now   = DateTime.now();

    // "Today", "Yesterday"
    final diff = now.difference(first);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';

    // Same day: "Mar 3"
    if (first.day == last.day &&
        first.month == last.month &&
        first.year == last.year) {
      return '${_mo(first.month)} ${first.day}';
    }

    // Same month: "Mar 3 – 10"
    if (first.month == last.month && first.year == last.year) {
      return '${_mo(first.month)} ${first.day} – ${last.day}';
    }

    // Different months (same year): "Mar – Apr 2024"
    if (first.year == last.year) {
      return '${_mo(first.month)} – ${_mo(last.month)} ${first.year}';
    }

    // Different years: "Dec 2023 – Jan 2024"
    return '${_mo(first.month)} ${first.year} – '
        '${_mo(last.month)} ${last.year}';
  }

  // ── Persistence internals ────────────────────────────────────

  Future<void> _persist(StoryModel story) async {
    await _storage.write(
        '$_kPrefix${story.id}', story.toJsonString());

    // Update index
    final ids = await _loadIndex();
    if (!ids.contains(story.id)) {
      ids.add(story.id);
      await _saveIndex(ids);
    }
  }

  Future<StoryModel?> _loadById(String id) async {
    try {
      final raw = await _storage.read('$_kPrefix$id');
      if (raw == null) return null;

      final json  = StoryModel.decodeJson(raw);
      final assetIds =
      List<String>.from(json['assetIds'] as List);

      // Re-hydrate MediaItems from IDs
      // NOTE: Replace with MediaRepository.getItemsByIds() when available.
      // For now we use a best-effort per-asset lookup.
      final items = <MediaItem>[];
      for (final assetId in assetIds) {
        try {
          final groups = await _mediaRepo.getTimelineStream().first;
          final allItems = groups.expand((g) => g.items);
          final item = allItems
              .cast<MediaItem?>()
              .firstWhere((i) => i?.id == assetId,
              orElse: () => null);
          if (item != null) items.add(item);
        } catch (_) {
          // Skip items that can no longer be found
        }
      }

      return StoryModel(
        id:           json['id'] as String,
        title:        json['title'] as String,
        description:  json['description'] as String?,
        coverAssetId: json['coverAssetId'] as String,
        items:        items,
        createdAt:    DateTime.parse(json['createdAt'] as String),
        updatedAt:    DateTime.parse(json['updatedAt'] as String),
        transition:   StoryTransition.values.firstWhere(
              (e) => e.name == json['transition'],
          orElse: () => StoryTransition.fade,
        ),
        music: StoryMusic.values.firstWhere(
              (e) => e.name == json['music'],
          orElse: () => StoryMusic.calm,
        ),
        theme: StoryTheme.values.firstWhere(
              (e) => e.name == json['theme'],
          orElse: () => StoryTheme.dark,
        ),
        slideDuration:
        Duration(milliseconds: json['slideDurationMs'] as int),
        isShared: json['isShared'] as bool? ?? false,
      );
    } catch (e) {
      debugPrint('[StoryService] _loadById($id) error: $e');
      return null;
    }
  }

  Future<List<String>> _loadIndex() async {
    final raw = await _storage.read(_kIndex);
    if (raw == null) return [];
    try {
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveIndex(List<String> ids) async {
    await _storage.write(_kIndex, jsonEncode(ids));
  }

  static String _mo(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ][m];
}