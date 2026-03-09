# Implementation Guide - Gallery & Albums Fix

## Overview
This guide explains how the gallery and albums display system works after the fixes.

## Core Components

### 1. Album Selection Flow

```
User Interface
├── AlbumsView (displays list of albums)
│   ├── AlbumsController (manages album list)
│   │   ├── loadAlbums() - fetches from AlbumRepository
│   │   └── State: RxList<Album> albums
│   └── _AlbumCard (tap navigates to gallery)
│       └── Get.toNamed(AppPages.gallery, 
│           arguments: {'albumId': album.id, 'albumName': album.name})
│
└── GalleryView (displays photos)
    └── GalleryController
        ├── onInit() - reads route arguments
        ├── _initialize() - decides: album or timeline
        ├── _loadAlbumMedia() - fetches album items
        └── _loadTimelineStream() - streams all media
```

### 2. GalleryController Logic

#### Initialization Sequence:
```dart
@override
void onInit() {
  super.onInit();
  // 1. Extract album info from navigation arguments
  final args = Get.arguments as Map<String, dynamic>?;
  if (args != null && args.containsKey('albumId')) {
    currentAlbumId.value = args['albumId'];      // e.g., "Camera"
    currentAlbumName.value = args['albumName'];  // e.g., "Camera"
  }
  // 2. Call initialization
  _initialize();
}

Future<void> _initialize() async {
  // 3. Request storage permission
  hasPermission.value = await _mediaRepo.requestPermission();
  
  // 4. Decide which data to load
  if (currentAlbumId.value.isNotEmpty) {
    // Album view - load specific album items
    await _loadAlbumMedia();
  } else {
    // Main gallery view - stream all media by date
    _loadTimelineStream();
  }
}
```

#### Data Loading:
```dart
Future<void> _loadAlbumMedia() async {
  // Get items from specific album
  final items = await _albumRepo.getAlbumItems(currentAlbumId.value);
  
  // Sort by date descending (newest first)
  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  
  // Group by date (Today, Yesterday, etc.)
  final grouped = _groupItemsByDate(items);
  
  // Update UI
  timelineGroups.assignAll(grouped);
}
```

### 3. Display Logic

#### AlbumsView:
```
┌─────────────────────────────┐
│ AlbumsView                  │
├─────────────────────────────┤
│ Loading State               │
│ ├─ if loading: Show spinner │
│ ├─ if error: Show error msg │
│ ├─ if empty: Show message   │
│ └─ else: Show grid of albums│
│                             │
│ Grid Layout:                │
│ ├─ 2 columns                │
│ ├─ Album card with thumbnail│
│ ├─ Album name              │
│ └─ Item count              │
└─────────────────────────────┘
```

#### GalleryView:
```
┌─────────────────────────────┐
│ AppBar                      │
│ ├─ Title: "Album Name" or   │
│ │         "Gallery"         │
│ ├─ Search icon (if main)    │
│ └─ Menu (favorite, move)    │
├─────────────────────────────┤
│ Body                        │
│ ├─ Loading State            │
│ ├─ Error State (with retry) │
│ ├─ Empty State (with refresh)
│ └─ Grid of Photos:          │
│    ├─ 4 columns             │
│    ├─ Thumbnail + badges    │
│    ├─ Video duration        │
│    └─ Selection overlay     │
└─────────────────────────────┘
```

## State Management

### GalleryController Observable Properties:

```dart
// Loading states
final RxBool isLoading = true.obs;
final RxBool hasPermission = false.obs;
final RxString errorMessage = ''.obs;

// Media data
final RxList<TimelineGroup> timelineGroups = <TimelineGroup>[].obs;

// Selection
final RxBool isSelectionMode = false.obs;
final RxSet<String> selectedIds = <String>{}.obs;

// Album filtering
final RxString currentAlbumId = ''.obs;      // "" = main gallery
final RxString currentAlbumName = ''.obs;    // "" = main gallery
```

### AlbumsController Observable Properties:

```dart
// Loading states
final RxBool isLoading = true.obs;
final RxString errorMessage = ''.obs;

// Album data
final RxList<Album> albums = <Album>[].obs;

// Selection
final RxBool isSelectionMode = false.obs;
final RxSet<String> selectedIds = <String>{}.obs;
```

## Error Handling

### Gallery View Error States:

1. **Permission Denied**
   - Shows icon + message + "Grant Permission" button
   - User can retry with `controller.refresh()`

2. **Loading Failed**
   - Shows error icon + error message + "Retry" button
   - User can retry with `controller.refresh()`

3. **No Photos**
   - Shows empty folder icon + "No photos found" message
   - User can refresh with `controller.refresh()`

### Albums View Error States:

1. **Loading Failed**
   - Shows error icon + error message + "Retry" button
   - User can retry with `controller.refresh()`

2. **No Albums**
   - Shows open folder icon + message
   - User can retry with "Refresh" button

## Thumbnail Loading

### Image Thumbnail Process:

```dart
// 1. Request thumbnail from asset
final asset = await AssetEntity.fromId(assetId);

// 2. Get thumbnail bytes (300x300, JPEG, 85% quality)
final bytes = await asset.thumbnailDataWithSize(
  const ThumbnailSize(300, 300),
  format: ThumbnailFormat.jpeg,
  quality: 85,
);

// 3. Display in UI
Image.memory(bytes, fit: BoxFit.cover)

// 4. Handle failures gracefully
// - Missing asset → show folder icon
// - Load error → show broken image icon
// - Null response → show image placeholder
```

## Date Grouping

### Algorithm:

```dart
String _formatDate(DateTime date) {
  final today = DateTime.now();
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  final dateOnly = DateTime(date.year, date.month, date.day);

  if (dateOnly == today) return 'Today';
  if (dateOnly == yesterday) return 'Yesterday';
  return '2024-03-09'; // YYYY-MM-DD format
}

// Groups items, then creates TimelineGroup for each label
List<TimelineGroup> _groupItemsByDate(List<MediaItem> items) {
  final grouped = <String, List<MediaItem>>{};
  for (final item in items) {
    final label = _formatDate(item.createdAt);
    grouped.putIfAbsent(label, () => []).add(item);
  }
  
  // Sort descending: [Today, Yesterday, 2024-03-08, ...]
  final sorted = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  
  return sorted.map((label) => TimelineGroup(
    label: label,
    items: grouped[label]!,
  )).toList();
}
```

## Navigation Flow

### Route Definitions (app_pages.dart):

```dart
GetPage(
  name: gallery,
  page: () => const GalleryView(),
  binding: GalleryBinding(),
  transition: Transition.fadeIn,
),

GetPage(
  name: albums,
  page: () => const AlbumsView(),
  binding: GalleryBinding(),  // Shares GalleryController
),
```

### Navigation Paths:

1. **Main Gallery → Albums**
   ```dart
   Get.toNamed(AppPages.albums);
   // GalleryController state preserved
   ```

2. **Albums → Album Gallery**
   ```dart
   Get.toNamed(
     AppPages.gallery,
     arguments: {
       'albumId': album.id,
       'albumName': album.name,
     },
   );
   ```

3. **Album Gallery → Photo Viewer**
   ```dart
   Get.toNamed(
     AppPages.viewer,
     arguments: {'mediaItem': item},
   );
   ```

## Dependency Injection (InitialBinding)

```dart
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Services
    Get.lazyPut(() => MediaIndexService(), fenix: true);
    Get.lazyPut(() => ExifService(), fenix: true);
    
    // Repositories
    Get.lazyPut<MediaRepository>(
      () => MediaRepositoryImpl(...),
      fenix: true,
    );
    Get.lazyPut<AlbumRepository>(
      () => AlbumRepositoryImpl(...),
      fenix: true,
    );
    
    // Controllers (per route via GalleryBinding)
    Get.lazyPut(() => GalleryController(), fenix: true);
    Get.lazyPut(() => AlbumsController(), fenix: true);
  }
}
```

## Performance Considerations

1. **Lazy Initialization**: Controllers/services only created when needed
2. **Fenix Pattern**: Controllers recreated if disposed during navigation
3. **Thumbnail Caching**: 300x300 thumbnails cached in memory
4. **Streaming**: Main gallery uses stream for real-time updates
5. **Pagination Support**: Album items can be loaded paginated (80 per page)

## Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Albums not showing | AlbumRepository not initialized | Check InitialBinding |
| Gallery shows all photos when clicking album | Route args not passed | Pass `albumId` in `arguments` |
| Album title not showing | `currentAlbumName` not set | Verify route argument parsing |
| Thumbnail not loading | Asset invalid or permission denied | Check permission + asset ID |
| Error state stuck | `refresh()` not implemented | Call `_initialize()` in refresh |
| Photos not refreshing | Not using `.obs` properly | Ensure all state uses reactive variables |

## Debugging Tips

1. **Enable debug logging in _AssetThumbnail:**
   ```dart
   if (kDebugMode) print('Asset not found: $assetId');
   if (kDebugMode) print('Error loading thumbnail: $e');
   ```

2. **Check state in gallery controller:**
   ```dart
   print('Album ID: ${controller.currentAlbumId.value}');
   print('Album Name: ${controller.currentAlbumName.value}');
   print('Groups: ${controller.timelineGroups.length}');
   ```

3. **Monitor repository calls:**
   ```dart
   final items = await _albumRepo.getAlbumItems(albumId);
   print('Loaded ${items.length} items from $albumId');
   ```

## Future Enhancements

1. **Search within album**
2. **Sort options** (date, name, size)
3. **Album sharing**
4. **Batch operations** (move, copy, delete)
5. **Album cover picker**
6. **Album statistics** (size, count, date range)

