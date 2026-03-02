// import 'dart:io';
// import 'dart:convert';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:http/http.dart' as http;
// import 'package:get/get.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:photo_manager/photo_manager.dart';
// import 'package:mime/mime.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import '../../../core/services/secure_storage_service.dart';
//
// // ── Sync State (observable) ─────────────────────────────────
// class SyncState {
//   final int totalToUpload;
//   final int uploaded;
//   final int totalToDownload;
//   final int downloaded;
//   final bool isRunning;
//   final String? lastError;
//   final DateTime? lastSyncAt;
//
//   const SyncState({
//     this.totalToUpload = 0,
//     this.uploaded = 0,
//     this.totalToDownload = 0,
//     this.downloaded = 0,
//     this.isRunning = false,
//     this.lastError,
//     this.lastSyncAt,
//   });
//
//   SyncState copyWith({
//     int? totalToUpload,
//     int? uploaded,
//     int? totalToDownload,
//     int? downloaded,
//     bool? isRunning,
//     String? lastError,
//     DateTime? lastSyncAt,
//   }) => SyncState(
//     totalToUpload: totalToUpload ?? this.totalToUpload,
//     uploaded: uploaded ?? this.uploaded,
//     totalToDownload: totalToDownload ?? this.totalToDownload,
//     downloaded: downloaded ?? this.downloaded,
//     isRunning: isRunning ?? this.isRunning,
//     lastError: lastError,
//     lastSyncAt: lastSyncAt ?? this.lastSyncAt,
//   );
//
//   double get uploadProgress =>
//       totalToUpload == 0 ? 0 : uploaded / totalToUpload;
//
//   double get downloadProgress =>
//       totalToDownload == 0 ? 0 : downloaded / totalToDownload;
//
//   double get totalProgress =>
//       (totalToUpload + totalToDownload) == 0
//           ? 0
//           : (uploaded + downloaded) / (totalToUpload + totalToDownload);
// }
//
// class GooglePhotosSyncService extends GetxService {
//   final SecureStorageService _secureStorage;
//   late final GoogleSignIn _googleSignIn;
//   final Rx<SyncState> syncState = const SyncState().obs;
//   final RxBool isAuthenticated = false.obs;
//
//   GooglePhotosSyncService({required SecureStorageService secureStorage})
//       : _secureStorage = secureStorage {
//     _googleSignIn = GoogleSignIn(
//       scopes: const [
//         photos.PhotosLibraryApi.photoslibraryScope,
//         photos.PhotosLibraryApi.photoslibraryReadonlyScope,
//       ],
//     );
//   }
//
//   @override
//   void onInit() {
//     super.onInit();
//     _checkSignInStatus();
//   }
//
//   // ----------------------------------------------------------
//   // AUTHENTICATION
//   // ----------------------------------------------------------
//   Future<void> _checkSignInStatus() async {
//     isAuthenticated.value = await _googleSignIn.isSignedIn();
//   }
//
//   Future<bool> signIn() async {
//     try {
//       final account = await _googleSignIn.signIn();
//       if (account == null) return false;
//
//       // Get authentication headers
//       final authHeaders = await account.authHeaders;
//
//       // Store account info for background sync
//       await _secureStorage.write('google_email', account.email);
//       await _secureStorage.write('google_auth_headers', jsonEncode(authHeaders));
//
//       isAuthenticated.value = true;
//       return true;
//     } catch (e) {
//       syncState.value = syncState.value.copyWith(lastError: e.toString());
//       return false;
//     }
//   }
//
//   Future<void> signOut() async {
//     await _googleSignIn.signOut();
//     await _secureStorage.delete('google_email');
//     await _secureStorage.delete('google_auth_headers');
//     await _secureStorage.delete('sync_map');
//     await _secureStorage.delete('sync_map_reverse');
//     await _secureStorage.delete('downloaded_items');
//     isAuthenticated.value = false;
//     syncState.value = const SyncState();
//   }
//
//   Future<bool> get isSignedIn async {
//     return await _googleSignIn.isSignedIn();
//   }
//
//   // ----------------------------------------------------------
//   // GET AUTHENTICATED HTTP CLIENT for Google APIs
//   // ----------------------------------------------------------
//   Future<photos.PhotosLibraryApi?> _getPhotosApi() async {
//     GoogleSignInAccount? account = _googleSignIn.currentUser;
//
//     if (account == null) {
//       account = await _googleSignIn.signInSilently();
//     }
//
//     if (account == null) {
//       // Try to restore from stored headers (for background sync)
//       final storedHeaders = await _secureStorage.read('google_auth_headers');
//       if (storedHeaders != null) {
//         try {
//           final headers = jsonDecode(storedHeaders) as Map<String, dynamic>;
//           final client = _AuthenticatedClient(
//             http.Client(),
//             headers.map((key, value) => MapEntry(key, value.toString())),
//           );
//           return photos.PhotosLibraryApi(client);
//         } catch (e) {
//           print('Error parsing stored headers: $e');
//         }
//       }
//       return null;
//     }
//
//     // Use the extension to get authenticated client
//     final client = await account.getAuthenticatedClient();
//     if (client == null) return null;
//
//     return photos.PhotosLibraryApi(client);
//   }
//
//   // ----------------------------------------------------------
//   // NETWORK CHECK
//   // ----------------------------------------------------------
//   Future<bool> _isOnWifi() async {
//     final connectivityResult = await Connectivity().checkConnectivity();
//     return connectivityResult == ConnectivityResult.wifi;
//   }
//
//   // ----------------------------------------------------------
//   // FULL SYNC (called by WorkManager background task)
//   // ----------------------------------------------------------
//   Future<void> runSync({bool wifiOnly = true}) async {
//     // Prevent concurrent runs
//     if (syncState.value.isRunning) return;
//
//     // Check if signed in
//     if (!await isSignedIn) {
//       syncState.value = syncState.value.copyWith(
//         lastError: 'Not signed in to Google',
//       );
//       return;
//     }
//
//     // Check WiFi condition
//     if (wifiOnly) {
//       final isWifi = await _isOnWifi();
//       if (!isWifi) {
//         print('Skipping sync - not on WiFi');
//         return;
//       }
//     }
//
//     syncState.value = syncState.value.copyWith(isRunning: true);
//
//     try {
//       final photosApi = await _getPhotosApi();
//       if (photosApi == null) {
//         syncState.value = syncState.value.copyWith(
//           isRunning: false,
//           lastError: 'Failed to get authenticated API client',
//         );
//         return;
//       }
//
//       // 1. Upload new local items to Google Photos
//       await _uploadQueue(photosApi);
//
//       // 2. Download new Google Photos items to device
//       await _downloadQueue(photosApi);
//
//       // 3. Mark sync as complete
//       final now = DateTime.now();
//       await _secureStorage.write(
//         'last_sync_at',
//         now.toIso8601String(),
//       );
//
//       syncState.value = syncState.value.copyWith(
//         isRunning: false,
//         lastSyncAt: now,
//         lastError: null,
//       );
//
//       // Close the client if it's a BaseClient
//       if (photosApi.client is http.Client) {
//         (photosApi.client as http.Client).close();
//       }
//     } catch (e) {
//       syncState.value = syncState.value.copyWith(
//         isRunning: false,
//         lastError: e.toString(),
//       );
//     }
//   }
//
//   // ----------------------------------------------------------
//   // UPLOAD QUEUE — Upload new local photos to Google Photos
//   // ----------------------------------------------------------
//   Future<void> _uploadQueue(photos.PhotosLibraryApi api) async {
//     // 1. Get list of local items not yet synced
//     final pendingUploads = await _getPendingUploads();
//
//     if (pendingUploads.isEmpty) {
//       syncState.value = syncState.value.copyWith(
//         totalToUpload: 0,
//         uploaded: 0,
//       );
//       return;
//     }
//
//     syncState.value = syncState.value.copyWith(
//       totalToUpload: pendingUploads.length,
//       uploaded: 0,
//     );
//
//     for (int i = 0; i < pendingUploads.length; i++) {
//       final asset = pendingUploads[i];
//
//       try {
//         // Step 1: Upload raw bytes → get upload token
//         final uploadToken = await _uploadBytes(asset);
//
//         if (uploadToken != null && uploadToken.isNotEmpty) {
//           // Step 2: Create media item using upload token
//           final request = photos.BatchCreateMediaItemsRequest(
//             newMediaItems: [
//               photos.NewMediaItem(
//                 simpleMediaItem: photos.SimpleMediaItem(
//                   uploadToken: uploadToken,
//                 ),
//                 description: '', // Optional caption
//               ),
//             ],
//           );
//
//           final response = await api.mediaItems.batchCreate(request);
//
//           if (response.newMediaItemResults != null &&
//               response.newMediaItemResults!.isNotEmpty) {
//             final result = response.newMediaItemResults!.first;
//
//             if (result.mediaItem != null && result.mediaItem!.id != null) {
//               // Mark as synced in local index
//               await _markAsSynced(
//                 asset.id,
//                 result.mediaItem!.id!,
//               );
//             }
//           }
//         }
//       } catch (e) {
//         // Log and continue — don't fail entire sync for one item
//         print('Upload failed for ${asset.title}: $e');
//       }
//
//       syncState.value = syncState.value.copyWith(uploaded: i + 1);
//     }
//   }
//
//   // ----------------------------------------------------------
//   // DOWNLOAD QUEUE — Fetch Google Photos items not on device
//   // ----------------------------------------------------------
//   Future<void> _downloadQueue(photos.PhotosLibraryApi api) async {
//     // List all media items from Google Photos
//     String? pageToken;
//     final allGoogleItems = <photos.MediaItem>[];
//
//     try {
//       do {
//         final response = await api.mediaItems.list(
//           pageSize: 100,
//           pageToken: pageToken,
//         );
//         if (response.mediaItems != null) {
//           allGoogleItems.addAll(response.mediaItems!);
//         }
//         pageToken = response.nextPageToken;
//       } while (pageToken != null);
//     } catch (e) {
//       print('Error fetching Google Photos: $e');
//       return;
//     }
//
//     // Filter to items not already on device
//     final toDownload = await _filterNotOnDevice(allGoogleItems);
//
//     if (toDownload.isEmpty) {
//       syncState.value = syncState.value.copyWith(
//         totalToDownload: 0,
//         downloaded: 0,
//       );
//       return;
//     }
//
//     syncState.value = syncState.value.copyWith(
//       totalToDownload: toDownload.length,
//       downloaded: 0,
//     );
//
//     for (int i = 0; i < toDownload.length; i++) {
//       final item = toDownload[i];
//       await _downloadItem(item);
//       syncState.value = syncState.value.copyWith(downloaded: i + 1);
//     }
//   }
//
//   // ----------------------------------------------------------
//   // UPLOAD BYTES via resumable upload API
//   // ----------------------------------------------------------
//   Future<String?> _uploadBytes(AssetEntity asset) async {
//     try {
//       // Get file bytes
//       final file = await asset.file;
//       if (file == null) return null;
//
//       final bytes = await file.readAsBytes();
//       final mimeType = asset.mimeType ??
//           lookupMimeType(file.path) ??
//           'image/jpeg';
//
//       // Get authenticated client specifically for upload
//       final account = _googleSignIn.currentUser ??
//           await _googleSignIn.signInSilently();
//
//       if (account == null) return null;
//
//       final client = await account.getAuthenticatedClient();
//       if (client == null) return null;
//
//       // Upload to Google Photos
//       final response = await client.post(
//         Uri.parse('https://photoslibrary.googleapis.com/v1/uploads'),
//         headers: {
//           'Content-type': 'application/octet-stream',
//           'X-Goog-Upload-Content-Type': mimeType,
//           'X-Goog-Upload-Protocol': 'raw',
//         },
//         body: bytes,
//       );
//
//       client.close();
//
//       if (response.statusCode == 200) {
//         return response.body; // This is the upload token
//       }
//
//       print('Upload failed with status: ${response.statusCode}');
//       print('Response body: ${response.body}');
//       return null;
//     } catch (e) {
//       print('Upload bytes error: $e');
//       return null;
//     }
//   }
//
//   Future<void> _downloadItem(photos.MediaItem item) async {
//     try {
//       if (item.baseUrl == null) return;
//
//       // Download URL format: baseUrl + '=d' for download
//       final downloadUrl = '${item.baseUrl}=d';
//       final response = await http.get(Uri.parse(downloadUrl));
//
//       if (response.statusCode != 200) {
//         print('Download failed with status: ${response.statusCode}');
//         return;
//       }
//
//       // Get app's documents directory
//       final directory = await getApplicationDocumentsDirectory();
//       final downloadDir = Directory('${directory.path}/google_photos');
//
//       if (!await downloadDir.exists()) {
//         await downloadDir.create(recursive: true);
//       }
//
//       // Create filename with timestamp to avoid duplicates
//       final timestamp = DateTime.now().millisecondsSinceEpoch;
//       final safeFileName = item.filename?.replaceAll(RegExp(r'[^\w\s.-]'), '_') ??
//           'photo_$timestamp.jpg';
//       final savePath = '${downloadDir.path}/$safeFileName';
//
//       // Save file
//       final file = File(savePath);
//       await file.writeAsBytes(response.bodyBytes);
//
//       // Import to gallery using PhotoManager
//       final result = await PhotoManager.editor.saveImage(
//         response.bodyBytes,
//         title: safeFileName,
//         relativePath: 'Google Photos',
//       );
//
//       if (result != null) {
//         // Mark as downloaded
//         await _markAsDownloaded(item.id!);
//
//         // If file was successfully imported, we can delete the temporary copy
//         if (await file.exists()) {
//           await file.delete();
//         }
//       }
//
//       print('Downloaded: $safeFileName, imported: $result');
//     } catch (e) {
//       print('Download error: $e');
//     }
//   }
//
//   // ── Local index operations ─────────────────────
//   Future<List<AssetEntity>> _getPendingUploads() async {
//     try {
//       // Request permission
//       final permission = await PhotoManager.requestPermissionExtend();
//       if (!permission) {
//         print('No permission to access photos');
//         return [];
//       }
//
//       // Get all local image assets
//       final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
//         type: RequestType.image,
//         hasAll: true,
//       );
//
//       if (albums.isEmpty) return [];
//
//       // Use the "All" album or first available
//       final allAlbum = albums.firstWhere(
//             (album) => album.isAll,
//         orElse: () => albums.first,
//       );
//
//       // Get all assets
//       final totalCount = await allAlbum.assetCountAsync;
//       if (totalCount == 0) return [];
//
//       final assets = await allAlbum.getAssetListRange(
//         start: 0,
//         end: totalCount,
//       );
//
//       // Filter out already synced ones
//       final syncedIds = await _getSyncedAssetIds();
//       return assets.where((asset) => !syncedIds.contains(asset.id)).toList();
//     } catch (e) {
//       print('Error getting pending uploads: $e');
//       return [];
//     }
//   }
//
//   Future<List<photos.MediaItem>> _filterNotOnDevice(
//       List<photos.MediaItem> items) async {
//     try {
//       // Get synced items
//       final syncedGoogleIds = await _getSyncedGoogleIds();
//
//       // Filter out already downloaded ones
//       return items.where((item) {
//         if (item.id == null) return false;
//         return !syncedGoogleIds.contains(item.id);
//       }).toList();
//     } catch (e) {
//       print('Error filtering items: $e');
//       return [];
//     }
//   }
//
//   Future<void> _markAsSynced(String localId, String googleId) async {
//     try {
//       // Store mapping in secure storage
//       final existing = await _secureStorage.read('sync_map') ?? '{}';
//       final Map<String, dynamic> syncMap = Map.from(jsonDecode(existing));
//
//       syncMap[localId] = googleId;
//       await _secureStorage.write('sync_map', jsonEncode(syncMap));
//
//       // Also store reverse mapping
//       final reverseMap = await _secureStorage.read('sync_map_reverse') ?? '{}';
//       final Map<String, dynamic> revMap = Map.from(jsonDecode(reverseMap));
//
//       revMap[googleId] = localId;
//       await _secureStorage.write('sync_map_reverse', jsonEncode(revMap));
//     } catch (e) {
//       print('Error marking as synced: $e');
//     }
//   }
//
//   Future<void> _markAsDownloaded(String googleId) async {
//     try {
//       final downloaded = await _secureStorage.read('downloaded_items') ?? '[]';
//       final List<String> downloadedList = List<String>.from(jsonDecode(downloaded));
//
//       if (!downloadedList.contains(googleId)) {
//         downloadedList.add(googleId);
//         await _secureStorage.write('downloaded_items', jsonEncode(downloadedList));
//       }
//     } catch (e) {
//       print('Error marking as downloaded: $e');
//     }
//   }
//
//   Future<Set<String>> _getSyncedAssetIds() async {
//     try {
//       final existing = await _secureStorage.read('sync_map') ?? '{}';
//       final Map<String, dynamic> syncMap = jsonDecode(existing);
//       return syncMap.keys.toSet();
//     } catch (e) {
//       print('Error getting synced asset IDs: $e');
//       return {};
//     }
//   }
//
//   Future<Set<String>> _getSyncedGoogleIds() async {
//     try {
//       final existing = await _secureStorage.read('sync_map_reverse') ?? '{}';
//       final Map<String, dynamic> revMap = jsonDecode(existing);
//       return revMap.keys.toSet();
//     } catch (e) {
//       print('Error getting synced Google IDs: $e');
//       return {};
//     }
//   }
//
//   // Helper method to get last sync time
//   Future<DateTime?> getLastSyncTime() async {
//     final lastSyncStr = await _secureStorage.read('last_sync_at');
//     if (lastSyncStr != null) {
//       try {
//         return DateTime.parse(lastSyncStr);
//       } catch (e) {
//         return null;
//       }
//     }
//     return null;
//   }
//
//   // Helper method to get sync progress
//   SyncState get currentSyncState => syncState.value;
// }
//
// // ── Authenticated HTTP client wrapper ─────────────────────
// class _AuthenticatedClient extends http.BaseClient {
//   final http.Client _inner;
//   final Map<String, String> _headers;
//
//   _AuthenticatedClient(this._inner, this._headers);
//
//   @override
//   Future<http.StreamedResponse> send(http.BaseRequest request) {
//     request.headers.addAll(_headers);
//     return _inner.send(request);
//   }
//
//   @override
//   void close() => _inner.close();
// }