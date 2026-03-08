
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../app/theme/theme.dart';
import 'controllers/shared_albums_controller.dart';

class SharedAlbumsView extends GetView<SharedAlbumsController> {
  const SharedAlbumsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() => controller.activeAlbum.value != null
        ? _AlbumDetailScreen(c: controller)
        : _SharedAlbumsListScreen(c: controller));
  }
}

// ══════════════════════════════════════════════════════════════
// SHARED ALBUMS LIST
// ══════════════════════════════════════════════════════════════
class _SharedAlbumsListScreen extends StatelessWidget {
  final SharedAlbumsController c;
  const _SharedAlbumsListScreen({required this.c});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('New Shared Album',
              style: TextStyle(color: Colors.white)),
          onPressed: () => _showCreateDialog(context, c),
        ),
        body: Column(children: [
          // Header
          Container(
            color: const Color(0xFF0F0F0F),
            padding: EdgeInsets.fromLTRB(4, top + 8, 16, 12),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Get.back(),
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Shared Albums',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700)),
                    Text('Share photos with friends & family',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            ]),
          ),

          // Body
          Expanded(
              child: Obx(() {
                if (c.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2),
                  );
                }

                if (c.albums.isEmpty) {
                  return _EmptyState(
                      onCreate: () => _showCreateDialog(context, c));
                }

                return RefreshIndicator(
                  onRefresh: c.refresh,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    children: [
                      // Owned albums
                      if (c.ownedAlbums.isNotEmpty) ...[
                        _SectionHeader('Your Albums',
                            count: c.ownedAlbums.length),
                        const SizedBox(height: 8),
                        ...c.ownedAlbums.map(
                                (a) => _AlbumTile(album: a, c: c)),
                        const SizedBox(height: 20),
                      ],

                      // Joined albums
                      if (c.joinedAlbums.isNotEmpty) ...[
                        _SectionHeader('Joined Albums',
                            count: c.joinedAlbums.length),
                        const SizedBox(height: 8),
                        ...c.joinedAlbums.map(
                                (a) => _AlbumTile(album: a, c: c)),
                      ],
                    ],
                  ),
                );
              },
              ),
          ),
              ],
        ),
    );
    }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader(this.title, {required this.count});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(title,
        style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3)),
    const SizedBox(width: 6),
    Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count',
          style: const TextStyle(
              color: Colors.white38, fontSize: 11)),
    ),
  ]);
}

class _AlbumTile extends StatelessWidget {
  final SharedAlbum album;
  final SharedAlbumsController c;
  const _AlbumTile({required this.album, required this.c});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => c.openAlbum(album),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(children: [
          // Cover thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 72, height: 72,
              child: album.coverItem != null
                  ? FutureBuilder<Uint8List?>(
                future: () async {
                  final a = await AssetEntity.fromId(
                      album.coverItem!.id);
                  return a?.thumbnailDataWithSize(
                      const ThumbnailSize(144, 144));
                }(),
                builder: (_, snap) => snap.hasData
                    ? Image.memory(snap.data!,
                    fit: BoxFit.cover)
                    : _PlaceholderCover(),
              )
                  : _PlaceholderCover(),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(album.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (album.isOwner)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Owner',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(
                  '${album.photoCount} photos · '
                      '${album.memberCount} member${album.memberCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 6),
                // Member avatars row
                _MemberAvatars(members: album.members),
              ],
            ),
          ),

          const Icon(Icons.chevron_right_rounded,
              color: Colors.white24, size: 20),
        ]),
      ),
    );
  }
}

class _MemberAvatars extends StatelessWidget {
  final List<SharedAlbumMember> members;
  const _MemberAvatars({required this.members});

  @override
  Widget build(BuildContext context) {
    final show = members.take(3).toList();
    return SizedBox(
      height: 22,
      child: Stack(
        children: List.generate(show.length, (i) {
          return Positioned(
            left: i * 16.0,
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: _color(i),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF1A1A1A), width: 1.5),
              ),
              child: Center(
                child: Text(
                  show[i].name.isNotEmpty
                      ? show[i].name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Color _color(int i) => const [
    Color(0xFF1259C3),
    Color(0xFF30D158),
    Color(0xFFFF9F0A),
  ][i % 3];
}

class _PlaceholderCover extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white.withOpacity(0.07),
    child: const Icon(Icons.photo_library_outlined,
        color: Colors.white24, size: 28),
  );
}

// ══════════════════════════════════════════════════════════════
// ALBUM DETAIL SCREEN
// ══════════════════════════════════════════════════════════════
class _AlbumDetailScreen extends StatelessWidget {
  final SharedAlbumsController c;
  const _AlbumDetailScreen({required this.c});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async { c.closeAlbum(); return false; },
      child: Obx(() {
        final album = c.activeAlbum.value;
        if (album == null) return const SizedBox.shrink();

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          body: CustomScrollView(
            slivers: [
              // App bar
              SliverAppBar(
                backgroundColor: const Color(0xFF0F0F0F),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
                  onPressed: c.closeAlbum,
                ),
                title: Text(album.name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.w700)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.more_vert,
                        color: Colors.white),
                    onPressed: () => _showOptions(context, album),
                  ),
                ],
                pinned: true,
              ),

              // Info bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(children: [
                    // Stats
                    Row(children: [
                      _InfoChip(Icons.photo_outlined,
                          '${album.photoCount} photos'),
                      const SizedBox(width: 10),
                      _InfoChip(Icons.people_outline_rounded,
                          '${album.memberCount} members'),
                      const Spacer(),
                      // Invite link button
                      if (album.isOwner)
                        Obx(() => GestureDetector(
                          onTap: () => c.copyInviteLink(album),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius:
                              BorderRadius.circular(20),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    c.copiedLink.value.isNotEmpty
                                        ? Icons.check
                                        : Icons.link_rounded,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    c.copiedLink.value.isNotEmpty
                                        ? 'Copied!'
                                        : 'Invite',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ]),
                          ),
                        )),
                    ]),

                    const SizedBox(height: 14),

                    // Members list
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Members',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          ...album.members.map((m) => Padding(
                            padding: const EdgeInsets.only(
                                bottom: 8),
                            child: Row(children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                AppColors.primary
                                    .withOpacity(0.3),
                                child: Text(
                                  m.name.isNotEmpty
                                      ? m.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  m.isOwner
                                      ? '${m.name} (Owner)'
                                      : m.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13),
                                ),
                              ),
                              Text('${m.photoCount} photos',
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11)),
                            ]),
                          )),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),

              // Photos grid
              if (album.items.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 48, color: Colors.white24),
                        SizedBox(height: 12),
                        Text('No photos yet',
                            style: TextStyle(
                                color: Colors.white38)),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(2),
                  sliver: SliverGrid(
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    delegate: SliverChildBuilderDelegate(
                          (_, i) {
                        final item = album.items[i];
                        return GestureDetector(
                          onTap: () => Get.toNamed('/viewer',
                              arguments: {'mediaItem': item}),
                          child: FutureBuilder<Uint8List?>(
                            future: () async {
                              final a =
                              await AssetEntity.fromId(item.id);
                              return a?.thumbnailDataWithSize(
                                  const ThumbnailSize(300, 300));
                            }(),
                            builder: (_, snap) => snap.hasData
                                ? Image.memory(snap.data!,
                                fit: BoxFit.cover)
                                : Container(
                                color: Colors.white
                                    .withOpacity(0.05)),
                          ),
                        );
                      },
                      childCount: album.items.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  void _showOptions(BuildContext context, SharedAlbum album) {
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
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2)),
            ),
            if (album.isOwner) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined,
                    color: Colors.white),
                title: const Text('Rename Album',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(context, album);
                },
              ),
              ListTile(
                leading: Icon(
                  album.allowContributions
                      ? Icons.lock_outline
                      : Icons.lock_open_outlined,
                  color: Colors.white,
                ),
                title: Text(
                  album.allowContributions
                      ? 'Disable Contributions'
                      : 'Enable Contributions',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  c.toggleContributions(album.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent),
                title: const Text('Delete Album',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  c.deleteAlbum(album.id);
                },
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.exit_to_app_rounded,
                    color: Colors.redAccent),
                title: const Text('Leave Album',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  c.leaveAlbum(album.id);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, SharedAlbum album) {
    final textCtrl = TextEditingController(text: album.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Rename Album',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Album name',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              c.renameAlbum(album.id, textCtrl.text);
            },
            child: const Text('Save',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Colors.white38, size: 14),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              color: Colors.white38, fontSize: 12)),
    ],
  );
}

// ── Create album dialog ───────────────────────────────────────
void _showCreateDialog(
    BuildContext context, SharedAlbumsController c) {
  final textCtrl = TextEditingController();
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      title: const Text('New Shared Album',
          style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: textCtrl,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Album name (e.g. "Summer Trip")',
          hintStyle: TextStyle(color: Colors.white38),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: Colors.white54)),
        ),
        Obx(() => TextButton(
          onPressed: c.isCreating.value
              ? null
              : () async {
            final album = await c.createAlbum(
                name: textCtrl.text);
            Navigator.pop(context);
            if (album != null) c.openAlbum(album);
          },
          child: c.isCreating.value
              ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary))
              : const Text('Create',
              style:
              TextStyle(color: AppColors.primary)),
        )),
      ],
    ),
  );
}

// ── Empty state ───────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.group_outlined,
                size: 44,
                color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          const Text('No Shared Albums',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          const Text(
            'Create a shared album to collaborate on photos with friends and family.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white38,
                height: 1.6,
                fontSize: 14),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Create Shared Album'),
            onPressed: onCreate,
          ),
        ],
      ),
    ),
  );
}