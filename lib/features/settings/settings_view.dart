
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/theme.dart';
import 'controllers/settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

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
            const Text('Settings',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
          ]),
        ),

        // Settings list
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              children: [

                // ── APPEARANCE ────────────────────────────
                _Section(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  children: [

                    _PickerTile(
                      label: 'Theme',
                      value: controller.themeModeLabel,
                      onTap: () => _showThemePicker(context),
                    ),

                    _PickerTile(
                      label: 'Grid Density',
                      value: controller.gridDensityLabel,
                      onTap: () => _showGridDensityPicker(context),
                    ),

                    _PickerTile(
                      label: 'Date Format',
                      value: controller.dateFormatLabel,
                      onTap: () => _showDateFormatPicker(context),
                    ),

                    Obx(() => _SwitchTile(
                      label: 'Show Video Duration',
                      value: controller.settings.value.showVideoDuration,
                      onChanged: (_) =>
                          controller.toggleShowVideoDuration(),
                    )),

                    Obx(() => _SwitchTile(
                      label: 'Show File Size',
                      value: controller.settings.value.showFileSize,
                      onChanged: (_) =>
                          controller.toggleShowFileSize(),
                      isLast: true,
                    )),
                  ],
                ),

                const SizedBox(height: 16),

                // ── PRIVACY ───────────────────────────────
                _Section(
                  icon: Icons.lock_outline_rounded,
                  title: 'Privacy & Security',
                  children: [

                    Obx(() => _SwitchTile(
                      label: 'Secure Folder',
                      subtitle: 'Hide private photos behind lock',
                      value: controller.settings.value.secureFolderEnabled,
                      onChanged: (_) =>
                          controller.toggleSecureFolder(),
                    )),

                    Obx(() => _PickerTile(
                      label: 'Lock Type',
                      value: controller.lockTypeLabel,
                      enabled: controller
                          .settings.value.secureFolderEnabled,
                      onTap: () => _showLockTypePicker(context),
                    )),

                    Obx(() => _SwitchTile(
                      label: 'Hide in Recent Apps',
                      subtitle: 'Blur screenshot in app switcher',
                      value: controller.settings.value.hideInRecentApps,
                      onChanged: (_) =>
                          controller.toggleHideInRecentApps(),
                      isLast: true,
                    )),
                  ],
                ),

                const SizedBox(height: 16),

                // ── STORAGE ───────────────────────────────
                _Section(
                  icon: Icons.storage_outlined,
                  title: 'Storage',
                  children: [

                    _PickerTile(
                      label: 'Auto-delete Trash',
                      value: controller.autoDeleteLabel,
                      onTap: () =>
                          _showAutoDeletePicker(context),
                    ),

                    Obx(() => _SwitchTile(
                      label: 'Save Edits as New File',
                      subtitle: 'Keeps original photo intact',
                      value: controller
                          .settings.value.saveEditsAsNewFile,
                      onChanged: (_) =>
                          controller.toggleSaveEditsAsNewFile(),
                    )),

                    Obx(() => _SwitchTile(
                      label: 'Include Metadata when Sharing',
                      subtitle: 'GPS, camera info',
                      value: controller.settings.value
                          .includeMetadataOnShare,
                      onChanged: (_) => controller
                          .toggleIncludeMetadataOnShare(),
                    )),

                    Obx(() => ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 2),
                      title: const Text('Thumbnail Cache',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14)),
                      subtitle: Text(
                        controller.cacheSizeLabel,
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12),
                      ),
                      trailing: controller.isClearing.value
                          ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.redAccent))
                          : TextButton(
                        onPressed: controller.clearCache,
                        child: const Text('Clear',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13)),
                      ),
                    )),
                  ],
                ),

                const SizedBox(height: 16),

                // ── BACKUP ────────────────────────────────
                _Section(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Backup',
                  children: [

                    Obx(() => _SwitchTile(
                      label: 'Auto Backup',
                      subtitle: 'Sync to Google Photos',
                      value: controller.settings.value.autoBackup,
                      onChanged: (_) =>
                          controller.toggleAutoBackup(),
                    )),

                    Obx(() => _SwitchTile(
                      label: 'Wi-Fi Only',
                      value: controller
                          .settings.value.backupOnWifiOnly,
                      enabled: controller.settings.value.autoBackup,
                      onChanged: (_) =>
                          controller.toggleBackupOnWifiOnly(),
                    )),

                    Obx(() => _SwitchTile(
                      label: 'Back Up Videos',
                      value: controller.settings.value.backupVideos,
                      enabled: controller.settings.value.autoBackup,
                      onChanged: (_) =>
                          controller.toggleBackupVideos(),
                      isLast: true,
                    )),
                  ],
                ),

                const SizedBox(height: 16),

                // ── MEMORIES ──────────────────────────────
                _Section(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Memories',
                  children: [

                    Obx(() => _SwitchTile(
                      label: 'Generate Memories',
                      subtitle: 'Auto-create photo stories',
                      value: controller
                          .settings.value.generateMemories,
                      onChanged: (_) =>
                          controller.toggleGenerateMemories(),
                    )),

                    Obx(() => _SwitchTile(
                      label: 'Memory Notifications',
                      value: controller
                          .settings.value.memoriesNotification,
                      enabled: controller
                          .settings.value.generateMemories,
                      onChanged: (_) => controller
                          .toggleMemoriesNotification(),
                      isLast: true,
                    )),
                  ],
                ),

                const SizedBox(height: 16),

                // ── NOTIFICATIONS ─────────────────────────
                _Section(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  children: [

                    Obx(() => _SwitchTile(
                      label: 'Shared Album Activity',
                      value: controller
                          .settings.value.shareNotifications,
                      onChanged: (_) =>
                          controller.toggleShareNotifications(),
                    )),

                    Obx(() => _SwitchTile(
                      label: 'Backup Completed',
                      value: controller
                          .settings.value.backupNotifications,
                      onChanged: (_) => controller
                          .toggleBackupNotifications(),
                      isLast: true,
                    )),
                  ],
                ),

                const SizedBox(height: 16),

                // ── ABOUT ─────────────────────────────────
                _Section(
                  icon: Icons.info_outline_rounded,
                  title: 'About',
                  children: [

                    _InfoTile(
                        label: 'Version',
                        value:
                        '${SettingsController.appVersion} (${SettingsController.buildNumber})'),

                    _TapTile(
                      label: 'Send Feedback',
                      icon: Icons.feedback_outlined,
                      onTap: () {},
                    ),

                    _TapTile(
                      label: 'Open Source Licenses',
                      icon: Icons.article_outlined,
                      onTap: () =>
                          showLicensePage(context: context),
                    ),

                    _TapTile(
                      label: 'Privacy Policy',
                      icon: Icons.privacy_tip_outlined,
                      onTap: () {},
                      isLast: true,
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
      ]),
    );
  }

  // ── Pickers ───────────────────────────────────────────────────

  void _showThemePicker(BuildContext context) {
    _radioSheet(
      context: context,
      title: 'Theme',
      options: AppThemeMode.values,
      selected: controller.settings.value.themeMode,
      labelOf: (v) => switch (v) {
        AppThemeMode.system => 'Follow system',
        AppThemeMode.light  => 'Light',
        AppThemeMode.dark   => 'Dark',
      },
      onSelect: controller.setThemeMode,
    );
  }

  void _showGridDensityPicker(BuildContext context) {
    _radioSheet(
      context: context,
      title: 'Grid Density',
      options: GridDensity.values,
      selected: controller.settings.value.gridDensity,
      labelOf: (v) => switch (v) {
        GridDensity.compact => 'Compact — 4 columns',
        GridDensity.normal  => 'Normal — 3 columns',
        GridDensity.large   => 'Large — 2 columns',
      },
      onSelect: controller.setGridDensity,
    );
  }

  void _showDateFormatPicker(BuildContext context) {
    _radioSheet(
      context: context,
      title: 'Date Format',
      options: DateFormat.values,
      selected: controller.settings.value.dateFormat,
      labelOf: (v) => switch (v) {
        DateFormat.relative => 'Relative  (3 days ago)',
        DateFormat.absolute => 'Absolute  (12 Jun 2024)',
        DateFormat.both     => 'Both',
      },
      onSelect: controller.setDateFormat,
    );
  }

  void _showLockTypePicker(BuildContext context) {
    _radioSheet(
      context: context,
      title: 'Lock Type',
      options: LockType.values,
      selected: controller.settings.value.lockType,
      labelOf: (v) => switch (v) {
        LockType.pin        => 'PIN',
        LockType.biometric  => 'Biometric (fingerprint / face)',
        LockType.pattern    => 'Pattern',
      },
      onSelect: controller.setLockType,
    );
  }

  void _showAutoDeletePicker(BuildContext context) {
    _radioSheet(
      context: context,
      title: 'Auto-delete Trash',
      options: AutoDeletePeriod.values,
      selected: controller.settings.value.autoDeleteTrash,
      labelOf: (v) => switch (v) {
        AutoDeletePeriod.never       => 'Never',
        AutoDeletePeriod.days30      => 'After 30 days',
        AutoDeletePeriod.days7       => 'After 7 days',
        AutoDeletePeriod.immediately => 'Immediately',
      },
      onSelect: controller.setAutoDeleteTrash,
    );
  }

  void _radioSheet<T>({
    required BuildContext context,
    required String title,
    required List<T> options,
    required T selected,
    required String Function(T) labelOf,
    required void Function(T) onSelect,
  }) {
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
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
            ...options.map((opt) => ListTile(
              title: Text(labelOf(opt),
                  style: TextStyle(
                      color: opt == selected
                          ? AppColors.primary
                          : Colors.white,
                      fontSize: 14)),
              trailing: opt == selected
                  ? const Icon(Icons.check_rounded,
                  color: AppColors.primary)
                  : null,
              onTap: () {
                Navigator.pop(context);
                onSelect(opt);
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// REUSABLE SETTING WIDGETS
// ══════════════════════════════════════════════════════════════

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(title.toUpperCase(),
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
        ]),
      ),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: children),
      ),
    ],
  );
}

class _SwitchTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final bool isLast;
  final void Function(bool) onChanged;

  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 2),
          title: Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14)),
          subtitle: subtitle != null
              ? Text(subtitle!,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 12))
              : null,
          value: value,
          onChanged: enabled ? onChanged : null,
          activeColor: AppColors.primary,
        ),
      ),
      if (!isLast)
        const Divider(
            color: Colors.white12, height: 1, indent: 16),
    ],
  );
}

class _PickerTile extends StatelessWidget {
  final String label;
  final String value;
  final bool enabled;
  final bool isLast;
  final VoidCallback onTap;

  const _PickerTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.enabled = true,
    this.isLast  = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 2),
          title: Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 13)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white24, size: 18),
            ],
          ),
          onTap: enabled ? onTap : null,
        ),
      ),
      if (!isLast)
        const Divider(
            color: Colors.white12, height: 1, indent: 16),
    ],
  );
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const _InfoTile({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 2),
        title: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 14)),
        trailing: Text(value,
            style: const TextStyle(
                color: Colors.white38, fontSize: 13)),
      ),
      if (!isLast)
        const Divider(
            color: Colors.white12, height: 1, indent: 16),
    ],
  );
}

class _TapTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLast;
  const _TapTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 2),
        leading: Icon(icon, color: Colors.white54, size: 20),
        title: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 14)),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: Colors.white24, size: 18),
        onTap: onTap,
      ),
      if (!isLast)
        const Divider(
            color: Colors.white12, height: 1, indent: 16),
    ],
  );
}