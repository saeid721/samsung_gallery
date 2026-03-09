import 'package:flutter/foundation.dart';
import 'media_model.dart';

/// Represents an item in the trash with metadata about when it was deleted
class TrashedItem {
  /// The media item that was trashed
  final MediaItem item;

  /// When this item was moved to trash
  final DateTime deletedAt;

  /// How long until this item is permanently deleted (30 days from deletion)
  static const Duration retentionPeriod = Duration(days: 30);

  TrashedItem({
    required this.item,
    required this.deletedAt,
  });

  /// When this item will be permanently deleted
  DateTime get expiresAt => deletedAt.add(retentionPeriod);

  /// Whether this item is expiring soon (within 7 days)
  bool get isExpiringSoon {
    final now = DateTime.now();
    final sevenDaysFromNow = now.add(const Duration(days: 7));
    return expiresAt.isBefore(sevenDaysFromNow);
  }

  /// Whether this item has expired and should be permanently deleted
  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  /// Days remaining until permanent deletion
  int get daysRemaining {
    final now = DateTime.now();
    final difference = expiresAt.difference(now);
    return difference.inDays;
  }

  /// Hours remaining until permanent deletion (for more precision)
  int get hoursRemaining {
    final now = DateTime.now();
    final difference = expiresAt.difference(now);
    return difference.inHours;
  }

  /// Formatted time remaining string
  String get timeRemainingString {
    if (daysRemaining > 0) {
      return '$daysRemaining day${daysRemaining == 1 ? '' : 's'}';
    } else if (hoursRemaining > 0) {
      return '$hoursRemaining hour${hoursRemaining == 1 ? '' : 's'}';
    } else {
      return 'Less than 1 hour';
    }
  }

  /// Create a copy with updated properties
  TrashedItem copyWith({
    MediaItem? item,
    DateTime? deletedAt,
  }) {
    return TrashedItem(
      item: item ?? this.item,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrashedItem &&
        other.item.id == item.id &&
        other.deletedAt == deletedAt;
  }

  @override
  int get hashCode => item.id.hashCode ^ deletedAt.hashCode;

  @override
  String toString() {
    return 'TrashedItem(item: ${item.id}, deletedAt: $deletedAt, '
        'expiresAt: $expiresAt, isExpiringSoon: $isExpiringSoon)';
  }
}

/// Extension methods for working with lists of TrashedItem
extension TrashedItemListExtension on List<TrashedItem> {
  /// Get items that are expiring soon (within 7 days)
  List<TrashedItem> get expiringSoon =>
      where((item) => item.isExpiringSoon).toList();

  /// Get items that have expired
  List<TrashedItem> get expired =>
      where((item) => item.isExpired).toList();

  /// Sort by expiration date (soonest first)
  List<TrashedItem> sortedByExpiration() {
    final sorted = List<TrashedItem>.from(this);
    sorted.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return sorted;
  }

  /// Sort by deletion date (oldest first)
  List<TrashedItem> sortedByDeletion() {
    final sorted = List<TrashedItem>.from(this);
    sorted.sort((a, b) => a.deletedAt.compareTo(b.deletedAt));
    return sorted;
  }
}
