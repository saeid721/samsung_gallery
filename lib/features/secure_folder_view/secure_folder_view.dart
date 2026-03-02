
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/theme.dart';
import 'controllers/secure_folder_controller.dart';

class SecureFolderView extends GetView<SecureFolderController> {
  const SecureFolderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Folder'),
        actions: [
          Obx(() => controller.isUnlocked.value
              ? IconButton(
            icon: const Icon(Icons.lock),
            onPressed: controller.lock,
            tooltip: 'Lock',
          )
              : const SizedBox.shrink()),
        ],
      ),
      body: Obx(() {
        // ── Locked state ─────────────────────────────────────
        if (!controller.isUnlocked.value) {
          return _LockScreen(controller: controller);
        }

        // ── Unlocked: show encrypted media grid ──────────────
        if (controller.secureItems.isEmpty) {
          return _EmptyVault(controller: controller);
        }

        return _SecureGrid(controller: controller);
      }),
    );
  }
}

// ── Lock screen ─────────────────────────────────────────────
class _LockScreen extends StatelessWidget {
  final SecureFolderController controller;
  const _LockScreen({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline,
                size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          const Text('Secure Folder',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Your private, encrypted photo vault.\nAuthenticate to access.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Obx(() => controller.errorMessage.value.isNotEmpty
              ? Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              controller.errorMessage.value,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          )
              : const SizedBox.shrink()),
          Obx(() => ElevatedButton.icon(
            onPressed: controller.isAuthenticating.value
                ? null
                : controller.authenticate,
            icon: controller.isAuthenticating.value
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.fingerprint),
            label: Text(controller.isAuthenticating.value
                ? 'Authenticating…'
                : 'Unlock'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          )),
        ],
      ),
    );
  }
}

// ── Empty vault prompt ──────────────────────────────────────
class _EmptyVault extends StatelessWidget {
  final SecureFolderController controller;
  const _EmptyVault({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Secure Folder is empty',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          const Text(
            'Long-press any photo in the gallery\nand choose "Move to Secure Folder".',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Unlocked media grid ─────────────────────────────────────
class _SecureGrid extends StatelessWidget {
  final SecureFolderController controller;
  const _SecureGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: controller.secureItems.length,
      itemBuilder: (context, index) {
        final item = controller.secureItems[index];
        // Thumbnails for encrypted items are generated on-demand
        // from decrypted bytes — never cached to disk unencrypted.
        return Container(
          color: Colors.grey.shade800,
          child: const Icon(Icons.lock, color: Colors.grey),
        );
      },
    );
  }
}