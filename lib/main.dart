import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'companies_screen.dart';
import 'inventory_screen.dart';
import 'reports_screen.dart';
import 'add_company_screen.dart';
import 'add_material_screen.dart';
import 'add_transaction_screen.dart';
import 'add_invoice_screen.dart';
import 'add_expense_screen.dart';
import 'overview_screen.dart';
import 'invoices_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';
import 'unpaid_transactions_screen.dart';
import 'widgets/wave_background.dart';
import 'widgets/app_background_controller.dart';
import 'widgets/glass.dart';
import 'widgets/glass_tab_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The setting read shares the database-open future, so these start together
  // instead of paying for two sequential startup waits.
  await Future.wait([
    DatabaseHelper.instance.database,
    AppBackgroundController.instance.loadPersisted(),
  ]);
  runApp(const MyApp());
  // Warm dropdown/reference data while the login screen is visible. This is
  // invisible to the UI, but makes the first app tab and add form faster.
  unawaited(DatabaseHelper.instance.warmLookupCache());
}

/// A subtle vertical shared-axis transition for full-screen routes.
///
/// The destination rises from the bottom as the previous screen subtly
/// recedes. This creates a clear sense of entering a focused task without the
/// heavy, modal feel of a bottom sheet.
class _TransparentBottomSharedAxisPageTransitionsBuilder
    extends PageTransitionsBuilder {
  const _TransparentBottomSharedAxisPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final incoming = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // A page that is being covered is still built by its own route. Give it a
    // small fade and upward retreat while the new page enters, which is the
    // second half that makes this a shared-axis transition rather than a
    // standalone slide.
    final outgoingOpacity = Tween<double>(begin: 1, end: 0.88).animate(outgoing);
    final outgoingOffset = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.018),
    ).animate(outgoing);

    // Keep the incoming page visible from the first frame. Starting a fade at
    // zero made the earlier version read as content appearing in place rather
    // than a page physically entering from below.
    final incomingOpacity = Tween<double>(begin: 0.72, end: 1).animate(incoming);

    return FadeTransition(
      opacity: outgoingOpacity,
      child: SlideTransition(
        position: outgoingOffset,
        child: FadeTransition(
          opacity: incomingOpacity,
          child: SlideTransition(
            position: Tween<Offset>(
              // 20% of the page height is intentional: it is far enough to
              // make the bottom origin unmistakable, without becoming the
              // slow, full-screen sweep associated with a modal sheet.
              begin: const Offset(0, 0.20),
              end: Offset.zero,
            ).animate(incoming),
            child: child,
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Shared glass look for every button/slider in the app. Buttons are
    // scattered across 20+ screens, so rather than hand-editing each one
    // this is set once here at the theme level and cascades everywhere.
    //
    // Note: true blur (BackdropFilter) can only wrap a widget from the
    // outside, and doing that per-button across every screen would mean
    // hundreds of blur layers — expensive, and pointless on small
    // controls where there's rarely much detail behind them to blur.
    // So buttons/sliders get the *other* half of the glass look —
    // translucency, a soft highlight border, and no flat elevation —
    // which reads as glass sitting over the WaveBackground without the
    // perf cost. Panels big enough for blur to actually matter
    // (GlassContainer, the app bar) still use real BackdropFilter.
    const glassShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      side: BorderSide(color: Colors.white, width: 1.2),
    );

    return MaterialApp(
      title: 'BizRise',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,

        // The app uses a transparent Scaffold over WaveBackground. Keep
        // Material's own canvas transparent too; otherwise a MaterialPageRoute
        // can briefly paint the default light surface during navigation,
        // which appears as a white flash in dark mode.
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,

        // Full-screen pages use a layered fade-and-rise shared-axis motion.
        // The background stays visible underneath instead of exposing a new
        // light Material surface while the destination screen is being built.
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android:
                _TransparentBottomSharedAxisPageTransitionsBuilder(),
            TargetPlatform.iOS:
                _TransparentBottomSharedAxisPageTransitionsBuilder(),
            TargetPlatform.linux:
                _TransparentBottomSharedAxisPageTransitionsBuilder(),
            TargetPlatform.macOS:
                _TransparentBottomSharedAxisPageTransitionsBuilder(),
            TargetPlatform.windows:
                _TransparentBottomSharedAxisPageTransitionsBuilder(),
            TargetPlatform.fuchsia:
                _TransparentBottomSharedAxisPageTransitionsBuilder(),
          },
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.blue.withOpacity(0.16),
            foregroundColor: Colors.blue.shade900,
            shadowColor: Colors.transparent,
            shape: glassShape,
            side: BorderSide(color: Colors.white.withOpacity(0.7), width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.blue.withOpacity(0.22),
            foregroundColor: Colors.blue.shade900,
            shape: glassShape,
            side: BorderSide(color: Colors.white.withOpacity(0.7), width: 1.2),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.12),
            foregroundColor: Colors.blue.shade900,
            shape: glassShape,
            side: BorderSide(color: Colors.white.withOpacity(0.7), width: 1.2),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.10),
            foregroundColor: Colors.blue.shade900,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.14),
            foregroundColor: Colors.blue.shade900,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            side: BorderSide(color: Colors.white.withOpacity(0.6), width: 1),
          ),
        ),
        sliderTheme: SliderThemeData(
          trackHeight: 4,
          activeTrackColor: Colors.blue.withOpacity(0.55),
          inactiveTrackColor: Colors.white.withOpacity(0.35),
          thumbColor: Colors.white,
          overlayColor: Colors.blue.withOpacity(0.15),
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 9,
            elevation: 1,
          ),
          valueIndicatorColor: Colors.blue.withOpacity(0.85),
        ),
      ),
      builder: (context, child) {
        // Full-app background: the wave sits behind every screen, painted
        // once here at the MaterialApp level (same slot the old
        // AnimatedMeshBackground used to occupy).
        return Stack(
          children: [
            const Positioned.fill(child: WaveBackground()),
            if (child != null) child,
          ],
        );
      },
      home: const AuthGate(),
    );
  }
}

/// Shows the login/setup screen first; only reveals the app once
/// the user has authenticated. Also lets the app be re-locked from
/// within HomePage without restarting.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    // AuthGate initially presents the login screen. Explicitly start the
    // background here as well as in _lock so a newly-created gate always has
    // the same live background as a re-locked app.
    AppBackgroundController.instance.animate.value = true;
  }

  void _unlock() {
    setState(() => _unlocked = true);
    // Background stops animating and freezes on unlock — it'll only
    // re-render when the active tab changes from here on.
    AppBackgroundController.instance.animate.value = false;
  }

  void _lock() {
    // Resume the lively continuous animation on the lock screen.
    AppBackgroundController.instance.animate.value = true;
    setState(() => _unlocked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return LoginScreen(onSuccess: _unlock);
    }
    return HomePage(onLock: _lock);
  }
}

/// Named sections shown in the top tab bar and the FAB quick-add menu.
/// Kept in one place so the tab list and the TabBarView children below
/// can't drift out of sync.
const List<String> _kSectionTitles = [
  'Overview',
  'Transactions',
  'Invoices',
  'Companies',
  'Inventory',
  'Reports',
  'Settings',
];

class HomePage extends StatefulWidget {
  final VoidCallback onLock;

  const HomePage({super.key, required this.onLock});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _lowStockMaterials = [];
  final Map<int, DateTime> _dismissedUntil = {};
  late final TabController _tabController;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _kSectionTitles.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    // Make sure the frozen background matches whichever tab we land on
    // (it may be stale from a previous unlocked session).
    AppBackgroundController.instance.variant.value = _tabController.index;
    _loadLowStock();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showBackupReminder());
  }

  void _onTabChanged() {
    // TabController's listener fires repeatedly during a swipe; `.index`
    // only reflects the settled tab, and the ValueNotifier itself only
    // notifies WaveBackground when the value actually changes.
    AppBackgroundController.instance.variant.value = _tabController.index;
    if (_activeTab != _tabController.index && mounted) {
      setState(() => _activeTab = _tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showBackupReminder() async {
    if (!await DatabaseHelper.instance.shouldShowBackupReminder() || !mounted)
      return;
    await DatabaseHelper.instance.setAppSetting(
      'backup_reminder_last_prompt',
      DateTime.now().toIso8601String(),
    );
    if (!mounted) return;

    final brightness = AppBackgroundController.instance.brightness.value;
    final isDarkMode = brightness < 0.5;
    final backgroundColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    final backupNow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(color: textColor, fontSize: 16),
        title: const Text('Backup Reminder'),
        content: const Text(
          'You have not created a backup in the last seven days. Create one now to protect your business records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Remind Me Tomorrow'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Backup Now'),
          ),
        ],
      ),
    );
    if (backupNow == true && mounted) {
      _tabController.animateTo(_kSectionTitles.indexOf('Settings'));
    }
    await _showUnpaidReminder();
  }

  Future<void> _showUnpaidReminder() async {
    if (!await DatabaseHelper.instance.shouldShowUnpaidReminder() || !mounted)
      return;
    await DatabaseHelper.instance.setAppSetting(
      'unpaid_reminder_last_prompt',
      DateTime.now().toIso8601String(),
    );
    if (!mounted) return;

    final brightness = AppBackgroundController.instance.brightness.value;
    final isDarkMode = brightness < 0.5;
    final backgroundColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    final viewNow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(color: textColor, fontSize: 16),
        title: const Text('Outstanding Payments'),
        content: const Text(
          'You have overdue or long-outstanding unpaid transactions. Review them now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Review Now'),
          ),
        ],
      ),
    );
    if (viewNow == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const UnpaidTransactionsScreen(),
        ),
      );
    }
  }

  Future<void> _loadLowStock() async {
    final data = await DatabaseHelper.instance.getLowStockMaterials();
    setState(() => _lowStockMaterials = data);
  }

  bool _isDismissed(int materialId) {
    final until = _dismissedUntil[materialId];
    return until != null && DateTime.now().isBefore(until);
  }

  void _dismissWarning(int materialId) {
    setState(() {
      _dismissedUntil[materialId] = DateTime.now().add(
        const Duration(minutes: 3),
      );
    });
    Timer(const Duration(minutes: 3), () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _changeThresholdDialog(Map<String, dynamic> material) async {
    final ctrl = TextEditingController(
      text: material['low_stock_threshold'] != null
          ? material['low_stock_threshold'].toString()
          : '',
    );

    final brightness = AppBackgroundController.instance.brightness.value;
    final isDarkMode = brightness < 0.5;
    final backgroundColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(color: textColor, fontSize: 16),
        title: Text('Change Low Stock Level — ${material['name']}'),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Warn when stock falls to or below',
            labelStyle: TextStyle(
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blue, width: 2),
            ),
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final value = double.tryParse(ctrl.text.trim());
      if (value == null || value < 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a valid non-negative number.')),
          );
        }
        return;
      }
      await DatabaseHelper.instance.updateMaterial(material['id'], {
        'low_stock_threshold': value,
      });
      _loadLowStock();
    }
  }

  Widget _lowStockBanner(List<Map<String, dynamic>> visibleWarnings) {
    return ValueListenableBuilder<double>(
      valueListenable: AppBackgroundController.instance.brightness,
      builder: (context, brightness, _) {
        final isDarkMode = brightness < 0.5;
        final bannerTextColor = isDarkMode ? Colors.white : Colors.black87;
        final warningIconColor = isDarkMode
            ? Colors.orange.shade300
            : Colors.orange;
        final titleStyle = TextStyle(
          fontWeight: FontWeight.bold,
          color: bannerTextColor,
        );

        return GlassContainer(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(12),
          borderRadius: BorderRadius.circular(14),
          tint: isDarkMode
              ? Colors.orange.shade900.withOpacity(0.3)
              : Colors.orange.shade50,
          opacity: isDarkMode ? 0.8 : 0.65,
          borderColor: isDarkMode
              ? Colors.orange.shade700.withOpacity(0.7)
              : Colors.orange.withOpacity(0.5),
          child: SizedBox(
            // Fill the available width rather than forcing a desktop-sized
            // banner that can exceed the screen after its outer margins.
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: warningIconColor),
                    const SizedBox(width: 8),
                    Text('Low Stock Warning', style: titleStyle),
                  ],
                ),
                const SizedBox(height: 8),
                ...visibleWarnings.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${m['name']}: ${m['current_stock']} ${m['unit']} left (warn at ${m['low_stock_threshold']})',
                            style: TextStyle(color: bannerTextColor),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _changeThresholdDialog(m),
                          child: const Text('Change'),
                        ),
                        TextButton(
                          onPressed: () => _dismissWarning(m['id']),
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Bottom sheet with the five quick-create actions that used to be
  /// their own "Quick Add" tab. Reachable from any section via the FAB.
  void _showQuickAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      // Lets the sheet grow with its content up to the screen height
      // instead of being locked to the default ~half-screen, so on
      // short screens (small phones, split-screen, landscape) it has
      // room before the inner ScrollView needs to kick in.
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: GlassContainer(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            // Cap height to the available screen space (minus the
            // keyboard/status bar) so the five quick-add buttons
            // scroll instead of overflowing on small screens.
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Add',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  GlassActionButton(
                    icon: Icons.swap_horiz,
                    color: Colors.blue,
                    expand: true,
                    onPressed: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddTransactionScreen(),
                        ),
                      );
                      _loadLowStock();
                    },
                    label: const Text('Transaction'),
                  ),
                  const SizedBox(height: 10),
                  GlassActionButton(
                    icon: Icons.apartment,
                    color: Colors.teal,
                    expand: true,
                    onPressed: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddCompanyScreen(),
                        ),
                      );
                    },
                    label: const Text('Company'),
                  ),
                  const SizedBox(height: 10),
                  GlassActionButton(
                    icon: Icons.inventory_2,
                    color: Colors.brown,
                    expand: true,
                    onPressed: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddMaterialScreen(),
                        ),
                      );
                      _loadLowStock();
                    },
                    label: const Text('Material'),
                  ),
                  const SizedBox(height: 10),
                  GlassActionButton(
                    icon: Icons.request_quote,
                    color: Colors.purple,
                    expand: true,
                    onPressed: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddInvoiceScreen(),
                        ),
                      );
                    },
                    label: const Text('Invoice'),
                  ),
                  const SizedBox(height: 10),
                  GlassActionButton(
                    icon: Icons.receipt_long,
                    color: Colors.deepOrange,
                    expand: true,
                    onPressed: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddExpenseScreen(),
                        ),
                      );
                    },
                    label: const Text('Expense'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleWarnings = _lowStockMaterials
        .where((m) => !_isDismissed(m['id']))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const AdaptiveGlassText(child: Text('BizRise')),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.55),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.6),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Lock, change password, brightness, and dark mode all now live
        // in the Settings tab instead of a popup menu here — one place
        // for account/app settings instead of two.
        bottom: GlassSlideTabBar(
          controller: _tabController,
          tabs: _kSectionTitles,
        ),
      ),
      // On phones each section provides its own labelled add action. This
      // avoids two FABs competing for the bottom-right corner and covering
      // filters or list content. Keep Quick Add visible on Overview and on
      // wider desktop layouts where both controls have enough room.
      floatingActionButton:
          MediaQuery.sizeOf(context).width >= 600 || _activeTab == 0
          ? FloatingActionButton(
              onPressed: _showQuickAddSheet,
              tooltip: 'Quick Add',
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          if (visibleWarnings.isNotEmpty)
            Center(child: _lowStockBanner(visibleWarnings)),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const OverviewScreen(),
                const TransactionsScreen(embedded: true),
                const InvoicesScreen(embedded: true),
                const CompaniesScreen(embedded: true),
                const InventoryScreen(),
                const ReportsScreen(),
                SettingsScreen(onLock: widget.onLock),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
