import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/busta_paga.dart';
import '../../providers/buste_paga_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/liquid_glass_surface.dart';

/// Contenuto della tab "Statistiche" della sezione Buste Paga: andamento
/// netto/lordo, ferie/ROL/permessi residui e ore di straordinario nel tempo.
///
/// Palette scelta per coerenza cross-chart: ogni serie usa un colore
/// semantico di sistema fisso (non legato alle 4 aree Budget, dato che
/// questi grafici non rappresentano aree) così la stessa grandezza è
/// riconoscibile a colpo d'occhio tra i vari grafici della schermata.
class BustePagaStatisticheScreen extends ConsumerWidget {
  const BustePagaStatisticheScreen({super.key});

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

    if (sorted.length < 2) {
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
              AppSpacing.screenHorizontal,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _EmptyStatistiche(),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
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
              title: 'Netto e lordo nel tempo',
              legend: const [
                _LegendEntry(label: 'Netto', color: _nettoColor),
                _LegendEntry(label: 'Lordo', color: _lordoColor),
              ],
              chart: _NettoLordoChart(buste: sorted),
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
              chart: _FerieRolPermessiChart(buste: sorted),
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
              chart: _StraordinarioChart(buste: sorted),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyStatistiche extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LiquidGlassSurface(
      radius: AppRadius.glass,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Icon(
              CupertinoIcons.chart_bar_alt_fill,
              size: 32,
              color: CupertinoDynamicColor.resolve(
                  AppColors.labelSecondary, context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Dati insufficienti',
              style: AppTextStyles.subtitle.copyWith(
                fontWeight: FontWeight.w600,
                color: CupertinoDynamicColor.resolve(
                    AppColors.labelPrimary, context),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Servono almeno 2 buste paga per vedere l\'andamento nel tempo.',
              textAlign: TextAlign.center,
              style: AppTextStyles.cardLabel.copyWith(
                color: CupertinoDynamicColor.resolve(
                    AppColors.labelSecondary, context),
              ),
            ),
          ],
        ),
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

/// Etichetta breve del periodo (es. "gen '24") usata sull'asse X di tutti
/// i grafici della schermata, per coerenza.
String _periodoAxisLabel(DateTime periodo) {
  final month = DateFormat('MMM', 'it_IT').format(periodo);
  final year = DateFormat('yy', 'it_IT').format(periodo);
  return "$month '$year";
}

/// Interval degli indici mostrati sull'asse X, per non affollare l'asse
/// quando l'archivio ha molte buste paga.
double _bottomTitleInterval(int count) {
  if (count <= 6) return 1;
  if (count <= 12) return 2;
  return (count / 6).ceilToDouble();
}

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
        CupertinoDynamicColor.resolve(AppColors.separator, context);
    final labelColor =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);

    final interval = _bottomTitleInterval(buste.length);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: null,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: interval,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= buste.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _periodoAxisLabel(buste[index].periodo),
                    style: AppTextStyles.cardLabel.copyWith(
                        color: labelColor, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          _line(buste.map((b) => b.netto).toList(), nettoColor),
          _line(buste.map((b) => b.lordo).toList(), lordoColor),
        ],
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
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }
}

class _FerieRolPermessiChart extends StatelessWidget {
  final List<BustaPaga> buste;

  const _FerieRolPermessiChart({required this.buste});

  @override
  Widget build(BuildContext context) {
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

    final interval = _bottomTitleInterval(buste.length);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: interval,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= buste.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _periodoAxisLabel(buste[index].periodo),
                    style: AppTextStyles.cardLabel.copyWith(
                        color: labelColor, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          _line(buste.map((b) => b.ferieResidue).toList(), ferieColor),
          _line(buste.map((b) => b.rolResidui).toList(), rolColor),
          _line(buste.map((b) => b.permessiGoduti).toList(), permessiColor),
        ],
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
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }
}

class _StraordinarioChart extends StatelessWidget {
  final List<BustaPaga> buste;

  const _StraordinarioChart({required this.buste});

  @override
  Widget build(BuildContext context) {
    final barColor = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._straordinarioColor, context);
    final gridColor =
        CupertinoDynamicColor.resolve(AppColors.separator, context);
    final labelColor =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);

    final interval = _bottomTitleInterval(buste.length);
    final maxValue = buste
        .map((b) => b.straordinari)
        .fold<double>(0, (max, v) => v > max ? v : max);

    return BarChart(
      BarChartData(
        maxY: maxValue <= 0 ? 1 : maxValue * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: interval,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= buste.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _periodoAxisLabel(buste[index].periodo),
                    style: AppTextStyles.cardLabel.copyWith(
                        color: labelColor, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(enabled: false),
        barGroups: [
          for (var i = 0; i < buste.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: buste[i].straordinari,
                  color: barColor,
                  width: 12,
                  borderRadius: BorderRadius.circular(AppRadius.small / 2),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
