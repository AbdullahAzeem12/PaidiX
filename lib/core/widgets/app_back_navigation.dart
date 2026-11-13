import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

/// Installs a route-aware Android back callback without changing page layout.
class AppBackButtonHandler extends StatelessWidget {
  const AppBackButtonHandler({
    super.key,
    required this.child,
    required this.onBack,
  });

  final Widget child;
  final Future<bool> Function(BuildContext context) onBack;

  @override
  Widget build(BuildContext context) {
    return BackButtonListener(
      onBackButtonPressed: () => onBack(context),
      child: child,
    );
  }
}

/// Asks for confirmation before closing the app from a root page.
Future<void> showAppExitConfirmation(BuildContext context) async {
  final shouldExit = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Exit PaidiX?'),
      content: const Text('Do you want to close the app?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Stay'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Exit'),
        ),
      ],
    ),
  );

  if (shouldExit == true) await SystemNavigator.pop();
}
