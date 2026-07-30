import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../../models/busta_paga.dart';
import '../../providers/buste_paga_provider.dart';
import '../../services/busta_paga_regex_parser.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/glass_form_section.dart';
import '../../widgets/liquid_glass_button.dart';
import '../../widgets/liquid_glass_surface.dart';

/// Form di revisione/modifica di una busta paga. Il form si apre in due
/// modalità soltanto:
/// - modifica di una busta paga esistente ([existing] non nullo, dal
///   dettaglio);
/// - revisione di un nuovo import PDF già processato a monte
///   ([estratti] non nullo, con [fileOrigine] il path del PDF già copiato):
///   i campi sono precompilati dal parser regex e restano editabili prima
///   della conferma esplicita (pulsante Salva).
///
/// Non esiste più una modalità "vuota" per inserimento manuale libero: il
/// PDF viene sempre scelto e processato prima di arrivare qui (vedi
/// `buste_paga_section_screen.dart` / CLAUDE.md).
class BustaPagaFormScreen extends ConsumerStatefulWidget {
  final BustaPaga? existing;
  final String? fileOrigine;
  final BustaPagaEstratti? estratti;

  const BustaPagaFormScreen({
    super.key,
    this.existing,
  })  : fileOrigine = null,
        estratti = null;

  const BustaPagaFormScreen.daImport({
    super.key,
    required String this.fileOrigine,
    required BustaPagaEstratti this.estratti,
  }) : existing = null;

  @override
  ConsumerState<BustaPagaFormScreen> createState() =>
      _BustaPagaFormScreenState();
}

class _TrattenutaRow {
  final TextEditingController chiave;
  final TextEditingController importo;

  _TrattenutaRow({String chiave = '', String importo = ''})
      : chiave = TextEditingController(text: chiave),
        importo = TextEditingController(text: importo);

  void dispose() {
    chiave.dispose();
    importo.dispose();
  }
}

class _BustaPagaFormScreenState extends ConsumerState<BustaPagaFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _periodo;

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

  late List<_TrattenutaRow> _trattenute;

  String? _fileOrigine;
  List<String> _warnings = const [];

  /// True quando i campi sono stati popolati dall'estrazione automatica e
  /// non ancora confermati esplicitamente (salvataggio) dall'utente.
  bool _valoriDaConferma = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final estratti = widget.estratti;

    _fileOrigine = existing?.fileOrigine ?? widget.fileOrigine;
    _valoriDaConferma = existing != null
        ? existing.statoVerifica == StatoVerificaBustaPaga.daConfermare
        : estratti != null;
    _warnings = estratti?.warnings ?? const [];

    _periodo = existing?.periodo ??
        _periodoFromEstratti(estratti?.periodo) ??
        DateTime(DateTime.now().year, DateTime.now().month);

    _lordoController = TextEditingController(
        text: _formatNumber(existing?.lordo ?? estratti?.lordo));
    _nettoController = TextEditingController(
        text: _formatNumber(existing?.netto ?? estratti?.netto));
    _straordinariController = TextEditingController(
        text: _formatNumber(existing?.straordinari ?? estratti?.straordinari));

    _ferieMaturateController = TextEditingController(
        text:
            _formatNumber(existing?.ferieMaturate ?? estratti?.ferieMaturate));
    _ferieGoduteController = TextEditingController(
        text: _formatNumber(existing?.ferieGodute ?? estratti?.ferieGodute));
    _ferieResidueController = TextEditingController(
        text: _formatNumber(existing?.ferieResidue ?? estratti?.ferieResidue));

    _rolMaturatiController = TextEditingController(
        text: _formatNumber(existing?.rolMaturati ?? estratti?.rolMaturati));
    _rolGodutiController = TextEditingController(
        text: _formatNumber(existing?.rolGoduti ?? estratti?.rolGoduti));
    _rolResiduiController = TextEditingController(
        text: _formatNumber(existing?.rolResidui ?? estratti?.rolResidui));

    _permessiGodutiController = TextEditingController(
        text:
            _formatNumber(existing?.permessiGoduti ?? estratti?.permessiGoduti));
    _oreLavorateController = TextEditingController(
        text: _formatNumber(existing?.oreLavorate ?? estratti?.oreLavorate));

    final trattenuteIniziali =
        existing?.trattenute ?? estratti?.trattenute ?? const {};
    _trattenute = trattenuteIniziali.isEmpty
        ? [_TrattenutaRow()]
        : trattenuteIniziali.entries
            .map((e) => _TrattenutaRow(
                chiave: e.key, importo: e.value.toStringAsFixed(2)))
            .toList();
  }

  static DateTime? _periodoFromEstratti(String? periodo) {
    if (periodo == null) return null;
    final parti = periodo.split('-');
    final anno = int.tryParse(parti.elementAtOrNull(0) ?? '');
    final mese = int.tryParse(parti.elementAtOrNull(1) ?? '');
    if (anno == null || mese == null) return null;
    return DateTime(anno, mese);
  }

  static String _formatNumber(double? value) {
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
    setState(() => _trattenute.add(_TrattenutaRow()));
  }

  void _removeTrattenuta(int index) {
    setState(() {
      _trattenute[index].dispose();
      _trattenute.removeAt(index);
    });
  }

  void _save() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final trattenute = <String, double>{};
    for (final row in _trattenute) {
      final chiave = row.chiave.text.trim();
      if (chiave.isEmpty) continue;
      trattenute[chiave] = _parse(row.importo);
    }

    final bustaPaga = BustaPaga(
      id: widget.existing?.id ??
          'bp-${DateTime.now().millisecondsSinceEpoch}',
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
      statoVerifica: _valoriDaConferma
          ? StatoVerificaBustaPaga.daConfermare
          : StatoVerificaBustaPaga.confermato,
    );

    if (_isEditing) {
      ref.read(busteRepositoryProvider.notifier).update(bustaPaga);
    } else {
      ref.read(busteRepositoryProvider.notifier).add(bustaPaga);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);
    final accent = CupertinoDynamicColor.resolve(AppColors.bustePaga, context);

    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoDynamicColor.resolve(AppColors.backgroundPrimary, context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? 'Modifica busta paga' : 'Nuova busta paga'),
        trailing: LiquidGlassButton(
          onPressed: _save,
          radius: AppRadius.glassSmall,
          tint: CupertinoTheme.of(context).primaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            'Salva',
            style: TextStyle(
              color: CupertinoTheme.of(context).primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.xl,
            ),
            children: [
              if (_valoriDaConferma) _ConfermaBanner(warnings: _warnings),
              GlassFormSection(
                header: 'Periodo',
                children: [
                  CupertinoFormRow(
                    prefix: const Text('Mese'),
                    child: GestureDetector(
                      onTap: _pickPeriodo,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_periodoLabel, style: TextStyle(color: accent)),
                          const SizedBox(width: AppSpacing.xs),
                          Icon(CupertinoIcons.chevron_down,
                              size: 14, color: labelSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_fileOrigine != null)
                GlassFormSection(
                  header: 'Documento',
                  children: [_documentoRow(labelSecondary)],
                ),
              GlassFormSection(
                header: 'Importi',
                children: [
                  _numberField(
                    label: 'Lordo',
                    controller: _lordoController,
                  ),
                  _numberField(
                    label: 'Netto',
                    controller: _nettoController,
                    requiredField: true,
                  ),
                  _numberField(
                    label: 'Straordinari',
                    controller: _straordinariController,
                  ),
                ],
              ),
              GlassFormSection(
                header: 'Ferie',
                children: [
                  _numberField(
                      label: 'Maturate', controller: _ferieMaturateController),
                  _numberField(
                      label: 'Godute', controller: _ferieGoduteController),
                  _numberField(
                      label: 'Residue', controller: _ferieResidueController),
                ],
              ),
              GlassFormSection(
                header: 'ROL',
                children: [
                  _numberField(
                      label: 'Maturati', controller: _rolMaturatiController),
                  _numberField(
                      label: 'Goduti', controller: _rolGodutiController),
                  _numberField(
                      label: 'Residui', controller: _rolResiduiController),
                ],
              ),
              GlassFormSection(
                header: 'Permessi e ore',
                children: [
                  _numberField(
                      label: 'Permessi goduti',
                      controller: _permessiGodutiController),
                  _numberField(
                      label: 'Ore lavorate', controller: _oreLavorateController),
                ],
              ),
              GlassFormSection(
                header: 'Trattenute',
                footer:
                    'Aggiungi le voci di trattenuta indicate in busta paga (es. INPS, IRPEF).',
                children: [
                  for (var i = 0; i < _trattenute.length; i++)
                    _trattenutaRow(i),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Riga di sola visualizzazione del PDF già associato alla busta paga: il
  /// file è già stato scelto e processato prima di arrivare al form, qui
  /// non ci sono azioni di allega/rimuovi (vedi CLAUDE.md).
  Widget _documentoRow(Color labelSecondary) {
    return CupertinoFormRow(
      prefix: const Text('PDF'),
      child: Text(
        p.basename(_fileOrigine!),
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: TextStyle(color: labelSecondary),
      ),
    );
  }

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    bool requiredField = false,
  }) {
    return CupertinoTextFormFieldRow(
      prefix: Text(label),
      controller: controller,
      textAlign: TextAlign.end,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: false),
      placeholder: '0',
      validator: requiredField
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Obbligatorio';
              }
              final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
              if (parsed == null) return 'Valore non valido';
              return null;
            }
          : null,
    );
  }

  Widget _trattenutaRow(int index) {
    final row = _trattenute[index];
    return CupertinoFormRow(
      prefix: SizedBox(
        width: 120,
        child: CupertinoTextField(
          controller: row.chiave,
          placeholder: 'Voce',
          decoration: const BoxDecoration(),
          padding: EdgeInsets.zero,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 90,
            child: CupertinoTextField(
              controller: row.importo,
              placeholder: '0',
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: false),
              decoration: const BoxDecoration(),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: _trattenute.length > 1
                ? () => _removeTrattenuta(index)
                : null,
            child: Icon(
              CupertinoIcons.minus_circle,
              size: 20,
              color: CupertinoDynamicColor.resolve(
                  AppColors.systemRed, context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner di conferma esplicita per i dati estratti automaticamente da un
/// nuovo import PDF: visibile finché `_valoriDaConferma == true`, incorpora
/// gli eventuali warning del parser regex. Il pulsante "Salva" nella nav
/// bar resta il meccanismo di conferma vera e propria (vedi `_save`).
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
