import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/busta_paga.dart';
import '../../providers/buste_paga_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/busta_paga_list_item.dart';
import '../../widgets/busta_paga_summary_hero.dart';
import 'busta_paga_detail_screen.dart';
import 'busta_paga_form_screen.dart';

/// Contenitore di primo livello della sezione Buste Paga (pagina 0 del
/// PageView radice). Card in evidenza sull'ultima busta paga + archivio
/// completo ordinato per periodo decrescente. Il titolo di sezione è già
/// mostrato dall'header globale (`AppSectionHeader`), qui non va duplicato.
class BustePagaSectionScreen extends ConsumerWidget {
  const BustePagaSectionScreen({super.key});

  void _openForm(BuildContext context, {BustaPaga? existing}) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => BustaPagaFormScreen(existing: existing),
      ),
    );
  }

  void _openDetail(BuildContext context, BustaPaga bustaPaga) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => BustaPagaDetailScreen(bustaPaga: bustaPaga),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buste = ref.watch(busteRepositoryProvider);
    final ultima = ref.watch(ultimaBustaPagaProvider);
    final sorted = [...buste]..sort((a, b) => b.periodo.compareTo(a.periodo));

    return Container(
      color: CupertinoDynamicColor.resolve(AppColors.backgroundPrimary, context),
      child: SafeArea(
        top: false,
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Archivio buste paga',
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: CupertinoDynamicColor.resolve(
                              AppColors.labelPrimary, context),
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _openForm(context),
                      child: Icon(
                        CupertinoIcons.add_circled_solid,
                        size: 30,
                        color: CupertinoDynamicColor.resolve(
                            AppColors.bustePaga, context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (ultima != null) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                sliver: SliverToBoxAdapter(
                  child: BustaPagaSummaryHero(
                    bustaPaga: ultima,
                    onTap: () => _openDetail(context, ultima),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            ],
            if (sorted.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                sliver: SliverToBoxAdapter(
                  child: _EmptyState(onAdd: () => _openForm(context)),
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
                      onTap: () => _openDetail(context, bustaPaga),
                    );
                  },
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(AppColors.surface, context),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Icon(
            CupertinoIcons.doc_text_search,
            size: 32,
            color: CupertinoDynamicColor.resolve(AppColors.labelSecondary, context),
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
          CupertinoButton.filled(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            onPressed: onAdd,
            child: const Text('Aggiungi busta paga'),
          ),
        ],
      ),
    );
  }
}
