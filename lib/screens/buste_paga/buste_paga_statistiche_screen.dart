import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/busta_paga.dart';
import '../../providers/buste_paga_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/busta_paga_formatting.dart';
import '../../widgets/progress_ring_tile.dart';
import '../../widgets/pulse_icon.dart';
import '../../widgets/pulse_surface.dart';

/// Contenuto della tab "Statistiche" della sezione Buste Paga.
///
/// Redesign 2026-08-30 (approvato dall'utente su mockup, vedi CLAUDE.md):
/// 3 card, ciascuna con una vista "protagonista" (numeri grandi + area
/// chart con glow / anelli di progresso grandi / barre a gradiente) e le
/// vecchie tabelle Media/Minimo/Massimo/Totale spostate dietro un link
/// "Dettagli" collassabile — stessa logica di calcolo/aggregazione/filtro
/// periodo di prima, solo riorganizzazione visiva (eccezione consapevole: il
/// blocco Ferie/Permessi/Ex festività passa da un trend nel tempo a uno
/// snapshot dell'ultima busta paga nel periodo filtrato).
///
/// Palette: `pulseAccent` (ciano) resta il colore funzionale primario,
/// `pulseSecondaryGlow` (viola) è usato qui SOLO come seconda serie/accento
/// decorativo di dati grafico (linea Lordo, anello Ferie, metà del
/// gradiente delle barre Straordinario) — mai per icone/testo/bottoni
/// interattivi, coerente con CLAUDE.md.
class BustePagaStatisticheScreen extends ConsumerWidget {
  final ({DateTime start, DateTime end})? periodoFiltro;

  const BustePagaStatisticheScreen({super.key, this.periodoFiltro});

  // Dissolvenza in fondo allo scroll, stesso pattern di
  // BustePagaArchivioView ma con fadeHeight tarato a parte: il viewport qui
  // ha densità diversa (3 card ampie invece di righe fitte), vedi CLAUDE.md
  // sulla nota "non assumere lo stesso valore assoluto tra schermate".
  static const _fadeHeight = 90.0;

  // Netto: area piena + linea con glow, colore funzionale primario
  // dell'app (`pulseAccent`, ciano).
  static const _nettoColor = AppColors.pulseAccent;
  // Lordo: seconda linea più sottile, uso decorativo del viola come serie
  // dati in un grafico (eccezione consapevole, vedi CLAUDE.md).
  static const _lordoColor = AppColors.pulseSecondaryGlow;
  // Anelli dello snapshot Ferie/Permessi/Ex festività: stessa terna di
  // colori del mockup approvato.
  static const _ferieColor = AppColors.pulseSecondaryGlow;
  static const _permessiRolColor = AppColors.pulseAccent;
  static const _exFestivitaColor = AppColors.pulsePositive;
  // Gradiente delle barre Straordinario (verticale viola→ciano) e tinta del
  // glow dietro la barra più alta.
  static const _straordinarioGradientTop = AppColors.pulseSecondaryGlow;
  static const _straordinarioGradientBottom = AppColors.pulseAccent;
  static const _straordinarioGlowColor = AppColors.pulseAccent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tutte = ref.watch(busteRepositoryProvider);
    final buste = tutte.where(bustaInclusaInStatistiche).toList();
    final sorted = [...buste]..sort((a, b) => a.periodo.compareTo(b.periodo));
    final filtro = periodoFiltro;
    final filtrati = filtro == null
        ? sorted
        : sorted
            .where((b) =>
                !b.periodo.isBefore(filtro.start) &&
                !b.periodo.isAfter(filtro.end))
            .toList();

    // Buste mensili "Da confermare" nel periodo selezionato (stesso filtro
    // di `filtrati`, criterio permissivo di [_bustaInclusaInRangePeriodo]
    // meno restrittivo di [bustaInclusaInStatistiche]): lo slider di periodo
    // sopra i grafici le include già (estende gli estremi min/max), ma i
    // grafici no — appena importate più buste paga in un colpo solo e prima
    // di confermarle, l'utente vedrebbe altrimenti uno slider popolato sopra
    // a tre card "Non ci sono dati" senza spiegazione, apparentemente un bug
    // di rendering. Passato a ogni grafico per un messaggio esplicito nello
    // stato vuoto (vedi [_NoDataMessage]) invece di quello generico.
    final busteNonConfermate = tutte
        .where((b) =>
            b.tipo == TipoBustaPaga.mensile &&
            b.statoVerifica == StatoVerificaBustaPaga.daConfermare &&
            (filtro == null ||
                (!b.periodo.isBefore(filtro.start) &&
                    !b.periodo.isAfter(filtro.end))))
        .length;

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final stop = 1 - (_fadeHeight / rect.height).clamp(0.0, 1.0);
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
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
              AppSpacing.screenHorizontal,
              AppSpacing.md,
            ),
            sliver: SliverToBoxAdapter(
              child: _ChartCard(
                title: 'Netto e lordo',
                chart: filtrati.isEmpty
                    ? SizedBox(
                        height: 180,
                        child: _NoDataMessage(
                            busteNonConfermate: busteNonConfermate),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _NettoLordoHeader(buste: filtrati),
                          const SizedBox(height: AppSpacing.md),
                          const Wrap(
                            spacing: AppSpacing.md,
                            runSpacing: AppSpacing.xs,
                            children: [
                              _LegendEntryChip(
                                  label: 'Netto', color: _nettoColor),
                              _LegendEntryChip(
                                  label: 'Lordo', color: _lordoColor),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            height: 180,
                            child: _NettoLordoChart(buste: filtrati),
                          ),
                        ],
                      ),
                stats: _nettoLordoStats(filtrati),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              0,
              AppSpacing.screenHorizontal,
              AppSpacing.md,
            ),
            sliver: SliverToBoxAdapter(
              child: _ChartCard(
                title: 'Ferie, permessi ed ex festività',
                subtitle: filtrati.isEmpty
                    ? null
                    : 'Ultima busta paga: ${periodoLabel(filtrati.last)}',
                chart: _FerieRolPermessiSnapshot(
                  buste: filtrati,
                  busteNonConfermate: busteNonConfermate,
                ),
                stats: _ferieRolPermessiStats(filtrati),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              0,
              AppSpacing.screenHorizontal,
              AppSpacing.xl,
            ),
            sliver: SliverToBoxAdapter(
              child: _ChartCard(
                title: 'Straordinario per mese',
                chart: _StraordinarioChart(
                  buste: filtrati,
                  busteNonConfermate: busteNonConfermate,
                ),
                stats: _straordinarioStats(filtrati),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Messaggio mostrato al posto del grafico quando non ci sono buste paga da
/// rappresentare — archivio vuoto (nessuna busta paga mensile confermata nel
/// periodo selezionato), oppure [busteNonConfermate] > 0: in quel caso i
/// dati esistono e sono già inclusi nello slider di periodo sopra i grafici
/// (vedi `_bustaInclusaInRangePeriodo`), ma sono esclusi da qui perché non
/// ancora confermati (`bustaInclusaInStatistiche`) — un messaggio esplicito
/// al posto del generico "Non ci sono dati" evita che l'utente scambi
/// questo per un bug di rendering subito dopo un import massivo.
class _NoDataMessage extends StatelessWidget {
  final int busteNonConfermate;

  const _NoDataMessage({this.busteNonConfermate = 0});

  @override
  Widget build(BuildContext context) {
    final secondary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);
    final messaggio = busteNonConfermate <= 0
        ? 'Non ci sono dati'
        : busteNonConfermate == 1
            ? 'Hai 1 busta paga da confermare: confermala per vederla nei '
                'grafici.'
            : 'Hai $busteNonConfermate buste paga da confermare: '
                'confermale per vederle nei grafici.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            busteNonConfermate > 0
                ? PulseIcon(
                    glyph: PulseIconGlyph.checkmark,
                    size: 28,
                    color: secondary,
                  )
                : PulseIcon(
                    glyph: PulseIconGlyph.chart,
                    size: 28,
                    color: secondary,
                  ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              messaggio,
              textAlign: TextAlign.center,
              style: AppTextStyles.pulseBody.copyWith(color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip di legenda (pallino colorato + etichetta) usato sotto i numeri
/// grandi del blocco Netto/Lordo, per disambiguare area (Netto) e linea
/// sottile (Lordo).
class _LegendEntryChip extends StatelessWidget {
  final String label;
  final CupertinoDynamicColor color;

  const _LegendEntryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final resolved = CupertinoDynamicColor.resolve(color, context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: resolved, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.pulseLabel.copyWith(
            color: CupertinoDynamicColor.resolve(
                AppColors.pulseTextSecondary, context),
          ),
        ),
      ],
    );
  }
}

/// Card che ospita un grafico/vista principale, più — se [stats] non è
/// `null` e ha righe — un link testuale "Dettagli" che espande/nasconde la
/// vecchia tabella Media/Minimo/Massimo/Totale (`AnimatedSize`, collassata
/// di default). Stessa superficie piatta con bordo a gradiente viola→ciano
/// di prima (`PulseSurface` + `Container` esterno).
class _ChartCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget chart;
  final _StatsTableData? stats;

  const _ChartCard({
    required this.title,
    this.subtitle,
    required this.chart,
    this.stats,
  });

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Bordo sottile a gradiente viola→ciano (direzione "gradient mesh", vedi
    // CLAUDE.md): non tocca `PulseSurface` in sé (widget condiviso da tutta
    // l'app, fuori scope qui) — un `Container` esterno con un `BoxDecoration`
    // a gradiente e 1px di `padding` disegna il bordo "attorno" alla
    // superficie piatta, così i tre grafici non sembrano isolati dal resto
    // dell'app ora più riccamente colorata, senza introdurre una seconda
    // superficie/ombra sovrapposta.
    final violet =
        CupertinoDynamicColor.resolve(AppColors.pulseSecondaryGlow, context);
    final cyan = CupertinoDynamicColor.resolve(AppColors.pulseAccent, context);
    final secondary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);
    final accent =
        CupertinoDynamicColor.resolve(AppColors.pulseAccent, context);
    final hasStats = widget.stats != null && widget.stats!.righe.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pulse),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            violet.withValues(alpha: 0.35),
            cyan.withValues(alpha: 0.35),
          ],
        ),
      ),
      padding: const EdgeInsets.all(1),
      child: PulseSurface(
        borderRadius: AppRadius.pulse,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: AppTextStyles.pulseBodyEmphasis.copyWith(
                  color: CupertinoDynamicColor.resolve(
                      AppColors.pulseTextPrimary, context),
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  widget.subtitle!,
                  style: AppTextStyles.pulseLabel.copyWith(color: secondary),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              widget.chart,
              if (hasStats) ...[
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _expanded ? 'Nascondi dettagli' : 'Dettagli',
                          style:
                              AppTextStyles.pulseLabel.copyWith(color: accent),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 220),
                          turns: _expanded ? 0.5 : 0,
                          child: PulseIcon(
                            glyph: PulseIconGlyph.chevronDown,
                            size: 12,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: _StatsTable(data: widget.stats!),
                        )
                      : const SizedBox(width: double.infinity, height: 0),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dati di `_StatsTable`: [colonne] è il nome di ciascuna serie (es.
/// `['Netto', 'Lordo']`), [righe] una lista di (etichetta metrica, un
/// valore già formattato per colonna, stesso ordine di [colonne]).
typedef _StatsTableData = ({
  List<String> colonne,
  List<(String label, List<String> valori)> righe,
});

/// Tabella numerica (media/min/max/totale) sotto un grafico Statistiche —
/// stesso pattern di `_MaturazioniSection` nel dettaglio busta paga
/// (`Row`+`Expanded` a flex fissi, non `Table`): riga header con i nomi
/// delle serie, poi una riga per metrica con un valore per colonna. Dal
/// redesign 2026-08-30 vive dietro il link "Dettagli" di `_ChartCard`
/// invece di essere sempre visibile — nessun cambio al contenuto/struttura
/// della tabella in sé.
class _StatsTable extends StatelessWidget {
  final _StatsTableData data;

  const _StatsTable({required this.data});

  @override
  Widget build(BuildContext context) {
    final labelColor =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);
    final valueColor =
        CupertinoDynamicColor.resolve(AppColors.pulseTextPrimary, context);
    final dividerColor = labelColor.withValues(alpha: 0.3);
    final headerStyle = AppTextStyles.pulseLabel.copyWith(color: labelColor);
    final labelStyle = AppTextStyles.pulseBody.copyWith(
      color: valueColor,
      fontWeight: FontWeight.w600,
    );
    final valueStyle = AppTextStyles.pulseBody.copyWith(color: valueColor);

    Widget divider() => Container(height: 0.5, color: dividerColor);
    Widget columnDivider() => Container(
          width: 0.5,
          margin: const EdgeInsets.symmetric(vertical: 2),
          color: dividerColor,
        );

    // Il testo non deve mai andare a capo (anche con celle lunghe tipo
    // "€ 1563.99 (mag '26)" in colonne strette): FittedBox lo restringe
    // fino a stare su una riga sola invece di lasciarlo wrappare — garanzia
    // strutturale indipendente dal numero di colonne del grafico. Il
    // `Padding` orizzontale attorno al `FittedBox` è necessario oltre al
    // `columnDivider` (0.5px, quasi invisibile): senza margine esplicito, il
    // testo di due celle scalate a piena larghezza (es. "9,00 (gen '26)" e
    // "17,80 (gen '26)" nella riga Minimo) arriva a ridosso del divisore su
    // entrambi i lati e appare come un'unica stringa attaccata — bug reale
    // corretto qui, non un'ipotesi.
    Widget cell(String text, TextStyle style,
        {TextAlign align = TextAlign.center}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: align == TextAlign.center
              ? Alignment.center
              : Alignment.centerLeft,
          child: Text(text, style: style, maxLines: 1, softWrap: false),
        ),
      );
    }

    // Un divisore verticale sottile tra ogni colonna (oltre a quelli
    // orizzontali tra le righe), per separare a colpo d'occhio le serie
    // quando sono 2-3 affiancate (Netto/Lordo, Ferie/Permessi).
    List<Widget> withColumnDividers(List<Widget> celle) {
      return [
        for (var i = 0; i < celle.length; i++) ...[
          if (i > 0) columnDivider(),
          celle[i],
        ],
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: withColumnDividers([
              const Expanded(flex: 2, child: SizedBox.shrink()),
              for (final colonna in data.colonne)
                Expanded(
                  flex: 2,
                  child: cell(colonna, headerStyle),
                ),
            ]),
          ),
        ),
        divider(),
        for (var i = 0; i < data.righe.length; i++) ...[
          if (i > 0) divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: withColumnDividers([
                Expanded(
                  flex: 2,
                  child:
                      cell(data.righe[i].$1, labelStyle, align: TextAlign.left),
                ),
                for (final valore in data.righe[i].$2)
                  Expanded(
                    flex: 2,
                    child: cell(valore, valueStyle),
                  ),
              ]),
            ),
          ),
        ],
      ],
    );
  }
}

/// Trova la busta paga con il valore minimo secondo [selettore]. Richiede
/// [buste] non vuota.
BustaPaga _bustaConMinimo(
    List<BustaPaga> buste, double Function(BustaPaga) selettore) {
  return buste.reduce((a, b) => selettore(a) <= selettore(b) ? a : b);
}

/// Trova la busta paga con il valore massimo secondo [selettore]. Richiede
/// [buste] non vuota.
BustaPaga _bustaConMassimo(
    List<BustaPaga> buste, double Function(BustaPaga) selettore) {
  return buste.reduce((a, b) => selettore(a) >= selettore(b) ? a : b);
}

double _media(List<BustaPaga> buste, double Function(BustaPaga) selettore) {
  return buste.map(selettore).reduce((a, b) => a + b) / buste.length;
}

double _totale(List<BustaPaga> buste, double Function(BustaPaga) selettore) {
  return buste.map(selettore).reduce((a, b) => a + b);
}

/// Formatta sempre con 2 decimali fissi e formato italiano (punto per le
/// migliaia, virgola per i decimali — a differenza di `toStringAsFixed`,
/// locale-indipendente e quindi sempre col punto) — usato solo nelle
/// tabelle statistiche sotto i grafici, dove valori nella stessa colonna con
/// un numero di decimali incoerente (es. "1.487,00" sotto "1.449,25")
/// rendono più difficile scansionare la colonna a colpo d'occhio. Delega a
/// [formatNumberFixed] in `busta_paga_formatting.dart` invece di duplicare
/// la logica di formattazione.
String _formatStatNumber(double value) => formatNumberFixed(value);

/// Tabella del riepilogo sotto il grafico Netto/Lordo. Opera sulle stesse
/// [buste] già filtrate (confermate, mensili, nel periodo selezionato) che
/// alimentano il grafico — nessun ricalcolo parallelo del filtro.
_StatsTableData? _nettoLordoStats(List<BustaPaga> buste) {
  if (buste.isEmpty) return null;
  final minNetto = _bustaConMinimo(buste, (b) => b.netto);
  final maxNetto = _bustaConMassimo(buste, (b) => b.netto);
  final minLordo = _bustaConMinimo(buste, (b) => b.lordo);
  final maxLordo = _bustaConMassimo(buste, (b) => b.lordo);
  return (
    colonne: const ['Netto', 'Lordo'],
    righe: [
      (
        'Media',
        [
          formatEuroConSegno(_media(buste, (b) => b.netto)),
          formatEuroConSegno(_media(buste, (b) => b.lordo)),
        ],
      ),
      (
        'Minimo',
        [
          '${formatEuroConSegno(minNetto.netto)} (${periodoAxisLabel(minNetto.periodo)})',
          '${formatEuroConSegno(minLordo.lordo)} (${periodoAxisLabel(minLordo.periodo)})',
        ],
      ),
      (
        'Massimo',
        [
          '${formatEuroConSegno(maxNetto.netto)} (${periodoAxisLabel(maxNetto.periodo)})',
          '${formatEuroConSegno(maxLordo.lordo)} (${periodoAxisLabel(maxLordo.periodo)})',
        ],
      ),
      (
        'Totale',
        [
          formatEuroConSegno(_totale(buste, (b) => b.netto)),
          formatEuroConSegno(_totale(buste, (b) => b.lordo)),
        ],
      ),
    ],
  );
}

/// Tabella del riepilogo sotto il grafico Ferie/Permessi. Ferie residue
/// e permessi residui (dato `rolResidui`) sono saldi puntuali mese per mese
/// (non quantità da sommare), quindi la riga "Totale" li mostra come `'—'`
/// — solo i permessi orario goduti sono una quantità che ha senso cumulare
/// nel periodo. Stessa convenzione già usata da `_MaturazioniSection` nel
/// dettaglio busta paga per le celle non applicabili. Contenuto invariato
/// dal redesign 2026-08-30 (vive dietro "Dettagli"): il blocco visivo
/// principale sopra è ora uno snapshot dell'ultima busta paga, ma questa
/// tabella resta il trend su tutto il periodo filtrato, come prima.
_StatsTableData? _ferieRolPermessiStats(List<BustaPaga> buste) {
  if (buste.isEmpty) return null;
  final minFerie = _bustaConMinimo(buste, (b) => b.ferieResidue);
  final maxFerie = _bustaConMassimo(buste, (b) => b.ferieResidue);
  final minRol = _bustaConMinimo(buste, (b) => b.rolResidui);
  final maxRol = _bustaConMassimo(buste, (b) => b.rolResidui);
  final minExFestivita = _bustaConMinimo(buste, (b) => b.exFestivitaResidue);
  final maxExFestivita = _bustaConMassimo(buste, (b) => b.exFestivitaResidue);
  return (
    // "Perm. orario" (non "Permessi orario"): l'etichetta completa era
    // l'unica delle 4 intestazioni troppo larga per la colonna, forzando lo
    // scale-down di `FittedBox` a una dimensione visibilmente più piccola
    // delle altre 3 — bug reale corretto qui, non un'ipotesi. Accorciare
    // l'etichetta invece di affidarsi allo scale-down mantiene tutte le
    // intestazioni alla stessa dimensione di font.
    colonne: const ['Ferie', 'Permessi', 'Perm. orario', 'Ex festività'],
    righe: [
      (
        'Media',
        [
          _formatStatNumber(_media(buste, (b) => b.ferieResidue)),
          _formatStatNumber(_media(buste, (b) => b.rolResidui)),
          _formatStatNumber(_media(buste, (b) => b.permessiGodutiMese)),
          _formatStatNumber(_media(buste, (b) => b.exFestivitaResidue)),
        ],
      ),
      (
        'Minimo',
        [
          '${_formatStatNumber(minFerie.ferieResidue)} (${periodoAxisLabel(minFerie.periodo)})',
          '${_formatStatNumber(minRol.rolResidui)} (${periodoAxisLabel(minRol.periodo)})',
          '—',
          '${_formatStatNumber(minExFestivita.exFestivitaResidue)} (${periodoAxisLabel(minExFestivita.periodo)})',
        ],
      ),
      (
        'Massimo',
        [
          '${_formatStatNumber(maxFerie.ferieResidue)} (${periodoAxisLabel(maxFerie.periodo)})',
          '${_formatStatNumber(maxRol.rolResidui)} (${periodoAxisLabel(maxRol.periodo)})',
          '—',
          '${_formatStatNumber(maxExFestivita.exFestivitaResidue)} (${periodoAxisLabel(maxExFestivita.periodo)})',
        ],
      ),
      (
        'Totale',
        [
          '—',
          '—',
          _formatStatNumber(_totale(buste, (b) => b.permessiGodutiMese)),
          '—',
        ],
      ),
    ],
  );
}

/// Tabella del riepilogo sotto il grafico Straordinario. Calcolata sempre
/// sulle buste mensili non aggregate (non sui bucket trimestrali usati per
/// disegnare le barre quando l'aggregazione è attiva in
/// `_StraordinarioChart`): media e mese di picco devono restare a livello
/// di mese reale.
_StatsTableData? _straordinarioStats(List<BustaPaga> buste) {
  if (buste.isEmpty) return null;
  final min = _bustaConMinimo(buste, (b) => b.straordinari);
  final max = _bustaConMassimo(buste, (b) => b.straordinari);
  return (
    colonne: const ['Ore straordinario'],
    righe: [
      (
        'Media',
        ['${_formatStatNumber(_media(buste, (b) => b.straordinari))} h/mese']
      ),
      (
        'Minimo',
        [
          '${_formatStatNumber(min.straordinari)} h (${periodoAxisLabel(min.periodo)})'
        ],
      ),
      (
        'Massimo',
        [
          '${_formatStatNumber(max.straordinari)} h (${periodoAxisLabel(max.periodo)})'
        ],
      ),
      (
        'Totale',
        ['${_formatStatNumber(_totale(buste, (b) => b.straordinari))} h']
      ),
    ],
  );
}

/// Interval degli indici mostrati sull'asse X: non solo in base al conteggio
/// di buste paga, ma anche alla larghezza reale disponibile per etichetta —
/// altrimenti con poche buste (interval sempre 1) le etichette da 6-7
/// caratteri si sovrappongono quando le barre/punti sono ravvicinati.
double _bottomTitleInterval({
  required int count,
  required double availableWidth,
  double estimatedLabelWidth = 34.0,
}) {
  if (count <= 1) return 1;
  final maxLabelsThatFit =
      (availableWidth / estimatedLabelWidth).floor().clamp(1, count);
  return (count / maxLabelsThatFit).ceilToDouble();
}

/// Oltre questo numero di buste paga nel periodo selezionato, l'asse X passa
/// da un'etichetta per mese ("gen '24") a una per anno ("'24") — con range
/// lunghi (es. gen '24 → ago '26) le etichette mensili si sovrappongono
/// anche dopo il diradamento di `_bottomTitleInterval`.
const _yearlyLabelsThreshold = 14;

/// Oltre questo numero di *slot mensili* nella griglia continua
/// (`_grigliaMensile`, l'ampiezza temporale coperta dal filtro — non il
/// numero di buste paga confermate, che può restare basso pur coprendo un
/// arco di molti anni se mancano mesi), `_StraordinarioChart` passa da barre
/// mensili a barre trimestrali (somma ore per trimestre): con 2+ anni di
/// dati mensili le barre diventano troppo sottili per essere lette anche con
/// lo scroll orizzontale, e 30 barre singole sono meno leggibili di un
/// andamento aggregato per trimestre.
const _quarterlyAggregationThreshold = 24;

/// Etichetta trimestre (es. "T1 '24"), usata sull'asse X e nel tooltip di
/// `_StraordinarioChart` quando le barre sono aggregate per trimestre.
String _trimestreLabel(DateTime periodo) {
  final trimestre = (periodo.month - 1) ~/ 3 + 1;
  return "T$trimestre '${annoAxisLabel(periodo).substring(1)}";
}

/// Aggrega [buste] per trimestre solare, sommando le ore di straordinario di
/// ogni trimestre. Il [DateTime] di ogni bucket è il primo giorno del primo
/// mese del trimestre, usato come riferimento per etichette e tooltip.
/// Assume [buste] ordinata per periodo crescente.
List<({DateTime periodo, double totale})> _aggregaStraordinariPerTrimestre(
    List<BustaPaga> buste) {
  final totali = <int, double>{};
  final riferimenti = <int, DateTime>{};
  for (final busta in buste) {
    final trimestre = (busta.periodo.month - 1) ~/ 3;
    final chiave = busta.periodo.year * 10 + trimestre;
    totali[chiave] = (totali[chiave] ?? 0) + busta.straordinari;
    riferimenti[chiave] ??= DateTime(busta.periodo.year, trimestre * 3 + 1);
  }
  final chiaviOrdinate = totali.keys.toList()..sort();
  return [
    for (final chiave in chiaviOrdinate)
      (periodo: riferimenti[chiave]!, totale: totali[chiave]!),
  ];
}

/// Indici del primo periodo di ogni anno presente in [periodi] (assume
/// [periodi] ordinata crescente) — usati per le etichette asse X in
/// modalità annuale.
List<int> _yearBoundaryIndices(List<DateTime> periodi) {
  final indices = <int>[];
  for (var i = 0; i < periodi.length; i++) {
    if (i == 0 || periodi[i].year != periodi[i - 1].year) {
      indices.add(i);
    }
  }
  return indices;
}

/// Espande [buste] (assunta ordinata per periodo crescente, un solo
/// elemento per mese solare — garantito da [bustaInclusaInStatistiche], che
/// filtra solo mensili confermate: l'app impedisce comunque due mensili
/// nello stesso anno+mese, vedi controllo anti-duplicati in
/// `buste_paga_section_screen.dart`) in una sequenza continua di TUTTI i
/// mesi solari fra il primo e l'ultimo periodo presente, un elemento per
/// mese: quelli senza una busta paga (mese non ancora confermato o non
/// importato) hanno `busta: null`.
///
/// Usata per disegnare le serie dei grafici su un asse X che riflette il
/// calendario reale invece della sola posizione nell'array: prima di questo
/// fix `FlSpot(i.toDouble(), ...)` usava l'indice nella lista filtrata come
/// coordinata X, quindi un mese mancante (frequente in un reimport massivo,
/// dove le buste si confermano una alla volta) faceva letteralmente sparire
/// il buco — la riga/barra del mese precedente si univa a quella del mese
/// successivo come se fossero consecutivi, senza alcun segnale visivo.
/// Con la griglia, l'indice nell'array coincide sempre con un preciso mese
/// solare (compresi quelli senza dati): un mese mancante resta uno slot con
/// `busta: null`, che i chiamanti traducono in un vero e proprio buco visivo
/// — `FlSpot.nullSpot` per le linee (fl_chart spezza la linea in più
/// segmenti quando incontra uno "spot nullo", meccanismo nativo, non uno
/// stratagemma: vedi `LineChartBarData.spots`) e l'assenza di una barra per
/// `_StraordinarioChart` — invece di un'interpolazione silenziosa.
List<({DateTime periodo, BustaPaga? busta})> _grigliaMensile(
  List<BustaPaga> buste,
) {
  if (buste.isEmpty) return const [];
  final risultato = <({DateTime periodo, BustaPaga? busta})>[];
  var cursore = DateTime(buste.first.periodo.year, buste.first.periodo.month);
  final fine = DateTime(buste.last.periodo.year, buste.last.periodo.month);
  var indice = 0;
  while (!cursore.isAfter(fine)) {
    final corrisponde = indice < buste.length &&
        buste[indice].periodo.year == cursore.year &&
        buste[indice].periodo.month == cursore.month;
    risultato.add(
      (periodo: cursore, busta: corrisponde ? buste[indice] : null),
    );
    if (corrisponde) indice++;
    // `DateTime(year, month + 1)` normalizza da solo il riporto a gennaio
    // dell'anno successivo quando `month` supera 12.
    cursore = DateTime(cursore.year, cursore.month + 1);
  }
  return risultato;
}

/// Analoga a [_grigliaMensile] ma a livello di trimestre, sui bucket già
/// prodotti da [_aggregaStraordinariPerTrimestre]: un trimestre interamente
/// privo di buste paga confermate (3 mesi consecutivi mancanti, possibile
/// solo quando l'aggregazione trimestrale è attiva, cioè con 2+ anni di
/// dati) resta comunque un buco visibile invece di sparire. Richiede
/// [buste] non vuota.
List<({DateTime periodo, double? totale})> _grigliaTrimestrale(
  List<BustaPaga> buste,
) {
  final aggregati = _aggregaStraordinariPerTrimestre(buste);
  int chiaveTrimestre(DateTime periodo) =>
      periodo.year * 4 + (periodo.month - 1) ~/ 3;
  final mappa = <int, double>{
    for (final punto in aggregati) chiaveTrimestre(punto.periodo): punto.totale,
  };
  final risultato = <({DateTime periodo, double? totale})>[];
  final chiaveFine = chiaveTrimestre(aggregati.last.periodo);
  for (var chiave = chiaveTrimestre(aggregati.first.periodo);
      chiave <= chiaveFine;
      chiave++) {
    final anno = chiave ~/ 4;
    final trimestre = chiave % 4;
    risultato.add(
      (periodo: DateTime(anno, trimestre * 3 + 1), totale: mappa[chiave]),
    );
  }
  return risultato;
}

/// Asse X condiviso dai tre grafici della schermata (etichette periodo
/// diradate in base allo spazio disponibile) — estratto per evitare che il
/// fix della sovrapposizione venga applicato a un solo grafico per errore.
/// Prende una lista di [periodi] invece delle buste paga intere, così può
/// essere riusata anche per punti aggregati (es. barre trimestrali di
/// `_StraordinarioChart`) che non corrispondono 1:1 a una `BustaPaga`.
/// [shortLabelBuilder] permette di personalizzare l'etichetta di dettaglio
/// (default "gen '24"), usato per il caso trimestrale ("T1 '24").
AxisTitles _periodoBottomAxisTitles({
  required List<DateTime> periodi,
  required double availableWidth,
  required Color labelColor,
  String Function(DateTime periodo) shortLabelBuilder = meseAxisLabel,
}) {
  final textStyle =
      AppTextStyles.pulseLabel.copyWith(color: labelColor, fontSize: 10);

  if (periodi.length > _yearlyLabelsThreshold) {
    final boundaries = _yearBoundaryIndices(periodi);
    final boundaryInterval = _bottomTitleInterval(
      count: boundaries.length,
      availableWidth: availableWidth,
      estimatedLabelWidth: 20.0,
    ).round();
    final shown = <int>{
      for (var i = 0; i < boundaries.length; i += boundaryInterval)
        boundaries[i],
    };
    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 22,
        interval: 1,
        getTitlesWidget: (value, meta) {
          final index = value.round();
          if (index < 0 || index >= periodi.length || !shown.contains(index)) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(annoAxisLabel(periodi[index]), style: textStyle),
          );
        },
      ),
    );
  }

  // Sotto la soglia annuale l'etichetta resta il solo mese ("ago") — con un
  // periodo che attraversa un solo anno solare non c'è ambiguità. Quando
  // invece [periodi] attraversa più anni (tipico di un archivio con 12+
  // mensilità su due anni solari, es. ago '25 → lug '26), lo stesso nome di
  // mese può comparire due volte identico ("ago ott dic feb apr giu" non
  // rivela a colpo d'occhio che si passa da un anno all'altro): si forza
  // sempre visibile il primo tick di ogni anno (`_yearBoundaryIndices`,
  // stesso helper già usato sopra per la modalità annuale) e SOLO su quei
  // tick si mostra il periodo completo con l'anno (`periodoAxisLabel`, "ago
  // '25") invece del solo mese — un'etichetta più lunga isolata nel punto
  // in cui serve davvero, non su ogni tick (che affollerebbe l'asse senza
  // aggiungere informazione ai tick "interni" a un anno già stabilito dal
  // tick precedente).
  //
  // Si applica SOLO quando [shortLabelBuilder] è il default (etichetta solo
  // mese): il caso trimestrale di `_StraordinarioChart` aggregato
  // (`_trimestreLabel`, "T1 '24") include già sempre l'anno per costruzione,
  // quindi non necessita di (e andrebbe anzi in conflitto di formato con)
  // questo trattamento.
  final usaEtichettaMeseDefault = identical(shortLabelBuilder, meseAxisLabel);
  final multiAnno = usaEtichettaMeseDefault &&
      periodi.isNotEmpty &&
      periodi.first.year != periodi.last.year;
  final confiniAnno =
      multiAnno ? _yearBoundaryIndices(periodi).toSet() : const <int>{};
  final interval = _bottomTitleInterval(
      count: periodi.length, availableWidth: availableWidth);
  final intervalSteps = interval.round();
  final gridIndices = <int>{
    for (var i = 0; i < periodi.length; i += intervalSteps) i,
  };
  // Unione "grezza" griglia regolare + confini anno: un confine non allineato
  // alla griglia (es. griglia diradata ogni 2 con confine all'indice 5) cade
  // a un solo indice di distanza da un tick regolare adiacente (4 o 6) — le
  // due etichette finirebbero attaccate, e quella di confine è pure più
  // lunga (mese+anno anziché solo mese). Il confine porta più informazione
  // e vince sempre: si scartano i tick regolari troppo vicini (a meno di
  // `intervalSteps`, la stessa distanza minima già usata per evitare
  // sovrapposizioni fra due tick regolari) a un confine, invece di mostrarli
  // entrambi adiacenti.
  final shown = <int>{...gridIndices, ...confiniAnno}..removeWhere((i) =>
      !confiniAnno.contains(i) &&
      confiniAnno.any((c) => (i - c).abs() < intervalSteps));
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 22,
      interval: 1,
      getTitlesWidget: (value, meta) {
        final index = value.round();
        if (index < 0 || index >= periodi.length || !shown.contains(index)) {
          return const SizedBox.shrink();
        }
        final label = confiniAnno.contains(index)
            ? periodoAxisLabel(periodi[index])
            : shortLabelBuilder(periodi[index]);
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(label, style: textStyle),
        );
      },
    ),
  );
}

/// Asse Y condiviso (valori sempre visibili, per dare la scala generale del
/// grafico senza dover toccare ogni punto/barra). Un solo asse per grafico:
/// nei grafici multi-serie tutte le serie condividono la stessa scala,
/// approccio più semplice scelto come primo passo — da rivedere con doppio
/// asse solo se le grandezze combinate risultassero poco leggibili.
AxisTitles _valueLeftAxisTitles({
  required Color labelColor,
  required double interval,
  String Function(double value) formatValue = formatNumber,
  // 40 di default (etichette corte tipo "12,5"/"20,0h" di `formatNumber`,
  // usate da Straordinario). Il grafico Netto/Lordo passa esplicitamente
  // `_euroCompactAxisReservedSize` (52): margine extra per il caso peggiore
  // plausibile del suo formato compatto ("− € 12,3k", vedi
  // `formatEuroConSegnoCompatto`) alla dimensione naturale del font (fontSize
  // 10), senza affidarsi allo scale-down di `FittedBox` sotto la soglia di
  // leggibilità.
  double reservedSize = 40,
}) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: reservedSize,
      // Interval SEMPRE esplicito (mai lasciato calcolare da fl_chart): senza
      // questo, con un range di dati stretto (es. un solo mese), fl_chart
      // sceglie da solo uno step piccolo (es. €20-30) che, una volta passato
      // a [formatValue] con la sua risoluzione di arrotondamento (es. "k" a
      // un decimale, cioè €100, di `formatEuroConSegnoCompatto`), produce
      // etichette duplicate su tick adiacenti — bug reale corretto qui, non
      // un'ipotesi. [interval] arriva già calcolato da [_niceStep] con una
      // soglia minima legata alla risoluzione del formato usato su
      // quell'asse, e dagli stessi bound "nice" allineati allo stesso step
      // (vedi `_niceAxisBounds`), così i tick coincidono sempre con min/max.
      interval: interval,
      getTitlesWidget: (value, meta) {
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: SizedBox(
            // -6 per il padding a destra sopra, così la larghezza reale
            // dell'etichetta resta sempre coerente con [reservedSize] invece
            // di un valore fisso indipendente che potrebbe disallinearsi.
            width: reservedSize - 6,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formatValue(value),
                style: AppTextStyles.pulseLabel
                    .copyWith(color: labelColor, fontSize: 10),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Arrotonda un intervallo di dati a multipli "puliti" di [step], così il
/// bordo dell'asse (`minY`/`maxY`) coincide sempre con un tick reale.
/// Senza questo, lasciare che fl_chart calcoli da solo `minY`/`maxY` produce
/// spesso un bordo non allineato ai tick automatici (es. 105.60 quando i
/// tick sono 0/50/100): fl_chart aggiunge comunque un'etichetta forzata al
/// bordo, che finisce per sovrapporsi al tick "pulito" più vicino.
/// Calcola uno step "nice" (1, 2 o 5 × una potenza di 10) per i tick di un
/// asse valori, mirando a circa [targetTicks] tick sul [range] di dati, ma
/// mai sotto [minStep] — la risoluzione minima della formattazione usata su
/// quell'asse (es. €100 per `formatEuroConSegnoCompatto` in notazione "k",
/// dove un decimale corrisponde a un decimo di migliaio). Con un range
/// stretto (es. un solo mese di dati) lo step "naturale" (range/targetTicks)
/// scenderebbe spesso sotto quella risoluzione, producendo tick adiacenti che
/// si formattano nella stessa stringa (bug reale corretto qui, non
/// un'ipotesi — vedi `_valueLeftAxisTitles`). Con un range ampio lo step
/// "nice" naturale è già più grande di [minStep], quindi il clamp non ha
/// alcun effetto e il numero di tick resta vicino a [targetTicks] invece di
/// esplodere: la stessa funzione copre così sia il caso "pochi
/// dati/range stretto" sia "molti dati/range ampio" senza introdurre
/// l'estremo opposto (assi con 1-2 soli tick).
double _niceStep(
  double range, {
  double targetTicks = 5,
  required double minStep,
}) {
  if (range <= 0) return minStep;
  final rawStep = range / targetTicks;
  final magnitude =
      math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
  final residual = rawStep / magnitude;
  final double niceResidual;
  if (residual <= 1) {
    niceResidual = 1;
  } else if (residual <= 2) {
    niceResidual = 2;
  } else if (residual <= 5) {
    niceResidual = 5;
  } else {
    niceResidual = 10;
  }
  final step = niceResidual * magnitude;
  return step < minStep ? minStep : step;
}

({double min, double max}) _niceAxisBounds(
  double dataMin,
  double dataMax, {
  required double step,
}) {
  final min = (dataMin / step).floor() * step;
  var max = (dataMax / step).ceil() * step;
  if (max <= min) max += step;
  return (min: min, max: max);
}

/// `reservedSize` di [_valueLeftAxisTitles] per il grafico Netto/Lordo,
/// l'unico che usa il formato euro compatto (`formatEuroConSegnoCompatto`,
/// caso peggiore "− € 12,3k") — costante condivisa per evitare che il fix del
/// disallineamento 40 vs 52 (vedi `_StraordinarioChartState._leftAxisWidth`)
/// si ripresenti in futuro se il valore viene cambiato in un solo punto.
const _euroCompactAxisReservedSize = 52.0;

/// Colori condivisi per lo sfondo/testo dei tooltip al tocco, usati da tutti
/// e tre i grafici — estratti per non avere tre calcoli divergenti.
({Color background, Color text}) _tooltipColors(BuildContext context) {
  return (
    background:
        CupertinoDynamicColor.resolve(AppColors.pulseTextPrimary, context),
    text: CupertinoDynamicColor.resolve(AppColors.pulseBackground, context),
  );
}

/// Badge freccia + percentuale di variazione (▲ verde/▼ rossa) sotto un
/// valore in evidenza — usato dai due numeri grandi del blocco Netto/Lordo.
/// `null` produce un widget vuoto (nessun mese precedente nel periodo
/// filtrato con cui confrontare, o precedente pari a zero — divisione non
/// definita).
class _VariationBadge extends StatelessWidget {
  final double? variazione;

  const _VariationBadge({required this.variazione});

  @override
  Widget build(BuildContext context) {
    final variazione = this.variazione;
    if (variazione == null) return const SizedBox.shrink();
    final positiva = variazione >= 0;
    final color = CupertinoDynamicColor.resolve(
      positiva ? AppColors.pulsePositive : AppColors.pulseNegative,
      context,
    );
    final percentuale = variazione.abs() * 100;
    // Una sola cifra decimale sotto il 10% (es. "3,2%"), intero oltre (es.
    // "18%") — coerente con la risoluzione già usata da `formatNumber` per
    // valori piccoli senza appesantire percentuali a due cifre.
    final testo = percentuale < 10
        ? '${percentuale.toStringAsFixed(1).replaceAll('.', ',')}%'
        : '${percentuale.round()}%';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          positiva
              ? CupertinoIcons.arrow_up_right
              : CupertinoIcons.arrow_down_right,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(testo, style: AppTextStyles.pulseLabel.copyWith(color: color)),
      ],
    );
  }
}

/// Due numeri grandi affiancati (Netto/Lordo) in cima al blocco 1, con la
/// variazione percentuale rispetto al mese immediatamente precedente
/// nell'elenco già filtrato dal periodo — non necessariamente il mese
/// solare precedente, se il periodo filtrato ha dei buchi. Richiede [buste]
/// non vuota, ordinata per periodo crescente.
class _NettoLordoHeader extends StatelessWidget {
  final List<BustaPaga> buste;

  const _NettoLordoHeader({required this.buste});

  double? _variazione(double Function(BustaPaga) selettore) {
    if (buste.length < 2) return null;
    final attuale = selettore(buste.last);
    final precedente = selettore(buste[buste.length - 2]);
    if (precedente == 0) return null;
    return (attuale - precedente) / precedente;
  }

  @override
  Widget build(BuildContext context) {
    final ultima = buste.last;
    final primary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextPrimary, context);
    final secondary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);
    final dividerColor = secondary.withValues(alpha: 0.25);

    Widget colonna(String label, double valore, double? variazione) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppTextStyles.pulseLabel.copyWith(color: secondary)),
            const SizedBox(height: 4),
            Text(
              formatEuroConSegno(valore),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.pulseDisplayLarge
                  .copyWith(fontSize: 24, color: primary),
            ),
            const SizedBox(height: 4),
            _VariationBadge(variazione: variazione),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        colonna('Netto', ultima.netto, _variazione((b) => b.netto)),
        Container(
          width: 0.5,
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          color: dividerColor,
        ),
        colonna('Lordo', ultima.lordo, _variazione((b) => b.lordo)),
      ],
    );
  }
}

/// Grafico ad area del blocco Netto/Lordo: Netto è un'area piena con
/// gradiente che sfuma a trasparente verso il basso più una linea con
/// glow (`LineChartBarData.shadow`, supportato nativamente da fl_chart —
/// applica un `MaskFilter.blur` dietro il tracciato del percorso, vedi
/// `line_chart_painter.dart`); Lordo è una seconda linea più sottile senza
/// riempimento. Stessa griglia mensile continua/bound "nice"/tooltip di
/// prima del redesign, nessun cambio alla logica di aggregazione dei dati.
class _NettoLordoChart extends StatelessWidget {
  final List<BustaPaga> buste;

  const _NettoLordoChart({required this.buste});

  @override
  Widget build(BuildContext context) {
    final nettoColor = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._nettoColor, context);
    final lordoColor = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._lordoColor, context);
    final gridColor =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context)
            .withValues(alpha: 0.18);
    final labelColor =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);
    final tooltip = _tooltipColors(context);

    // Griglia continua mese per mese (vedi doc di libreria su
    // `_grigliaMensile`): un mese senza busta paga confermata resta un buco
    // visibile nel grafico (`FlSpot.nullSpot`) invece di sparire
    // silenziosamente collegando i due mesi adiacenti come se fossero
    // consecutivi.
    final griglia = _grigliaMensile(buste);

    // Range ristretto ai dati reali (non da 0): Netto e Lordo hanno un
    // divario fisso di alcune centinaia di euro (INPS/IRPEF) che, su un
    // asse condiviso partito da 0, schiacciava le due linee ciascuna vicino
    // al proprio estremo con un grande vuoto in mezzo. Margine 8% sopra e
    // sotto il range osservato, poi arrotondato a centinaia "pulite".
    final valori = [
      ...buste.map((b) => b.netto),
      ...buste.map((b) => b.lordo),
    ];
    final datiMin = valori.reduce((a, b) => a < b ? a : b);
    final datiMax = valori.reduce((a, b) => a > b ? a : b);
    final margine = (datiMax - datiMin) * 0.08;
    // Step minimo di €100: coincide con la risoluzione di arrotondamento di
    // `formatEuroConSegnoCompatto` in notazione "k" (un decimale = un decimo
    // di migliaio) — vedi doc di [_niceStep], evita etichette duplicate
    // sull'asse con un range di dati stretto.
    final step = _niceStep(
      (datiMax + margine) - (datiMin - margine),
      minStep: 100,
    );
    final bounds = _niceAxisBounds(
      datiMin - margine,
      datiMax + margine,
      step: step,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return LineChart(
          LineChartData(
            minY: bounds.min,
            maxY: bounds.max,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: null,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: gridColor, strokeWidth: 0.5),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: _valueLeftAxisTitles(
                labelColor: labelColor,
                interval: step,
                // Formato compatto SOLO per l'etichetta dell'asse (spazio
                // ristretto): `formatEuroConSegno` resta usato per tooltip e
                // tabella riepilogativa, dove serve precisione a 2 decimali
                // — vedi doc di `formatEuroConSegnoCompatto`.
                formatValue: formatEuroConSegnoCompatto,
                reservedSize: _euroCompactAxisReservedSize,
              ),
              bottomTitles: _periodoBottomAxisTitles(
                periodi: [for (final g in griglia) g.periodo],
                availableWidth: constraints.maxWidth,
                labelColor: labelColor,
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => tooltip.background,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (touchedSpots) {
                  return [
                    for (var i = 0; i < touchedSpots.length; i++)
                      _tooltipItem(
                        griglia,
                        touchedSpots[i],
                        showPeriodo: i == 0,
                        textColor: tooltip.text,
                      ),
                  ];
                },
              ),
            ),
            lineBarsData: [
              // Lordo disegnato PRIMA (sotto) così la linea/area Netto con
              // glow resta visivamente in primo piano sopra la linea sottile
              // Lordo nei punti in cui si sovrappongono.
              _lordoLine(griglia, lordoColor),
              _nettoLine(griglia, nettoColor),
            ],
          ),
        );
      },
    );
  }

  LineTooltipItem? _tooltipItem(
    List<({DateTime periodo, BustaPaga? busta})> griglia,
    LineBarSpot spot, {
    required bool showPeriodo,
    required Color textColor,
  }) {
    final busta = griglia[spot.x.toInt()].busta;
    // Guardia difensiva: fl_chart esclude gli spot nulli dal touch
    // detection (`getNearestTouchedSpot`), quindi in pratica `busta` non è
    // mai `null` qui — ma un tooltip mancante è comunque preferibile a un
    // crash se questa garanzia dovesse mai cambiare.
    if (busta == null) return null;
    final label = spot.barIndex == 0 ? 'Lordo' : 'Netto';
    final text = showPeriodo
        ? '${periodoAxisLabel(busta.periodo)}\n$label: ${formatEuroConSegno(spot.y)}'
        : '$label: ${formatEuroConSegno(spot.y)}';
    return LineTooltipItem(
      text,
      AppTextStyles.pulseBody.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  List<FlSpot> _spots(
    List<({DateTime periodo, BustaPaga? busta})> griglia,
    double Function(BustaPaga) selettore,
  ) {
    return [
      for (var i = 0; i < griglia.length; i++)
        griglia[i].busta == null
            ? FlSpot.nullSpot
            : FlSpot(i.toDouble(), selettore(griglia[i].busta!)),
    ];
  }

  LineChartBarData _nettoLine(
    List<({DateTime periodo, BustaPaga? busta})> griglia,
    Color color,
  ) {
    return LineChartBarData(
      spots: _spots(griglia, (b) => b.netto),
      isCurved: true,
      curveSmoothness: 0.2,
      color: color,
      barWidth: 2.5,
      // Glow nativo dietro il tracciato — vedi doc di libreria.
      shadow: Shadow(color: color.withValues(alpha: 0.55), blurRadius: 14),
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.32),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }

  LineChartBarData _lordoLine(
    List<({DateTime periodo, BustaPaga? busta})> griglia,
    Color color,
  ) {
    return LineChartBarData(
      spots: _spots(griglia, (b) => b.lordo),
      isCurved: true,
      curveSmoothness: 0.2,
      color: color.withValues(alpha: 0.85),
      barWidth: 1.5,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }
}

/// Frazione residuo/maturato, clampata e senza dividere per zero se
/// `maturato` è 0 (nessun rateo maturato in questa busta paga) — stesso
/// pattern di `_MaturazioniRingsRow._progress` in `buste_paga_archivio_view.
/// dart`.
double _progressoResiduo(double residuo, double maturato) {
  if (maturato <= 0) return 0;
  return (residuo / maturato).clamp(0.0, 1.0);
}

/// Snapshot Ferie/Permessi/Ex festività residui: 3 anelli di progresso
/// grandi sull'ULTIMA busta paga del periodo filtrato (non più un trend nel
/// tempo, unica eccezione consapevole di questo redesign — vedi CLAUDE.md).
class _FerieRolPermessiSnapshot extends StatelessWidget {
  final List<BustaPaga> buste;
  final int busteNonConfermate;

  const _FerieRolPermessiSnapshot({
    required this.buste,
    this.busteNonConfermate = 0,
  });

  static const _diameter = 60.0;

  @override
  Widget build(BuildContext context) {
    if (buste.isEmpty) {
      return SizedBox(
        height: 180,
        child: _NoDataMessage(busteNonConfermate: busteNonConfermate),
      );
    }

    final ultima = buste.last;
    final ferieColor = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._ferieColor, context);
    final permessiRolColor = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._permessiRolColor, context);
    final exFestivitaColor = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._exFestivitaColor, context);

    return Row(
      children: [
        Expanded(
          child: ProgressRingTile(
            label: 'Ferie',
            value: formatNumber(ultima.ferieResidue),
            progress:
                _progressoResiduo(ultima.ferieResidue, ultima.ferieMaturate),
            accentColor: ferieColor,
            diameter: _diameter,
            showGradientBorder: true,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ProgressRingTile(
            label: 'Permessi',
            value: formatNumber(ultima.rolResidui),
            progress: _progressoResiduo(ultima.rolResidui, ultima.rolMaturati),
            accentColor: permessiRolColor,
            diameter: _diameter,
            showGradientBorder: true,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ProgressRingTile(
            label: 'Ex festività',
            value: formatNumber(ultima.exFestivitaResidue),
            progress: _progressoResiduo(
              ultima.exFestivitaResidue,
              ultima.exFestivitaMaturate,
            ),
            accentColor: exFestivitaColor,
            diameter: _diameter,
            showGradientBorder: true,
          ),
        ),
      ],
    );
  }
}

/// Grafico Straordinario per mese. Su range ampi (> [_quarterlyAggregationThreshold]
/// buste) le barre passano da mensili a trimestrali (vedi
/// `_aggregaStraordinariPerTrimestre`); se anche con l'aggregazione le barre
/// risulterebbero più strette di [_minGroupSlotWidth], il grafico diventa
/// scrollabile in orizzontale (barre a larghezza fissa leggibile) con
/// l'asse valori a sinistra tenuto fisso in un `BarChart` "scheletro"
/// separato — fl_chart non supporta nativamente un asse fisso + plot
/// scrollabile in un singolo chart. Ogni barra ha un gradiente verticale
/// viola→ciano (invece del vecchio arancione piatto); la barra del valore
/// più alto nel periodo filtrato ha in più un alone sfumato dietro di sé
/// (approssimazione del "glow": `BarChartRodData` in questa versione di
/// fl_chart non espone un parametro `shadow` nativo come `LineChartBarData`
/// — un cerchio sfumato posizionato dietro la barra via `BoxShadow`, alla
/// stessa coordinata X approssimata del centro del gruppo, è il miglior
/// risultato ottenibile senza reimplementare il layout interno del chart).
class _StraordinarioChart extends StatefulWidget {
  final List<BustaPaga> buste;
  final int busteNonConfermate;

  const _StraordinarioChart({
    required this.buste,
    this.busteNonConfermate = 0,
  });

  @override
  State<_StraordinarioChart> createState() => _StraordinarioChartState();
}

class _StraordinarioChartState extends State<_StraordinarioChart> {
  static const _barWidth = 16.0;
  static const _groupsSpace = 20.0;
  static const _minGroupSlotWidth = _barWidth + _groupsSpace;
  // Larghezza della colonna fissa dell'asse Y in `buildAxisOnly()` (modalità
  // scroll orizzontale): deve corrispondere esattamente al `reservedSize`
  // passato a `_valueLeftAxisTitles` in ENTRAMBI i percorsi di rendering
  // (`buildPlot`/`buildAxisOnly`) di questo grafico — bug reale corretto qui
  // (40 vs 52, vedi CLAUDE.md), non un'ipotesi: se in futuro serve un valore
  // diverso dal default di `_valueLeftAxisTitles`, va cambiato qui e passato
  // esplicitamente a entrambe le chiamate sotto, mai lasciato disallineato.
  static const _leftAxisWidth = 40.0;
  static const _rightFadeWidth = 28.0;
  // Coincide con `reservedSize: 22` di `_periodoBottomAxisTitles` — il glow
  // dietro la barra più alta è ancorato appena sopra l'asse X, non alla
  // sommità reale della barra (vedi doc di libreria della classe).
  static const _bottomAxisReservedSize = 22.0;
  static const _glowDiameter = 64.0;

  final _scrollController = ScrollController();

  // true finché non si è scrollato fino in fondo — nasconde la dissolvenza
  // di bordo destro non appena non c'è più altro da scorrere, invece di
  // lasciarla sempre visibile come indicatore statico.
  bool _showRightFade = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateRightFade);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateRightFade);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateRightFade() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final showFade = position.pixels < position.maxScrollExtent - 1;
    if (showFade != _showRightFade) {
      setState(() => _showRightFade = showFade);
    }
  }

  @override
  Widget build(BuildContext context) {
    final buste = widget.buste;
    if (buste.isEmpty) {
      return SizedBox(
        height: 180,
        child: _NoDataMessage(busteNonConfermate: widget.busteNonConfermate),
      );
    }

    final gradientTop = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._straordinarioGradientTop, context);
    final gradientBottom = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._straordinarioGradientBottom, context);
    final glowColor = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._straordinarioGlowColor, context);
    final gridColor =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context)
            .withValues(alpha: 0.18);
    final labelColor =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);
    final tooltip = _tooltipColors(context);

    // Griglia continua (mensile o trimestrale a seconda dell'aggregazione),
    // stesso meccanismo di `_NettoLordoChart`: un mese/trimestre senza dati
    // resta un buco visibile (nessuna barra disegnata per quello slot)
    // invece di sparire silenziosamente avvicinando le barre dei
    // mesi/trimestri adiacenti come se fossero consecutivi.
    final grigliaMensile = _grigliaMensile(buste);
    // Decisione basata sull'ampiezza temporale reale coperta dalla griglia
    // (numero di slot mensili, buchi inclusi), non sul numero di buste paga
    // confermate: un archivio con molti mesi mancanti/non confermati ma che
    // copre un arco di molti anni renderizzerebbe altrimenti una griglia
    // mensile non aggregata su molti slot, con uno scroll orizzontale molto
    // lungo — in contrasto con l'intento della soglia (vedi doc su
    // `_quarterlyAggregationThreshold`).
    final aggregato = grigliaMensile.length > _quarterlyAggregationThreshold;
    final punti = aggregato
        ? _grigliaTrimestrale(buste)
        : [
            for (final g in grigliaMensile)
              (periodo: g.periodo, totale: g.busta?.straordinari),
          ];
    final shortLabelBuilder = aggregato ? _trimestreLabel : meseAxisLabel;

    final maxValue = punti.fold<double>(
        0, (max, p) => (p.totale ?? 0) > max ? p.totale! : max);
    final maxIndex =
        punti.indexWhere((p) => p.totale != null && p.totale == maxValue);
    final straordinarioAxisMax = maxValue <= 0 ? 1.0 : maxValue * 1.2;
    final step = _niceStep(straordinarioAxisMax, minStep: 1);
    final bounds = _niceAxisBounds(0, straordinarioAxisMax, step: step);

    // Posizione X approssimata (centro del gruppo `maxIndex`, layout
    // `BarChartAlignment.spaceEvenly` — il default di fl_chart quando non
    // specificato esplicitamente, vedi `BarChartData.alignment`): con N
    // gruppi equidistanziati su una larghezza `width`, il centro del gruppo
    // i-esimo è a `(i + 0.5) / N * width`. Un'approssimazione dichiarata,
    // non un valore pixel-perfect letto dal layout interno del chart (fl_
    // chart non lo espone) — sufficiente per un effetto decorativo di glow.
    // IMPORTANTE: `barGroups` sotto include SOLO le voci con `totale != null`
    // (`if (punti[i].totale != null)`) — fl_chart spazia equamente solo i
    // gruppi realmente renderizzati, "comprimendo via" i mesi mancanti invece
    // di lasciare uno slot vuoto proporzionale. `N` e l'indice del gruppo
    // massimo vanno quindi calcolati sul sottoinsieme filtrato (numero di
    // gruppi disegnati), non sull'indice grezzo/lunghezza di `punti` — con
    // anche un solo mese mancante prima della barra massima, usare l'indice
    // grezzo disallinea visibilmente l'alone dalla barra reale.
    Widget glowDietroBarraMassima(double width) {
      if (maxIndex < 0 || maxValue <= 0) return const SizedBox.shrink();
      final renderedCount = punti.where((p) => p.totale != null).length;
      final renderedMaxIndex =
          punti.take(maxIndex).where((p) => p.totale != null).length;
      final slotWidth = width / renderedCount;
      final centerX = (renderedMaxIndex + 0.5) * slotWidth;
      return Positioned(
        left: centerX - _glowDiameter / 2,
        bottom: _bottomAxisReservedSize,
        child: IgnorePointer(
          child: Container(
            width: _glowDiameter,
            height: _glowDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.5),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget buildPlot({required double width, required bool showLeftAxis}) {
      return SizedBox(
        width: width,
        child: Stack(
          children: [
            glowDietroBarraMassima(width),
            BarChart(
              BarChartData(
                minY: bounds.min,
                maxY: bounds.max,
                groupsSpace: _groupsSpace,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: gridColor, strokeWidth: 0.5),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: showLeftAxis
                      ? _valueLeftAxisTitles(
                          labelColor: labelColor,
                          interval: step,
                          reservedSize: _leftAxisWidth,
                        )
                      : const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: _periodoBottomAxisTitles(
                    periodi: [for (final p in punti) p.periodo],
                    availableWidth: width,
                    labelColor: labelColor,
                    shortLabelBuilder: shortLabelBuilder,
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => tooltip.background,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final punto = punti[group.x];
                      return BarTooltipItem(
                        '${shortLabelBuilder(punto.periodo)}\n'
                        '${formatNumber(rod.toY)} h',
                        AppTextStyles.pulseBody.copyWith(
                          color: tooltip.text,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < punti.length; i++)
                    if (punti[i].totale != null)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: punti[i].totale!,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: i == maxIndex
                                  ? [gradientTop, gradientBottom]
                                  : [
                                      gradientTop.withValues(alpha: 0.55),
                                      gradientBottom.withValues(alpha: 0.55),
                                    ],
                            ),
                            width: _barWidth,
                            borderRadius:
                                BorderRadius.circular(AppRadius.small / 2),
                          ),
                        ],
                      ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget buildAxisOnly() {
      return SizedBox(
        width: _leftAxisWidth,
        child: BarChart(
          BarChartData(
            minY: bounds.min,
            maxY: bounds.max,
            barGroups: const [],
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false, reservedSize: 22)),
              leftTitles: _valueLeftAxisTitles(
                labelColor: labelColor,
                interval: step,
                reservedSize: _leftAxisWidth,
              ),
            ),
          ),
        ),
      );
    }

    // `SizedBox(height: 180, ...)` esplicito attorno al `LayoutBuilder`:
    // il ramo "archivio vuoto" sopra usa la stessa altezza fissa, ma questo
    // ramo con dati reali ne era rimasto privo dopo il redesign "Pulse"
    // 2026-08-30 — prima di quel redesign `_ChartCard` avvolgeva SEMPRE
    // `chart` in un `SizedBox(height: 180, ...)` uniforme per tutti e tre i
    // grafici, ma la nuova `_ChartCard` (vedi sopra) passa `widget.chart`
    // così com'è, e solo il grafico Netto/Lordo si è portato dietro
    // un'altezza fissa propria. Senza un limite esplicito qui,
    // `LayoutBuilder`/`BarChart` ricevono un vincolo di altezza ILLIMITATO
    // dalla `Column` di `PulseSurface` dentro lo `SliverToBoxAdapter` (che
    // non vincola l'altezza dei figli) — bug reale riprodotto e corretto
    // qui, non un'ipotesi: fl_chart usa a sua volta un `LayoutBuilder` +
    // `Stack` interni (`AxisChartScaffoldWidget`) che assumono un'altezza
    // FINITA per posizionare gli assi; con altezza infinita il layout del
    // renderer del grafico fallisce a metà (un `RenderBox` resta senza
    // dimensione assegnata), il che in questa versione di Flutter/fl_chart
    // si manifesta come un "Null check operator used on a null value" che
    // si ripete a ogni frame (l'animazione implicita di `BarChart` continua
    // a ritentare il rebuild) invece di un errore di asserzione più
    // esplicito sui vincoli illimitati.
    return SizedBox(
      height: 180,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth;
          final contentWidth = punti.length * _minGroupSlotWidth;
          final needsScroll = contentWidth > viewportWidth - _leftAxisWidth;

          if (!needsScroll) {
            return buildPlot(width: viewportWidth, showLeftAxis: true);
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildAxisOnly(),
              Expanded(
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) {
                    final fadeWidth = _showRightFade ? _rightFadeWidth : 0.0;
                    final stop = 1 - (fadeWidth / rect.width).clamp(0.0, 1.0);
                    return LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: const [
                        CupertinoColors.white,
                        CupertinoColors.white,
                        CupertinoColors.transparent,
                      ],
                      stops: [0.0, stop, 1.0],
                    ).createShader(rect);
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: buildPlot(width: contentWidth, showLeftAxis: false),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
