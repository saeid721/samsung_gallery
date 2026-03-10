import 'package:get/get.dart';

// Views
import '../../features/albums/albums_view.dart';
import '../../features/duplicates_view/duplicates_view.dart';
import '../../features/editor/editor_view.dart';
import '../../features/gallery/views/gallery_view.dart';
import '../../features/media_viewer_view/media_viewer_view.dart';
//import '../../features/memories_view/story_view.dart';
import '../../features/people_view/people_view.dart';
import '../../features/search/search_view.dart';
import '../../features/secure_folder_view/secure_folder_view.dart';

// Bindings (lazy DI per route)
import '../../features/story/story_view.dart';
import '../../features/sync_settings_view/sync_settings_view.dart';
import '../../features/trash_view/trash_view.dart';
import '../bindings/editor_binding.dart';
import '../bindings/gallery_binding.dart';
import '../bindings/search_binding.dart';
import '../bindings/secure_folder_binding.dart';
import '../bindings/viewer_binding.dart';
import '../bindings/trash_binding.dart';

abstract class AppPages {
  static const initial = gallery;

  // ── Route constants ──────────────────────────────────────
  static const gallery      = '/gallery';
  static const albums       = '/albums';
  static const categories   = '/categories';
  static const viewer       = '/viewer';
  static const editor       = '/editor';
  static const search       = '/search';
  static const secureFolder = '/secure_folder_view-folder';
  static const stories     = '/stories';
  static const people       = '/people';
  static const duplicates   = '/duplicates';
  static const trash        = '/trash';
  static const syncSettings = '/sync-settings';
  static const mapView      = '/map';
  static const videos      = '/videos';
  static const favourites      = '/favourites';
  static const recent      = '/recent';
  static const suggestions      = '/suggestions';
  static const locations      = '/locations';
  static const sharedAlbums      = '/sharedAlbums';
  static const settings      = '/settings';

  // ── Route definitions with lazy bindings ────────────────
  static final routes = [
    GetPage(
      name: gallery,
      page: () => const GalleryView(),
      binding: GalleryBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: albums,
      page: () => const AlbumsView(),
      // Albums reuses GalleryBinding (shares MediaRepository)
      binding: GalleryBinding(),
    ),
    GetPage(
      name: viewer,
      page: () => const MediaViewerView(),
      binding: ViewerBinding(),
      transition: Transition.zoom,
      transitionDuration: const Duration(milliseconds: 250),
    ),
    GetPage(
      name: editor,
      page: () => const EditorView(),
      binding: EditorBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: search,
      page: () => const SearchView(),
      binding: SearchBinding(),
      transition: Transition.downToUp,
    ),
    GetPage(
      name: secureFolder,
      page: () => const SecureFolderView(),
      binding: SecureFolderBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: stories,
      page: () => const StoryView(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: people,
      page: () => const PeopleView(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: duplicates,
      page: () => const DuplicatesView(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: trash,
      page: () => const TrashView(),
      binding: TrashBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: syncSettings,
      page: () => const SyncSettingsView(),
      transition: Transition.rightToLeft,
    ),
  ];
}
