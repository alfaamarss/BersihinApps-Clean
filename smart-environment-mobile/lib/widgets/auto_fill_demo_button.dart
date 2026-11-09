import 'package:flutter/material.dart';

class AutoFillDemoButton extends StatelessWidget {
  const AutoFillDemoButton({
    super.key,
    required this.isFormEmpty,
    required this.onFill,
    this.enabled = true,
  });

  final bool isFormEmpty;
  final Future<bool> Function() onFill;
  final bool enabled;

  Future<void> _handlePressed(BuildContext context) async {
    if (!isFormEmpty) {
      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ganti isi form?'),
          content: const Text(
            'Form sudah berisi data. Ganti dengan data contoh Auto Fill Demo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ganti'),
            ),
          ],
        ),
      );

      if (shouldReplace != true) return;
    }

    if (!context.mounted) return;
    final didFill = await onFill();
    if (!didFill || !context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Data contoh berhasil diisi. Silakan tinjau dan ubah bila perlu.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: enabled ? () => _handlePressed(context) : null,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Auto Fill Demo'),
      ),
    );
  }
}
