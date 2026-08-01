import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/busta_paga.dart';
import '../../providers/buste_paga_provider.dart';
import '../../services/busta_paga_regex_parser.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/busta_paga_formatting.dart';
import '../../widgets/app_alert_dialog.dart';
import '../../widgets/busta_paga_documento_chip.dart';
import '../../widgets/busta_paga_hero_card.dart';
import '../../widgets/busta_paga_maturazioni_section.dart';
import '../../widgets/busta_paga_stat_row.dart';
import '../../widgets/flat_chip_button.dart';
import '../../widgets/glass_form_section.dart';
import '../../widgets/liquid_glass_surface.dart';
import '../../widgets/trattenuta_edit_row.dart';

/// Altezza riservata alla barra flottante "Salva/Annulla" in basso, usata
/// come padding in fondo al contenuto scrollabile perché l'ultima card non
/// finisca nascosta/tappabile dietro di essa — stesso valore/motivazione di
/// `_actionBarReservedHeight` in `busta_paga_detail_screen.dart`.
const double _actionBarReservedHeight = 80;

/// Form di revisione di un nuovo import PDF già processato a monte: i campi
/// sono precompilati dal parser regex ([estratti], con [fileOrigine] il path
/// del PDF già copiato) e restano editabili prima della conferma esplicita
/// (bottone "Salva" nella barra flottante in basso). Stesso impianto visivo
/// del dettaglio busta paga in modifica (`BustaPagaDetailScreen`): hero
/// card, riga di statistiche a scomparti, tabella unica Maturazioni, chip
/// documento (qui non tappabile: il file è ancora in fase di revisione),
/// trattenute con swipe-to-delete.
///
/// La modifica di una busta paga già esistente non passa più da qui: dal
/// dettaglio è ora inline nella stessa pagina, senza navigazione verso un
/// form separato. Non esiste più nemmeno una modalità "vuota" per
/// inserimento manuale libero: il PDF viene sempre scelto e processato
/// prima di arrivare qui (vedi `buste_paga_section_screen.dart` / CLAUDE.md).
class BustaPagaFormScreen extends ConsumerStatefulWidget {
  final String fileOrigine;
  final BustaPagaEstratti estratti;

  const BustaPagaFormScreen.daImport({
    super.key,
    required this.fileOrigine,
    required this.estratti,
  });

  @override
  ConsumerState<BustaPagaFormScreen> createState() =>
      _BustaPagaFormScreenState();
}

class _BustaPagaFormScreenState extends ConsumerState<BustaPagaFormScreen> {
  late DateTime _periodo;
  late TipoBustaPaga _tipo;

  late final TextEditingController _lordoController;
  late final TextEditingController _nettoController;
  late final TextEditingController _straordinariController;

  late final TextEditingController _ferieMaturateController;
  late final TextEditingController _ferieGoduteController;
  late final TextEditingController _ferieResidueController;

  late final TextEditingController _rolMaturatiController;
  late final TextEditingController _rolGodutiController;
  late final TextEditingController _rolResiduiController;

  late final TextEditingController _permessiGodutiController;
  late final TextEditingController _oreLavorateController;

  late List<TrattenutaEditRow> _trattenute;

  late final String _fileOrigine;
  List<String> _warnings = const [];

  /// True quando i campi sono stati popolati dall'estrazione automatica e
  /// non ancora confermati esplicitamente (salvataggio) dall'utente.
  bool _valoriDaConferma = false;

  @override
  void initState() {
    super.initState();
    final estratti = widget.estratti;

    _fileOrigine = widget.fileOrigine;
    _valoriDaConferma = true;
    _warnings = estratti.warnings;

    _periodo = _periodoFromEstratti(estratti.periodo) ??
        DateTime(DateTime.now().year, DateTime.now().month);
    _tipo = estratti.tipo;

    _lordoController =
        TextEditingController(text: _formatNumero(estratti.lordo));
    _nettoController =
        TextEditingController(text: _formatNumero(estratti.netto));
    _straordinariController =
        TextEditingController(text: _formatNumero(estratti.straordinari));

    _ferieMaturateController =
        TextEditingController(text: _formatNumero(estratti.ferieMaturate));
    _ferieGoduteController =
        TextEditingController(text: _formatNumero(estratti.ferieGodute));
    _ferieResidueController =
        TextEditingController(text: _formatNumero(estratti.ferieResidue));

    _rolMaturatiController =
        TextEditingController(text: _formatNumero(estratti.rolMaturati));
    _rolGodutiController =
        TextEditingController(text: _formatNumero(estratti.rolGoduti));
    _rolResiduiController =
        TextEditingController(text: _formatNumero(estratti.rolResidui));

    _permessiGodutiController =
        TextEditingController(text: _formatNumero(estratti.permessiGoduti));
    _oreLavorateController =
        TextEditingController(text: _formatNumero(estratti.oreLavorate));

    final trattenuteIniziali = estratti.trattenute;
    _trattenute = trattenuteIniziali.isEmpty
        ? [TrattenutaEditRow()]
        : trattenuteIniziali.entries
            .map((e) => TrattenutaEditRow(
                chiave: e.key, importo: e.value.toStringAsFixed(2)))
            .toList();

    // Forza il rebuild della `BustaPagaStatRow` (Ferie/ROL residui) ogni
    // volta che cambia il campo "Residuo" corrispondente nella tabella
    // Maturazioni sottostante — stesso meccanismo `_onResiduiChanged` del
    // dettaglio busta paga.
    _ferieResidueController.addListener(_onResiduiChanged);
    _rolResiduiController.addListener(_onResiduiChanged);
  }

  void _onResiduiChanged() => setState(() {});

  static DateTime? _periodoFromEstratti(String? periodo) {
    if (periodo == null) return null;
    final parti = periodo.split('-');
    final anno = int.tryParse(parti.elementAtOrNull(0) ?? '');
    final mese = int.tryParse(parti.elementAtOrNull(1) ?? '');
    if (anno == null || mese == null) return null;
    return DateTime(anno, mese);
  }

  static String _formatNumero(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  @override
  void dispose() {
    _lordoController.dispose();
    _nettoController.dispose();
    _straordinariController.dispose();
    _ferieMaturateController.dispose();
    _ferieGoduteController.dispose();
    _ferieResidueController.dispose();
    _rolMaturatiController.dispose();
    _rolGodutiController.dispose();
    _rolResiduiController.dispose();
    _permessiGodutiController.dispose();
    _oreLavorateController.dispose();
    for (final row in _trattenute) {
      row.dispose();
    }
    super.dispose();
  }

  double _parse(TextEditingController controller) {
    final text = controller.text.trim().replaceAll(',', '.');
    return double.tryParse(text) ?? 0;
  }

  String get _periodoLabel {
    final formatted = DateFormat('MMMM yyyy', 'it_IT').format(_periodo);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  static const _tipoLabels = {
    TipoBustaPaga.mensile: 'Mensile',
    TipoBustaPaga.tredicesima: '13esima',
    TipoBustaPaga.quattordicesima: '14esima',
  };

  Future<void> _pickTipo() async {
    final scelta = await showCupertinoModalPopup<TipoBustaPaga>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Tipo busta paga'),
        actions: [
          for (final tipo in TipoBustaPaga.values)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(tipo),
              child: Text(_tipoLabels[tipo]!),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
      ),
    );
    if (scelta != null) setState(() => _tipo = scelta);
  }

  Future<void> _pickPeriodo() async {
    DateTime tempSelection = _periodo;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return Container(
          height: 280,
          color: CupertinoDynamicColor.resolve(AppColors.surface, context),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      child: const Text('Fatto'),
                      onPressed: () {
                        setState(() => _periodo = tempSelection);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.monthYear,
                    initialDateTime: _periodo,
                    onDateTimeChanged: (value) => tempSelection = value,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addTrattenuta() {
    setState(() => _trattenute.add(TrattenutaEditRow()));
  }

  void _removeTrattenuta(int index) {
    setState(() {
      _trattenute[index].dispose();
      _trattenute.removeAt(index);
    });
  }

  void _showAlert(String title, String message) {
    final accent = CupertinoDynamicColor.resolve(AppColors.systemBlue, context);
    showAppAlertDialog<void>(
      context: context,
      title: title,
      message: message,
      actions: [
        AppAlertAction(
          icon: CupertinoIcons.checkmark_alt,
          label: 'OK',
          color: accent,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  void _save() {
    final nettoText = _nettoController.text.trim().replaceAll(',', '.');
    if (nettoText.isEmpty || double.tryParse(nettoText) == null) {
      _showAlert(
        'Netto non valido',
        'Inserisci un valore numerico per il netto prima di salvare.',
      );
      return;
    }

    // Stesso controllo anti-duplicati già usato dal dettaglio
    // (`busta_paga_detail_screen.dart._save()`): per le mensili anno+mese+
    // tipo, per 13esima/14esima solo anno+tipo. Qui è sempre un nuovo
    // inserimento, nessuna esclusione per id necessaria — spostato qui
    // (invece che nel pre-import) perché l'utente possa correggere prima il
    // tipo/periodo se il parser li ha dedotti male.
    final conflitto = ref.read(busteRepositoryProvider).any((b) {
      if (b.tipo != _tipo) return false;
      if (_tipo == TipoBustaPaga.mensile) {
        return b.periodo.year == _periodo.year &&
            b.periodo.month == _periodo.month;
      }
      return b.periodo.year == _periodo.year;
    });
    if (conflitto) {
      _showAlert(
        'Busta paga già presente',
        'Hai già una busta paga per '
            '${periodoDisplayFor(periodo: _periodo, tipo: _tipo)} '
            'in archivio. Per correggerla, modificala dal dettaglio invece '
            'di reimportarla.',
      );
      return;
    }

    final trattenute = <String, double>{};
    for (final row in _trattenute) {
      final chiave = row.chiave.text.trim();
      if (chiave.isEmpty) continue;
      trattenute[chiave] = _parse(row.importo);
    }

    final bustaPaga = BustaPaga(
      id: 'bp-${DateTime.now().millisecondsSinceEpoch}',
      periodo: _periodo,
      fileOrigine: _fileOrigine,
      lordo: _parse(_lordoController),
      netto: _parse(_nettoController),
      trattenute: trattenute,
      straordinari: _parse(_straordinariController),
      ferieMaturate: _parse(_ferieMaturateController),
      ferieGodute: _parse(_ferieGoduteController),
      ferieResidue: _parse(_ferieResidueController),
      rolMaturati: _parse(_rolMaturatiController),
      rolGoduti: _parse(_rolGodutiController),
      rolResidui: _parse(_rolResiduiController),
      permessiGoduti: _parse(_permessiGodutiController),
      oreLavorate: _parse(_oreLavorateController),
      tipo: _tipo,
      statoVerifica: _valoriDaConferma
          ? StatoVerificaBustaPaga.daConfermare
          : StatoVerificaBustaPaga.confermato,
    );

    ref.read(busteRepositoryProvider.notifier).add(bustaPaga);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoDynamicColor.resolve(AppColors.systemBlue, context);
    final secondaryAccent =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);

    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoDynamicColor.resolve(AppColors.backgroundPrimary, context),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Nuova busta paga'),
      ),
      child: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.sm,
                AppSpacing.screenHorizontal,
                _actionBarReservedHeight,
              ),
              children: [
                if (_valoriDaConferma) _ConfermaBanner(warnings: _warnings),
                BustaPagaHeroCard(
                  isConfermato: false,
                  periodoLabel: _periodoLabel,
                  tipo: _tipo,
                  isEditing: true,
                  nettoDisplay: formatNumber(_parse(_nettoController)),
                  nettoController: _nettoController,
                  onTapPeriodo: _pickPeriodo,
                  onTapTipo: _pickTipo,
                ),
                const SizedBox(height: AppSpacing.lg),
                BustaPagaStatRow(items: [
                  (
                    'Ferie residue',
                    Text(
                      formatNumber(_parse(_ferieResidueController)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  (
                    'ROL residui',
                    Text(
                      formatNumber(_parse(_rolResiduiController)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  (
                    'Ore lavorate',
                    inlineNumberField(_oreLavorateController),
                  ),
                ]),
                const SizedBox(height: AppSpacing.lg),
                BustaPagaDocumentoChip(filePath: _fileOrigine),
                const SizedBox(height: AppSpacing.lg),
                BustaPagaMaturazioniSection(
                  isEditing: true,
                  ferieMaturate:
                      formatNumber(_parse(_ferieMaturateController)),
                  ferieGodute: formatNumber(_parse(_ferieGoduteController)),
                  ferieResidue: formatNumber(_parse(_ferieResidueController)),
                  rolMaturati: formatNumber(_parse(_rolMaturatiController)),
                  rolGoduti: formatNumber(_parse(_rolGodutiController)),
                  rolResidui: formatNumber(_parse(_rolResiduiController)),
                  permessiGoduti:
                      formatNumber(_parse(_permessiGodutiController)),
                  ferieMaturateCtrl: _ferieMaturateController,
                  ferieGoduteCtrl: _ferieGoduteController,
                  ferieResidueCtrl: _ferieResidueController,
                  rolMaturatiCtrl: _rolMaturatiController,
                  rolGodutiCtrl: _rolGodutiController,
                  rolResiduiCtrl: _rolResiduiController,
                  permessiGodutiCtrl: _permessiGodutiController,
                ),
                BustaPagaStatRow(items: [
                  (
                    'Lordo',
                    inlineNumberField(_lordoController, prefix: '€ '),
                  ),
                  (
                    'Straordinari',
                    inlineNumberField(_straordinariController, prefix: '€ '),
                  ),
                ]),
                const SizedBox(height: AppSpacing.lg),
                GlassFormSection(
                  footer: 'Aggiungi le voci di trattenuta indicate in busta '
                      'paga (es. INPS, IRPEF).',
                  children: [
                    for (var i = 0; i < _trattenute.length; i++)
                      trattenutaEditRow(
                        _trattenute[i],
                        onDismissed: () => _removeTrattenuta(i),
                      ),
                    _aggiungiVoceButton(accent),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: AppSpacing.screenHorizontal,
            right: AppSpacing.screenHorizontal,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: FlatChipButton(
                        icon: CupertinoIcons.checkmark_alt,
                        label: 'Salva',
                        color: accent,
                        onPressed: _save,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FlatChipButton(
                        icon: CupertinoIcons.xmark,
                        label: 'Annulla',
                        color: secondaryAccent,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aggiungiVoceButton(Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _addTrattenuta,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.add_circled, color: accent, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text('Aggiungi voce',
                style: AppTextStyles.subtitle.copyWith(color: accent)),
          ],
        ),
      ),
    );
  }
}

/// Banner di conferma esplicita per i dati estratti automaticamente da un
/// nuovo import PDF: visibile finché `_valoriDaConferma == true`, incorpora
/// gli eventuali warning del parser regex. Il bottone "Salva" nella barra
/// flottante in basso resta il meccanismo di conferma vera e propria (vedi
/// `_save`).
class _ConfermaBanner extends StatelessWidget {
  final List<String> warnings;

  const _ConfermaBanner({required this.warnings});

  @override
  Widget build(BuildContext context) {
    final accent =
        CupertinoDynamicColor.resolve(AppColors.systemOrange, context);
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: LiquidGlassSurface(
        radius: AppRadius.glass,
        tint: accent,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.wand_stars, size: 18, color: accent),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Dati estratti automaticamente',
                    style: AppTextStyles.subtitle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: labelPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Verifica e correggi i campi se necessario: si confermano '
              'salvando con "Salva".',
              style: AppTextStyles.cardLabel.copyWith(color: labelPrimary),
            ),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              for (final warning in warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '• $warning',
                    style: AppTextStyles.cardLabel.copyWith(
                      color: labelPrimary,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
