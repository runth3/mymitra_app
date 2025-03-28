import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void showMaintenanceDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Pemeliharaan"),
      content: const Text("Sistem sedang dalam pemeliharaan. Silakan coba lagi nanti."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("Keluar"),
        ),
      ],
    ),
  );
}

void showUpdateDialog(BuildContext context, String updateUrl, String currentVersion) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Update Diperlukan"),
      content: Text("Versi Anda ($currentVersion) usang. Update ke versi terbaru."),
      actions: [
        TextButton(
          onPressed: () async {
            await launchUrl(Uri.parse(updateUrl));
          },
          child: const Text("Update Sekarang"),
        ),
      ],
    ),
  );
}