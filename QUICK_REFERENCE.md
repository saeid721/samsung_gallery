# Quick Reference - Gallery & Albums Navigation

## Key States to Remember

### GalleryController
- `currentAlbumId` - Empty string "" = main gallery, otherwise = album ID
- `currentAlbumName` - Display name shown in AppBar
- `timelineGroups` - List of grouped media items by date
- `isLoading`, `errorMessage` - Loading/error states

### AlbumsController  
- `albums` - List of all available albums
- `isLoading`, `errorMessage` - Loading/error states

## How to Navigate

### From AlbumsView to Gallery (for specific album):
```dart
Get.toNamed(
  AppPages.gallery,
  arguments: {
    'albumId': album.id,      // Required
    'albumName': album.name,  // Required
  },
);
```

### From GalleryView to AlbumsView:
```dart
Get.toNamed(AppPages.albums);
```

### From GalleryView to Photo Viewer:
```dart
Get.toNamed(
  AppPages.viewer,
  arguments: {'mediaItem': item},
);
```

## Fixing Common Problems

### Problem: Albums not loading
**Check:** 
1. AlbumRepository registered in InitialBinding? ✓
2. AlbumsController calling loadAlbums() in onInit()? ✓
3. Permission granted? ✓

### Problem: Clicking album shows all photos
**Check:**
1. Route arguments passed correctly? 
   ```dart
   arguments: {'albumId': album.id, 'albumName': album.name}
   ```
2. GalleryController.onInit() reading arguments?
   ```dart
   final args = Get.arguments as Map<String, dynamic>?;
   if (args?.containsKey('albumId') ?? false) { ... }
   ```
3. currentAlbumId.value not empty before _initialize()?

### Problem: Album title not showing
**Check:**
1. AppBar uses: `controller.currentAlbumName.value` ✓
2. Route arguments include 'albumName'? ✓
3. _initialize() called after argument parsing? ✓

### Problem: Thumbnails not loading
**Check:**
1. Asset ID valid? Try debug logging:
   ```dart
   if (kDebugMode) print('Loading thumbnail for: $assetId');
   ```
2. Permission granted? Check `hasPermission` state
3. Asset still exists? (deleted file = thumbnail fails)

## State Flow Diagram

```
Main Gallery View
    ↓
[Browse all photos grouped by date]
    ↓
Bottom Nav: Switch to Albums
    ↓
Albums View  
    ↓
[List of albums with covers]
    ↓
Tap Album → Pass albumId + albumName
    ↓
Gallery View (with album filter)
    ↓
[Show only photos from that album]
    ↓
AppBar shows album name instead of "Gallery"
```

## Testing Checklist

- [ ] AlbumsView loads and shows albums
- [ ] Each album has a thumbnail
- [ ] Album name and item count display
- [ ] Clicking album opens GalleryView with album title
- [ ] Gallery shows ONLY photos from selected album
- [ ] AppBar title changes to album name
- [ ] Photos are grouped by date (Today, Yesterday, etc)
- [ ] Clicking photo opens viewer
- [ ] Pull-to-refresh works
- [ ] Error states show retry button
- [ ] Empty states show helpful message
- [ ] Selection mode works in both views
- [ ] Navigation back works properly

## Code Snippets to Copy

### Check album mode in view:
```dart
if (controller.currentAlbumId.value.isNotEmpty) {
  // Viewing album
  Text('Album: ${controller.currentAlbumName.value}')
} else {
  // Viewing main gallery
  Text('Gallery')
}
```

### Show loading state:
```dart
if (controller.isLoading.value) {
  return CircularProgressIndicator();
}
```

### Show error state:
```dart
if (controller.errorMessage.isNotEmpty) {
  return Column(
    children: [
      Text(controller.errorMessage.value),
      ElevatedButton(
        onPressed: controller.refresh,
        child: Text('Retry'),
      ),
    ],
  );
}
```

### Flatten timeline groups to items:
```dart
final allItems = controller.timelineGroups
    .expand((group) => group.items)
    .toList();
```

### Get all album items:
```dart
final items = await Get.find<AlbumRepository>()
    .getAlbumItems(albumId);
```

## File Locations

- **Controllers:** `lib/features/*/controllers/*.dart`
- **Views:** `lib/features/*/views/*.dart` or `lib/features/*/*_view.dart`
- **Models:** `lib/data/models/*.dart`
- **Repositories:** `lib/data/repositories/*.dart`
- **Routes:** `lib/app/routes/app_pages.dart`
- **Bindings:** `lib/app/bindings/*.dart`

## Key Files Modified in Fix

1. `lib/features/gallery/controllers/gallery_controller.dart`
   - Added album filtering support
   - Parse route arguments
   - Load album-specific media

2. `lib/features/gallery/views/gallery_view.dart`
   - Show album name in AppBar
   - Better error handling
   - Improved empty states

3. `lib/features/albums/albums_view.dart`
   - Fixed deprecated API calls
   - Added error state UI
   - Better thumbnail handling

## Useful Commands

```bash
# Run app
flutter run

# Build debug APK
flutter build apk --debug

# Get dependencies
flutter pub get

# Check for errors
flutter analyze

# Format code
flutter format lib/

# Run specific feature tests
flutter test test/features/gallery_test.dart
```

