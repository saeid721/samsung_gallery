
import 'dart:convert';
import 'package:get/get.dart';

import '../../../core/services/secure_storage_service.dart';
import '../../../data/models/media_model.dart';
import '../../../data/repositories/media_repository.dart';

// ── Models ─────────────────────────────────────────────────────

class SharedAlbumMember {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final int     photoCount;
  final bool    isOwner;

  const SharedAlbumMember({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.photoCount,
    required this.isOwner,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'avatarUrl': avatarUrl,
    'photoCount': photoCount,
    'isOwner': isOwner,
  };

  factory SharedAlbumMember.fromJson(Map<String, dynamic> j) =>
      SharedAlbumMember(
        id:         j['id'] as String,
        name:       j['name'] as String,
        email:      j['email'] as String,
        avatarUrl:  j['avatarUrl'] as String?,
        photoCount: j['photoCount'] as int,
        isOwner:    j['isOwner'] as bool,
      );
}

class SharedAlbum {
  final String                id;
  final String                name;
  final String                ownerId;
  final bool                  isOwner;
  final List<MediaItem>       items;
  final List<SharedAlbumMember> members;
  final DateTime              createdAt;
  final DateTime              updatedAt;
  final bool                  allowContributions;
  final String?               inviteLink;

  const SharedAlbum({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.isOwner,
    required this.items,
    required this.members,
    required this.createdAt,
    required this.updatedAt,
    this.allowContributions = true,
    this.inviteLink,
  });

  int get photoCount => items.length;
  int get memberCount => members.length;

  MediaItem? get coverItem => items.isNotEmpty ? items.first : null;

  SharedAlbum copyWith({
    String? name,
    bool? allowContributions,
  }) => SharedAlbum(
    id:                 id,
    name:               name ?? this.name,
    ownerId:            ownerId,
    isOwner:            isOwner,
    items:              items,
    members:            members,
    createdAt:          createdAt,
    updatedAt:          DateTime.now(),
    allowContributions: allowContributions ?? this.allowContributions,
    inviteLink:         inviteLink,
  );
}

// ── Controller ─────────────────────────────────────────────────

class SharedAlbumsController extends GetxController {
  final MediaRepository      _repo    = Get.find<MediaRepository>();
  final SecureStorageService _storage = Get.find<SecureStorageService>();

  static const _kAlbums = 'shared_albums.list';

  // ── State ─────────────────────────────────────────────────────
  final RxList<SharedAlbum> albums          = <SharedAlbum>[].obs;
  final RxBool              isLoading       = true.obs;
  final Rx<SharedAlbum?>    activeAlbum     = Rx(null);
  final RxBool              isCreating      = false.obs;
  final RxString            createError     = ''.obs;

  // Invite flow
  final RxBool              showInviteSheet = false.obs;
  final RxString            copiedLink      = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  // ── Load ──────────────────────────────────────────────────────
  Future<void> _load() async {
    isLoading.value = true;
    try {
      final cached = await _loadCached();
      albums.assignAll(cached);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() => _load();

  // ── Create ────────────────────────────────────────────────────
  Future<SharedAlbum?> createAlbum({
    required String name,
    List<MediaItem> initialItems = const [],
  }) async {
    if (name.trim().isEmpty) {
      createError.value = 'Album name cannot be empty';
      return null;
    }
    isCreating.value = true;
    createError.value = '';
    try {
      final album = SharedAlbum(
        id:                 'sa_${DateTime.now().millisecondsSinceEpoch}',
        name:               name.trim(),
        ownerId:            'me',
        isOwner:            true,
        items:              initialItems,
        members:            [
          SharedAlbumMember(
            id:         'me',
            name:       'You',
            email:      '',
            photoCount: initialItems.length,
            isOwner:    true,
          )
        ],
        createdAt:          DateTime.now(),
        updatedAt:          DateTime.now(),
        allowContributions: true,
        inviteLink:
        'https://gallery.app/share/${_generateCode()}',
      );
      albums.insert(0, album);
      await _saveCache();
      return album;
    } finally {
      isCreating.value = false;
    }
  }

  // ── Delete / Leave ────────────────────────────────────────────
  Future<void> deleteAlbum(String albumId) async {
    albums.removeWhere((a) => a.id == albumId);
    if (activeAlbum.value?.id == albumId) activeAlbum.value = null;
    await _saveCache();
  }

  Future<void> leaveAlbum(String albumId) async {
    // Non-owner leaves — in production: API call
    albums.removeWhere((a) => a.id == albumId);
    if (activeAlbum.value?.id == albumId) activeAlbum.value = null;
    await _saveCache();
  }

  // ── Toggle contributions ──────────────────────────────────────
  Future<void> toggleContributions(String albumId) async {
    final i = albums.indexWhere((a) => a.id == albumId);
    if (i < 0) return;
    final updated = albums[i].copyWith(
        allowContributions: !albums[i].allowContributions);
    albums[i] = updated;
    if (activeAlbum.value?.id == albumId) {
      activeAlbum.value = updated;
    }
    await _saveCache();
  }

  // ── Rename ────────────────────────────────────────────────────
  Future<void> renameAlbum(String albumId, String newName) async {
    if (newName.trim().isEmpty) return;
    final i = albums.indexWhere((a) => a.id == albumId);
    if (i < 0) return;
    final updated = albums[i].copyWith(name: newName.trim());
    albums[i] = updated;
    if (activeAlbum.value?.id == albumId) {
      activeAlbum.value = updated;
    }
    await _saveCache();
  }

  // ── Navigation ────────────────────────────────────────────────
  void openAlbum(SharedAlbum album) => activeAlbum.value = album;
  void closeAlbum() => activeAlbum.value = null;

  void copyInviteLink(SharedAlbum album) {
    if (album.inviteLink == null) return;
    // Clipboard.setData(ClipboardData(text: album.inviteLink!));
    copiedLink.value = album.inviteLink!;
    Future.delayed(const Duration(seconds: 2), () {
      copiedLink.value = '';
    });
  }

  // ── Computed getters ──────────────────────────────────────────
  List<SharedAlbum> get ownedAlbums =>
      albums.where((a) => a.isOwner).toList();

  List<SharedAlbum> get joinedAlbums =>
      albums.where((a) => !a.isOwner).toList();

  // ── Persistence ───────────────────────────────────────────────
  Future<List<SharedAlbum>> _loadCached() async {
    // In production this is synced from server; for now returns []
    // (full impl persists album metadata, re-hydrates MediaItems
    // from MediaRepository by stored asset IDs)
    return [];
  }

  Future<void> _saveCache() async {
    // Persist album metadata (without MediaItem objects)
    final json = albums.map((a) => {
      'id':                 a.id,
      'name':               a.name,
      'ownerId':            a.ownerId,
      'isOwner':            a.isOwner,
      'memberCount':        a.memberCount,
      'photoCount':         a.photoCount,
      'createdAt':          a.createdAt.toIso8601String(),
      'allowContributions': a.allowContributions,
      'inviteLink':         a.inviteLink,
    }).toList();
    await _storage.write(_kAlbums, jsonEncode(json));
  }

  String _generateCode() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36);
}