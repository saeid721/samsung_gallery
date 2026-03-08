
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/secure_storage_service.dart';
import '../../../data/models/media_model.dart';
import '../../../data/repositories/media_repository.dart';

// ── Suggestion card model ─────────────────────────────────────
enum SuggestionType {
  onThisDay,
  bestShot,
  lowStorage,
  shareReminder,
  enhancePhoto,
  backupNudge,
}

class SuggestionCard {
  final String          id;
  final SuggestionType  type;
  final String          title;
  final String          subtitle;
  final List<MediaItem> previewItems;  // up to 4 thumbnails
  final String          actionLabel;
  final bool            isDismissed;

  const SuggestionCard({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.previewItems,
    required this.actionLabel,
    this.isDismissed = false,
  });

  SuggestionCard copyWith({bool? isDismissed}) => SuggestionCard(
    id:           id,
    type:         type,
    title:        title,
    subtitle:     subtitle,
    previewItems: previewItems,
    actionLabel:  actionLabel,
    isDismissed:  isDismissed ?? this.isDismissed,
  );

  IconData get icon => switch (type) {
    SuggestionType.onThisDay     => Icons.history_rounded,
    SuggestionType.bestShot      => Icons.auto_awesome_rounded,
    SuggestionType.lowStorage    => Icons.storage_rounded,
    SuggestionType.shareReminder => Icons.share_rounded,
    SuggestionType.enhancePhoto  => Icons.hdr_on_rounded,
    SuggestionType.backupNudge   => Icons.cloud_upload_outlined,
  };

  Color get accentColor => switch (type) {
    SuggestionType.onThisDay     => const Color(0xFF5E5CE6),
    SuggestionType.bestShot      => const Color(0xFFFF9F0A),
    SuggestionType.lowStorage    => const Color(0xFFFF3B30),
    SuggestionType.shareReminder => const Color(0xFF30D158),
    SuggestionType.enhancePhoto  => const Color(0xFF0A84FF),
    SuggestionType.backupNudge   => const Color(0xFF64D2FF),
  };
}

class SuggestionsController extends GetxController {
  final MediaRepository      _repo    = Get.find<MediaRepository>();
  final SecureStorageService _storage = Get.find<SecureStorageService>();

  static const _kDismissed = 'suggestions.dismissed';

  // ── State ─────────────────────────────────────────────────────
  final RxList<SuggestionCard> cards     = <SuggestionCard>[].obs;
  final RxBool                 isLoading = true.obs;

  // ── On This Day carousel state ────────────────────────────────
  final RxList<MediaItem> onThisDayItems = <MediaItem>[].obs;
  final RxInt             onThisDayYear  = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _buildSuggestions();
  }

  // ── Build all suggestion cards ────────────────────────────────
  Future<void> _buildSuggestions() async {
    isLoading.value = true;
    try {
      final dismissed = await _loadDismissed();
      final timeline  = await _repo.getTimelineStream().first;
      final allItems  = timeline.expand((g) => g.items).toList();

      if (allItems.isEmpty) {
        isLoading.value = false;
        return;
      }

      final results = <SuggestionCard>[];

      // 1. On This Day
      final otd = _buildOnThisDay(allItems);
      if (otd != null) results.add(otd);

      // 2. Best Shot (detect burst: same minute, pick highest-res)
      final best = _buildBestShot(allItems);
      if (best != null) results.add(best);

      // 3. Low Storage (items > 10 MB)
      final storage = _buildLowStorage(allItems);
      if (storage != null) results.add(storage);

      // 4. Share Reminder (photos from last 7 days, no album)
      final share = _buildShareReminder(allItems);
      if (share != null) results.add(share);

      // 5. Enhance Photo (small resolution images)
      final enhance = _buildEnhance(allItems);
      if (enhance != null) results.add(enhance);

      // 6. Backup Nudge
      results.add(_buildBackupNudge(allItems));

      // Filter dismissed
      final visible = results
          .where((c) => !dismissed.contains(c.id))
          .toList();

      cards.assignAll(visible);

      // Store on-this-day items for the special carousel
      if (otd != null) {
        onThisDayItems.assignAll(otd.previewItems);
        onThisDayYear.value = otd.previewItems.isNotEmpty
            ? DateTime.now().year -
            otd.previewItems.first.createdAt.year
            : 0;
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() => _buildSuggestions();

  // ── Dismiss a card ────────────────────────────────────────────
  Future<void> dismiss(String cardId) async {
    cards.removeWhere((c) => c.id == cardId);
    final dismissed = await _loadDismissed();
    dismissed.add(cardId);
    await _storage.write(_kDismissed, jsonEncode(dismissed.toList()));
  }

  // ── Execute suggestion action ─────────────────────────────────
  void executeAction(SuggestionCard card) {
    switch (card.type) {
      case SuggestionType.onThisDay:
        Get.toNamed('/memories');
        break;
      case SuggestionType.bestShot:
      // Open viewer on the best-scored item
        if (card.previewItems.isNotEmpty) {
          Get.toNamed('/viewer',
              arguments: {'mediaItem': card.previewItems.first});
        }
        break;
      case SuggestionType.lowStorage:
        Get.toNamed('/duplicates');
        break;
      case SuggestionType.shareReminder:
      // Share all items in the card
        break;
      case SuggestionType.enhancePhoto:
        if (card.previewItems.isNotEmpty) {
          Get.toNamed('/editor',
              arguments: {'mediaItem': card.previewItems.first});
        }
        break;
      case SuggestionType.backupNudge:
        Get.toNamed('/sync');
        break;
    }
  }

  // ── Card builders ─────────────────────────────────────────────

  SuggestionCard? _buildOnThisDay(List<MediaItem> all) {
    final now   = DateTime.now();
    final month = now.month;
    final day   = now.day;
    final year  = now.year;

    final matches = all
        .where((i) =>
    i.createdAt.month == month &&
        i.createdAt.day   == day   &&
        i.createdAt.year  <  year)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (matches.isEmpty) return null;

    final yearsAgo = year - matches.first.createdAt.year;
    return SuggestionCard(
      id:           'on_this_day_${now.month}_${now.day}',
      type:         SuggestionType.onThisDay,
      title:        'On This Day',
      subtitle:     '$yearsAgo ${yearsAgo == 1 ? 'year' : 'years'} ago'
          ' — ${matches.length} photos',
      previewItems: matches.take(8).toList(),
      actionLabel:  'View Memories',
    );
  }

  SuggestionCard? _buildBestShot(List<MediaItem> all) {
    // Group photos taken within 60 seconds of each other
    final sorted = [...all]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    List<MediaItem> burstGroup = [];
    List<MediaItem> bestBurst  = [];

    for (int i = 0; i < sorted.length - 1; i++) {
      final diff = sorted[i + 1].createdAt
          .difference(sorted[i].createdAt)
          .inSeconds
          .abs();
      if (diff <= 60) {
        burstGroup.add(sorted[i]);
      } else {
        if (burstGroup.length > 3 &&
            burstGroup.length > bestBurst.length) {
          bestBurst = List.from(burstGroup);
        }
        burstGroup = [];
      }
    }

    if (bestBurst.isEmpty) return null;

    // Score: pick the highest resolution one
    bestBurst.sort(
            (a, b) => (b.width * b.height).compareTo(a.width * a.height));

    return SuggestionCard(
      id:           'best_shot_${bestBurst.first.id}',
      type:         SuggestionType.bestShot,
      title:        'Best Shot Suggestion',
      subtitle:     'We found a burst of ${bestBurst.length} similar photos',
      previewItems: bestBurst.take(4).toList(),
      actionLabel:  'Pick Best',
    );
  }

  SuggestionCard? _buildLowStorage(List<MediaItem> all) {
    final large = all
        .where((i) => i.size > 10 * 1024 * 1024) // > 10 MB
        .toList()
      ..sort((a, b) => b.size.compareTo(a.size));

    if (large.length < 3) return null;

    final totalMb =
        large.fold(0, (s, i) => s + i.size) ~/ (1024 * 1024);

    return SuggestionCard(
      id:           'low_storage',
      type:         SuggestionType.lowStorage,
      title:        'Free Up Space',
      subtitle:     '${large.length} large files taking up ${totalMb} MB',
      previewItems: large.take(4).toList(),
      actionLabel:  'Review & Delete',
    );
  }

  SuggestionCard? _buildShareReminder(List<MediaItem> all) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent = all
        .where((i) =>
    i.createdAt.isAfter(cutoff) && !i.isVideo)
        .toList();

    if (recent.length < 5) return null;

    return SuggestionCard(
      id:           'share_reminder_${DateTime.now().day}',
      type:         SuggestionType.shareReminder,
      title:        'Share Recent Photos',
      subtitle:     '${recent.length} new photos this week',
      previewItems: recent.take(4).toList(),
      actionLabel:  'Share',
    );
  }

  SuggestionCard? _buildEnhance(List<MediaItem> all) {
    final lowRes = all
        .where((i) =>
    !i.isVideo && i.width < 1000 && i.height < 1000)
        .toList();

    if (lowRes.isEmpty) return null;

    return SuggestionCard(
      id:           'enhance_photos',
      type:         SuggestionType.enhancePhoto,
      title:        'Enhance Photo Quality',
      subtitle:     '${lowRes.length} photos can be upscaled with AI',
      previewItems: lowRes.take(4).toList(),
      actionLabel:  'Enhance',
    );
  }

  SuggestionCard _buildBackupNudge(List<MediaItem> all) {
    final unbackedCount = (all.length * 0.3).round(); // stub
    return SuggestionCard(
      id:           'backup_nudge',
      type:         SuggestionType.backupNudge,
      title:        'Back Up Your Photos',
      subtitle:     '$unbackedCount photos not yet backed up',
      previewItems: all.take(4).toList(),
      actionLabel:  'Back Up Now',
    );
  }

  // ── Persistence ───────────────────────────────────────────────
  Future<Set<String>> _loadDismissed() async {
    final raw = await _storage.read(_kDismissed);
    if (raw == null) return {};
    try { return Set<String>.from(jsonDecode(raw) as List); }
    catch (_) { return {}; }
  }
}