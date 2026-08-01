import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/busta_paga.dart';
import '../../providers/buste_paga_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/busta_paga_formatting.dart';
import '../../widgets/liquid_glass_button.dart';
import '../../widgets/liquid_glass_surface.dart';

/// Contenuto della tab "Statistiche" della sezione Buste Paga: andamento
/// netto/lordo, ferie/ROL/permessi residui e ore di straordinario nel tempo.
///
/// Palette scelta per coerenza cross-chart: ogni serie usa un colore
/// semantico di sistema fisso (non legato alle 4 aree Budget, dato che
/// questi grafici non rappresentano aree) così la stessa grandezza è
/// riconoscibile a colpo d'occhio tra i vari grafici della schermata.
class BustePagaStatisticheScreen extends ConsumerWidget {
  final ({DateTime start, DateTime end})? periodoFiltro;

  const BustePagaStatisticheScreen({super.key, this.periodoFiltro});

  // Dissolvenza in fondo allo scroll, stesso pattern di
  // BustePagaArchivioView ma con fadeHeight tarato a parte: il viewport qui
  // ha densità diversa (3 card ampie invece di righe fitte), vedi CLAUDE.md
  // sulla nota "non assumere lo stesso valore assoluto tra schermate".
  static const _fadeHeight = 90.0;

  static const _nettoColor = AppColors.systemGreen;
  static const _lordoColor = AppColors.systemBlue;
  static const _ferieColor = AppColors.systemBlue;
  static const _rolColor = AppColors.systemPurple;
  static const _permessiColor = AppColors.systemOrange;
  static const _straordinarioColor = AppColors.systemOrange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buste = ref.watch(busteRepositoryProvider);
    final sorted = [...buste]..sort((a, b) => a.periodo.compareTo(b.periodo));
    final filtro = periodoFiltro;
    final filtrati = filtro == null
        ? sorted
        : sorted
            .where((b) =>
                !b.periodo.isBefore(filtro.start) &&
                !b.periodo.isAfter(filtro.end))
            .toList();

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
        if (kDebugMode)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
              AppSpacing.screenHorizontal,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _DebugTools(
                onSeed: () => ref
                    .read(busteRepositoryProvider.notifier)
                    .seedDebugData(),
                onClear: () => ref
                    .read(busteRepositoryProvider.notifier)
                    .clearDebugData(),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.lg,
            AppSpacing.screenHorizontal,
            AppSpacing.md,
          ),
          sliver: SliverToBoxAdapter(
            child: _ChartCard(
              title: 'Netto e lordo nel tempo',
              legend: const [
                _LegendEntry(label: 'Netto', color: _nettoColor),
                _LegendEntry(label: 'Lordo', color: _lordoColor),
              ],
              chart: _NettoLordoChart(buste: filtrati),
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
              title: 'Ferie, ROL e permessi',
              legend: const [
                _LegendEntry(label: 'Ferie residue', color: _ferieColor),
                _LegendEntry(label: 'ROL residui', color: _rolColor),
                _LegendEntry(label: 'Permessi goduti', color: _permessiColor),
              ],
              chart: _FerieRolPermessiChart(buste: filtrati),
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
              legend: const [
                _LegendEntry(
                    label: 'Ore straordinario', color: _straordinarioColor),
              ],
              chart: _StraordinarioChart(buste: filtrati),
            ),
          ),
        ),
      ],
      ),
    );
  }
}

/// Messaggio mostrato al posto del grafico quando non ci sono buste paga
/// da rappresentare (archivio vuoto).
/// Debug-only (`kDebugMode`): inserisce/rigenera o elimina i dati di prova
/// nell'archivio reale, per test manuali rapidi senza dover importare PDF
/// veri. Mai visibile in una build di release. "Elimina" tocca solo le
/// buste paga di test (id `dbg-`), mai i dati reali importati.
class _DebugTools extends StatelessWidget {
  final VoidCallback onSeed;
  final VoidCallback onClear;

  const _DebugTools({required this.onSeed, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final seedAccent =
        CupertinoDynamicColor.resolve(AppColors.systemOrange, context);
    final clearAccent =
        CupertinoDynamicColor.resolve(AppColors.systemRed, context);
    return Row(
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: LiquidGlassButton(
              onPressed: onSeed,
              tint: seedAccent,
              child: _DebugButtonLabel(
                icon: CupertinoIcons.hammer,
                label: 'Aggiungi dati di prova',
                color: seedAccent,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: LiquidGlassButton(
              onPressed: onClear,
              tint: clearAccent,
              child: _DebugButtonLabel(
                icon: CupertinoIcons.trash,
                label: 'Elimina dati di prova',
                color: clearAccent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DebugButtonLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DebugButtonLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.cardLabel.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _NoDataMessage extends StatelessWidget {
  const _NoDataMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.chart_bar_alt_fill,
            size: 28,
            color: CupertinoDynamicColor.resolve(
                AppColors.labelSecondary, context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Non ci sono dati',
            style: AppTextStyles.cardLabel.copyWith(
              color: CupertinoDynamicColor.resolve(
                  AppColors.labelSecondary, context),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendEntry {
  final String label;
  final CupertinoDynamicColor color;

  const _LegendEntry({required this.label, required this.color});
}

class _ChartCard extends StatelessWidget {
  final String title;
  final List<_LegendEntry> legend;
  final Widget chart;

  const _ChartCard({
    required this.title,
    required this.legend,
    required this.chart,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSurface(
      radius: AppRadius.glass,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.subtitle.copyWith(
                fontWeight: FontWeight.w600,
                color: CupertinoDynamicColor.resolve(
                    AppColors.labelPrimary, context),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                for (final entry in legend)
                  _LegendChip(entry: entry),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(height: 180, child: chart),
          ],
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final _LegendEntry entry;

  const _LegendChip({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = CupertinoDynamicColor.resolve(entry.color, context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          entry.label,
          style: AppTextStyles.cardLabel.copyWith(
            color: CupertinoDynamicColor.resolve(
                AppColors.labelSecondary, context),
          ),
        ),
      ],
    );
  }
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

/// Oltre questo numero di buste paga, `_StraordinarioChart` passa da barre
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
  String Function(DateTime periodo) shortLabelBuilder = periodoAxisLabel,
}) {
  final textStyle =
      AppTextStyles.cardLabel.copyWith(color: labelColor, fontSize: 10);

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

  final interval = _bottomTitleInterval(
      count: periodi.length, availableWidth: availableWidth);
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 22,
      interval: interval,
      getTitlesWidget: (value, meta) {
        final index = value.round();
        if (index < 0 || index >= periodi.length) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(shortLabelBuilder(periodi[index]), style: textStyle),
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
  String Function(double value) formatValue = formatNumber,
}) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 40,
      getTitlesWidget: (value, meta) {
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Text(
            formatValue(value),
            style: AppTextStyles.cardLabel.copyWith(
                color: labelColor, fontSize: 10),
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

/// Colori condivisi per lo sfondo/testo dei tooltip al tocco, usati da tutti
/// e tre i grafici — estratti per non avere tre calcoli divergenti.
({Color background, Color text}) _tooltipColors(BuildContext context) {
  return (
    background: CupertinoDynamicColor.resolve(AppColors.labelPrimary, context),
    text: CupertinoDynamicColor.resolve(AppColors.backgroundPrimary, context),
  );
}

class _NettoLordoChart extends StatelessWidget {
  final List<BustaPaga> buste;

  const _NettoLordoChart({required this.buste});

  @override
  Widget build(BuildContext context) {
    if (buste.isEmpty) return const _NoDataMessage();

    final nettoColor = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._nettoColor, context);
    final lordoColor = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._lordoColor, context);
    final gridColor =
        CupertinoDynamicColor.resolve(AppColors.separator, context);
    final labelColor =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);
    final tooltip = _tooltipColors(context);

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
    final bounds = _niceAxisBounds(
      datiMin - margine,
      datiMax + margine,
      step: 100,
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
                formatValue: (v) => '€${formatNumber(v)}',
              ),
              bottomTitles: _periodoBottomAxisTitles(
                periodi: buste.map((b) => b.periodo).toList(),
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
                        touchedSpots[i],
                        showPeriodo: i == 0,
                        textColor: tooltip.text,
                      ),
                  ];
                },
              ),
            ),
            lineBarsData: [
              _line(buste.map((b) => b.netto).toList(), nettoColor),
              _line(buste.map((b) => b.lordo).toList(), lordoColor),
            ],
          ),
        );
      },
    );
  }

  LineTooltipItem _tooltipItem(
    LineBarSpot spot, {
    required bool showPeriodo,
    required Color textColor,
  }) {
    final busta = buste[spot.x.toInt()];
    final label = spot.barIndex == 0 ? 'Netto' : 'Lordo';
    final text = showPeriodo
        ? '${periodoAxisLabel(busta.periodo)}\n$label: €${formatNumber(spot.y)}'
        : '$label: €${formatNumber(spot.y)}';
    return LineTooltipItem(
      text,
      AppTextStyles.cardLabel.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  LineChartBarData _line(List<double> values, Color color) {
    return LineChartBarData(
      spots: [
        for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
      ],
      isCurved: true,
      curveSmoothness: 0.2,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 4,
          color: color,
          strokeWidth: 0,
        ),
      ),
      belowBarData: BarAreaData(show: false),
    );
  }
}

class _FerieRolPermessiChart extends StatelessWidget {
  final List<BustaPaga> buste;

  const _FerieRolPermessiChart({required this.buste});

  @override
  Widget build(BuildContext context) {
    if (buste.isEmpty) return const _NoDataMessage();

    final ferieColor = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._ferieColor, context);
    final rolColor = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._rolColor, context);
    final permessiColor = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._permessiColor, context);
    final gridColor =
        CupertinoDynamicColor.resolve(AppColors.separator, context);
    final labelColor =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);
    final tooltip = _tooltipColors(context);

    // Solo bound "puliti" (fix sovrapposizione etichette): a differenza di
    // Netto/Lordo, qui il range resta da 0 — non richiesto restringerlo.
    final valoriMax = [
      ...buste.map((b) => b.ferieResidue),
      ...buste.map((b) => b.rolResidui),
      ...buste.map((b) => b.permessiGoduti),
    ].reduce((a, b) => a > b ? a : b);
    final bounds = _niceAxisBounds(0, valoriMax, step: 20);

    return LayoutBuilder(
      builder: (context, constraints) {
        return LineChart(
          LineChartData(
            minY: bounds.min,
            maxY: bounds.max,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: gridColor, strokeWidth: 0.5),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: _valueLeftAxisTitles(labelColor: labelColor),
              bottomTitles: _periodoBottomAxisTitles(
                periodi: buste.map((b) => b.periodo).toList(),
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
                        touchedSpots[i],
                        showPeriodo: i == 0,
                        textColor: tooltip.text,
                      ),
                  ];
                },
              ),
            ),
            lineBarsData: [
              _line(buste.map((b) => b.ferieResidue).toList(), ferieColor),
              _line(buste.map((b) => b.rolResidui).toList(), rolColor),
              _line(
                  buste.map((b) => b.permessiGoduti).toList(), permessiColor),
            ],
          ),
        );
      },
    );
  }

  LineTooltipItem _tooltipItem(
    LineBarSpot spot, {
    required bool showPeriodo,
    required Color textColor,
  }) {
    final busta = buste[spot.x.toInt()];
    final label = switch (spot.barIndex) {
      0 => 'Ferie residue',
      1 => 'ROL residui',
      _ => 'Permessi goduti',
    };
    final text = showPeriodo
        ? '${periodoAxisLabel(busta.periodo)}\n$label: ${formatNumber(spot.y)}'
        : '$label: ${formatNumber(spot.y)}';
    return LineTooltipItem(
      text,
      AppTextStyles.cardLabel.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  LineChartBarData _line(List<double> values, Color color) {
    return LineChartBarData(
      spots: [
        for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
      ],
      isCurved: true,
      curveSmoothness: 0.2,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 4,
          color: color,
          strokeWidth: 0,
        ),
      ),
      belowBarData: BarAreaData(show: false),
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
/// scrollabile in un singolo chart.
class _StraordinarioChart extends StatefulWidget {
  final List<BustaPaga> buste;

  const _StraordinarioChart({required this.buste});

  @override
  State<_StraordinarioChart> createState() => _StraordinarioChartState();
}

class _StraordinarioChartState extends State<_StraordinarioChart> {
  static const _barWidth = 16.0;
  static const _groupsSpace = 20.0;
  static const _minGroupSlotWidth = _barWidth + _groupsSpace;
  static const _leftAxisWidth = 40.0;
  static const _rightFadeWidth = 28.0;

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
    if (buste.isEmpty) return const _NoDataMessage();

    final barColor = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._straordinarioColor, context);
    final gridColor =
        CupertinoDynamicColor.resolve(AppColors.separator, context);
    final labelColor =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);
    final tooltip = _tooltipColors(context);

    final aggregato = buste.length > _quarterlyAggregationThreshold;
    final punti = aggregato
        ? _aggregaStraordinariPerTrimestre(buste)
        : [
            for (final b in buste) (periodo: b.periodo, totale: b.straordinari)
          ];
    final shortLabelBuilder = aggregato ? _trimestreLabel : periodoAxisLabel;

    final maxValue =
        punti.fold<double>(0, (max, p) => p.totale > max ? p.totale : max);
    final maxIndex = punti.indexWhere((p) => p.totale == maxValue);
    final bounds = _niceAxisBounds(0, maxValue <= 0 ? 1 : maxValue * 1.2,
        step: 20);

    Widget buildPlot({required double width, required bool showLeftAxis}) {
      return SizedBox(
        width: width,
        child: BarChart(
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
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: showLeftAxis
                  ? _valueLeftAxisTitles(labelColor: labelColor)
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
                    AppTextStyles.cardLabel.copyWith(
                      color: tooltip.text,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
            barGroups: [
              for (var i = 0; i < punti.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: punti[i].totale,
                      color: i == maxIndex
                          ? barColor
                          : barColor.withValues(alpha: 0.55),
                      width: _barWidth,
                      borderRadius: BorderRadius.circular(AppRadius.small / 2),
                    ),
                  ],
                ),
            ],
          ),
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
              leftTitles: _valueLeftAxisTitles(labelColor: labelColor),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final contentWidth = punti.length * _minGroupSlotWidth;
        final needsScroll =
            contentWidth > viewportWidth - _leftAxisWidth;

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
    );
  }
}
