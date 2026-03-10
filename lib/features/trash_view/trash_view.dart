import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../app/theme/theme.dart';
import '../../data/models/media_model.dart';
import '../../shared/widgets/global_progress_hub.dart';
import 'controllers/trash_controller.dart';

class TrashView extends StatelessWidget {
  const TrashView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<TrashController>(
      init: TrashController(),
      builder: (c) {
        if (c.isSelectionMode) {
          return _TrashSelectionScreen(c: c);
        }
        return _TrashNormalScreen(c: c);
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  ① NORMAL SCREEN
// ══════════════════════════════════════════════════════════════

class _TrashNormalScreen extends StatelessWidget {
  final TrashController c;
  const _TrashNormalScreen({required this.c});

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: _TrashAppBar(c: c),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ProgressHUD(
          inAsyncCall: c.isLoading,
          child: Container(
            height: sz.height,
            width: sz.width,
            color: Colors.black,
            child: c.isLoading
                ? const SizedBox.shrink()
                : RefreshIndicator(
              onRefresh: c.refresh,
              color: Colors.white,
              backgroundColor: const Color(0xFF1C1C1E),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                children: [
                  // ── Info banner ──────────────────────
                  _infoBanner(),

                  // ── Expiring soon warning ────────────
                  if (c.expiringSoon.isNotEmpty)
                    _expiringBanner(c.expiringSoon.length),

                  // ── Grid or empty ────────────────────
                  c.trashedItems.isEmpty
                      ? _EmptyState(sz: sz)
                      : _TrashGrid(c: c, selectionMode: false),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoBanner() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: Colors.blueAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Items are permanently deleted after 30 days.',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue.shade100,
                  height: 1.4),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _expiringBanner(int count) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count item${count == 1 ? '' : 's'} will be deleted within 3 days.',
              style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 13,
                  height: 1.4),
            ),
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  ② SELECTION SCREEN
// ══════════════════════════════════════════════════════════════

class _TrashSelectionScreen extends StatelessWidget {
  final TrashController c;
  const _TrashSelectionScreen({required this.c});

  @override
  Widget build(BuildContext context) {
    final sz     = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: _SelectionAppBar(c: c),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Container(
          height: sz.height,
          width: sz.width,
          color: Colors.black,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              _TrashGrid(c: c, selectionMode: true),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
      bottomNavigationBar: GetBuilder<TrashController>(
        builder: (c) => Container(
          height: 72 + bottom,
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            border:
            Border(top: BorderSide(color: Colors.white10, width: 0.5)),
          ),
          child: Row(
            children: [
              // Restore
              Expanded(
                child: _ActionBtn(
                  label: c.selectedIds.isEmpty
                      ? 'Restore'
                      : 'Restore (${c.selectedIds.length})',
                  icon: Icons.restore_rounded,
                  color: Colors.white,
                  onTap: c.selectedIds.isEmpty
                      ? null
                      : () => _confirmRestore(context, c),
                ),
              ),
              const SizedBox(width: 12),
              // Delete
              Expanded(
                child: _ActionBtn(
                  label: c.selectedIds.isEmpty
                      ? 'Delete'
                      : 'Delete (${c.selectedIds.length})',
                  icon: Icons.delete_rounded,
                  color: Colors.redAccent,
                  onTap: c.selectedIds.isEmpty
                      ? null
                      : () => _confirmDelete(context, c),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmRestore(BuildContext ctx, TrashController c) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            const SizedBox(height: 8),
            Text(
              'Restore ${c.selectedIds.length} item(s)?',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'They will be moved back to your gallery.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 20),
            _SheetBtn(
              label: 'Restore',
              color: Colors.white,
              onTap: () { Navigator.pop(ctx); c.restoreSelected(); },
            ),
            _SheetBtn(
              label: 'Cancel',
              color: Colors.white38,
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, TrashController c) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            const SizedBox(height: 8),
            Text(
              'Delete ${c.selectedIds.length} item(s)?',
              style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'This cannot be undone.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 20),
            _SheetBtn(
              label: 'Delete permanently',
              color: Colors.redAccent,
              onTap: () { Navigator.pop(ctx); c.deleteSelected(); },
            ),
            _SheetBtn(
              label: 'Cancel',
              color: Colors.white38,
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  APP BARS
// ══════════════════════════════════════════════════════════════

class _TrashAppBar extends StatelessWidget {
  final TrashController c;
  const _TrashAppBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Recycle Bin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            // Dynamic image / video count
            GetBuilder<TrashController>(
              builder: (c) {
                final imgs = c.imageCount;
                final vids = c.videoCount;
                if (imgs == 0 && vids == 0) {
                  return const SizedBox.shrink();
                }
                final parts = <String>[];
                if (imgs > 0) parts.add('$imgs image${imgs == 1 ? '' : 's'}');
                if (vids > 0) parts.add('$vids video${vids == 1 ? '' : 's'}');
                return Text(
                  parts.join('  ·  '),
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w400),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        // Edit button
        TextButton(
          onPressed: () => c.enterSelectionMode(),
          style: TextButton.styleFrom(
              foregroundColor: AppColors.primary),
          child: const Text('Edit',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500)),
        ),
        // ⋮ more menu
        GetBuilder<TrashController>(
          builder: (c) => c.trashedItems.isEmpty
              ? const SizedBox.shrink()
              : PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                color: Colors.white70),
            color: const Color(0xFF2C2C2E),
            onSelected: (v) {
              if (v == 'empty') {
                _confirmEmptyTrash(context, c);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'empty',
                child: Text('Empty Recycle Bin',
                    style:
                    TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _confirmEmptyTrash(BuildContext context, TrashController c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            const SizedBox(height: 8),
            const Text('Empty Recycle Bin?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'All items will be permanently deleted. This cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white54, fontSize: 14, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
            _SheetBtn(
              label: 'Empty Recycle Bin',
              color: Colors.redAccent,
              onTap: () { Navigator.pop(context); c.emptyTrash(); },
            ),
            _SheetBtn(
              label: 'Cancel',
              color: Colors.white38,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SelectionAppBar extends StatelessWidget {
  final TrashController c;
  const _SelectionAppBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF1A1A1A),
      elevation: 0,
      automaticallyImplyLeading: false,
      title: GetBuilder<TrashController>(
        builder: (c) => Text(
          c.selectedIds.isEmpty
              ? 'Select items'
              : '${c.selectedIds.length} selected',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600),
        ),
      ),
      centerTitle: true,
      leading: TextButton(
        onPressed: c.exitSelectionMode,
        style:
        TextButton.styleFrom(foregroundColor: AppColors.primary),
        child: const Text('Cancel',
            style: TextStyle(fontSize: 15)),
      ),
      actions: [
        GetBuilder<TrashController>(
          builder: (c) => TextButton(
            onPressed: c.toggleSelectAll,
            style: TextButton.styleFrom(
                foregroundColor: AppColors.primary),
            child: Text(
              c.allSelected ? 'Deselect all' : 'All',
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  GRID
// ══════════════════════════════════════════════════════════════

class _TrashGrid extends StatelessWidget {
  final TrashController c;
  final bool selectionMode;
  const _TrashGrid({required this.c, required this.selectionMode});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<TrashController>(
      builder: (c) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(2),
          gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 1.0,
          ),
          itemCount: c.trashedItems.length,
          itemBuilder: (_, i) => _TrashCell(
            trashedItem: c.trashedItems[i],
            c: c,
            selectionMode: selectionMode,
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  CELL
// ══════════════════════════════════════════════════════════════

class _TrashCell extends StatelessWidget {
  final TrashedItem trashedItem;
  final TrashController c;
  final bool selectionMode;

  const _TrashCell({
    required this.trashedItem,
    required this.c,
    required this.selectionMode,
  });

  @override
  Widget build(BuildContext context) {
    final id = trashedItem.item.id;

    return GestureDetector(
      onTap: () {
        if (selectionMode) {
          c.toggleSelection(id);
        } else {
          _showItemOptions(context);
        }
      },
      onLongPress: () {
        if (!selectionMode) {
          c.enterSelectionMode(firstId: id);
        }
      },
      child: GetBuilder<TrashController>(
        builder: (c) {
          final selected =
              selectionMode && c.selectedIds.contains(id);

          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Thumbnail ─────────────────────────────
              _Thumbnail(item: trashedItem.item),

              // ── Selection dim ─────────────────────────
              if (selected)
                Container(color: Colors.black.withOpacity(0.40)),

              // ── Subtle scrim ──────────────────────────
              Container(color: Colors.black.withOpacity(0.10)),

              // ── Video badge ───────────────────────────
              if (trashedItem.item.type == MediaType.video)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: _VideoBadge(
                      duration: trashedItem.item.duration),
                ),

              // ── Days-remaining badge (top-left) ───────
              Positioned(
                top: 5,
                left: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: trashedItem.isExpiringSoon
                        ? Colors.red.withOpacity(0.85)
                        : Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    trashedItem.timeRemainingLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // ── Checkbox (selection mode) ─────────────
              if (selectionMode)
                Positioned(
                  top: 5,
                  right: 5,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? AppColors.primary
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 13)
                        : null,
                  ),
                ),

              // ── Restore quick-action (normal mode) ────
              if (!selectionMode)
                Positioned(
                  bottom: 5,
                  right: 5,
                  child: GestureDetector(
                    onTap: () => c.restoreItem(id),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white30, width: 0.8),
                      ),
                      child: const Icon(Icons.restore_rounded,
                          color: Colors.white, size: 15),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showItemOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            _SheetTile(
              icon: Icons.restore_rounded,
              color: Colors.white,
              label: 'Restore',
              onTap: () {
                Navigator.pop(context);
                c.restoreItem(trashedItem.item.id);
              },
            ),
            _SheetTile(
              icon: Icons.delete_forever_rounded,
              color: Colors.redAccent,
              label: 'Delete permanently',
              onTap: () {
                Navigator.pop(context);
                c.deleteItemPermanently(trashedItem.item.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  THUMBNAIL
// ══════════════════════════════════════════════════════════════

class _Thumbnail extends StatelessWidget {
  final MediaItem item;
  const _Thumbnail({required this.item});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _load(),
      builder: (_, snap) {
        if (snap.hasData && snap.data != null) {
          return Image.memory(snap.data!,
              fit: BoxFit.cover, gaplessPlayback: true);
        }
        return Container(
          color: const Color(0xFF2A2A2A),
          child: const Icon(Icons.image_outlined,
              color: Colors.white12, size: 32),
        );
      },
    );
  }

  Future<Uint8List?> _load() async {
    final asset = await AssetEntity.fromId(item.id);
    return asset?.thumbnailDataWithSize(
        const ThumbnailSize(300, 300));
  }
}

// ══════════════════════════════════════════════════════════════
//  EMPTY STATE
// ══════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final Size sz;
  const _EmptyState({required this.sz});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: sz.height * 0.55,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.delete_outline_rounded,
                size: 72, color: Colors.white12),
            SizedBox(height: 16),
            Text(
              'No recently deleted items',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.white54,
                  fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'Deleted photos and videos\nappear here for 30 days.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.white24,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SHARED MICRO-WIDGETS
// ══════════════════════════════════════════════════════════════

class _VideoBadge extends StatelessWidget {
  final Duration duration;
  const _VideoBadge({required this.duration});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.6),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.play_arrow_rounded,
            color: Colors.white, size: 11),
        const SizedBox(width: 2),
        Text(_fmt(duration),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _ActionBtn(
      {required this.label,
        required this.icon,
        required this.color,
        this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedOpacity(
      opacity: onTap == null ? 0.35 : 1.0,
      duration: const Duration(milliseconds: 180),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color.withOpacity(0.35), width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 4,
    margin: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white12,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _SheetTile(
      {required this.icon,
        required this.color,
        required this.label,
        required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color),
    title: Text(label,
        style: TextStyle(color: color, fontSize: 16)),
    onTap: onTap,
  );
}

class _SheetBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SheetBtn(
      {required this.label,
        required this.color,
        required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding:
    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    child: SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w500)),
      ),
    ),
  );
}