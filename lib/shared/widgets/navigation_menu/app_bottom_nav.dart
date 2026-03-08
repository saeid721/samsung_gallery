
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'bottom_nav_controller.dart';

// ── Public entry point ────────────────────────────────────────
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    // BottomNavController is permanent — always available.
    final nav = Get.find<BottomNavController>();

    return Obx(() => _BottomBar(
      activeTab: nav.activeTab.value,
      onTabTapped: (tab) {
        if (tab == BottomNavTab.more) {
          _openMoreSheet(context, nav);
        } else {
          nav.setTab(tab);
        }
      },
    ));
  }

  void _openMoreSheet(BuildContext context, BottomNavController nav) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,       // overlay above all routes
      builder: (_) => _MoreSheet(nav: nav),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BOTTOM BAR
// ══════════════════════════════════════════════════════════════

// Static descriptor for each tab.
class _TabDef {
  final BottomNavTab tab;
  final IconData     icon;
  final IconData     activeIcon;
  final String       label;
  const _TabDef({
    required this.tab,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

const _kPrimary = Color(0xFF1259C3); // Samsung Blue

class _BottomBar extends StatelessWidget {
  final BottomNavTab                  activeTab;
  final void Function(BottomNavTab)   onTabTapped;

  const _BottomBar({
    required this.activeTab,
    required this.onTabTapped,
  });

  static const _tabs = [
    _TabDef(
      tab:        BottomNavTab.pictures,
      icon:       Icons.photo_library_outlined,
      activeIcon: Icons.photo_library_rounded,
      label:      'Pictures',
    ),
    _TabDef(
      tab:        BottomNavTab.albums,
      icon:       Icons.folder_outlined,
      activeIcon: Icons.folder_rounded,
      label:      'Albums',
    ),
    _TabDef(
      tab:        BottomNavTab.stories,
      icon:       Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome_rounded,
      label:      'Stories',
    ),
    _TabDef(
      tab:        BottomNavTab.more,
      icon:       Icons.apps_rounded,
      activeIcon: Icons.apps_rounded,
      label:      'More',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: _tabs.map((def) => _TabItem(
              def:      def,
              isActive: activeTab == def.tab,
              isDark:   isDark,
              onTap:    () => onTabTapped(def.tab),
            )).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Single tab item ───────────────────────────────────────────
class _TabItem extends StatelessWidget {
  final _TabDef       def;
  final bool          isActive;
  final bool          isDark;
  final VoidCallback  onTap;

  const _TabItem({
    required this.def,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor   = _kPrimary;
    final inactiveColor = isDark ? Colors.white54 : Colors.grey.shade600;
    final color         = isActive ? activeColor : inactiveColor;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor:     activeColor.withOpacity(0.10),
        highlightColor:  Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated indicator pill above icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve:    Curves.easeOutCubic,
              width:    isActive ? 28 : 0,
              height:   3,
              margin:   const EdgeInsets.only(bottom: 3),
              decoration: BoxDecoration(
                color:        activeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? def.activeIcon : def.icon,
                key:   ValueKey(isActive),
                color: color,
                size:  24,
              ),
            ),
            const SizedBox(height: 3),
            // Label
            Text(
              def.label,
              style: TextStyle(
                fontSize:   11,
                color:      color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MORE SHEET
// ══════════════════════════════════════════════════════════════

// Icons for each More-item id
const _moreIcons = <String, IconData>{
  'videos':        Icons.videocam_rounded,
  'favourites':    Icons.favorite_border_rounded,
  'recent':        Icons.history_rounded,
  'suggestions':   Icons.lightbulb_outline_rounded,
  'locations':     Icons.location_on_outlined,
  'shared_albums': Icons.folder_shared_outlined,
  'people':        Icons.people_outline_rounded,
  'duplicates':    Icons.copy_all_rounded,
  'trash':         Icons.delete_outline_rounded,
  'settings':      Icons.settings_outlined,
};

class _MoreSheet extends StatelessWidget {
  final BottomNavController nav;
  const _MoreSheet({required this.nav});

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bg        = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final divider   = isDark ? Colors.white12 : Colors.grey.shade200;
    final titleColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ────────────────────────────────────
          Container(
            width:  40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 6),
            decoration: BoxDecoration(
              color:        isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Title row ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'More',
                style: TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.w700,
                  color:      titleColor,
                ),
              ),
            ),
          ),

          Divider(height: 1, color: divider),

          // ── 5-column grid ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
            child: GridView.builder(
              shrinkWrap:  true,
              physics:     const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:  5,
                crossAxisSpacing: 6,
                mainAxisSpacing:  8,
                childAspectRatio: 0.75,
              ),
              itemCount:   BottomNavController.moreItems.length,
              itemBuilder: (_, i) {
                final item = BottomNavController.moreItems[i];
                return _MoreItem(
                  item:   item,
                  isDark: isDark,
                  onTap:  () {
                    Navigator.of(context).pop();    // close sheet first
                    nav.navigateTo(item.id);
                  },
                );
              },
            ),
          ),

          // ── Bottom safe area ───────────────────────────────
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}

class _MoreItem extends StatelessWidget {
  final MoreMenuItem  item;
  final bool          isDark;
  final VoidCallback  onTap;

  const _MoreItem({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon       = _moreIcons[item.id] ?? Icons.apps_rounded;
    final iconColor  = isDark ? Colors.white70   : Colors.grey.shade700;
    final bgColor    = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.grey.shade100;
    final labelColor = isDark ? Colors.white60 : Colors.grey.shade800;

    return GestureDetector(
      onTap:     onTap,
      behavior:  HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon container
          Container(
            width:  54,
            height: 54,
            decoration: BoxDecoration(
              color:        bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 6),
          // Label
          Text(
            item.label,
            style: TextStyle(
              fontSize:   10.5,
              fontWeight: FontWeight.w500,
              color:      labelColor,
              height:     1.2,
            ),
            textAlign:  TextAlign.center,
            maxLines:   2,
            overflow:   TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}