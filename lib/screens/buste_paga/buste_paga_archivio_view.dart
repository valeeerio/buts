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
import '../../widgets/app_alert_dialog.dart';
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
class BustePagaArchivioView extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<BustePagaArchivioView> createState() =>
      _BustePagaArchivioViewState();
}

class _BustePagaArchivioViewState extends ConsumerState<BustePagaArchivioView> {
  /// Anni con la sotto-sezione "Extra" (13esima/14esima) espansa — vuoto di
  /// default, quindi tutte chiuse all'apertura dell'Archivio.
  final Set<int> _extraEspansi = {};

  final _scrollController = ScrollController();

  // true finché non si è scrollato fino in fondo alla lista — nasconde la
  // dissolvenza di fondo (ShaderMask) non appena non c'è più altro sotto:
  // altrimenti, essendo un gradiente statico legato al viewport e non alla
  // posizione di scroll, l'ultima busta paga (o l'intera lista se sta tutta
  // a schermo senza bisogno di scroll) restava sempre semi-trasparente,
  // anche quando non c'era nient'altro da rivelare scorrendo oltre.
  bool _showBottomFade = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateBottomFade);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateBottomFade);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateBottomFade() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final showFade = position.pixels < position.maxScrollExtent - 1;
    if (showFade != _showBottomFade) {
      setState(() => _showBottomFade = showFade);
    }
  }

  /// Alert di conferma prima di eliminare davvero, mostrato dallo
  /// swipe-to-delete sia sull'hero sia sulle righe dell'elenco.
  Future<bool> _confirmaEliminazione(
    BuildContext context,
    BustaPaga bustaPaga,
  ) async {
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);
    final destructive =
        CupertinoDynamicColor.resolve(AppColors.systemRed, context);
    final risultato = await showAppAlertDialog<bool>(
      context: context,
      title: 'Elimina busta paga',
      message: 'Sei sicuro di voler eliminare la busta paga di '
          '${periodoLabel(bustaPaga)}?',
      actions: [
        AppAlertAction(
          label: 'Annulla',
          color: labelSecondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppAlertAction(
          label: 'Elimina',
          color: destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    return risultato ?? false;
  }

  /// Righe di un gruppo di buste paga (swipe-to-delete + tap per il
  /// dettaglio), fattorizzato perché sia la sotto-sezione "Extra" sia le
  /// mensilità normali di un anno usano esattamente questo pattern.
  Widget _bustePagaSliverList(WidgetRef ref, List<BustaPaga> buste) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.xs,
        AppSpacing.screenHorizontal,
        0,
      ),
      sliver: SliverList.separated(
        itemCount: buste.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final bustaPaga = buste[index];
          return Dismissible(
            key: ValueKey('row-${bustaPaga.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmaEliminazione(context, bustaPaga),
            onDismissed: (_) =>
                ref.read(busteRepositoryProvider.notifier).remove(bustaPaga.id),
            background:
                const SwipeDeleteBackground(radius: AppRadius.glassSmall),
            child: BustaPagaListItem(
              bustaPaga: bustaPaga,
              onTap: () => widget.onOpenDetail(bustaPaga),
            ),
          );
        },
      ),
    );
  }

  /// Contenuto (`sliver:`) di un `SliverStickyHeader` anno: le mensilità
  /// normali, poi in fondo la sotto-sezione "Extra" (13esima/14esima) se
  /// presente — header tappabile con freccetta che espande/collassa
  /// `_bustePagaSliverList(extra)`, chiusa di default (`anno` non in
  /// `_extraEspansi`). Niente sticky header annidato (non supportato da
  /// `flutter_sticky_header`), tutto sotto lo stesso header "$anno".
  Widget _yearSliver(BuildContext context, WidgetRef ref, int anno, List<BustaPaga> buste) {
    // Ordine fisso per tipo (13esima sempre prima della 14esima), non
    // cronologico per mese come le mensilità: il mese registrato su
    // ciascuna può variare da un anno all'altro, l'ordine per tipo resta
    // prevedibile in ogni sezione "Extra".
    final extra = buste.where((b) => b.tipo != TipoBustaPaga.mensile).toList()
      ..sort((a, b) => a.tipo.index.compareTo(b.tipo.index));
    final normali = buste.where((b) => b.tipo == TipoBustaPaga.mensile).toList();
    final espansa = _extraEspansi.contains(anno);

    return SliverMainAxisGroup(
      slivers: [
        if (extra.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: CupertinoButton(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.xs,
                AppSpacing.screenHorizontal,
                AppSpacing.xs,
              ),
              minimumSize: Size.zero,
              onPressed: () => setState(() {
                if (espansa) {
                  _extraEspansi.remove(anno);
                } else {
                  _extraEspansi.add(anno);
                }
              }),
              child: Row(
                children: [
                  Text(
                    'Extra',
                    style: AppTextStyles.cardLabel.copyWith(
                      fontWeight: FontWeight.w600,
                      color: CupertinoDynamicColor.resolve(
                          AppColors.labelSecondary, context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AnimatedRotation(
                    turns: espansa ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: CupertinoDynamicColor.resolve(
                          AppColors.labelSecondary, context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (espansa) _bustePagaSliverList(ref, extra),
          if (normali.isNotEmpty)
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.md),
            ),
        ],
        if (normali.isNotEmpty) _bustePagaSliverList(ref, normali),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final buste = ref.watch(busteRepositoryProvider);
    final ultima = ref.watch(ultimaBustaPagaProvider);
    final sorted = [...buste]..sort((a, b) => b.periodo.compareTo(a.periodo));
    final filtered =
        widget.searchActive ? _filtered(sorted, widget.query) : sorted;
    final byYear = _groupByYear(filtered);
    final anni = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
    final nessunRisultato = widget.searchActive &&
        widget.query.trim().isNotEmpty &&
        filtered.isEmpty;
    final mostraHero = !widget.searchActive && ultima != null;

    // Ricontrolla dopo ogni layout (non solo sullo scroll dell'utente): il
    // contenuto della lista cambia (import/eliminazione, ricerca) e con
    // esso può cambiare se c'è ancora altro da scorrere sotto.
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateBottomFade());

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
                onTap: () => widget.onOpenDetail(ultima),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Expanded(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) {
              final fadeHeight = _showBottomFade ? 120.0 : 0.0;
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
              controller: _scrollController,
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
                      child: _EmptyState(onAdd: widget.onAdd),
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
                      child: _NessunRisultato(query: widget.query.trim()),
                    ),
                  )
                else
                  for (final anno in anni) ...[
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
                      sliver: _yearSliver(context, ref, anno, byYear[anno]!),
                    ),
                    if (anno != anni.last)
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.lg),
                      ),
                  ],
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
