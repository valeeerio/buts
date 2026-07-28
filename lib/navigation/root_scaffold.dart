import 'package:flutter/cupertino.dart';
import '../models/area_type.dart';
import '../models/dashboard_area_summary.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/placeholder_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_tab.dart';

/// Scaffold radice dell'app: contiene la tab bar inferiore a 5 destinazioni
/// con Dashboard al centro, stile Instagram/WhatsApp.
///
/// Buste Paga NON è una tab: è raggiunta da un ingresso secondario dentro
/// la Dashboard (icona nell'header) e aperta come schermata push, non come tab.
class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  AppTab _activeTab = AppTab.dashboard;

  void _openBustePaga() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => const PlaceholderScreen(title: 'Buste Paga'),
      ),
    );
  }

  void _openAreaDetail(DashboardAreaSummary area) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PlaceholderScreen(title: area.type.label),
      ),
    );
  }

  Widget _screenForTab(AppTab tab) {
    switch (tab) {
      case AppTab.dashboard:
        return DashboardScreen(
          userName: 'Valerio',
          onOpenArea: _openAreaDetail,
          onOpenBustePaga: _openBustePaga,
        );
      case AppTab.contoPrincipale:
        return const PlaceholderScreen(title: 'Conto Principale');
      case AppTab.risparmioPrincipale:
        return const PlaceholderScreen(title: 'Risparmio Principale');
      case AppTab.piccoloRisparmio:
        return const PlaceholderScreen(title: 'Piccolo Risparmio');
      case AppTab.impegniFissi:
        return const PlaceholderScreen(title: 'Impegni Fissi');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _screenForTab(_activeTab)),
        _BottomTabBar(
          activeTab: _activeTab,
          onTabSelected: (tab) => setState(() => _activeTab = tab),
        ),
      ],
    );
  }
}

class _BottomTabBar extends StatelessWidget {
  final AppTab activeTab;
  final ValueChanged<AppTab> onTabSelected;

  const _BottomTabBar({required this.activeTab, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 10,
        bottom: 24 + MediaQuery.of(context).padding.bottom / 2,
      ),
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(AppColors.surface, context)
            .withOpacity(0.95),
        border: Border(
          top: BorderSide(
            color: CupertinoDynamicColor.resolve(AppColors.separator, context),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final tab in AppTab.orderedTabs)
            _TabBarItem(
              tab: tab,
              isActive: tab == activeTab,
              onTap: () => onTabSelected(tab),
            ),
        ],
      ),
    );
  }
}

class _TabBarItem extends StatelessWidget {
  final AppTab tab;
  final bool isActive;
  final VoidCallback onTap;

  const _TabBarItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? CupertinoDynamicColor.resolve(tab.activeColor, context)
        : CupertinoDynamicColor.resolve(AppColors.labelTertiary, context);

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tab.icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            tab.label,
            style: (isActive
                    ? AppTextStyles.tabLabelActive
                    : AppTextStyles.tabLabel)
                .copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
