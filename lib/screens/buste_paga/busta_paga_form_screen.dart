import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/busta_paga.dart';
import '../../providers/buste_paga_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Form di inserimento/modifica manuale di una busta paga. Se [existing] è
/// presente, precompila i campi e salva con `update`; altrimenti crea un
/// nuovo `BustaPaga` e salva con `add`.
class BustaPagaFormScreen extends ConsumerStatefulWidget {
  final BustaPaga? existing;

  const BustaPagaFormScreen({super.key, this.existing});

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

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _periodo = existing?.periodo ?? DateTime(DateTime.now().year, DateTime.now().month);

    _lordoController =
        TextEditingController(text: _formatNumber(existing?.lordo));
    _nettoController =
        TextEditingController(text: _formatNumber(existing?.netto));
    _straordinariController =
        TextEditingController(text: _formatNumber(existing?.straordinari));

    _ferieMaturateController =
        TextEditingController(text: _formatNumber(existing?.ferieMaturate));
    _ferieGoduteController =
        TextEditingController(text: _formatNumber(existing?.ferieGodute));
    _ferieResidueController =
        TextEditingController(text: _formatNumber(existing?.ferieResidue));

    _rolMaturatiController =
        TextEditingController(text: _formatNumber(existing?.rolMaturati));
    _rolGodutiController =
        TextEditingController(text: _formatNumber(existing?.rolGoduti));
    _rolResiduiController =
        TextEditingController(text: _formatNumber(existing?.rolResidui));

    _permessiGodutiController =
        TextEditingController(text: _formatNumber(existing?.permessiGoduti));
    _oreLavorateController =
        TextEditingController(text: _formatNumber(existing?.oreLavorate));

    _trattenute = existing == null || existing.trattenute.isEmpty
        ? [_TrattenutaRow()]
        : existing.trattenute.entries
            .map((e) => _TrattenutaRow(
                chiave: e.key, importo: e.value.toStringAsFixed(2)))
            .toList();
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
      fileOrigine: widget.existing?.fileOrigine,
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
      statoVerifica:
          widget.existing?.statoVerifica ?? StatoVerificaBustaPaga.confermato,
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
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text('Salva'),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              CupertinoFormSection.insetGrouped(
                header: const Text('Periodo'),
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
              CupertinoFormSection.insetGrouped(
                header: const Text('Importi'),
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
              CupertinoFormSection.insetGrouped(
                header: const Text('Ferie'),
                children: [
                  _numberField(
                      label: 'Maturate', controller: _ferieMaturateController),
                  _numberField(
                      label: 'Godute', controller: _ferieGoduteController),
                  _numberField(
                      label: 'Residue', controller: _ferieResidueController),
                ],
              ),
              CupertinoFormSection.insetGrouped(
                header: const Text('ROL'),
                children: [
                  _numberField(
                      label: 'Maturati', controller: _rolMaturatiController),
                  _numberField(
                      label: 'Goduti', controller: _rolGodutiController),
                  _numberField(
                      label: 'Residui', controller: _rolResiduiController),
                ],
              ),
              CupertinoFormSection.insetGrouped(
                header: const Text('Permessi e ore'),
                children: [
                  _numberField(
                      label: 'Permessi goduti',
                      controller: _permessiGodutiController),
                  _numberField(
                      label: 'Ore lavorate', controller: _oreLavorateController),
                ],
              ),
              CupertinoFormSection.insetGrouped(
                header: const Text('Trattenute'),
                footer: const Text(
                    'Aggiungi le voci di trattenuta indicate in busta paga (es. INPS, IRPEF).'),
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
