import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/busta_paga.dart';
import '../../providers/buste_paga_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/busta_paga_list_item.dart';
import '../../widgets/busta_paga_summary_hero.dart';
import '../../widgets/liquid_glass_button.dart';
import '../../widgets/liquid_glass_surface.dart';

/// Contenuto della tab "Archivio" della sezione Buste Paga: card in
/// evidenza sull'ultima busta paga + elenco completo ordinato per periodo
/// decrescente. Estratto da `BustePagaSectionScreen` per fare spazio alla
/// sotto-navigazione Archivio/Statistiche.
class BustePagaArchivioView extends ConsumerWidget {
  final ValueChanged<BustaPaga> onOpenDetail;
  final VoidCallback onAdd;

  const BustePagaArchivioView({
    super.key,
    required this.onOpenDetail,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buste = ref.watch(busteRepositoryProvider);
    final ultima = ref.watch(ultimaBustaPagaProvider);
    final sorted = [...buste]..sort((a, b) => b.periodo.compareTo(a.periodo));

    return CustomScrollView(
      slivers: [
        if (ultima != null) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: BustaPagaSummaryHero(
                bustaPaga: ultima,
                onTap: () => onOpenDetail(ultima),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        ] else
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
        if (sorted.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverToBoxAdapter(
              child: _EmptyState(onAdd: onAdd),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              0,
              AppSpacing.screenHorizontal,
              AppSpacing.xs,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Tutte le buste paga',
                style: AppTextStyles.cardLabel.copyWith(
                  color: CupertinoDynamicColor.resolve(
                      AppColors.labelSecondary, context),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverList.separated(
              itemCount: sorted.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final bustaPaga = sorted[index];
                return BustaPagaListItem(
                  bustaPaga: bustaPaga,
                  onTap: () => onOpenDetail(bustaPaga),
                );
              },
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoDynamicColor.resolve(AppColors.systemBlue, context);
    return LiquidGlassSurface(
      radius: AppRadius.glass,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Icon(
              CupertinoIcons.doc_text_search,
              size: 32,
              color: CupertinoDynamicColor.resolve(
                  AppColors.labelSecondary, context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Nessuna busta paga in archivio',
              style: AppTextStyles.subtitle.copyWith(
                fontWeight: FontWeight.w600,
                color: CupertinoDynamicColor.resolve(
                    AppColors.labelPrimary, context),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Aggiungi la tua prima busta paga per iniziare l\'archivio.',
              textAlign: TextAlign.center,
              style: AppTextStyles.cardLabel.copyWith(
                color: CupertinoDynamicColor.resolve(
                    AppColors.labelSecondary, context),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LiquidGlassButton(
              onPressed: onAdd,
              tint: accent,
              child: Text(
                'Aggiungi busta paga',
                style: AppTextStyles.subtitle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
