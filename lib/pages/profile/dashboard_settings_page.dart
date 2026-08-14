import 'package:site_lapse/core/imports.dart';

class DashboardSettingsPage extends StatefulWidget {
  const DashboardSettingsPage({super.key});

  @override
  State<DashboardSettingsPage> createState() => _DashboardSettingsPageState();
}

class _DashboardSettingsPageState extends State<DashboardSettingsPage> {
  static const _sectionIds = <String>[
    'stats',
    'installations',
    'removals',
    'quick_actions',
  ];
  static const _actionIds = <String>[
    'add_project',
    'add_client',
    'add_product',
    'view_projects',
    'inventory',
    'clients',
    'employees',
    'calendar',
    'messages',
    'test_notification',
  ];

  final _sectionLabels = const <String, String>{
    'stats': 'Overview cards',
    'installations': 'Today’s installations',
    'removals': 'Today’s removals',
    'quick_actions': 'Quick actions',
  };
  final _actionLabels = const <String, String>{
    'add_project': 'Add project',
    'add_client': 'Add client',
    'add_product': 'Add product',
    'view_projects': 'View projects',
    'inventory': 'Inventory',
    'clients': 'Clients',
    'employees': 'Employees',
    'calendar': 'Calendar',
    'messages': 'Messages',
    'test_notification': 'Test notification',
  };

  late List<String> _sectionOrder;
  late List<String> _actionOrder;
  final Set<String> _enabledSections = {};
  final Set<String> _enabledActions = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _sectionOrder = List.of(_sectionIds);
    _actionOrder = List.of(_actionIds);
    _load();
  }

  Future<void> _load() async {
    final sections = await DashboardPreferences.sections();
    final actions = await DashboardPreferences.actions();
    if (!mounted) return;
    setState(() {
      _enabledSections.addAll(sections);
      _enabledActions.addAll(actions);
      _sectionOrder = [
        ...sections,
        ..._sectionIds.where((id) => !sections.contains(id)),
      ];
      _actionOrder = [
        ...actions,
        ..._actionIds.where((id) => !actions.contains(id)),
      ];
      _loading = false;
    });
  }

  Future<void> _save() async {
    await DashboardPreferences.save(
      sections: _sectionOrder.where(_enabledSections.contains).toList(),
      actions: _actionOrder.where(_enabledActions.contains).toList(),
    );
    if (!mounted) return;
    CustomSnackBar.show(context, 'Dashboard updated', color: AppColors.green);
  }

  String _iconFor(String id) => switch (id) {
    'stats' => AppIcons.home,
    'installations' => AppIcons.returns,
    'removals' => AppIcons.pickUp,
    'quick_actions' => AppIcons.add,
    'add_project' => AppIcons.booking,
    'add_client' => AppIcons.userAdd,
    'add_product' => AppIcons.add,
    'view_projects' => AppIcons.booking,
    'inventory' => AppIcons.inventory,
    'clients' => AppIcons.client,
    'employees' => AppIcons.userSearch,
    'calendar' => AppIcons.calendar,
    'messages' => AppIcons.messages,
    _ => AppIcons.notification,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: const CustomAppBar(text: 'Customize Dashboard', showPfp: false),
      body: _loading
          ? const Center(child: CustomLoader())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
              children: [
                _heading('Dashboard cards', isDark),
                _reorderableList(
                  items: _sectionOrder,
                  labels: _sectionLabels,
                  enabled: _enabledSections,
                  isDark: isDark,
                  onReorder: (oldIndex, newIndex) => setState(() {
                    _sectionOrder.insert(
                      newIndex,
                      _sectionOrder.removeAt(oldIndex),
                    );
                  }),
                ),
                const SizedBox(height: 22),
                _heading('Quick actions', isDark),
                _reorderableList(
                  items: _actionOrder,
                  labels: _actionLabels,
                  enabled: _enabledActions,
                  isDark: isDark,
                  onReorder: (oldIndex, newIndex) => setState(() {
                    _actionOrder.insert(
                      newIndex,
                      _actionOrder.removeAt(oldIndex),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _heading(String text, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black,
      ),
    ),
  );

  Widget _reorderableList({
    required List<String> items,
    required Map<String, String> labels,
    required Set<String> enabled,
    required bool isDark,
    required ReorderCallback onReorder,
  }) => ReorderableListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    buildDefaultDragHandles: false,
    itemCount: items.length,
    onReorderItem: onReorder,
    itemBuilder: (context, index) {
      final id = items[index];
      final selected = enabled.contains(id);
      return Card(
        key: ValueKey(id),
        margin: const EdgeInsets.only(bottom: 7),
        color: isDark ? AppColors.darkSurface : Colors.white,
        child: ListTile(
          dense: true,
          leading: Checkbox.adaptive(
            value: selected,
            activeColor: AppColors.primary,
            onChanged: (value) => setState(
              () => value == true ? enabled.add(id) : enabled.remove(id),
            ),
          ),
          title: Text(labels[id] ?? id),
          subtitle: null,
          trailing: ReorderableDragStartListener(
            index: index,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconHandler.buildIcon(
                  imagePath: _iconFor(id),
                  color: selected ? AppColors.primary : Colors.grey,
                  size: 23,
                ),
                const SizedBox(width: 12),
                const Icon(Icons.drag_handle_rounded, color: Colors.grey),
              ],
            ),
          ),
          onTap: () =>
              setState(() => selected ? enabled.remove(id) : enabled.add(id)),
        ),
      );
    },
  );
}
