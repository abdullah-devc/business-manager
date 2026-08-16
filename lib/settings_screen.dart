import 'package:flutter/material.dart';

import 'backup_restore_screen.dart';
import 'change_password_screen.dart';
import 'delete_password_screen.dart';
import 'company_profile_screen.dart';
import 'widgets/app_background_controller.dart';
import 'widgets/glass.dart';

/// Settings tab: everything that used to live in the AppBar's popup
/// menu (Lock, Change Password, Background Brightness, Dark Mode) plus
/// Backup & Restore and Company Profile, now as one dedicated section.
class SettingsScreen extends StatefulWidget {
  final VoidCallback onLock;

  const SettingsScreen({super.key, required this.onLock});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return AdaptiveBackgroundText(
      child: Builder(builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          GlassContainer(
            padding: const EdgeInsets.symmetric(vertical: 4),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      AppBackgroundController.instance.isDarkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      key: ValueKey(AppBackgroundController.instance.isDarkMode),
                    ),
                  ),
                  title: const Text('Dark Mode'),
                  value: AppBackgroundController.instance.isDarkMode,
                  // setState here (not inside the controller call) is what
                  // actually rebuilds this switch to its new state — the
                  // controller itself has no listenable for isDarkMode.
                  onChanged: (_) => setState(() => AppBackgroundController.instance.toggleDarkMode()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: const Text('Background Brightness'),
                  subtitle: const Text('Drag to dim the animated background'),
                  onTap: () => _showBrightnessSheet(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassContainer(
            padding: const EdgeInsets.symmetric(vertical: 4),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.apartment_outlined),
                  title: const Text('Company Profile'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CompanyProfileScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Backup & Restore'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BackupRestoreScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassContainer(
            padding: const EdgeInsets.symmetric(vertical: 4),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Change Password'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePasswordScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined),
                  title: const Text('Delete Password'),
                  subtitle: const Text('Separate password required before deleting data'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DeletePasswordScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Lock App'),
                  onTap: widget.onLock,
                ),
              ],
            ),
          ),
        ],
      )),
    );
  }

  void _showBrightnessSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: GlassContainer(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.all(20),
          child: _BrightnessSliderContent(),
        ),
      ),
    );
  }
}

class _BrightnessSliderContent extends StatefulWidget {
  @override
  State<_BrightnessSliderContent> createState() => _BrightnessSliderContentState();
}

class _BrightnessSliderContentState extends State<_BrightnessSliderContent> {
  late double _value = AppBackgroundController.instance.brightness.value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 16, backgroundColor: Colors.blue.withOpacity(0.18), child: const Icon(Icons.brightness_6, color: Colors.blue, size: 18)),
            const SizedBox(width: 10),
            Text('Background Brightness', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Drag toward the moon for a darker background.'),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.dark_mode_outlined, size: 18),
            Expanded(
              child: Slider(
                value: _value,
                onChanged: (v) {
                  setState(() => _value = v);
                  AppBackgroundController.instance.brightness.value = v;
                },
                onChangeEnd: (v) => AppBackgroundController.instance.setBrightness(v),
              ),
            ),
            const Icon(Icons.light_mode_outlined, size: 18),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
        ),
      ],
    );
  }
}
