import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/dashboard_area_summary.dart';
import '../../providers/buste_paga_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/area_summary_card.dart';
import '../../widgets/donut_summary.dart';
import '../../widgets/insight_card.dart';

/// Schermata Dashboard: saluto → riepilogo a donut → insight automatico →
/// le 4 card delle aree di budget. Non contiene la tab bar: quella vive
/// nello scaffold radice (root_scaffold.dart), la Dashboard è solo il contenuto.
///
/// Il netto dell'ultima busta paga (sezione Buste Paga, di pari livello)
/// alimenta qui la suddivisione mensile del budget — vedi
/// ultimaBustaPagaProvider in lib/providers/buste_paga_provider.dart. Nessun
/// doppio inserimento manuale del netto.
class DashboardScreen extends ConsumerWidget {
  final String userName;
  final void Function(DashboardAreaSummary area) onOpenArea;

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.onOpenArea,
  });

  String get _greeting {
    final hour = DateTime.now().hour;
    final saluto = (hour >= 6 && hour < 18) ? 'Buongiorno' : 'Buonasera';
    return '$saluto, $userName';
  }

  String get _monthLabel {
    final formatted = DateFormat('MMMM yyyy', 'it_IT').format(DateTime.now());
    final capitalized = formatted[0].toUpperCase() + formatted.substring(1);
    return '$capitalized · ecco la tua situazione';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areas = DashboardMockData.areas;
    final total = DashboardMockData.totalAmount;
    final ultimaBustaPaga = ref.watch(ultimaBustaPagaProvider);

    return Container(
      color: CupertinoDynamicColor.resolve(AppColors.backgroundPrimary, context),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.lg,
                AppSpacing.screenHorizontal,
                AppSpacing.sm,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: AppTextStyles.greeting.copyWith(
                        color: CupertinoDynamicColor.resolve(
                            AppColors.labelPrimary, context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _monthLabel,
                      style: AppTextStyles.subtitle.copyWith(
                        color: CupertinoDynamicColor.resolve(
                            AppColors.labelSecondary, context),
                      ),
                    ),
                    if (ultimaBustaPaga != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Netto disponibile da Buste Paga: '
                        '€ ${ultimaBustaPaga.netto.toStringAsFixed(2)}',
                        style: AppTextStyles.subtitle.copyWith(
                          color: CupertinoDynamicColor.resolve(
                              AppColors.labelSecondary, context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: SliverToBoxAdapter(
                child: DonutSummary(areas: areas, total: total),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: const SliverToBoxAdapter(
                child: InsightCard(
                  mode: InsightMode.positive,
                  text: 'Hai speso il 12% in meno questo mese rispetto alla media.',
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              sliver: SliverList.separated(
                itemCount: areas.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final area = areas[index];
                  return AreaSummaryCard(
                    area: area,
                    onTap: () => onOpenArea(area),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],
        ),
      ),
    );
  }
}
