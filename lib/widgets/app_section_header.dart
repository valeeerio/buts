import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../navigation/app_section.dart';
import '../navigation/app_section_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Top bar persistente sopra il PageView delle 2 sezioni: mostra icona ed
/// etichetta della sezione attiva a sinistra, freccia per lo swipe assistito
/// a destra (punta sempre verso "l'altra" sezione). Non è una sidebar
/// laterale — è una barra orizzontale in alto, fuori dal PageView.
class AppSectionHeader extends ConsumerWidget {
  final ValueChanged<AppSection> onNavigate;

  const AppSectionHeader({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSection = ref.watch(activeSectionProvider);
    final targetSection =
        AppSection.orderedSections[1 - activeSection.index];

    return Container(
      color: CupertinoDynamicColor.resolve(AppColors.surface, context),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                activeSection.icon,
                size: 20,
                color: CupertinoDynamicColor.resolve(
                    activeSection.accentColor, context),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                activeSection.label,
                style: AppTextStyles.subtitle.copyWith(
                  color: CupertinoDynamicColor.resolve(
                      AppColors.labelPrimary, context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => onNavigate(targetSection),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      targetSection.label,
                      style: AppTextStyles.subtitle.copyWith(
                        color: CupertinoDynamicColor.resolve(
                            AppColors.labelSecondary, context),
                      ),
                    ),
                    Icon(
                      activeSection.index == 0
                          ? CupertinoIcons.chevron_right
                          : CupertinoIcons.chevron_left,
                      size: 18,
                      color: CupertinoDynamicColor.resolve(
                          AppColors.labelSecondary, context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
