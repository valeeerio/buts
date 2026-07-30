import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';

import '../../models/busta_paga.dart';
import '../../providers/buste_paga_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/busta_paga_formatting.dart';
import '../../widgets/busta_paga_list_item.dart';
import '../../widgets/busta_paga_summary_hero.dart';
import '../../widgets/liquid_glass_button.dart';
import '../../widgets/liquid_glass_surface.dart';
import '../../widgets/swipe_delete_background.dart';

/// Filtra le buste paga per periodo (nome mese e/o anno, case-insensitive).
/// Query vuota (dopo trim) restituisce l'elenco invariato.
List<BustaPaga> _filtered(List<BustaPaga> sorted, String query) {
  final normalized = query.toLowerCase().trim();
  if (normalized.isEmpty) return sorted;
  return sorted
      .where((b) => periodoLabel(b).toLowerCase().contains(normalized))
      .toList();
}

/// Raggruppa per anno preservando l'ordine decrescente dell'elenco in
/// ingresso (già ordinato per periodo decrescente).
Map<int, List<BustaPaga>> _groupByYear(List<BustaPaga> sorted) {
  final Map<int, List<BustaPaga>> byYear = {};
  for (final bustaPaga in sorted) {
    byYear.putIfAbsent(bustaPaga.periodo.year, () => []).add(bustaPaga);
  }
  return byYear;
}

/// Contenuto della tab "Archivio" della sezione Buste Paga: card in
/// evidenza sull'ultima busta paga + elenco raggruppato per anno (header
/// sticky, stile Contatti/Mail). Estratto da `BustePagaSectionScreen` per
/// fare spazio alla sotto-navigazione Archivio/Statistiche. La ricerca per
/// periodo è pilotata dall'esterno (campo minimale nel titolo di
/// `BustePagaSectionScreen`): quando `searchActive` è vero l'hero
/// dell'ultima busta paga si nasconde per fare spazio all'elenco filtrato.
class BustePagaArchivioView extends ConsumerWidget {
  final ValueChanged<BustaPaga> onOpenDetail;
  final VoidCallback onAdd;
  final bool searchActive;
  final String query;

  const BustePagaArchivioView({
    super.key,
    required this.onOpenDetail,
    required this.onAdd,
    required this.searchActive,
    required this.query,
  });

  /// Alert di conferma prima di eliminare davvero, mostrato dallo
  /// swipe-to-delete sia sull'hero sia sulle righe dell'elenco.
  Future<bool> _confirmaEliminazione(
    BuildContext context,
    BustaPaga bustaPaga,
  ) async {
    final risultato = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Elimina busta paga'),
        content: Text(
          'Sei sicuro di voler eliminare la busta paga di '
          '${periodoLabel(bustaPaga)}?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    return risultato ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buste = ref.watch(busteRepositoryProvider);
    final ultima = ref.watch(ultimaBustaPagaProvider);
    final sorted = [...buste]..sort((a, b) => b.periodo.compareTo(a.periodo));
    final filtered = searchActive ? _filtered(sorted, query) : sorted;
    final byYear = _groupByYear(filtered);
    final anni = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
    final nessunRisultato =
        searchActive && query.trim().isNotEmpty && filtered.isEmpty;
    final mostraHero = !searchActive && ultima != null;

    return Column(
      children: [
        if (mostraHero) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              0,
            ),
            child: Dismissible(
              key: ValueKey('hero-${ultima.id}'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => _confirmaEliminazione(context, ultima),
              onDismissed: (_) =>
                  ref.read(busteRepositoryProvider.notifier).remove(
                        ultima.id,
                      ),
              background: const SwipeDeleteBackground(radius: AppRadius.glass),
              child: BustaPagaSummaryHero(
                bustaPaga: ultima,
                onTap: () => onOpenDetail(ultima),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Expanded(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) {
              const fadeHeight = 120.0;
              final stop = 1 - (fadeHeight / rect.height).clamp(0.0, 1.0);
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [
                  CupertinoColors.white,
                  CupertinoColors.white,
                  CupertinoColors.transparent,
                ],
                stops: [0.0, stop, 1.0],
              ).createShader(rect);
            },
            child: CustomScrollView(
              slivers: [
                if (!mostraHero)
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.sm),
                  ),
                if (sorted.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _EmptyState(onAdd: onAdd),
                    ),
                  )
                else if (nessunRisultato)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.lg,
                      AppSpacing.screenHorizontal,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _NessunRisultato(query: query.trim()),
                    ),
                  )
                else
                  for (final anno in anni)
                    SliverStickyHeader(
                      header: _pinnedBackground(
                        context,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenHorizontal,
                            AppSpacing.xs,
                            AppSpacing.screenHorizontal,
                            AppSpacing.sm + 2,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '$anno',
                              style: AppTextStyles.subtitle.copyWith(
                                fontWeight: FontWeight.w600,
                                color: CupertinoDynamicColor.resolve(
                                    AppColors.labelPrimary, context),
                              ),
                            ),
                          ),
                        ),
                      ),
                      sliver: SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          AppSpacing.xs,
                          AppSpacing.screenHorizontal,
                          0,
                        ),
                        sliver: SliverList.separated(
                          itemCount: byYear[anno]!.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final bustaPaga = byYear[anno]![index];
                            return Dismissible(
                              key: ValueKey('row-${bustaPaga.id}'),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) =>
                                  _confirmaEliminazione(context, bustaPaga),
                              onDismissed: (_) => ref
                                  .read(busteRepositoryProvider.notifier)
                                  .remove(bustaPaga.id),
                              background: const SwipeDeleteBackground(
                                  radius: AppRadius.glassSmall),
                              child: BustaPagaListItem(
                                bustaPaga: bustaPaga,
                                onTap: () => onOpenDetail(bustaPaga),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xl),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Sfondo "chrome" traslucido/sfocato condiviso dai due header pinned
/// (ricerca e anno): vero `BackdropFilter` sul contenuto scrollato
/// sottostante, coerente con il materiale Liquid Glass invece di un
/// riempimento piatto a tinta unita.
Widget _pinnedBackground(BuildContext context, {required Widget child}) {
  final fill =
      CupertinoDynamicColor.resolve(AppColors.backgroundPrimary, context);
  return ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: DecoratedBox(
        decoration: BoxDecoration(color: fill.withValues(alpha: 0.8)),
        child: child,
      ),
    ),
  );
}

class _NessunRisultato extends StatelessWidget {
  final String query;

  const _NessunRisultato({required this.query});

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSurface(
      radius: AppRadius.glassSmall,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Icon(
              CupertinoIcons.search,
              size: 28,
              color: CupertinoDynamicColor.resolve(
                  AppColors.labelSecondary, context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Nessun risultato per "$query"',
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(
                fontWeight: FontWeight.w600,
                color: CupertinoDynamicColor.resolve(
                    AppColors.labelPrimary, context),
              ),
            ),
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
