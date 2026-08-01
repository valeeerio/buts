import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/busta_paga.dart';
import '../../providers/buste_paga_provider.dart';
import '../../services/busta_paga_regex_parser.dart';
import '../../services/pdf_import_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/cupertino_range_slider.dart';
import '../../widgets/flat_chip_button.dart';
import '../../widgets/spring_button.dart';
import 'busta_paga_detail_screen.dart';
import 'busta_paga_form_screen.dart';
import 'buste_paga_archivio_view.dart';
import 'buste_paga_statistiche_screen.dart';

/// Sotto-navigazione interna alla sezione Buste Paga (unica sezione
/// dell'app, non c'è una navigazione radice).
enum _BustePagaTab { archivio, statistiche }

/// Saluto dinamico in base all'ora corrente. Funzione pura per testabilità
/// (vedi piano sessione "barra di benvenuto dinamica").
String greetingFor(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 13) return 'Buongiorno Valerio';
  if (hour >= 13 && hour < 18) return 'Buon pomeriggio Valerio';
  return 'Buonasera Valerio';
}

/// Altezza approssimativa riservata alla sidecar flottante in basso
/// (barra + margini), da sottrarre al contenuto scrollabile sottostante
/// perché non finisca nascosto dietro di essa.
const double _sidecarReservedHeight = 96;

/// Schermata radice dell'app: barra di benvenuto, titolo di sezione,
/// contenuto Archivio/Statistiche e sidecar flottante in basso con la
/// sotto-navigazione e la CTA "+" (import PDF).
class BustePagaSectionScreen extends ConsumerStatefulWidget {
  const BustePagaSectionScreen({super.key});

  @override
  ConsumerState<BustePagaSectionScreen> createState() =>
      _BustePagaSectionScreenState();
}

class _BustePagaSectionScreenState
    extends ConsumerState<BustePagaSectionScreen> {
  _BustePagaTab _tab = _BustePagaTab.archivio;
  final _pdfImportService = const PdfImportService();
  final _regexParser = const BustaPagaRegexParser();
  bool _importingPdf = false;
  bool _searchActive = false;
  final _searchController = TextEditingController();

  /// Periodo selezionato dallo slider di Statistiche (`null` = nessun
  /// filtro, tutti i periodi disponibili). Vive qui, non in un provider
  /// Riverpod: è stato di UI locale alla sessione, non dato di dominio,
  /// stesso trattamento di `_tab`/`_searchActive`.
  ({DateTime start, DateTime end})? _periodoFiltro;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _changeTab(_BustePagaTab tab) {
    setState(() {
      _tab = tab;
      if (tab != _BustePagaTab.archivio) _closeSearch();
    });
  }

  void _closeSearch() {
    _searchActive = false;
    _searchController.clear();
  }

  void _openDetail(BuildContext context, BustaPaga bustaPaga) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => BustaPagaDetailScreen(bustaPaga: bustaPaga),
      ),
    );
  }

  /// CTA "+": avvia direttamente l'import PDF, niente più form vuoto per
  /// inserimento manuale libero (vedi CLAUDE.md / piano sessione).
  Future<void> _startImport() async {
    if (_importingPdf) return;
    setState(() => _importingPdf = true);
    final result = await _pdfImportService.pickAndImport();
    if (!mounted) return;
    setState(() => _importingPdf = false);

    switch (result.status) {
      case PdfImportStatus.cancelled:
        return;
      case PdfImportStatus.noExtractableText:
        _showImportError(
          'PDF non supportato',
          'Questo PDF sembra una scansione o un\'immagine, senza testo '
              'selezionabile. In questa versione sono supportati solo PDF '
              'testuali generati da un software paghe.',
        );
        return;
      case PdfImportStatus.error:
        _showImportError(
          'Import non riuscito',
          result.errorMessage ?? 'Si è verificato un errore imprevisto.',
        );
        return;
      case PdfImportStatus.success:
        break;
    }

    final testo = result.extractedText;
    final risultato =
        testo == null ? null : _regexParser.parse(testo);

    if (risultato == null ||
        (risultato.netto == null && risultato.periodo == null)) {
      _showImportError(
        'Formato non riconosciuto',
        'Non è stato possibile riconoscere i dati principali in questo '
            'PDF. Prova con un altro file oppure verifica che sia una '
            'busta paga generata dal software paghe supportato.',
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => BustaPagaFormScreen.daImport(
          fileOrigine: result.filePath!,
          estratti: risultato,
        ),
      ),
    );
  }

  /// Sostituisce il titolo "Archivio buste paga" con un campo di ricerca
  /// minimale (nessun bordo/riempimento) quando la lente è attiva: icona
  /// lente come prefix (tappabile per chiudere), campo borderless, tasto
  /// "Annulla" per chiudere in alternativa.
  Widget _buildSearchField(Color labelPrimary, Color labelSecondary) {
    final accent = CupertinoDynamicColor.resolve(AppColors.systemBlue, context);
    return Row(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: () => setState(_closeSearch),
          child: Icon(
            CupertinoIcons.search,
            size: 20,
            color: accent,
          ),
        ),
        Expanded(
          child: CupertinoTextField.borderless(
            controller: _searchController,
            autofocus: true,
            padding: EdgeInsets.zero,
            placeholder: 'Cerca per mese o anno',
            placeholderStyle: AppTextStyles.subtitle.copyWith(
              color: labelSecondary,
            ),
            style: AppTextStyles.subtitle.copyWith(color: labelPrimary),
            onChanged: (_) => setState(() {}),
          ),
        ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          minimumSize: const Size(0, 44),
          onPressed: () => setState(_closeSearch),
          child: Text(
            'Annulla',
            style: AppTextStyles.subtitle.copyWith(color: accent),
          ),
        ),
      ],
    );
  }

  void _showImportError(String title, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);
    final now = DateTime.now();
    // Ogni volta che il range disponibile cambia (nuova busta paga importata
    // con un periodo più vecchio/recente di quelli già filtrati), un filtro
    // impostato manualmente in precedenza smette di coprire tutti i dati:
    // per evitare che l'utente debba riallargare lo slider a mano ogni
    // volta, il filtro torna a "nessun filtro" (range completo) — vedi
    // richiesta utente "il range deve sempre comprendere di default il
    // minimo e il massimo delle date".
    ref.listen(periodoRangeDisponibileProvider, (previous, next) {
      if (previous != null && previous != next) {
        setState(() => _periodoFiltro = null);
      }
    });
    final periodoRangeDisponibile = ref.watch(periodoRangeDisponibileProvider);
    final dataLabel = () {
      final formatted = DateFormat('EEEE d MMMM', 'it_IT').format(now);
      return formatted[0].toUpperCase() + formatted.substring(1);
    }();

    return Container(
      color: CupertinoDynamicColor.resolve(AppColors.backgroundPrimary, context),
      child: Stack(
        children: [
          Column(
            children: [
              // Fascia di benvenuto: gradiente dedicato (blu elettrico in
              // cima che sfuma in trasparenza) per separarla visivamente dal
              // resto dell'app, sempre fissa sopra il contenuto scrollabile
              // (fuori da Expanded/CustomScrollView).
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    // Dissolvenza continua su tutta l'altezza della fascia
                    // (niente più plateau di blu pieno): passaggio più
                    // lungo e leggero verso il contenuto sotto, in linea
                    // col trattamento "wash" leggero già usato dai chip
                    // pieni della sidecar (`FlatChipButton`).
                    colors: [
                      CupertinoDynamicColor.resolve(
                              AppColors.systemBlue, context)
                          .withValues(alpha: 0.55),
                      CupertinoDynamicColor.resolve(
                              AppColors.systemBlue, context)
                          .withValues(alpha: 0),
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.lg,
                      AppSpacing.screenHorizontal,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greetingFor(now),
                          style: AppTextStyles.greeting.copyWith(
                            color: labelPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dataLabel,
                          style: AppTextStyles.subtitle.copyWith(
                            color: labelSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    if (_tab == _BustePagaTab.statistiche &&
                        periodoRangeDisponibile != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          AppSpacing.sm,
                          AppSpacing.screenHorizontal,
                          0,
                        ),
                        child: CupertinoRangeSlider(
                          minDate: periodoRangeDisponibile.start,
                          maxDate: periodoRangeDisponibile.end,
                          startValue:
                              _periodoFiltro?.start ?? periodoRangeDisponibile.start,
                          endValue:
                              _periodoFiltro?.end ?? periodoRangeDisponibile.end,
                          onChanged: (range) =>
                              setState(() => _periodoFiltro = range),
                        ),
                      ),
                    if (_tab == _BustePagaTab.archivio)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          AppSpacing.md,
                          AppSpacing.screenHorizontal,
                          AppSpacing.sm,
                        ),
                        child: _searchActive
                            ? _buildSearchField(labelPrimary, labelSecondary)
                            : Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Archivio buste paga',
                                      style:
                                          AppTextStyles.sectionTitle.copyWith(
                                        color: labelPrimary,
                                      ),
                                    ),
                                  ),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(44, 44),
                                    onPressed: () =>
                                        setState(() => _searchActive = true),
                                    child: Icon(
                                      CupertinoIcons.search,
                                      size: 22,
                                      color: CupertinoDynamicColor.resolve(
                                          AppColors.systemBlue, context),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: _sidecarReservedHeight,
                        ),
                        child: switch (_tab) {
                          _BustePagaTab.archivio => BustePagaArchivioView(
                              onOpenDetail: (bustaPaga) =>
                                  _openDetail(context, bustaPaga),
                              onAdd: () => _startImport(),
                              searchActive: _searchActive,
                              query: _searchController.text,
                            ),
                          _BustePagaTab.statistiche => BustePagaStatisticheScreen(
                              periodoFiltro: _periodoFiltro,
                            ),
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: AppSpacing.screenHorizontal,
            right: AppSpacing.screenHorizontal,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _BustePagaSidecar(
                  tab: _tab,
                  onTabChanged: _changeTab,
                  onAdd: _importingPdf ? null : () => _startImport(),
                  importing: _importingPdf,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra flottante ancorata in basso: sotto-navigazione Archivio/
/// Statistiche + CTA "+" (import PDF) come terzo elemento, tint accent.
class _BustePagaSidecar extends StatelessWidget {
  final _BustePagaTab tab;
  final ValueChanged<_BustePagaTab> onTabChanged;
  final VoidCallback? onAdd;
  final bool importing;

  const _BustePagaSidecar({
    required this.tab,
    required this.onTabChanged,
    required this.onAdd,
    required this.importing,
  });

  @override
  Widget build(BuildContext context) {
    // Stesso colore della fascia di benvenuto in alto, usato per il "+" e
    // per il tab attivo.
    final plusAccent = CupertinoDynamicColor.resolve(
        AppColors.systemBlue, context);
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);

    // Chip piatti senza superficie di vetro dietro (stessa resa di
    // "Conferma"/"Modifica" nel dettaglio busta paga, vedi
    // `FlatChipButton`): solo il tab attivo ha il riempimento colorato, il
    // tab non attivo resta icona+testo grigi senza sfondo.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: FlatChipButton(
            icon: CupertinoIcons.archivebox,
            label: 'Archivio',
            color: tab == _BustePagaTab.archivio ? plusAccent : labelSecondary,
            filled: tab == _BustePagaTab.archivio,
            onPressed: () => onTabChanged(_BustePagaTab.archivio),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FlatChipButton(
            icon: CupertinoIcons.chart_bar_alt_fill,
            label: 'Statistiche',
            color:
                tab == _BustePagaTab.statistiche ? plusAccent : labelSecondary,
            filled: tab == _BustePagaTab.statistiche,
            onPressed: () => onTabChanged(_BustePagaTab.statistiche),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SpringButton(
          onPressed: onAdd ?? () {},
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: plusAccent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: importing
                ? CupertinoActivityIndicator(color: plusAccent)
                : Icon(
                    CupertinoIcons.add,
                    size: 24,
                    color: plusAccent,
                  ),
          ),
        ),
      ],
    );
  }
}
