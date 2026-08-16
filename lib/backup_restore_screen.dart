import 'package:flutter/material.dart';

import 'backup_service.dart';
import 'csv_export_service.dart';
import 'widgets/glass.dart';
import 'widgets/app_loading_indicator.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _working = false;

  Future<void> _backup() async {
    setState(() => _working = true);
    try {
      final path = await BackupService.createBackup();
      if (path != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backup saved as $path')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create backup: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _shareBackup() async {
    setState(() => _working = true);
    try {
      final shared = await BackupService.shareBackup();
      if (shared && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup ready to share')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share backup: $error')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PinnedDarkText(
        child: AlertDialog(
          title: const Text('Restore Backup?'),
          content: const Text(
            'Restoring replaces all current companies, materials, transactions, invoices, expenses, balances, and profile details. Create a backup first if you need to keep the current data.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      await BackupService.restoreBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Backup restored. Restart the app to refresh every screen.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not restore backup: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _export(String label, Future<String?> Function() action) async {
    setState(() => _working = true);
    try {
      final path = await action();
      if (path != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$label CSV saved to $path')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export $label: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: AdaptiveBackgroundText(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isPhone = constraints.maxWidth < 600;
              final exportButtons = [
                _ExportButton(
                  label: 'Transactions',
                  icon: Icons.receipt_long,
                  onPressed: _working
                      ? null
                      : () => _export(
                          'Transactions',
                          CsvExportService.exportTransactions,
                        ),
                ),
                _ExportButton(
                  label: 'Expenses',
                  icon: Icons.money_off,
                  onPressed: _working
                      ? null
                      : () => _export(
                          'Expenses',
                          CsvExportService.exportExpenses,
                        ),
                ),
                _ExportButton(
                  label: 'Invoices',
                  icon: Icons.request_quote,
                  onPressed: _working
                      ? null
                      : () => _export(
                          'Invoices',
                          CsvExportService.exportInvoices,
                        ),
                ),
                _ExportButton(
                  label: 'Balances',
                  icon: Icons.account_balance_wallet,
                  onPressed: _working
                      ? null
                      : () => _export(
                          'Balances',
                          CsvExportService.exportBalances,
                        ),
                ),
              ];

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const Text(
                    'Keep a backup before moving devices or making major changes.',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 20),
                  GlassContainer(
                    padding: EdgeInsets.zero,
                    child: Material(
                      type: MaterialType.transparency,
                      child: isPhone
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      Icons.backup_outlined,
                                      color: Colors.blue,
                                    ),
                                    title: Text('Create Backup'),
                                    subtitle: Text(
                                      'Saves all app data, your company logo, and attached bill images in one portable file.',
                                    ),
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: GlassActionButton(
                                      onPressed: _working ? null : _backup,
                                      icon: Icons.backup,
                                      color: Colors.blueGrey,
                                      label: const Text('Create Backup'),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _working ? null : _shareBackup,
                                      icon: const Icon(Icons.share),
                                      label: const Text('Share Backup'),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListTile(
                              leading: const Icon(
                                Icons.backup_outlined,
                                color: Colors.blue,
                              ),
                              title: const Text('Create Backup'),
                              subtitle: const Text(
                                'Saves all app data, your company logo, and attached bill images in one portable file.',
                              ),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _working ? null : _shareBackup,
                                    icon: const Icon(Icons.share),
                                    label: const Text('Share'),
                                  ),
                                  GlassActionButton(
                                    onPressed: _working ? null : _backup,
                                    icon: Icons.backup,
                                    color: Colors.blueGrey,
                                    label: const Text('Backup Now'),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassContainer(
                    padding: EdgeInsets.zero,
                    child: Material(
                      type: MaterialType.transparency,
                      child: isPhone
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      Icons.restore,
                                      color: Colors.orange,
                                    ),
                                    title: Text('Restore Backup'),
                                    subtitle: Text(
                                      'Replaces the current app data with a selected backup file.',
                                    ),
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _working ? null : _restore,
                                      icon: const Icon(Icons.restore),
                                      label: const Text('Restore Backup'),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListTile(
                              leading: const Icon(
                                Icons.restore,
                                color: Colors.orange,
                              ),
                              title: const Text('Restore Backup'),
                              subtitle: const Text(
                                'Replaces the current app data with a selected backup file.',
                              ),
                              trailing: OutlinedButton(
                                onPressed: _working ? null : _restore,
                                child: const Text('Restore'),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Export CSV',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Save a spreadsheet-compatible CSV file. Exports are kept here so they do not crowd the main backup actions.',
                  ),
                  const SizedBox(height: 12),
                  if (isPhone)
                    ...exportButtons.map(
                      (button) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(width: double.infinity, child: button),
                      ),
                    )
                  else
                    Wrap(spacing: 8, runSpacing: 8, children: exportButtons),
                  if (_working)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: AppLoadingIndicator(label: 'Working securely'),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text('Export $label CSV'),
  );
}
