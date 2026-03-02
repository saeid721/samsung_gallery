
import 'dart:io';
import '../../data/models/media_model.dart';

class StoryService {
  Future<String> generateStory(List<MediaItem> mediaList, String albumPath) async {
    final storyFolder = Directory('$albumPath/.stories');
    if (!await storyFolder.exists()) await storyFolder.create();

    final previewPath = '${storyFolder.path}/preview_${DateTime.now().millisecondsSinceEpoch}.mp4';
    await File(previewPath).writeAsBytes([]); // placeholder
    return previewPath;
  }
}