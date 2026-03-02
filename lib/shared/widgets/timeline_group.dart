import '../../../data/models/media_model.dart';

class TimelineGroup {
  final DateTime date;
  final String label; // "Today", "Yesterday", "Jan 15, 2024", etc.
  final List<MediaItem> items;

  TimelineGroup({
    required this.date,
    required this.label,
    required this.items,
  });

  // Factory constructor for creating from API/DB response
  factory TimelineGroup.fromMap(Map<String, dynamic> map, List<MediaItem> mediaItems) {
    return TimelineGroup(
      date: map['date'] as DateTime,
      label: map['label'] as String,
      items: List<MediaItem>.from(mediaItems),
    );
  }

  // Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'label': label,
      //'items': items.map((item) => item.toMap()).toList(),
    };
  }

  // CopyWith for immutable updates (optional but recommended)
  TimelineGroup copyWith({
    DateTime? date,
    String? label,
    List<MediaItem>? items,
  }) {
    return TimelineGroup(
      date: date ?? this.date,
      label: label ?? this.label,
      items: items ?? this.items,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimelineGroup &&
        other.date == date &&
        other.label == label &&
        other.items.length == items.length;
  }

  @override
  int get hashCode => date.hashCode ^ label.hashCode ^ items.hashCode;

  @override
  String toString() => 'TimelineGroup(date: $date, label: $label, items: ${items.length})';
}