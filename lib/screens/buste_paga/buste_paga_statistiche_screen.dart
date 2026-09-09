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
import '../../widgets/busta_paga_drilldown_sheet.dart';
import '../../widgets/period_year_month_picker.dart';
import '../../widgets/progress_ring_tile.dart';
import '../../widgets/pulse_icon.dart';
import '../../widgets/pulse_surface.dart';

/// Contenuto della tab "Statistiche" della sezione Buste Paga.
///
/// Redesign 2026-08-30 (approvato dall'utente su mockup, vedi CLAUDE.md):
/// 3 card, ciascuna con una vista "protagonista" (numeri grandi + area
/// chart con glow / anelli di progresso grandi / barre a gradiente) — stessa
/// logica di calcolo/aggregazione/filtro periodo di prima, solo
/// riorganizzazione visiva (eccezione consapevole: il blocco
/// Ferie/Permessi/Ex festività passa da un trend nel tempo a uno snapshot
/// dell'ultima busta paga nel periodo filtrato). Solo la card Netto/Lordo
/// mantiene la vecchia tabella Media/Minimo/Massimo/Totale dietro un link
/// "Dettagli" collassabile; le card Ferie/permessi/ex festività e
/// Straordinario per mese mostrano solo header/anelli o titolo/grafico,
/// senza dettagli aggiuntivi (rimossi in una revisione successiva, ridondanti
/// con la vista protagonista).
///
/// Palette: `pulseAccent` (ciano) resta il colore funzionale primario e
/// unico colore-dato dei 3 grafici. `pulseSecondaryGlow` (viola) resta usato
/// qui SOLO come metà del bordo decorativo esterno di `_ChartCard` — mai per
/// icone/testo/bottoni interattivi, coerente con CLAUDE.md. La card Netto
/// (Task 2, 2026-09-08) mostra ora una linea singola: il Lordo non è più una
/// serie/colonna della vista principale, resta consultabile solo tramite il
/// drill-down al tap su un punto della linea (`showBustaPagaDrilldown`). Gli
/// anelli Ferie/Permessi/Ex festività (Task 3, 2026-09-08) sono monocromatici
/// (stesso `pulseAccent` per tutti e 3, solo opacità decrescente) e
/// tappabili, stesso drill-down sull'ultima busta paga del periodo filtrato.
/// Le barre Straordinario (Task 4, 2026-09-08) sono un riempimento pieno
/// ciano (niente più gradiente viola→ciano né glow dietro la barra massima),
/// tappabili con lo stesso drill-down. Il confronto anno su anno (Task 5,
/// 2026-09-08) aggiunge, quando l'utente attiva il toggle "Confronta con
/// l'anno precedente" (stato locale `_confrontaAnnoPrecedente`, unico a
/// livello di schermata, richiede un `periodoFiltro` esplicito) una seconda
/// serie "fantasma" — stesso ciano a opacità ridotta e tratteggiata per la
/// linea Netto, una barra a solo contorno ciano accanto a quella piena per
/// lo Straordinario — con i dati dello stesso range di mesi un anno prima,
/// esclusa dal drill-down su entrambi i grafici.
class BustePagaStatisticheScreen extends ConsumerStatefulWidget {
  final ({DateTime start, DateTime end})? periodoFiltro;

  const BustePagaStatisticheScreen({super.key, this.periodoFiltro});

  // Dissolvenza in fondo allo scroll, stesso pattern di
  // BustePagaArchivioView ma con fadeHeight tarato a parte: il viewport qui
  // ha densità diversa (3 card ampie invece di righe fitte), vedi CLAUDE.md
  // sulla nota "non assumere lo stesso valore assoluto tra schermate".
  static const _fadeHeight = 90.0;

  // Netto: unica linea/area del grafico, colore funzionale primario
  // dell'app (`pulseAccent`, ciano) — niente più una seconda serie Lordo
  // (Task 2 del redesign 2026-09-08, vedi CLAUDE.md).
  static const _nettoColor = AppColors.pulseAccent;
  // Anelli dello snapshot Ferie/Permessi/Ex festività: stessa tinta
  // funzionale primaria dell'app per tutti e 3 (Task 3 del redesign
  // 2026-09-08, vedi CLAUDE.md) — nessun hue diverso per anello, solo
  // opacità decrescente per distinguere i 3 cerchi affiancati a colpo
  // d'occhio senza reintrodurre una palette multicolore.
  static const _ferieColor = AppColors.pulseAccent;
  static const _permessiRolColor = AppColors.pulseAccent;
  static const _exFestivitaColor = AppColors.pulseAccent;
  // Barre Straordinario: riempimento pieno ciano (Task 4 del redesign
  // 2026-09-08, vedi CLAUDE.md) — niente più gradiente viola→ciano né glow
  // dietro la barra massima, solo opacità ridotta per le barre non massime.
  static const _straordinarioColor = AppColors.pulseAccent;

  @override
  ConsumerState<BustePagaStatisticheScreen> createState() =>
      _BustePagaStatisticheScreenState();
}

class _BustePagaStatisticheScreenState
    extends ConsumerState<BustePagaStatisticheScreen> {
  // Stato locale del toggle "Confronta con l'anno precedente" (Task 5 del
  // redesign 2026-09-08, vedi CLAUDE.md): unico a livello di schermata,
  // applicato sia a Netto sia a Straordinario, non persistito tra
  // sessioni/aperture. Richiede un `periodoFiltro` esplicito (vedi `build`)
  // — con "Da sempre" non esiste un "anno prima" ben definito.
  bool _confrontaAnnoPrecedente = false;

  @override
  Widget build(BuildContext context) {
    final tutte = ref.watch(busteRepositoryProvider);
    final buste = tutte.where(bustaInclusaInStatistiche).toList();
    final sorted = [...buste]..sort((a, b) => a.periodo.compareTo(b.periodo));
    final filtro = widget.periodoFiltro;
    final filtrati = filtro == null
        ? sorted
        : sorted
            .where((b) =>
                !b.periodo.isBefore(filtro.start) &&
                !b.periodo.isAfter(filtro.end))
            .toList();

    // Dati dell'anno precedente per il confronto anno su anno (Netto e
    // Straordinario): solo quando il toggle è attivo E c'è un range
    // esplicito selezionato — con "Da sempre" (`filtro == null`) non c'è un
    // "anno prima" ben definito, vedi doc di [_busteAnnoPrecedente].
    final busteAnnoPrecedente = _confrontaAnnoPrecedente && filtro != null
        ? _busteAnnoPrecedente(
            tutte: sorted,
            start: filtro.start,
            end: filtro.end,
          )
        : null;

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

    // Fine a cui estendere i grafici Netto/Lordo e Straordinario oltre
    // l'ultima busta paga confermata nel periodo filtrato: di norma il mese
    // corrente reale, ma senza mai superare un filtro periodo più
    // restrittivo scelto esplicitamente dall'utente (in quel caso la
    // griglia si ferma comunque a `filtro.end`, comportamento invariato).
    // Il confronto va fatto contro l'ultima busta paga REALMENTE
    // disponibile (`sorted`, non filtrata), non contro oggi: il picker di
    // norma restituisce come estremo massimo proprio l'ultima busta paga
    // disponibile, non il mese corrente — usare `oggiNormalizzato` come
    // riferimento romperebbe l'estensione in quel caso comune, che non è
    // una restrizione deliberata dell'utente.
    final ultimoConfermato = sorted.isNotEmpty
        ? DateTime(sorted.last.periodo.year, sorted.last.periodo.month)
        : null;
    final oggiNormalizzato = DateTime(DateTime.now().year, DateTime.now().month);
    final restrizioneEsplicita = filtro != null &&
        ultimoConfermato != null &&
        filtro.end.isBefore(ultimoConfermato);
    final estendiFinoA =
        restrizioneEsplicita ? filtro.end : oggiNormalizzato;

    // Etichetta leggibile del periodo effettivo applicato, mostrata come
    // sottotitolo su ogni card (Task 6 del redesign 2026-09-08, vedi
    // CLAUDE.md) così l'effetto del filtro resta leggibile senza dover
    // riaprire il filtro per ricordarselo.
    final periodoFiltroLabel = filtro == null
        ? 'Tutto lo storico'
        : PeriodYearMonthPicker.formatRangeLabel(filtro.start, filtro.end);

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final stop = 1 -
            (BustePagaStatisticheScreen._fadeHeight / rect.height)
                .clamp(0.0, 1.0);
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
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _ConfrontaAnnoPrecedenteToggle(
                value: _confrontaAnnoPrecedente,
                enabled: filtro != null,
                onChanged: (value) =>
                    setState(() => _confrontaAnnoPrecedente = value),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.md,
              AppSpacing.screenHorizontal,
              AppSpacing.md,
            ),
            sliver: SliverToBoxAdapter(
              child: _ChartCard(
                title: 'Netto',
                subtitle: periodoFiltroLabel,
                chart: filtrati.isEmpty
                    ? SizedBox(
                        height: 180,
                        child: _NoDataMessage(
                            busteNonConfermate: busteNonConfermate),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _NettoHeader(buste: filtrati),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            height: 180,
                            child: _NettoChart(
                              buste: filtrati,
                              estendiFinoA: estendiFinoA,
                              busteAnnoPrecedente: busteAnnoPrecedente,
                            ),
                          ),
                        ],
                      ),
                stats: _nettoStats(filtrati),
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
                    ? periodoFiltroLabel
                    : '$periodoFiltroLabel · '
                        'Ultima busta paga: ${periodoLabel(filtrati.last)}',
                chart: _FerieRolPermessiSnapshot(
                  buste: filtrati,
                  busteNonConfermate: busteNonConfermate,
                ),
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
                subtitle: periodoFiltroLabel,
                chart: _StraordinarioChart(
                  buste: filtrati,
                  busteNonConfermate: busteNonConfermate,
                  estendiFinoA: estendiFinoA,
                  busteAnnoPrecedente: busteAnnoPrecedente,
                ),
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

/// Toggle unico a livello di schermata (non duplicato per card, vedi CLAUDE.
/// md) per il confronto anno su anno di Netto e Straordinario (Task 5 del
/// redesign 2026-09-08). Disabilitato quando [enabled] è `false`, cioè
/// quando `periodoFiltro == null` ("Da sempre": non esiste un "anno prima"
/// ben definito, vedi [_busteAnnoPrecedente]) — resta visibile ma non
/// interagibile, invece di sparire, così l'utente capisce che la funzione
/// esiste ma richiede un periodo selezionato.
class _ConfrontaAnnoPrecedenteToggle extends StatelessWidget {
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ConfrontaAnnoPrecedenteToggle({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextPrimary, context);
    final secondary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);
    final accent = CupertinoDynamicColor.resolve(AppColors.pulseAccent, context);
    final textColor = enabled ? primary : secondary;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Confronta con l\'anno precedente',
              style: AppTextStyles.pulseBody.copyWith(color: textColor),
            ),
          ),
          CupertinoSwitch(
            value: value && enabled,
            activeTrackColor: accent,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
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

/// Tabella del riepilogo sotto il grafico Netto. Opera sulle stesse [buste]
/// già filtrate (confermate, mensili, nel periodo selezionato) che
/// alimentano il grafico — nessun ricalcolo parallelo del filtro. Il Lordo
/// non è più una colonna di questa tabella (Task 2 del redesign
/// 2026-09-08): resta consultabile busta paga per busta paga tramite il
/// drill-down al tap su un punto della linea.
_StatsTableData? _nettoStats(List<BustaPaga> buste) {
  if (buste.isEmpty) return null;
  final minNetto = _bustaConMinimo(buste, (b) => b.netto);
  final maxNetto = _bustaConMassimo(buste, (b) => b.netto);
  return (
    colonne: const ['Netto'],
    righe: [
      (
        'Media',
        [formatEuroConSegno(_media(buste, (b) => b.netto))],
      ),
      (
        'Minimo',
        [
          '${formatEuroConSegno(minNetto.netto)} (${periodoAxisLabel(minNetto.periodo)})',
        ],
      ),
      (
        'Massimo',
        [
          '${formatEuroConSegno(maxNetto.netto)} (${periodoAxisLabel(maxNetto.periodo)})',
        ],
      ),
      (
        'Totale',
        [formatEuroConSegno(_totale(buste, (b) => b.netto))],
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

/// Sottoinsieme di [tutte] che cade nello stesso range di mesi di
/// [start]/[end] ma un anno prima — stesso identico criterio di inclusione
/// di `filtrati` nella schermata (nessun filtro aggiuntivo, in particolare
/// nessun requisito di conferma extra oltre a quello già applicato a
/// [tutte] dal chiamante), usato per il confronto anno su anno opzionale di
/// Netto/Straordinario (Task 5 del redesign 2026-09-08).
List<BustaPaga> _busteAnnoPrecedente({
  required List<BustaPaga> tutte,
  required DateTime start,
  required DateTime end,
}) {
  final startAnnoPrima = DateTime(start.year - 1, start.month);
  final endAnnoPrima = DateTime(end.year - 1, end.month);
  return tutte
      .where((b) =>
          !b.periodo.isBefore(startAnnoPrima) &&
          !b.periodo.isAfter(endAnnoPrima))
      .toList()
    ..sort((a, b) => a.periodo.compareTo(b.periodo));
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
/// [estendiFinoA], se non nullo e successivo all'ultimo periodo presente in
/// [buste], estende la griglia con ulteriori slot vuoti (`busta: null`) fino
/// a quel mese incluso — usato per estendere i grafici fino al mese corrente
/// reale invece di fermarsi all'ultima busta paga confermata, rispettando
/// comunque un filtro periodo più restrittivo (in quel caso il chiamante
/// passa la fine del filtro, non oggi).
List<({DateTime periodo, BustaPaga? busta})> _grigliaMensile(
  List<BustaPaga> buste, {
  DateTime? estendiFinoA,
}) {
  if (buste.isEmpty) return const [];
  final risultato = <({DateTime periodo, BustaPaga? busta})>[];
  var cursore = DateTime(buste.first.periodo.year, buste.first.periodo.month);
  var fine = DateTime(buste.last.periodo.year, buste.last.periodo.month);
  if (estendiFinoA != null) {
    final estensione = DateTime(estendiFinoA.year, estendiFinoA.month);
    if (estensione.isAfter(fine)) fine = estensione;
  }
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
/// [estendiFinoA], se non nullo e successivo al trimestre dell'ultimo bucket
/// aggregato, estende la griglia con trimestri vuoti (`totale: null`) fino al
/// trimestre che lo contiene — stessa logica di estensione di
/// [_grigliaMensile], vedi doc lì.
List<({DateTime periodo, double? totale})> _grigliaTrimestrale(
  List<BustaPaga> buste, {
  DateTime? estendiFinoA,
}) {
  final aggregati = _aggregaStraordinariPerTrimestre(buste);
  int chiaveTrimestre(DateTime periodo) =>
      periodo.year * 4 + (periodo.month - 1) ~/ 3;
  final mappa = <int, double>{
    for (final punto in aggregati) chiaveTrimestre(punto.periodo): punto.totale,
  };
  final risultato = <({DateTime periodo, double? totale})>[];
  var chiaveFine = chiaveTrimestre(aggregati.last.periodo);
  if (estendiFinoA != null) {
    final chiaveEstensione = chiaveTrimestre(estendiFinoA);
    if (chiaveEstensione > chiaveFine) chiaveFine = chiaveEstensione;
  }
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

/// Numero grande del Netto in cima al blocco 1, con la variazione
/// percentuale rispetto al mese immediatamente precedente nell'elenco già
/// filtrato dal periodo — non necessariamente il mese solare precedente, se
/// il periodo filtrato ha dei buchi. Il Lordo non compare più qui (Task 2
/// del redesign 2026-09-08): resta consultabile busta paga per busta paga
/// tramite il drill-down al tap su un punto della linea. Richiede [buste]
/// non vuota, ordinata per periodo crescente.
class _NettoHeader extends StatelessWidget {
  final List<BustaPaga> buste;

  const _NettoHeader({required this.buste});

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Netto',
            style: AppTextStyles.pulseLabel.copyWith(color: secondary)),
        const SizedBox(height: 4),
        Text(
          formatEuroConSegno(ultima.netto),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.pulseDisplayLarge
              .copyWith(fontSize: 24, color: primary),
        ),
        const SizedBox(height: 4),
        _VariationBadge(variazione: _variazione((b) => b.netto)),
      ],
    );
  }
}

/// Grafico ad area del blocco Netto: un'unica linea/area piena col colore
/// funzionale primario dell'app (`pulseAccent`), niente più una seconda
/// serie Lordo né un glow dietro il tracciato (Task 2 del redesign
/// 2026-09-08, vedi CLAUDE.md — vincolo "nessun glow/bagliore diffuso nei
/// grafici"; l'area sotto la linea resta perché è un riempimento pieno a
/// bassa opacità, non un bagliore). Il tap secco (`FlTapUpEvent`, non
/// hover/drag) su un punto apre il drill-down (`showBustaPagaDrilldown`)
/// sulla busta paga corrispondente — lo scrubbing/hover continua a mostrare
/// il tooltip nativo di fl_chart senza aprire nulla. Stessa griglia mensile
/// continua/bound "nice" di prima del redesign, nessun cambio alla logica di
/// aggregazione dei dati.
///
/// [busteAnnoPrecedente], se non nullo/non vuoto (confronto anno su anno
/// attivo, Task 5 del redesign 2026-09-08), aggiunge una seconda linea
/// "fantasma" allineata sullo stesso asse X (indice i ↔ stesso mese un anno
/// prima): stesso ciano a opacità ridotta, tratteggiata, senza area
/// riempita — esclusa dal drill-down al tap, che continua a riferirsi solo
/// alla serie principale (identificata da `LineBarSpot.barIndex == 0`).
class _NettoChart extends StatelessWidget {
  final List<BustaPaga> buste;
  final DateTime estendiFinoA;
  final List<BustaPaga>? busteAnnoPrecedente;

  const _NettoChart({
    required this.buste,
    required this.estendiFinoA,
    this.busteAnnoPrecedente,
  });

  @override
  Widget build(BuildContext context) {
    final nettoColor = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._nettoColor, context);
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
    final griglia = _grigliaMensile(buste, estendiFinoA: estendiFinoA);

    // Griglia "fantasma" dell'anno precedente, allineata indice per indice
    // con [griglia] (stesso mese, anno-1) — non una griglia mensile
    // indipendente, per garantire che ogni punto della linea tratteggiata
    // cada esattamente sotto/sopra il punto corrispondente della linea
    // principale sull'asse X condiviso.
    final annoPrecedente = busteAnnoPrecedente;
    final grigliaAnnoPrecedente = (annoPrecedente == null || annoPrecedente.isEmpty)
        ? null
        : _grigliaAnnoPrecedenteAllineata(griglia, annoPrecedente);

    // Range ristretto ai dati reali (non da 0), margine 8% sopra e sotto il
    // range osservato, poi arrotondato a centinaia "pulite".
    final valori = buste.map((b) => b.netto).toList();
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
                        touchedSpots[i].barIndex == 0
                            ? griglia
                            : grigliaAnnoPrecedente ?? griglia,
                        touchedSpots[i],
                        showPeriodo: i == 0,
                        textColor: tooltip.text,
                        annoPrecedente: touchedSpots[i].barIndex != 0,
                      ),
                  ];
                },
              ),
              // Solo il tap secco apre il drill-down, e solo sulla serie
              // principale (`barIndex == 0`): la linea fantasma dell'anno
              // precedente resta esclusa dal drill-down, vedi doc di
              // classe.
              touchCallback: (event, response) {
                if (event is! FlTapUpEvent) return;
                final spots = response?.lineBarSpots;
                if (spots == null || spots.isEmpty) return;
                LineBarSpot? mainSpot;
                for (final spot in spots) {
                  if (spot.barIndex == 0) {
                    mainSpot = spot;
                    break;
                  }
                }
                if (mainSpot == null) return;
                final index = mainSpot.spotIndex;
                if (index < 0 || index >= griglia.length) return;
                final busta = griglia[index].busta;
                if (busta == null) return;
                showBustaPagaDrilldown(context, busta);
              },
            ),
            lineBarsData: [
              _nettoLine(griglia, nettoColor),
              if (grigliaAnnoPrecedente != null)
                _nettoLineAnnoPrecedente(grigliaAnnoPrecedente, nettoColor),
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
    bool annoPrecedente = false,
  }) {
    final busta = griglia[spot.x.toInt()].busta;
    // Guardia difensiva: fl_chart esclude gli spot nulli dal touch
    // detection (`getNearestTouchedSpot`), quindi in pratica `busta` non è
    // mai `null` qui — ma un tooltip mancante è comunque preferibile a un
    // crash se questa garanzia dovesse mai cambiare.
    if (busta == null) return null;
    final etichetta = annoPrecedente ? 'Netto (anno prec.)' : 'Netto';
    final text = showPeriodo
        ? '${periodoAxisLabel(busta.periodo)}\n$etichetta: ${formatEuroConSegno(spot.y)}'
        : '$etichetta: ${formatEuroConSegno(spot.y)}';
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

  /// Griglia allineata all'indice della griglia principale (indice i ↔
  /// stesso mese di [griglia], anno-1), costruita a partire dalle
  /// [annoPrecedente] (già filtrate sullo stesso range di mesi un anno
  /// prima, vedi [_busteAnnoPrecedente]) — non una griglia mensile
  /// indipendente, per garantire che ogni punto della linea fantasma cada
  /// esattamente sullo stesso indice X del punto corrispondente dell'anno
  /// corrente.
  List<({DateTime periodo, BustaPaga? busta})> _grigliaAnnoPrecedenteAllineata(
    List<({DateTime periodo, BustaPaga? busta})> griglia,
    List<BustaPaga> annoPrecedente,
  ) {
    final mappa = <DateTime, BustaPaga>{
      for (final b in annoPrecedente) DateTime(b.periodo.year, b.periodo.month): b,
    };
    return [
      for (final g in griglia)
        (
          periodo: DateTime(g.periodo.year - 1, g.periodo.month),
          busta: mappa[DateTime(g.periodo.year - 1, g.periodo.month)],
        ),
    ];
  }

  /// Linea "fantasma" del confronto anno su anno: stesso ciano di
  /// [_nettoLine] a opacità ridotta e tratteggiata, nessuna area riempita
  /// (per non competere visivamente con l'area della serie principale) —
  /// vedi doc di classe e [Task 5 del redesign 2026-09-08].
  LineChartBarData _nettoLineAnnoPrecedente(
    List<({DateTime periodo, BustaPaga? busta})> griglia,
    Color color,
  ) {
    return LineChartBarData(
      spots: _spots(griglia, (b) => b.netto),
      isCurved: true,
      curveSmoothness: 0.2,
      color: color.withValues(alpha: 0.35),
      barWidth: 2.5,
      dashArray: const [6, 4],
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
    // Stessa tinta `pulseAccent` per i 3 anelli (Task 3 del redesign
    // 2026-09-08, vedi CLAUDE.md): opacità decrescente solo per distinguere
    // a colpo d'occhio i 3 cerchi affiancati, mai un hue diverso.
    final ferieColor = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._ferieColor, context);
    final permessiRolColor = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._permessiRolColor, context)
        .withValues(alpha: 0.8);
    final exFestivitaColor = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._exFestivitaColor, context)
        .withValues(alpha: 0.6);

    void apriDrilldown() => showBustaPagaDrilldown(context, ultima);

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: apriDrilldown,
            child: ProgressRingTile(
              label: 'Ferie',
              value: formatNumber(ultima.ferieResidue),
              progress: _progressoResiduo(
                  ultima.ferieResidue, ultima.ferieMaturate),
              accentColor: ferieColor,
              diameter: _diameter,
              showGradientBorder: true,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: apriDrilldown,
            child: ProgressRingTile(
              label: 'Permessi',
              value: formatNumber(ultima.rolResidui),
              progress:
                  _progressoResiduo(ultima.rolResidui, ultima.rolMaturati),
              accentColor: permessiRolColor,
              diameter: _diameter,
              showGradientBorder: true,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: apriDrilldown,
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
/// scrollabile in un singolo chart. Ogni barra è un riempimento pieno ciano
/// (`pulseAccent`, Task 4 del redesign 2026-09-08, vedi CLAUDE.md — niente
/// più gradiente viola→ciano né glow dietro la barra massima): la barra del
/// valore più alto nel periodo filtrato resta piena/opaca, le altre a
/// opacità ridotta. Il tap secco (`FlTapUpEvent`) su una barra con dati apre
/// il drill-down (`showBustaPagaDrilldown`) sulla busta paga corrispondente
/// (l'ultima del trimestre, se le barre sono aggregate) — nessuna azione al
/// tap su uno slot senza dati.
///
/// [busteAnnoPrecedente], se non nullo/non vuoto (confronto anno su anno
/// attivo, Task 5 del redesign 2026-09-08), aggiunge per ogni gruppo con
/// dati un secondo `BarChartRodData` "fantasma" (mese/trimestre corrispondente
/// un anno prima): nessun riempimento, solo contorno ciano (`color:
/// transparent` + `borderSide`, l'unico modo nativo in questa versione di
/// fl_chart di ottenere una barra "a contorno" senza dover simulare l'effetto
/// con un `BackgroundBarChartRodData`) — esclusa dal drill-down al tap, che
/// continua a riferirsi solo al rod principale (`BarTouchedSpot.
/// touchedRodDataIndex == 0`).
class _StraordinarioChart extends StatefulWidget {
  final List<BustaPaga> buste;
  final int busteNonConfermate;
  final DateTime estendiFinoA;
  final List<BustaPaga>? busteAnnoPrecedente;

  const _StraordinarioChart({
    required this.buste,
    this.busteNonConfermate = 0,
    required this.estendiFinoA,
    this.busteAnnoPrecedente,
  });

  @override
  State<_StraordinarioChart> createState() => _StraordinarioChartState();
}

class _StraordinarioChartState extends State<_StraordinarioChart> {
  static const _barWidth = 16.0;
  static const _groupsSpace = 20.0;
  static const _minGroupSlotWidth = _barWidth + _groupsSpace;
  // Spazio tra la barra principale e quella fantasma dell'anno precedente
  // dentro lo stesso gruppo, quando il confronto anno su anno è attivo.
  static const _ghostBarsSpace = 6.0;
  // Larghezza della colonna fissa dell'asse Y in `buildAxisOnly()` (modalità
  // scroll orizzontale): deve corrispondere esattamente al `reservedSize`
  // passato a `_valueLeftAxisTitles` in ENTRAMBI i percorsi di rendering
  // (`buildPlot`/`buildAxisOnly`) di questo grafico — bug reale corretto qui
  // (40 vs 52, vedi CLAUDE.md), non un'ipotesi: se in futuro serve un valore
  // diverso dal default di `_valueLeftAxisTitles`, va cambiato qui e passato
  // esplicitamente a entrambe le chiamate sotto, mai lasciato disallineato.
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
    if (buste.isEmpty) {
      return SizedBox(
        height: 180,
        child: _NoDataMessage(busteNonConfermate: widget.busteNonConfermate),
      );
    }

    final barColor = CupertinoDynamicColor.resolve(
        BustePagaStatisticheScreen._straordinarioColor, context);
    final gridColor =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context)
            .withValues(alpha: 0.18);
    final labelColor =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);
    final tooltip = _tooltipColors(context);

    // Griglia continua (mensile o trimestrale a seconda dell'aggregazione),
    // stesso meccanismo di `_NettoChart`: un mese/trimestre senza dati
    // resta un buco visibile (nessuna barra disegnata per quello slot)
    // invece di sparire silenziosamente avvicinando le barre dei
    // mesi/trimestri adiacenti come se fossero consecutivi.
    // Decisione basata sull'ampiezza temporale REALE dei dati (senza
    // l'estensione a `estendiFinoA`), non su quella estesa: estendere la
    // griglia fino a oggi allunga di uno slot vuoto ogni mese che passa
    // senza nuove buste paga, e se la decisione di aggregare si basasse su
    // quella lunghezza estesa l'aggregazione trimestrale scatterebbe da
    // sola col solo passare del tempo, senza che l'utente importi nulla.
    final grigliaMensileReale = _grigliaMensile(buste);
    // Decisione basata sull'ampiezza temporale reale coperta dalla griglia
    // (numero di slot mensili, buchi inclusi), non sul numero di buste paga
    // confermate: un archivio con molti mesi mancanti/non confermati ma che
    // copre un arco di molti anni renderizzerebbe altrimenti una griglia
    // mensile non aggregata su molti slot, con uno scroll orizzontale molto
    // lungo — in contrasto con l'intento della soglia (vedi doc su
    // `_quarterlyAggregationThreshold`).
    final aggregato =
        grigliaMensileReale.length > _quarterlyAggregationThreshold;
    // Griglia effettivamente renderizzata (estesa fino a `estendiFinoA`):
    // se non serve aggregare per trimestre, riusa quella reale già
    // calcolata solo quando coincide (nessuna estensione applicabile),
    // altrimenti ricalcola con l'estensione — evita un ricalcolo superfluo
    // nel caso comune in cui `estendiFinoA` non estende oltre i dati reali.
    final grigliaMensile = aggregato
        ? const <({DateTime periodo, BustaPaga? busta})>[]
        : _grigliaMensile(buste, estendiFinoA: widget.estendiFinoA);
    // L'asse X va dal mese/trimestre più vecchio del periodo filtrato (prima
    // barra a sinistra) al più recente (verso destra) — cronologico
    // CRESCENTE, come gli altri grafici della schermata (Netto/Lordo).
    // `_grigliaMensile`/`_grigliaTrimestrale` producono entrambe una
    // griglia continua in questo stesso ordine (compresi i buchi), quindi
    // vengono usate direttamente senza ulteriore riordino.
    final punti = aggregato
        ? _grigliaTrimestrale(buste, estendiFinoA: widget.estendiFinoA)
        : [
            for (final g in grigliaMensile)
              (periodo: g.periodo, totale: g.busta?.straordinari),
          ];
    final shortLabelBuilder = aggregato ? _trimestreLabel : meseAxisLabel;

    // Valori "fantasma" del confronto anno su anno (Task 5 del redesign
    // 2026-09-08), allineati indice per indice con [punti] (stesso
    // mese/trimestre, anno-1) — non una griglia/aggregazione indipendente,
    // per garantire che ogni barra a contorno cada esattamente accanto alla
    // barra piena corrispondente sull'asse X condiviso.
    final annoPrecedente = widget.busteAnnoPrecedente;
    final hasGhost = annoPrecedente != null && annoPrecedente.isNotEmpty;
    final ghostValues = List<double?>.filled(punti.length, null);
    if (hasGhost) {
      if (!aggregato) {
        final mappaMensile = <int, double>{
          for (final b in annoPrecedente) b.periodo.year * 12 + b.periodo.month: b.straordinari,
        };
        for (var i = 0; i < punti.length; i++) {
          final p = punti[i].periodo;
          ghostValues[i] = mappaMensile[(p.year - 1) * 12 + p.month];
        }
      } else {
        final mappaTrimestrale = <int, double>{
          for (final punto in _aggregaStraordinariPerTrimestre(annoPrecedente))
            punto.periodo.year * 4 + (punto.periodo.month - 1) ~/ 3: punto.totale,
        };
        for (var i = 0; i < punti.length; i++) {
          final p = punti[i].periodo;
          final trimestre = (p.month - 1) ~/ 3;
          ghostValues[i] = mappaTrimestrale[(p.year - 1) * 4 + trimestre];
        }
      }
    }

    final maxValue = punti.fold<double>(
        0, (max, p) => (p.totale ?? 0) > max ? p.totale! : max);
    final maxIndex =
        punti.indexWhere((p) => p.totale != null && p.totale == maxValue);
    // Il massimo dell'asse tiene conto anche dei valori fantasma, altrimenti
    // una barra a contorno dell'anno precedente più alta di ogni barra piena
    // dell'anno corrente verrebbe tagliata fuori dal grafico.
    final maxValueConGhost = ghostValues.fold<double>(
        maxValue, (max, v) => (v ?? 0) > max ? v! : max);
    final straordinarioAxisMax =
        maxValueConGhost <= 0 ? 1.0 : maxValueConGhost * 1.2;
    final step = _niceStep(straordinarioAxisMax, minStep: 1);
    final bounds = _niceAxisBounds(0, straordinarioAxisMax, step: step);

    // Ultimo indice con un dato reale (`totale != null`): i buchi INTERNI
    // alla storia (mesi mai confermati fra due mesi con dati) restano
    // "compressi via" come prima, ma tutti gli slot DOPO questo indice (la
    // coda aggiunta da `estendiFinoA`, sempre priva di dati per definizione)
    // ricevono comunque uno slot/etichetta — altrimenti l'estensione fino al
    // mese corrente reale (vedi doc di `_grigliaMensile`) resterebbe invisibile
    // con `BarChartAlignment.spaceEvenly`. -1 se `punti` non ha alcun dato.
    final ultimoDatoIndex = punti.lastIndexWhere((p) => p.totale != null);
    bool includiSlot(int i) => punti[i].totale != null || i > ultimoDatoIndex;

    // Risale alla `BustaPaga` rappresentata dalla barra/gruppo di indice [i]
    // in `punti`, per il drill-down al tap (Task 4 del redesign 2026-09-08).
    // In modalità mensile è una lettura diretta dalla griglia già calcolata;
    // in modalità trimestrale la barra rappresenta 3 mesi, e come da spec si
    // apre il drill-down sull'ULTIMO mese del trimestre con dati reali (non
    // un menu di scelta) — se il calendario mese esatto non ha una busta
    // paga associata (es. solo i primi 2 mesi del trimestre confermati), si
    // usa comunque la busta più recente disponibile in quel trimestre.
    BustaPaga? bustaAlIndice(int i) {
      if (punti[i].totale == null) return null;
      if (!aggregato) return grigliaMensile[i].busta;
      final inizioTrimestre = punti[i].periodo;
      final fineTrimestre =
          DateTime(inizioTrimestre.year, inizioTrimestre.month + 3);
      BustaPaga? ultima;
      for (final busta in buste) {
        if (!busta.periodo.isBefore(inizioTrimestre) &&
            busta.periodo.isBefore(fineTrimestre)) {
          if (ultima == null || busta.periodo.isAfter(ultima.periodo)) {
            ultima = busta;
          }
        }
      }
      return ultima;
    }

    Widget buildPlot({required double width, required bool showLeftAxis}) {
      return SizedBox(
        width: width,
        child: Stack(
          children: [
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
                  // Solo il tap secco apre il drill-down, stesso pattern di
                  // `_NettoChart` — hover/scrubbing restano riservati al
                  // tooltip nativo sopra. `touchedBarGroup.x` (non l'indice
                  // nell'array `barGroups`, che esclude gli slot compressi)
                  // è l'indice reale in `punti`, coerente con `group.x` già
                  // usato in `getTooltipItem` sotto. `touchedRodDataIndex !=
                  // 0` significa che è stata toccata la barra fantasma
                  // dell'anno precedente: esclusa dal drill-down, vedi doc di
                  // classe.
                  touchCallback: (event, response) {
                    if (event is! FlTapUpEvent) return;
                    final spot = response?.spot;
                    if (spot == null) return;
                    if (spot.touchedRodDataIndex != 0) return;
                    final index = spot.touchedBarGroup.x;
                    if (index < 0 || index >= punti.length) return;
                    final busta = bustaAlIndice(index);
                    if (busta == null) return;
                    showBustaPagaDrilldown(context, busta);
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => tooltip.background,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final punto = punti[group.x];
                      final isGhost = hasGhost && rodIndex != 0;
                      final valore = isGhost ? ghostValues[group.x] : punto.totale;
                      // Gli slot di coda dopo `ultimoDatoIndex` (mesi ancora
                      // senza busta paga confermata, aggiunti solo per
                      // estendere l'asse fino al mese corrente) hanno sempre
                      // `totale == null`: un tooltip "0 h" per un mese senza
                      // alcun dato sarebbe fuorviante, indistinguibile da uno
                      // straordinario davvero pari a zero.
                      if (valore == null) {
                        return BarTooltipItem(
                          '${shortLabelBuilder(punto.periodo)}\nNessun dato',
                          AppTextStyles.pulseBody.copyWith(
                            color: tooltip.text,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }
                      final etichetta =
                          isGhost ? 'Anno prec.' : shortLabelBuilder(punto.periodo);
                      return BarTooltipItem(
                        '$etichetta\n'
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
                    if (includiSlot(i))
                      BarChartGroupData(
                        x: i,
                        barsSpace: hasGhost ? _ghostBarsSpace : 2,
                        barRods: [
                          BarChartRodData(
                            toY: punti[i].totale ?? 0,
                            color: i == maxIndex
                                ? barColor
                                : barColor.withValues(alpha: 0.55),
                            width: _barWidth,
                            borderRadius:
                                BorderRadius.circular(AppRadius.small / 2),
                          ),
                          if (hasGhost && ghostValues[i] != null)
                            BarChartRodData(
                              toY: ghostValues[i]!,
                              color: CupertinoColors.transparent,
                              borderSide: BorderSide(
                                color: barColor.withValues(alpha: 0.7),
                                width: 1.5,
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
          // Con il confronto anno su anno attivo ogni gruppo è più largo (due
          // barre affiancate anziché una), lo slot minimo per gruppo cresce
          // di conseguenza — altrimenti la barra fantasma finirebbe
          // parzialmente sovrapposta al gruppo successivo.
          final groupSlotWidth = hasGhost
              ? _barWidth * 2 + _ghostBarsSpace + _groupsSpace
              : _minGroupSlotWidth;
          final contentWidth = punti.length * groupSlotWidth;
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
