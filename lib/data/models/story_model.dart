import 'media_model.dart';

class StoryModel {
  final String previewPath;   // Low-res preview
  final String finalPath;     // Full-resolution render
  final List<String> mediaIds; // Media used in story
  StoryModel({
    required this.previewPath,
    required this.finalPath,
    required this.mediaIds,
  });
}

class StoryService {
  /// Generate a story from a list of media
  Future<StoryModel> generateStory(List<MediaItem> mediaList) async {
    // Step 1: Select highlights (faces, smiles, objects)
    final highlights = _selectHighlights(mediaList);

    // Step 2: Render low-res preview
    final previewPath = await _renderSlideshow(highlights, lowRes: true);

    // Step 3: Render full story on demand
    final finalPath = await _renderSlideshow(highlights, lowRes: false);

    // Step 4: Return StoryModel
    return StoryModel(
      previewPath: previewPath,
      finalPath: finalPath,
      mediaIds: highlights.map((m) => m.id).toList(),
    );
  }

  /// Select highlights (pseudo)
  List<MediaItem> _selectHighlights(List<MediaItem> mediaList) {
    // Example: prioritize photos with faces / smiles / AI tags
    return mediaList.take(10).toList(); // temporary
  }

  /// Render slideshow (pseudo)
  Future<String> _renderSlideshow(List<MediaItem> mediaList, {bool lowRes = true}) async {
    // TODO: integrate video generator (ffmpeg / flutter_video_editor)
    // Return path to preview or full-res video
    await Future.delayed(const Duration(seconds: 1)); // simulate rendering
    return "/tmp/story_${lowRes ? 'preview' : 'final'}.mp4";
  }
}