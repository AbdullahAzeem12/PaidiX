import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/paidix_toast.dart';

/// Explains the mobile role restriction and opens the official admin portal.
class AdminWebLoginDialog {
  AdminWebLoginDialog._();

  static final Uri loginUri = Uri.parse('https://paidix.com/login');

  static Future<void> show(
    BuildContext context, {
    required String backendMessage,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Admin sign-in is web only'),
        content: Text(
          '$backendMessage\n\nOpen the PaidiX web admin login to continue.\n'
          '${loginUri.toString()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Dismiss'),
          ),
          FilledButton.icon(
            onPressed: () async {
              var launched = false;
              try {
                launched = await launchUrl(
                  loginUri,
                  mode: LaunchMode.externalApplication,
                );
              } catch (_) {
                // Keep the dialog actionable if the device has no browser.
              }
              if (launched) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              } else if (dialogContext.mounted) {
                PaidiXToast.showError(
                  dialogContext,
                  'Could not open the admin login. Visit https://paidix.com/login.',
                );
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Admin Web Login'),
          ),
        ],
      ),
    );
  }
}
