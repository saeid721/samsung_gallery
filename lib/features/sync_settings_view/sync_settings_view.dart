
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/theme.dart';
import '../../data/repositories/sync_repository.dart';

class SyncSettingsView extends StatelessWidget {
  const SyncSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Backup')),
      body: FutureBuilder<SyncSettings>(
        future: _loadSettings(),
        builder: (context, snap) {
          final settings = snap.data ?? const SyncSettings();
          return _SettingsList(settings: settings);
        },
      ),
    );
  }

  Future<SyncSettings> _loadSettings() async {
    // return Get.find<SyncRepository>().getSettings();
    return const SyncSettings(); // stub
  }
}

class _SettingsList extends StatefulWidget {
  final SyncSettings settings;
  const _SettingsList({required this.settings});

  @override
  State<_SettingsList> createState() => _SettingsListState();
}

class _SettingsListState extends State<_SettingsList> {
  late bool _autoSync;
  late bool _wifiOnly;
  late bool _syncVideos;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _autoSync   = widget.settings.autoSyncEnabled;
    _wifiOnly   = widget.settings.wifiOnly;
    _syncVideos = widget.settings.syncVideos;
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = widget.settings.connectedEmail != null;

    return ListView(
      children: [
        // ── Google Account ──────────────────────────────────
        const _SectionHeader('Google Account'),
        if (isSignedIn) ...[
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(widget.settings.connectedEmail ?? ''),
            subtitle: const Text('Connected'),
            trailing: TextButton(
              onPressed: _signOut,
              child: const Text('Sign out',
                  style: TextStyle(color: Colors.red)),
            ),
          ),
        ] else
          ListTile(
            leading: const Icon(Icons.add_circle_outline,
                color: AppColors.primary),
            title: const Text('Sign in with Google'),
            subtitle:
            const Text('Back up photos to Google Photos'),
            onTap: _signIn,
          ),

        const Divider(),

        // ── Sync settings ───────────────────────────────────
        const _SectionHeader('Backup Settings'),
        SwitchListTile(
          secondary: const Icon(Icons.sync),
          title: const Text('Auto backup'),
          subtitle: const Text('Automatically back up new photos'),
          value: _autoSync,
          activeColor: AppColors.primary,
          onChanged: isSignedIn
              ? (v) { setState(() => _autoSync = v); _save(); }
              : null,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.wifi),
          title: const Text('Use WiFi only'),
          subtitle: const Text('Don\'t use mobile data for backup'),
          value: _wifiOnly,
          activeColor: AppColors.primary,
          onChanged: (_autoSync && isSignedIn)
              ? (v) { setState(() => _wifiOnly = v); _save(); }
              : null,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.videocam),
          title: const Text('Backup videos'),
          subtitle: const Text('Include videos in backup'),
          value: _syncVideos,
          activeColor: AppColors.primary,
          onChanged: (_autoSync && isSignedIn)
              ? (v) { setState(() => _syncVideos = v); _save(); }
              : null,
        ),

        const Divider(),

        // ── Manual sync ─────────────────────────────────────
        const _SectionHeader('Sync'),
        ListTile(
          leading: _isSyncing
              ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.cloud_sync),
          title: const Text('Sync now'),
          subtitle: widget.settings.lastSyncAt != null
              ? Text('Last synced: ${_formatDate(widget.settings.lastSyncAt!)}')
              : const Text('Never synced'),
          enabled: isSignedIn && !_isSyncing,
          onTap: _syncNow,
        ),

        const Divider(),

        // ── Storage info ────────────────────────────────────
        const _SectionHeader('Storage'),
        const ListTile(
          leading: Icon(Icons.storage),
          title: Text('Google One storage'),
          subtitle: Text('Opens Google One in browser'),
          trailing: Icon(Icons.open_in_new, size: 16),
        ),
      ],
    );
  }

  void _signIn() {
    // Get.find<GooglePhotosSyncService>().signIn()
    Get.snackbar('Sign In',
        'Redirecting to Google sign in…',
        snackPosition: SnackPosition.BOTTOM);
  }

  void _signOut() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'Your photos will remain on this device. Backup will be paused.'),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              // Get.find<GooglePhotosSyncService>().signOut()
            },
            child: const Text('Sign out',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    await Future.delayed(const Duration(seconds: 2)); // stub
    setState(() => _isSyncing = false);
    Get.snackbar('Sync complete', 'All photos are backed up.',
        snackPosition: SnackPosition.BOTTOM);
  }

  void _save() {
    // Get.find<SyncRepository>().saveSettings(SyncSettings(...))
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}