
import 'package:get/get.dart';
import '../../../app/routes/app_pages.dart';

// ── Tab identifiers (order = visual left→right order) ─────────
enum BottomNavTab { pictures, albums, stories, more }

// ── Data class for items inside the More grid sheet ───────────
class MoreMenuItem {
  final String   id;     // unique string key, maps to a route
  final String   label;  // display text below icon
  const MoreMenuItem({required this.id, required this.label});
}

// ─────────────────────────────────────────────────────────────

class BottomNavController extends GetxController {
  // ── Reactive active tab ───────────────────────────────────────
  final Rx<BottomNavTab> activeTab = BottomNavTab.pictures.obs;

  // ── More-grid catalogue (order = grid order, 5 per row) ───────
  static const List<MoreMenuItem> moreItems = [
    MoreMenuItem(id: 'videos',        label: 'Videos'),
    MoreMenuItem(id: 'favourites',    label: 'Favourites'),
    MoreMenuItem(id: 'recent',        label: 'Recent'),
    MoreMenuItem(id: 'suggestions',   label: 'Suggestions'),
    MoreMenuItem(id: 'locations',     label: 'Locations'),
    MoreMenuItem(id: 'shared_albums', label: 'Shared albums'),
    MoreMenuItem(id: 'people',        label: 'People'),
    MoreMenuItem(id: 'duplicates',    label: 'Duplicates'),
    MoreMenuItem(id: 'trash',         label: 'Recycle bin'),
    MoreMenuItem(id: 'settings',      label: 'Settings'),
  ];

  // ── Route map (id → named route) ─────────────────────────────
  static Map<String, String> _moreRoutes = {
    'videos':        AppPages.videos,
    'favourites':    AppPages.favourites,
    'recent':        AppPages.recent,
    'suggestions':   AppPages.suggestions,
    'locations':     AppPages.locations,
    'shared_albums': AppPages.sharedAlbums,
    'people':        AppPages.people,
    'duplicates':    AppPages.duplicates,
    'trash':         AppPages.trash,
    'settings':      AppPages.settings,
  };

  // ── Set active main tab + navigate ───────────────────────────
  void setTab(BottomNavTab tab) {
    if (tab == BottomNavTab.more) return; // More opens a sheet, not a page

    activeTab.value = tab;

    switch (tab) {
      case BottomNavTab.pictures: Get.offAllNamed(AppPages.gallery);
      case BottomNavTab.albums: Get.offAllNamed(AppPages.albums);
      case BottomNavTab.stories: Get.offAllNamed(AppPages.stories);
      case BottomNavTab.more:
        break;
    }
  }

  // ── Navigate from More-sheet item tap ────────────────────────
  void navigateTo(String id) {
    final route = _moreRoutes[id];
    if (route != null) Get.toNamed(route);
  }

  // ── Mark the correct tab when a screen is entered directly ───
  // Call this from a screen's onInit/initState if it lives under
  // one of the main tabs (not the More sheet).
  void markTab(BottomNavTab tab) => activeTab.value = tab;
}