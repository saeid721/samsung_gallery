// ============================================================
// features/settings/controllers/settings_controller.dart
// ============================================================
// Manages all app settings, persisted to SecureStorageService.
//
// SECTIONS:
//   • Appearance    — theme, grid density, date format
//   • Privacy       — secure folder lock type, biometrics
//   • Storage       — auto-delete trash, cache management
//   • Backup        — Google Photos sync settings
//   • Memories      — generation frequency, notification
//   • About         — version, feedback, licenses
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/secure_storage_service.dart';
import '../../../core/services/thumbnail_cache_service.dart';

enum AppThemeMode { system, light, dark }
enum GridDensity  { compact, normal, large }
enum DateFormat   { relative, absolute, both }
enum LockType     { pin, biometric, pattern }
enum AutoDeletePeriod { never, days30, days7, immediately }

class AppSettings {
  // Appearance
  final AppThemeMode themeMode;
  final GridDensity  gridDensity;
  final DateFormat   dateFormat;
  final bool         showVideoDuration;
  final bool         showFileSize;

  // Privacy
  final bool         secureFolderEnabled;
  final LockType     lockType;
  final bool         hideInRecentApps;

  // Storage
  final AutoDeletePeriod autoDeleteTrash;
  final bool             saveEditsAsNewFile;
  final bool             includeMetadataOnShare;

  // Backup
  final bool   autoBackup;
  final bool   backupOnWifiOnly;
  final bool   backupVideos;

  // Memories
  final bool   generateMemories;
  final bool   memoriesNotification;

  // Notifications
  final bool   shareNotifications;
  final bool   backupNotifications;

  const AppSettings({
    this.themeMode             = AppThemeMode.system,
    this.gridDensity           = GridDensity.normal,
    this.dateFormat            = DateFormat.relative,
    this.showVideoDuration     = true,
    this.showFileSize          = false,
    this.secureFolderEnabled   = false,
    this.lockType              = LockType.biometric,
    this.hideInRecentApps      = true,
    this.autoDeleteTrash       = AutoDeletePeriod.days30,
    this.saveEditsAsNewFile    = true,
    this.includeMetadataOnShare = false,
    this.autoBackup            = false,
    this.backupOnWifiOnly      = true,
    this.backupVideos          = false,
    this.generateMemories      = true,
    this.memoriesNotification  = true,
    this.shareNotifications    = true,
    this.backupNotifications   = true,
  });

  AppSettings copyWith({
    AppThemeMode?      themeMode,
    GridDensity?       gridDensity,
    DateFormat?        dateFormat,
    bool?              showVideoDuration,
    bool?              showFileSize,
    bool?              secureFolderEnabled,
    LockType?          lockType,
    bool?              hideInRecentApps,
    AutoDeletePeriod?  autoDeleteTrash,
    bool?              saveEditsAsNewFile,
    bool?              includeMetadataOnShare,
    bool?              autoBackup,
    bool?              backupOnWifiOnly,
    bool?              backupVideos,
    bool?              generateMemories,
    bool?              memoriesNotification,
    bool?              shareNotifications,
    bool?              backupNotifications,
  }) => AppSettings(
    themeMode:              themeMode             ?? this.themeMode,
    gridDensity:            gridDensity           ?? this.gridDensity,
    dateFormat:             dateFormat            ?? this.dateFormat,
    showVideoDuration:      showVideoDuration     ?? this.showVideoDuration,
    showFileSize:           showFileSize          ?? this.showFileSize,
    secureFolderEnabled:    secureFolderEnabled   ?? this.secureFolderEnabled,
    lockType:               lockType              ?? this.lockType,
    hideInRecentApps:       hideInRecentApps      ?? this.hideInRecentApps,
    autoDeleteTrash:        autoDeleteTrash       ?? this.autoDeleteTrash,
    saveEditsAsNewFile:     saveEditsAsNewFile    ?? this.saveEditsAsNewFile,
    includeMetadataOnShare: includeMetadataOnShare ?? this.includeMetadataOnShare,
    autoBackup:             autoBackup            ?? this.autoBackup,
    backupOnWifiOnly:       backupOnWifiOnly      ?? this.backupOnWifiOnly,
    backupVideos:           backupVideos          ?? this.backupVideos,
    generateMemories:       generateMemories      ?? this.generateMemories,
    memoriesNotification:   memoriesNotification  ?? this.memoriesNotification,
    shareNotifications:     shareNotifications    ?? this.shareNotifications,
    backupNotifications:    backupNotifications   ?? this.backupNotifications,
  );

  Map<String, dynamic> toJson() => {
    'themeMode':              themeMode.index,
    'gridDensity':            gridDensity.index,
    'dateFormat':             dateFormat.index,
    'showVideoDuration':      showVideoDuration,
    'showFileSize':           showFileSize,
    'secureFolderEnabled':    secureFolderEnabled,
    'lockType':               lockType.index,
    'hideInRecentApps':       hideInRecentApps,
    'autoDeleteTrash':        autoDeleteTrash.index,
    'saveEditsAsNewFile':     saveEditsAsNewFile,
    'includeMetadataOnShare': includeMetadataOnShare,
    'autoBackup':             autoBackup,
    'backupOnWifiOnly':       backupOnWifiOnly,
    'backupVideos':           backupVideos,
    'generateMemories':       generateMemories,
    'memoriesNotification':   memoriesNotification,
    'shareNotifications':     shareNotifications,
    'backupNotifications':    backupNotifications,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    themeMode:              AppThemeMode.values[j['themeMode'] ?? 0],
    gridDensity:            GridDensity.values[j['gridDensity'] ?? 1],
    dateFormat:             DateFormat.values[j['dateFormat'] ?? 0],
    showVideoDuration:      j['showVideoDuration'] ?? true,
    showFileSize:           j['showFileSize'] ?? false,
    secureFolderEnabled:    j['secureFolderEnabled'] ?? false,
    lockType:               LockType.values[j['lockType'] ?? 1],
    hideInRecentApps:       j['hideInRecentApps'] ?? true,
    autoDeleteTrash:        AutoDeletePeriod.values[j['autoDeleteTrash'] ?? 1],
    saveEditsAsNewFile:     j['saveEditsAsNewFile'] ?? true,
    includeMetadataOnShare: j['includeMetadataOnShare'] ?? false,
    autoBackup:             j['autoBackup'] ?? false,
    backupOnWifiOnly:       j['backupOnWifiOnly'] ?? true,
    backupVideos:           j['backupVideos'] ?? false,
    generateMemories:       j['generateMemories'] ?? true,
    memoriesNotification:   j['memoriesNotification'] ?? true,
    shareNotifications:     j['shareNotifications'] ?? true,
    backupNotifications:    j['backupNotifications'] ?? true,
  );
}

class SettingsController extends GetxController {
  final SecureStorageService  _storage      = Get.find<SecureStorageService>();
  final ThumbnailCacheService _cacheService = Get.find<ThumbnailCacheService>();

  static const _kSettings = 'app.settings';

  // ── State ─────────────────────────────────────────────────────
  final Rx<AppSettings> settings     = const AppSettings().obs;
  final RxBool          isLoading    = true.obs;
  final RxInt           cacheSizeMB  = 0.obs;
  final RxBool          isClearing   = false.obs;

  // App version info
  static const appVersion    = '1.0.0';
  static const buildNumber   = '42';

  @override
  void onInit() {
    super.onInit();
    _load();
    _calcCacheSize();
  }

  // ── Load & Save ───────────────────────────────────────────────
  Future<void> _load() async {
    isLoading.value = true;
    try {
      final raw = await _storage.read(_kSettings);
      if (raw != null) {
        settings.value =
            AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _save() async {
    await _storage.write(
        _kSettings, jsonEncode(settings.value.toJson()));
  }

  // ── Generic setter ────────────────────────────────────────────
  void _update(AppSettings Function(AppSettings) updater) {
    settings.value = updater(settings.value);
    _save();
  }

  // ── Appearance ────────────────────────────────────────────────
  void setThemeMode(AppThemeMode mode) {
    _update((s) => s.copyWith(themeMode: mode));
    // Apply to GetX theme manager
    switch (mode) {
      case AppThemeMode.light:  Get.changeThemeMode(ThemeMode.light);
      case AppThemeMode.dark:   Get.changeThemeMode(ThemeMode.dark);
      case AppThemeMode.system: Get.changeThemeMode(ThemeMode.system);
    }
  }

  void setGridDensity(GridDensity d) =>
      _update((s) => s.copyWith(gridDensity: d));

  void setDateFormat(DateFormat f) =>
      _update((s) => s.copyWith(dateFormat: f));

  void toggleShowVideoDuration() =>
      _update((s) => s.copyWith(showVideoDuration: !s.showVideoDuration));

  void toggleShowFileSize() =>
      _update((s) => s.copyWith(showFileSize: !s.showFileSize));

  // ── Privacy ───────────────────────────────────────────────────
  void toggleSecureFolder() =>
      _update((s) => s.copyWith(secureFolderEnabled: !s.secureFolderEnabled));

  void setLockType(LockType t) =>
      _update((s) => s.copyWith(lockType: t));

  void toggleHideInRecentApps() =>
      _update((s) => s.copyWith(hideInRecentApps: !s.hideInRecentApps));

  // ── Storage ───────────────────────────────────────────────────
  void setAutoDeleteTrash(AutoDeletePeriod p) =>
      _update((s) => s.copyWith(autoDeleteTrash: p));

  void toggleSaveEditsAsNewFile() =>
      _update((s) => s.copyWith(saveEditsAsNewFile: !s.saveEditsAsNewFile));

  void toggleIncludeMetadataOnShare() =>
      _update((s) => s.copyWith(
          includeMetadataOnShare: !s.includeMetadataOnShare));

  Future<void> clearCache() async {
    isClearing.value = true;
    try {
      await _cacheService.clearAll();
      await _calcCacheSize();
    } finally {
      isClearing.value = false;
    }
  }

  Future<void> _calcCacheSize() async {
    final bytes = await _cacheService.diskCacheSize();
    cacheSizeMB.value = bytes ~/ (1024 * 1024);
  }

  // ── Backup ────────────────────────────────────────────────────
  void toggleAutoBackup() =>
      _update((s) => s.copyWith(autoBackup: !s.autoBackup));

  void toggleBackupOnWifiOnly() =>
      _update((s) => s.copyWith(backupOnWifiOnly: !s.backupOnWifiOnly));

  void toggleBackupVideos() =>
      _update((s) => s.copyWith(backupVideos: !s.backupVideos));

  // ── Memories ──────────────────────────────────────────────────
  void toggleGenerateMemories() =>
      _update((s) => s.copyWith(generateMemories: !s.generateMemories));

  void toggleMemoriesNotification() =>
      _update((s) => s.copyWith(memoriesNotification: !s.memoriesNotification));

  // ── Notifications ─────────────────────────────────────────────
  void toggleShareNotifications() =>
      _update((s) => s.copyWith(shareNotifications: !s.shareNotifications));

  void toggleBackupNotifications() =>
      _update((s) => s.copyWith(backupNotifications: !s.backupNotifications));

  // ── Label helpers ─────────────────────────────────────────────
  String get themeModeLabel => switch (settings.value.themeMode) {
    AppThemeMode.system => 'Follow system',
    AppThemeMode.light  => 'Light',
    AppThemeMode.dark   => 'Dark',
  };

  String get gridDensityLabel => switch (settings.value.gridDensity) {
    GridDensity.compact => 'Compact (4 col)',
    GridDensity.normal  => 'Normal (3 col)',
    GridDensity.large   => 'Large (2 col)',
  };

  String get dateFormatLabel => switch (settings.value.dateFormat) {
    DateFormat.relative => 'Relative (3 days ago)',
    DateFormat.absolute => 'Absolute (12 Jun 2024)',
    DateFormat.both     => 'Both',
  };

  String get autoDeleteLabel => switch (settings.value.autoDeleteTrash) {
    AutoDeletePeriod.never       => 'Never',
    AutoDeletePeriod.days30      => 'After 30 days',
    AutoDeletePeriod.days7       => 'After 7 days',
    AutoDeletePeriod.immediately => 'Immediately',
  };

  String get lockTypeLabel => switch (settings.value.lockType) {
    LockType.pin        => 'PIN',
    LockType.biometric  => 'Biometric',
    LockType.pattern    => 'Pattern',
  };

  String get cacheSizeLabel =>
      cacheSizeMB.value > 0 ? '${cacheSizeMB.value} MB' : 'Empty';
}