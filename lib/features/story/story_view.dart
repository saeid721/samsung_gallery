import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../data/models/story_model.dart';
import '../../features/story/controllers/story_controller.dart';
import '../../shared/widgets/navigation_menu/app_bottom_nav.dart';
import '../../shared/widgets/navigation_menu/bottom_nav_controller.dart';

class StoryView extends GetView<StoryController> {
  const StoryView({super.key});

  void onInit() {
    // Initialize in the next frame to avoid build phase conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<BottomNavController>().markTab(BottomNavTab.albums);
      controller.loadStories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stories'),
        elevation: 2,
        actions: [
          Obx(() => controller.isGenerating.value
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white30),
          )
              : _IconChip(
            icon: Icons.auto_awesome_rounded,
            label: 'Suggest',
            onTap: controller.generateSuggestions,
          )),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: const Color(0xFF1C1C1E),
        onRefresh: controller.loadStories,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          child: Padding(
            padding: EdgeInsets.only(top: top),
            child: Column(
              children: [
                // ── Suggestions row ──────────────────────────────
                Obx(() {
                  if (controller.suggestions.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return _SuggestionsRow(c: controller);
                }),

                // ── Stories list ──────────────────────────────────
                Obx(() {
                  if (controller.isLoading.value) {
                    return const _ShimmerList();
                  }
                  if (controller.error.value.isNotEmpty) {
                    return _ErrorState(
                        message: controller.error.value, onRetry: controller.loadStories);
                  }
                  if (controller.stories.isEmpty) {
                    return const _EmptyState();
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 60),
                    child: Column(
                      children: controller.stories
                          .map((story) => _StoryCard(story: story, controller: controller))
                          .toList(),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _IconChip(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 15),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Suggestions row ───────────────────────────────────────────

class _SuggestionsRow extends StatelessWidget {
  final StoryController c;
  const _SuggestionsRow({required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Text(
            'Suggested for you',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: c.suggestions.length,
            itemBuilder: (_, i) =>
                _SuggestionCard(story: c.suggestions[i], c: c),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(color: Colors.white10, height: 1),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final StoryModel story;
  final StoryController c;
  const _SuggestionCard({required this.story, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Photo(id: story.coverAssetId, thumbSize: 200),
                  // Gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  // Dismiss
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => c.dismissSuggestion(story),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white70, size: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            story.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
          Text(
            '${story.photoCount} photos',
            style: const TextStyle(color: Colors.white30, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Story card (main list) ────────────────────────────────────

class _StoryCard extends StatelessWidget {
  final StoryModel story;
  final StoryController controller;
  const _StoryCard({required this.story, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => controller.openPlayer(story),
        onLongPress: () => _showOptions(context),
        child: SizedBox(
          height: 280,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Cover image
                _Photo(id: story.coverAssetId, thumbSize: 600),

                // 2. Dual gradient overlay
                _Gradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    startOpacity: 0.45),
                _Gradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    startOpacity: 0.78),

                // 3. Story type badge — top left
                Positioned(
                  top: 12,
                  left: 12,
                  child: _TypeBadge(story: story),
                ),

                // 4. Options — top right
                Positioned(
                  top: 6,
                  right: 6,
                  child: _CircleIconBtn(
                    icon: Icons.more_vert_rounded,
                    onTap: () => _showOptions(context),
                  ),
                ),

                // 5. Centered play button
                const Center(
                  child: _PlayButton(size: 60),
                ),

                // 6. Text block — bottom
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // photo count pill
                      _MetaPill(story.summaryLabel),
                      const SizedBox(height: 6),
                      // title
                      Text(
                        story.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          height: 1.18,
                          shadows: [
                            Shadow(blurRadius: 14, color: Colors.black87)
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      // date range
                      if (story.dateRangeLabel.isNotEmpty)
                        Text(
                          story.dateRangeLabel,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12.5,
                            shadows: [
                              Shadow(blurRadius: 8, color: Colors.black87)
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child:
                      _Photo(id: story.coverAssetId, thumbSize: 100),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(story.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        Text(story.summaryLabel,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            _SheetTile(
              icon: Icons.play_circle_outline_rounded,
              color: Colors.white,
              label: 'Play',
              onTap: () {
                Navigator.pop(context);
                controller.openPlayer(story);
              },
            ),
            _SheetTile(
              icon: Icons.drive_file_rename_outline_rounded,
              color: Colors.white,
              label: 'Rename',
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context);
              },
            ),
            _SheetTile(
              icon: Icons.share_outlined,
              color: Colors.white,
              label: 'Share',
              onTap: () => Navigator.pop(context),
            ),
            const Divider(color: Colors.white10, height: 1),
            _SheetTile(
              icon: Icons.delete_outline_rounded,
              color: Colors.redAccent,
              label: 'Delete story',
              onTap: () {
                Navigator.pop(context);
                controller.deleteStory(story.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final tc = TextEditingController(text: story.title);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Rename story',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: tc,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Story name',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF1259C3))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              controller.renameStory(story.id, tc.text);
              Get.back();
            },
            child: const Text('Save',
                style: TextStyle(color: Color(0xFF1259C3))),
          ),
        ],
      ),
    );
  }
}

// ── Card sub-widgets ───────────────────────────────────────────

class _Gradient extends StatelessWidget {
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final double startOpacity;
  const _Gradient(
      {required this.begin,
        required this.end,
        required this.startOpacity});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: begin,
        end: end,
        colors: [
          Colors.black.withOpacity(startOpacity),
          Colors.transparent,
        ],
      ),
    ),
  );
}

class _TypeBadge extends StatelessWidget {
  final StoryModel story;
  const _TypeBadge({required this.story});

  String get _label => switch (story.transition) {
    StoryTransition.fade => 'Story',
    StoryTransition.slide => 'Story',
    StoryTransition.zoom => 'Story',
    StoryTransition.dissolve => 'Story',
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white24, width: 0.8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.auto_stories_rounded,
            color: Colors.white70, size: 12),
        const SizedBox(width: 4),
        Text(_label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3)),
      ],
    ),
  );
}

class _PlayButton extends StatelessWidget {
  final double size;
  const _PlayButton({required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white60, width: 1.8),
    ),
    child: Icon(Icons.play_arrow_rounded,
        color: Colors.white, size: size * 0.55),
  );
}

class _MetaPill extends StatelessWidget {
  final String label;
  const _MetaPill(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.45),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label,
        style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500)),
  );
}

class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.40),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white70, size: 18),
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

// ── Ken Burns animated photo ─────────────────────────────────

/// Photo with subtle Ken Burns (slow zoom) effect.
class _KenBurnsPhoto extends StatefulWidget {
  final String assetId;
  final Duration duration;
  const _KenBurnsPhoto(
      {super.key, required this.assetId, required this.duration});

  @override
  State<_KenBurnsPhoto> createState() => _KenBurnsPhotoState();
}

class _KenBurnsPhotoState extends State<_KenBurnsPhoto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: widget.duration + const Duration(seconds: 1));
    _scale = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.linear));
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: _Photo(
        key: ValueKey(widget.assetId),
        id: widget.assetId,
        fullRes: true,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// EMPTY / ERROR / LOADING STATES
// ══════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.of(context).size.height * 0.7,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_stories_rounded,
                  size: 44, color: Colors.white24),
            ),
            const SizedBox(height: 28),
            const Text('No stories yet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3)),
            const SizedBox(height: 12),
            const Text(
              'Create a story from your favourite photos, or tap "Suggest" to let us make one for you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 15,
                  height: 1.6),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.of(context).size.height * 0.7,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white30, size: 52),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 14)),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry',
                  style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Column(
      children: List.generate(
        3,
            (_) => Container(
          height: 275,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.05),
          ),
        ),
      ),
    ),
  );
}

class _CreateStorySheet extends StatefulWidget {
  final StoryController c;
  const _CreateStorySheet({required this.c});

  @override
  State<_CreateStorySheet> createState() => _CreateStorySheetState();
}

class _CreateStorySheetState extends State<_CreateStorySheet> {
  final _tc = TextEditingController();
  StoryTransition _transition = StoryTransition.fade;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, kb + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text('New Story',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          // Name input
          TextField(
            controller: _tc,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Story name',
              hintStyle: TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Color(0xFF2C2C2E),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Transition picker
          const Text('Transition',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: StoryTransition.values.map((t) {
              final selected = _transition == t;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _transition = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 6),
                    padding:
                    const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1259C3)
                          : const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      t.name[0].toUpperCase() + t.name.substring(1),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: selected
                              ? Colors.white
                              : Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1259C3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Navigator.pop(context);
                Get.snackbar(
                  'Story',
                  'Select photos from Gallery to add to your story.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: const Color(0xFF1C1C1E),
                  colorText: Colors.white,
                );
              },
              child: const Text('Continue',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHARED — ASYNC PHOTO WIDGET
// ══════════════════════════════════════════════════════════════

class _Photo extends StatelessWidget {
  final String id;
  final bool fullRes;
  final int thumbSize;

  const _Photo({
    super.key,
    required this.id,
    this.fullRes = false,
    this.thumbSize = 420,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _load(),
      builder: (_, snap) {
        if (snap.hasData && snap.data != null) {
          return Image.memory(
            snap.data!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        }
        return ColoredBox(color: Colors.white.withOpacity(0.05));
      },
    );
  }

  Future<Uint8List?> _load() async {
    final asset = await AssetEntity.fromId(id);
    if (asset == null) return null;
    if (fullRes) return asset.originBytes;
    return asset.thumbnailDataWithSize(
        ThumbnailSize(thumbSize, thumbSize));
  }
}