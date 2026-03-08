
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../app/theme/theme.dart';
import '../../data/models/media_model.dart';
import 'controllers/suggestions_controller.dart';

class SuggestionsView extends GetView<SuggestionsController> {
  const SuggestionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
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
                  Text('Suggestions',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                  Text('Personalized for you',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white54),
              onPressed: controller.refresh,
            ),
          ]),
        ),

        // Cards
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const _LoadingState();
            }
            if (controller.cards.isEmpty) {
              return const _EmptyState();
            }
            return RefreshIndicator(
              onRefresh: controller.refresh,
              color: AppColors.primary,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                itemCount: controller.cards.length,
                itemBuilder: (_, i) => _SuggestionCard(
                  card: controller.cards[i],
                  c: controller,
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final SuggestionCard card;
  final SuggestionsController c;
  const _SuggestionCard({required this.card, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: card.accentColor.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: icon + title + dismiss ───────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 10),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: card.accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(card.icon,
                    color: card.accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(card.subtitle,
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white30, size: 18),
                onPressed: () => c.dismiss(card.id),
              ),
            ]),
          ),

          // ── Photo previews ─────────────────────────────
          if (card.previewItems.isNotEmpty)
            _PhotoStrip(items: card.previewItems),

          // ── Action button ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: card.accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => c.executeAction(card),
                child: Text(card.actionLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  final List<MediaItem> items;
  const _PhotoStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    final count = items.length.clamp(0, 4);
    return SizedBox(
      height: 90,
      child: Row(
        children: List.generate(count, (i) {
          final isLast = i == count - 1;
          return Expanded(
            child: Container(
              margin: EdgeInsets.fromLTRB(
                  i == 0 ? 16 : 3, 0, isLast ? 16 : 0, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withOpacity(0.05),
              ),
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<Uint8List?>(
                future: _thumb(items[i].id),
                builder: (_, snap) => snap.hasData
                    ? Image.memory(snap.data!,
                    fit: BoxFit.cover)
                    : const SizedBox.shrink(),
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<Uint8List?> _thumb(String id) async {
    final a = await AssetEntity.fromId(id);
    return a?.thumbnailDataWithSize(
        const ThumbnailSize(200, 200));
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: List.generate(
      3,
          (_) => Container(
        height: 220,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lightbulb_outline_rounded,
            size: 64, color: Colors.white24),
        SizedBox(height: 16),
        Text('All caught up!',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        SizedBox(height: 8),
        Text('No suggestions right now.\nCheck back later.',
            textAlign: TextAlign.center,
            style:
            TextStyle(color: Colors.white38, height: 1.5)),
      ],
    ),
  );
}