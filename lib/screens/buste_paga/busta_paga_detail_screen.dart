import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../../models/busta_paga.dart';
import '../../providers/buste_paga_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/busta_paga_formatting.dart';
import '../../widgets/app_alert_dialog.dart';
import '../../widgets/flat_chip_button.dart';
import '../../widgets/glass_form_section.dart';
import '../../widgets/liquid_glass_surface.dart';
import '../../widgets/spring_button.dart';
import '../../widgets/swipe_delete_background.dart';

/// Altezza riservata alla barra flottante "Conferma/Modifica" (o
/// "Salva/Annulla" in modifica) in basso, usata come padding in fondo al
/// contenuto scrollabile perché l'ultima card non finisca nascosta/tappabile
/// dietro di essa. Nessun effetto di dissolvenza in questa schermata
/// (abbandonato il 2026-07-31): la hero card resta fissa in alto fuori dalla
/// lista e il resto scorre con scroll naturale — questo valore è quindi un
/// margine di sicurezza puro, non un calcolo legato a uno shader. Più
/// generoso di quanto basterebbe alla sola `_ActionBar` (che da sola misura
/// meno) perché in modifica l'ultimo elemento scrollabile è spesso il footer
/// testuale (due righe) della sezione Trattenute, più alto del contenuto
/// tipico della vista di sola lettura: senza questo margine extra, quel
/// footer restava visibilmente sovrapposto/nascosto dietro la barra invece
/// di poterci scorrere sopra come qualunque altra card.
const double _actionBarReservedHeight = 80;

/// Etichette del tipo busta paga, condivise da hero (sola lettura/modifica)
/// e dal picker `_pickTipo` — stessa mappa duplicata in
/// `busta_paga_form_screen.dart` (nessun modulo condiviso per 3 stringhe).
const _tipoLabels = {
  TipoBustaPaga.mensile: 'Mensile',
  TipoBustaPaga.tredicesima: '13esima',
  TipoBustaPaga.quattordicesima: '14esima',
};

/// Riga di trattenuta in editing: chiave + importo come controller separati,
/// stessa forma di `_TrattenutaRow` in `BustaPagaFormScreen`. `id` è una
/// chiave stabile e univoca per riga (indipendente dall'indice, che cambia
/// quando si rimuove una riga precedente), usata da `Dismissible` per lo
/// swipe-to-delete.
class _TrattenutaEditRow {
  static int _nextId = 0;

  final int id;
  final TextEditingController chiave;
  final TextEditingController importo;

  _TrattenutaEditRow({String chiave = '', String importo = ''})
      : id = _nextId++,
        chiave = TextEditingController(text: chiave),
        importo = TextEditingController(text: importo);

  void dispose() {
    chiave.dispose();
    importo.dispose();
  }
}

/// Vista di dettaglio di una busta paga: hero con i dati principali, tabella
/// riepilogativa di Ferie/ROL/Permessi e sezioni di dettaglio per documento,
/// importi e trattenute. La barra flottante in basso permette di confermare
/// lo stato o attivare la modifica **inline** dei dati (nessuna navigazione
/// verso un form separato): in modifica le stesse card diventano editabili
/// sul posto, mantenendo lo stesso layout della vista di sola lettura.
///
/// `ConsumerStatefulWidget` (non più `ConsumerWidget`/`StatelessWidget`):
/// serve stato locale per la modalità modifica (flag `_isEditing` e un
/// `TextEditingController` per ogni campo numerico + periodo + trattenute).
class BustaPagaDetailScreen extends ConsumerStatefulWidget {
  final BustaPaga bustaPaga;

  const BustaPagaDetailScreen({super.key, required this.bustaPaga});

  @override
  ConsumerState<BustaPagaDetailScreen> createState() =>
      _BustaPagaDetailScreenState();
}

class _BustaPagaDetailScreenState extends ConsumerState<BustaPagaDetailScreen> {
  bool _isEditing = false;

  late DateTime _periodoEdit;
  late TipoBustaPaga _tipoEdit;

  late TextEditingController _nettoCtrl;
  late TextEditingController _lordoCtrl;
  late TextEditingController _straordinariCtrl;
  late TextEditingController _oreLavorateCtrl;

  late TextEditingController _ferieMaturateCtrl;
  late TextEditingController _ferieGoduteCtrl;
  late TextEditingController _ferieResidueCtrl;

  late TextEditingController _rolMaturatiCtrl;
  late TextEditingController _rolGodutiCtrl;
  late TextEditingController _rolResiduiCtrl;

  late TextEditingController _permessiGodutiCtrl;

  late List<_TrattenutaEditRow> _trattenuteEdit;

  String _periodoLabelForDate(DateTime data) {
    final formatted = DateFormat('MMMM yyyy', 'it_IT').format(data);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  /// Popola tutti i controller di editing dai valori correnti (letti dal
  /// provider) e attiva la modalità modifica. I controller di
  /// `ferieResidue`/`rolResidui` hanno anche un listener che forza un
  /// rebuild, così `_StatRow` (che li mostra in sola lettura, riflettendo lo
  /// stesso dato della tabella Maturato/Goduto/Residuo) resta sincronizzato
  /// live mentre l'utente digita nella tabella.
  void _enterEditing(BustaPaga corrente) {
    _periodoEdit = corrente.periodo;
    _tipoEdit = corrente.tipo;

    _nettoCtrl = TextEditingController(text: formatNumber(corrente.netto));
    _lordoCtrl = TextEditingController(text: formatNumber(corrente.lordo));
    _straordinariCtrl =
        TextEditingController(text: formatNumber(corrente.straordinari));
    _oreLavorateCtrl =
        TextEditingController(text: formatNumber(corrente.oreLavorate));

    _ferieMaturateCtrl =
        TextEditingController(text: formatNumber(corrente.ferieMaturate));
    _ferieGoduteCtrl =
        TextEditingController(text: formatNumber(corrente.ferieGodute));
    _ferieResidueCtrl =
        TextEditingController(text: formatNumber(corrente.ferieResidue));

    _rolMaturatiCtrl =
        TextEditingController(text: formatNumber(corrente.rolMaturati));
    _rolGodutiCtrl =
        TextEditingController(text: formatNumber(corrente.rolGoduti));
    _rolResiduiCtrl =
        TextEditingController(text: formatNumber(corrente.rolResidui));

    _permessiGodutiCtrl =
        TextEditingController(text: formatNumber(corrente.permessiGoduti));

    _trattenuteEdit = corrente.trattenute.isEmpty
        ? [_TrattenutaEditRow()]
        : corrente.trattenute.entries
            .map((e) => _TrattenutaEditRow(
                chiave: e.key, importo: formatNumber(e.value)))
            .toList();

    // Forza il rebuild dello `_StatRow` (Ferie/ROL residui) ogni volta che
    // cambia il campo "Residuo" corrispondente nella tabella sottostante.
    _ferieResidueCtrl.addListener(_onResiduiChanged);
    _rolResiduiCtrl.addListener(_onResiduiChanged);

    setState(() => _isEditing = true);
  }

  void _onResiduiChanged() => setState(() {});

  void _disposeEditingControllers() {
    _nettoCtrl.dispose();
    _lordoCtrl.dispose();
    _straordinariCtrl.dispose();
    _oreLavorateCtrl.dispose();
    _ferieMaturateCtrl.dispose();
    _ferieGoduteCtrl.dispose();
    _ferieResidueCtrl.dispose();
    _rolMaturatiCtrl.dispose();
    _rolGodutiCtrl.dispose();
    _rolResiduiCtrl.dispose();
    _permessiGodutiCtrl.dispose();
    for (final row in _trattenuteEdit) {
      row.dispose();
    }
  }

  void _cancelEditing() {
    _disposeEditingControllers();
    setState(() => _isEditing = false);
  }

  double _parse(TextEditingController controller) {
    final text = controller.text.trim().replaceAll(',', '.');
    return double.tryParse(text) ?? 0;
  }

  void _addTrattenuta() {
    setState(() => _trattenuteEdit.add(_TrattenutaEditRow()));
  }

  void _removeTrattenuta(int index) {
    setState(() {
      _trattenuteEdit[index].dispose();
      _trattenuteEdit.removeAt(index);
    });
  }

  Future<void> _pickPeriodo() async {
    DateTime tempSelection = _periodoEdit;
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
                        setState(() => _periodoEdit = tempSelection);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.monthYear,
                    initialDateTime: _periodoEdit,
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
    if (scelta != null) setState(() => _tipoEdit = scelta);
  }

  void _showAlert(String title, String message) {
    final accent = CupertinoDynamicColor.resolve(AppColors.systemBlue, context);
    showAppAlertDialog<void>(
      context: context,
      title: title,
      message: message,
      actions: [
        AppAlertAction(
          label: 'OK',
          color: accent,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  /// Costruisce il candidato dai controller correnti, calcola il diff
  /// rispetto a [corrente] e, se non vuoto, chiede conferma esplicita
  /// prima di salvare — vedi CLAUDE.md/istruzioni task per il comportamento
  /// dettagliato dei 3 esiti (invariato / conferma / annulla).
  void _save(BustaPaga corrente) {
    final nettoText = _nettoCtrl.text.trim().replaceAll(',', '.');
    if (nettoText.isEmpty || double.tryParse(nettoText) == null) {
      _showAlert(
        'Netto non valido',
        'Inserisci un valore numerico per il netto prima di salvare.',
      );
      return;
    }

    final trattenute = <String, double>{};
    for (final row in _trattenuteEdit) {
      final chiave = row.chiave.text.trim();
      if (chiave.isEmpty) continue;
      trattenute[chiave] = _parse(row.importo);
    }

    final candidato = corrente.copyWith(
      periodo: _periodoEdit,
      tipo: _tipoEdit,
      netto: _parse(_nettoCtrl),
      lordo: _parse(_lordoCtrl),
      straordinari: _parse(_straordinariCtrl),
      oreLavorate: _parse(_oreLavorateCtrl),
      ferieMaturate: _parse(_ferieMaturateCtrl),
      ferieGodute: _parse(_ferieGoduteCtrl),
      ferieResidue: _parse(_ferieResidueCtrl),
      rolMaturati: _parse(_rolMaturatiCtrl),
      rolGoduti: _parse(_rolGodutiCtrl),
      rolResidui: _parse(_rolResiduiCtrl),
      permessiGoduti: _parse(_permessiGodutiCtrl),
      trattenute: trattenute,
    );

    // Stesso controllo dell'import (vedi `buste_paga_section_screen.dart`):
    // per le mensili anno+mese+tipo, per 13esima/14esima solo anno+tipo (il
    // mese esatto in cui vengono pagate varia, ma non può essercene più di
    // una dello stesso tipo nello stesso anno). Esclude se stessa dal
    // confronto (l'id non cambia durante la modifica).
    final conflitto = ref.read(busteRepositoryProvider).any((b) {
      if (b.id == candidato.id) return false;
      if (b.tipo != candidato.tipo) return false;
      if (candidato.tipo == TipoBustaPaga.mensile) {
        return b.periodo.year == candidato.periodo.year &&
            b.periodo.month == candidato.periodo.month;
      }
      return b.periodo.year == candidato.periodo.year;
    });
    if (conflitto) {
      _showAlert(
        'Busta paga già presente',
        'Hai già una busta paga per '
            '${periodoDisplayFor(periodo: candidato.periodo, tipo: candidato.tipo)} '
            'in archivio.',
      );
      return;
    }

    final diff = _buildDiff(corrente, candidato);

    if (diff.isEmpty) {
      _cancelEditing();
      return;
    }

    final accent = CupertinoDynamicColor.resolve(AppColors.systemBlue, context);
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);
    showAppAlertDialog<void>(
      context: context,
      title: 'Conferma modifiche',
      message: 'Hai modificato i seguenti dati, confermi?\n\n'
          '${diff.join('\n')}',
      actions: [
        AppAlertAction(
          label: 'Annulla',
          color: labelSecondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppAlertAction(
          label: 'Conferma',
          color: accent,
          onPressed: () {
            ref.read(busteRepositoryProvider.notifier).update(
                  candidato.copyWith(
                    statoVerifica: StatoVerificaBustaPaga.daConfermare,
                  ),
                );
            Navigator.of(context).pop();
            _cancelEditing();
          },
        ),
      ],
    );
  }

  List<String> _buildDiff(BustaPaga vecchia, BustaPaga nuova) {
    final diff = <String>[];

    void addIfChanged(String label, double oldValue, double newValue) {
      if (formatNumber(oldValue) != formatNumber(newValue)) {
        diff.add(
            '$label: ${formatNumber(oldValue)} → ${formatNumber(newValue)}');
      }
    }

    if (_periodoLabelForDate(vecchia.periodo) !=
        _periodoLabelForDate(nuova.periodo)) {
      diff.add(
        'Periodo: ${_periodoLabelForDate(vecchia.periodo)} → '
        '${_periodoLabelForDate(nuova.periodo)}',
      );
    }
    if (vecchia.tipo != nuova.tipo) {
      diff.add(
        'Tipo: ${_tipoLabels[vecchia.tipo]} → ${_tipoLabels[nuova.tipo]}',
      );
    }
    addIfChanged('Netto', vecchia.netto, nuova.netto);
    addIfChanged('Lordo', vecchia.lordo, nuova.lordo);
    addIfChanged('Straordinari', vecchia.straordinari, nuova.straordinari);
    addIfChanged('Ferie maturate', vecchia.ferieMaturate, nuova.ferieMaturate);
    addIfChanged('Ferie godute', vecchia.ferieGodute, nuova.ferieGodute);
    addIfChanged('Ferie residue', vecchia.ferieResidue, nuova.ferieResidue);
    addIfChanged('ROL maturati', vecchia.rolMaturati, nuova.rolMaturati);
    addIfChanged('ROL goduti', vecchia.rolGoduti, nuova.rolGoduti);
    addIfChanged('ROL residui', vecchia.rolResidui, nuova.rolResidui);
    addIfChanged(
        'Permessi goduti', vecchia.permessiGoduti, nuova.permessiGoduti);
    addIfChanged('Ore lavorate', vecchia.oreLavorate, nuova.oreLavorate);

    final chiavi = {...vecchia.trattenute.keys, ...nuova.trattenute.keys};
    for (final chiave in chiavi) {
      final prima = vecchia.trattenute[chiave];
      final dopo = nuova.trattenute[chiave];
      if (prima == null && dopo != null) {
        diff.add('Trattenuta $chiave: aggiunta (€ ${formatNumber(dopo)})');
      } else if (prima != null && dopo == null) {
        diff.add('Trattenuta $chiave: rimossa (era € ${formatNumber(prima)})');
      } else if (prima != null &&
          dopo != null &&
          formatNumber(prima) != formatNumber(dopo)) {
        diff.add(
          'Trattenuta $chiave: € ${formatNumber(prima)} → € ${formatNumber(dopo)}',
        );
      }
    }

    return diff;
  }

  @override
  void dispose() {
    if (_isEditing) {
      _disposeEditingControllers();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buste = ref.watch(busteRepositoryProvider);
    final corrente = buste.firstWhere((b) => b.id == widget.bustaPaga.id,
        orElse: () => widget.bustaPaga);
    final periodoLabelVista = _isEditing
        ? periodoDisplayFor(periodo: _periodoEdit, tipo: _tipoEdit)
        : bustaPagaPeriodoDisplay(corrente);

    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoDynamicColor.resolve(AppColors.backgroundPrimary, context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(periodoLabelVista),
      ),
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.sm,
                    AppSpacing.screenHorizontal,
                    0,
                  ),
                  child: _HeroCard(
                    bustaPaga: corrente,
                    periodoLabel: periodoLabelVista,
                    tipo: _isEditing ? _tipoEdit : corrente.tipo,
                    isEditing: _isEditing,
                    nettoController: _isEditing ? _nettoCtrl : null,
                    onTapPeriodo: _isEditing ? _pickPeriodo : null,
                    onTapTipo: _isEditing ? _pickTipo : null,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.only(bottom: _actionBarReservedHeight),
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (rect) {
                        const fadeHeight = 32.0;
                        final stop =
                            1 - (fadeHeight / rect.height).clamp(0.0, 1.0);
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
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenHorizontal,
                          AppSpacing.lg,
                          AppSpacing.screenHorizontal,
                          AppSpacing.xl,
                        ),
                        children: [
                          _StatRow(items: [
                            (
                              'Ferie residue',
                              Text(
                                _isEditing
                                    ? formatNumber(_parse(_ferieResidueCtrl))
                                    : formatNumber(corrente.ferieResidue),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            (
                              'ROL residui',
                              Text(
                                _isEditing
                                    ? formatNumber(_parse(_rolResiduiCtrl))
                                    : formatNumber(corrente.rolResidui),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            (
                              'Ore lavorate',
                              _isEditing
                                  ? _inlineNumberField(_oreLavorateCtrl)
                                  : Text(formatNumber(corrente.oreLavorate),
                                      textAlign: TextAlign.center),
                            ),
                          ]),
                          const SizedBox(height: AppSpacing.lg),
                          if (corrente.fileOrigine != null) ...[
                            _DocumentoChip(filePath: corrente.fileOrigine!),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          _MaturazioniSection(
                            bustaPaga: corrente,
                            isEditing: _isEditing,
                            ferieMaturateCtrl:
                                _isEditing ? _ferieMaturateCtrl : null,
                            ferieGoduteCtrl:
                                _isEditing ? _ferieGoduteCtrl : null,
                            ferieResidueCtrl:
                                _isEditing ? _ferieResidueCtrl : null,
                            rolMaturatiCtrl:
                                _isEditing ? _rolMaturatiCtrl : null,
                            rolGodutiCtrl: _isEditing ? _rolGodutiCtrl : null,
                            rolResiduiCtrl: _isEditing ? _rolResiduiCtrl : null,
                            permessiGodutiCtrl:
                                _isEditing ? _permessiGodutiCtrl : null,
                          ),
                          _StatRow(items: [
                            (
                              'Lordo',
                              _isEditing
                                  ? _inlineNumberField(_lordoCtrl, prefix: '€ ')
                                  : Text('€ ${formatNumber(corrente.lordo)}',
                                      textAlign: TextAlign.center),
                            ),
                            (
                              'Straordinari',
                              _isEditing
                                  ? _inlineNumberField(_straordinariCtrl,
                                      prefix: '€ ')
                                  : Text(
                                      '€ ${formatNumber(corrente.straordinari)}',
                                      textAlign: TextAlign.center),
                            ),
                          ]),
                          const SizedBox(height: AppSpacing.lg),
                          GlassFormSection(
                            footer: _isEditing
                                ? 'Aggiungi le voci di trattenuta indicate in busta '
                                    'paga (es. INPS, IRPEF).'
                                : null,
                            children: _isEditing
                                ? [
                                    for (var i = 0;
                                        i < _trattenuteEdit.length;
                                        i++)
                                      _trattenutaEditRow(i),
                                    _aggiungiVoceButton(context),
                                  ]
                                : corrente.trattenute.isEmpty
                                    ? [
                                        _trattenutaRow(
                                            'Nessuna trattenuta', '—')
                                      ]
                                    : corrente.trattenute.entries
                                        .map((e) => _trattenutaRow(e.key,
                                            '− € ${formatNumber(e.value)}'))
                                        .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                child: _ActionBar(
                  bustaPaga: corrente,
                  isEditing: _isEditing,
                  onConferma: () {
                    ref.read(busteRepositoryProvider.notifier).update(
                          corrente.copyWith(
                            statoVerifica: StatoVerificaBustaPaga.confermato,
                          ),
                        );
                    showAppAlertDialog<void>(
                      context: context,
                      title: 'Dati confermati',
                      actions: [
                        AppAlertAction(
                          label: 'OK',
                          color: CupertinoDynamicColor.resolve(
                              AppColors.systemBlue, context),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    );
                  },
                  onModifica: () => _enterEditing(corrente),
                  onSalva: () => _save(corrente),
                  onAnnulla: _cancelEditing,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aggiungiVoceButton(BuildContext context) {
    final accent = CupertinoDynamicColor.resolve(AppColors.systemBlue, context);
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

  Widget _trattenutaRow(String label, String value) {
    return Builder(
      builder: (context) {
        final labelPrimary =
            CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  label,
                  style: AppTextStyles.subtitle.copyWith(
                    color: labelPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cardAmount.copyWith(
                    color: labelPrimary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Riga editabile di trattenuta: chiave + importo come campi di testo,
  /// stesso layout a due colonne label/valore della vista di sola lettura.
  /// La rimozione avviene via swipe verso sinistra (stesso pattern usato
  /// per eliminare una busta paga in `BusteePagaArchivioView`), senza
  /// alert di conferma: qui si rimuove solo una riga dallo stato locale di
  /// modifica, ancora reversibile con "Annulla".
  Widget _trattenutaEditRow(int index) {
    final row = _trattenuteEdit[index];
    return Dismissible(
      key: ValueKey(row.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeTrattenuta(index),
      background: const SwipeDeleteBackground(radius: AppRadius.glassSmall),
      child: Builder(
        builder: (context) {
          final labelPrimary =
              CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: CupertinoTextField(
                    controller: row.chiave,
                    placeholder: 'Voce',
                    decoration: const BoxDecoration(),
                    padding: EdgeInsets.zero,
                    style: AppTextStyles.subtitle.copyWith(
                      color: labelPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  // Stesso prefisso "− € " e centratura della corrispondente
                  // riga di sola lettura (`_trattenutaRow`): l'importo
                  // digitato resta sempre positivo, il segno e il simbolo
                  // sono un prefisso fisso, non editabile.
                  child: Center(
                    child: _inlineNumberField(
                      row.importo,
                      prefix: '− € ',
                      style: AppTextStyles.cardAmount
                          .copyWith(fontWeight: FontWeight.w400),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Campo di testo numerico compatto, senza bordo/riempimento proprio (si
/// appoggia sopra il vetro della card ospitante), stile allineato al valore
/// che sostituisce. Riusato da `_StatRow` e tabella Maturazioni.
///
/// Con `prefix` (es. "€ " in `_StatRow` Lordo/Straordinari, "− € " nelle
/// trattenute), il blocco "prefisso + campo" si dimensiona sul proprio
/// contenuto (`IntrinsicWidth`, non una larghezza fissa arbitraria): entrare
/// in modifica non deve introdurre alcun gap visibile tra simbolo e numero
/// rispetto alla vista di sola lettura (che è un unico `Text` con
/// spaziatura naturale). `IntrinsicWidth` qui è sicuro: entrambi gli usi
/// attuali (`_StatRow`, `_trattenutaEditRow`) vivono dentro un `Expanded`/
/// `Center` a larghezza già vincolata, non dentro un `LayoutBuilder` a
/// constraints illimitate (il bug storico documentato altrove nel file
/// riguardava tutt'altro contesto). `rowAlignment` permette di riprodurre
/// esattamente lo stesso allineamento della corrispondente vista di sola
/// lettura — centrato, sia in `_StatRow` sia nella colonna valore di
/// `_trattenutaRow` — l'unica differenza visibile tra vista e modifica deve
/// restare "il testo è ora in un campo tappabile", non lo spostamento del
/// blocco.
Widget _inlineNumberField(
  TextEditingController controller, {
  TextStyle? style,
  String? prefix,
  MainAxisAlignment rowAlignment = MainAxisAlignment.center,
}) {
  return Builder(
    builder: (context) {
      final labelPrimary =
          CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
      final resolvedStyle = (style ?? AppTextStyles.cardAmount).copyWith(
        color: labelPrimary,
        fontWeight: style == null ? FontWeight.w400 : style.fontWeight,
      );
      final field = CupertinoTextField(
        controller: controller,
        placeholder: '0',
        textAlign: TextAlign.center,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: false),
        decoration: const BoxDecoration(),
        padding: EdgeInsets.zero,
        style: resolvedStyle,
      );
      if (prefix == null) return field;
      // `IntrinsicWidth` invece di una larghezza fissa: il campo si
      // dimensiona sul testo digitato, come farebbe il `Text` di sola
      // lettura che sostituisce. Con `mainAxisSize.min` il blocco
      // "prefisso + campo" resta un'unica unità di larghezza nota, sicura
      // da centrare o allineare a destra nella riga ospitante.
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: rowAlignment,
        children: [
          Text(prefix, style: resolvedStyle),
          IntrinsicWidth(child: field),
        ],
      );
    },
  );
}

/// Hero card in cima al dettaglio: mese, badge di stato e netto in massima
/// evidenza. In modalità modifica il netto diventa un campo di testo e il
/// mese è tap-to-edit (apre lo stesso picker periodo del form); il badge di
/// stato resta sempre di sola lettura, non è modificabile direttamente.
class _HeroCard extends StatelessWidget {
  final BustaPaga bustaPaga;
  final String periodoLabel;
  final TipoBustaPaga tipo;
  final bool isEditing;
  final TextEditingController? nettoController;
  final VoidCallback? onTapPeriodo;
  final VoidCallback? onTapTipo;

  const _HeroCard({
    required this.bustaPaga,
    required this.periodoLabel,
    required this.tipo,
    required this.isEditing,
    this.nettoController,
    this.onTapPeriodo,
    this.onTapTipo,
  });

  @override
  Widget build(BuildContext context) {
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);
    final isConfermato =
        bustaPaga.statoVerifica == StatoVerificaBustaPaga.confermato;
    final badgeColor = CupertinoDynamicColor.resolve(
      isConfermato ? AppColors.systemGreen : AppColors.systemRed,
      context,
    );
    final heroAmountStyle =
        AppTextStyles.heroAmount.copyWith(color: labelPrimary);

    return LiquidGlassSurface(
      radius: AppRadius.glass,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: onTapPeriodo == null
                    ? Text(
                        periodoLabel,
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: labelPrimary,
                        ),
                      )
                    : GestureDetector(
                        onTap: onTapPeriodo,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              periodoLabel,
                              style: AppTextStyles.sectionTitle.copyWith(
                                color: labelPrimary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Icon(CupertinoIcons.chevron_down,
                                size: 16, color: labelSecondary),
                          ],
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Text(
                  isConfermato ? 'Confermato' : 'Da confermare',
                  style: AppTextStyles.changeBadge.copyWith(color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          onTapTipo == null
              ? Text(
                  _tipoLabels[tipo]!,
                  style: AppTextStyles.cardLabel.copyWith(
                      color: labelSecondary),
                )
              : GestureDetector(
                  onTap: onTapTipo,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _tipoLabels[tipo]!,
                        style: AppTextStyles.cardLabel.copyWith(
                            color: labelSecondary),
                      ),
                      const SizedBox(width: 4),
                      Icon(CupertinoIcons.chevron_down,
                          size: 12, color: labelSecondary),
                    ],
                  ),
                ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Netto',
            style: AppTextStyles.cardLabel.copyWith(color: labelSecondary),
          ),
          const SizedBox(height: 2),
          if (nettoController == null)
            Text(
              '€ ${formatNumber(bustaPaga.netto)}',
              style: heroAmountStyle,
            )
          else
            Row(
              children: [
                Text('€ ', style: heroAmountStyle),
                Expanded(
                  child: CupertinoTextField(
                    controller: nettoController,
                    placeholder: '0',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: false),
                    decoration: const BoxDecoration(),
                    padding: EdgeInsets.zero,
                    style: heroAmountStyle,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Riga di statistiche compatte (residui, importi): **una sola**
/// `LiquidGlassSurface` con scomparti interni separati da `VerticalDivider`,
/// invece di N `LiquidGlassSurface` affiancate — più `BackdropFilter`
/// ravvicinati (distanza di pochi pixel) producevano un artefatto di
/// rendering visibile come una "cucitura" netta tra una card e l'altra.
/// Stessa filosofia della sidecar in basso (`_BustePagaSidecar` in
/// `buste_paga_section_screen.dart`): un'unica superficie di vetro con
/// scomparti piatti dentro, mai vetro annidato.
///
/// `items` accetta un `Widget` già costruito per il valore (invece di una
/// stringa) per poter mostrare, in modalità modifica, un campo di testo al
/// posto del `Text` statico senza duplicare il layout dei compartimenti.
class _StatRow extends StatelessWidget {
  final List<(String label, Widget value)> items;

  const _StatRow({required this.items});

  @override
  Widget build(BuildContext context) {
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final separator =
        CupertinoDynamicColor.resolve(AppColors.separator, context);

    return LiquidGlassSurface(
      radius: AppRadius.glass,
      blurSigma: 22,
      elevation: 4,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Container(
                  width: 0.5,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  color: separator,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      items[i].$1,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitle.copyWith(
                        color: labelPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    DefaultTextStyle.merge(
                      style: AppTextStyles.cardAmount.copyWith(
                        color: labelPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                      child: items[i].$2,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Riga compatta e tappabile per il PDF di origine: apre il foglio di
/// condivisione di sistema. Sempre di sola lettura, in vista e in modifica:
/// nessuna azione di allega/rimuovi.
class _DocumentoChip extends StatelessWidget {
  final String filePath;

  const _DocumentoChip({required this.filePath});

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoDynamicColor.resolve(AppColors.systemBlue, context);
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);

    return SpringButton(
      onPressed: () => Share.shareXFiles([XFile(filePath)]),
      child: LiquidGlassSurface(
        radius: AppRadius.glassSmall,
        blurSigma: 22,
        elevation: 4,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.doc_text, size: 20, color: accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                p.basename(filePath),
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.subtitle.copyWith(color: labelPrimary),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Condividi',
              style: AppTextStyles.cardLabel.copyWith(color: labelSecondary),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(CupertinoIcons.square_arrow_up, size: 16, color: accent),
          ],
        ),
      ),
    );
  }
}

/// Tabella unica Ferie/ROL/Permessi con colonne Maturato/Goduto/Residuo:
/// sostituisce le 3 sezioni separate precedenti, che ripetevano la stessa
/// struttura a righe per ciascuna categoria. In modifica le celle Ferie/ROL
/// diventano campi di testo numerici; nella riga Permessi solo "Goduto" è
/// editabile (Maturato/Residuo non esistono come campi nel modello per i
/// permessi, restano "—" fissi anche in modifica).
class _MaturazioniSection extends StatelessWidget {
  final BustaPaga bustaPaga;
  final bool isEditing;
  final TextEditingController? ferieMaturateCtrl;
  final TextEditingController? ferieGoduteCtrl;
  final TextEditingController? ferieResidueCtrl;
  final TextEditingController? rolMaturatiCtrl;
  final TextEditingController? rolGodutiCtrl;
  final TextEditingController? rolResiduiCtrl;
  final TextEditingController? permessiGodutiCtrl;

  const _MaturazioniSection({
    required this.bustaPaga,
    required this.isEditing,
    this.ferieMaturateCtrl,
    this.ferieGoduteCtrl,
    this.ferieResidueCtrl,
    this.rolMaturatiCtrl,
    this.rolGodutiCtrl,
    this.rolResiduiCtrl,
    this.permessiGodutiCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);
    return GlassFormSection(
      children: [
        _tableHeaderRow(labelSecondary),
        _tableDataRow(
          context,
          label: 'Ferie',
          maturato: formatNumber(bustaPaga.ferieMaturate),
          goduto: formatNumber(bustaPaga.ferieGodute),
          residuo: formatNumber(bustaPaga.ferieResidue),
          maturatoCtrl: ferieMaturateCtrl,
          godutoCtrl: ferieGoduteCtrl,
          residuoCtrl: ferieResidueCtrl,
        ),
        _tableDataRow(
          context,
          label: 'ROL',
          maturato: formatNumber(bustaPaga.rolMaturati),
          goduto: formatNumber(bustaPaga.rolGoduti),
          residuo: formatNumber(bustaPaga.rolResidui),
          maturatoCtrl: rolMaturatiCtrl,
          godutoCtrl: rolGodutiCtrl,
          residuoCtrl: rolResiduiCtrl,
        ),
        _tableDataRow(
          context,
          label: 'Permessi',
          maturato: '—',
          goduto: formatNumber(bustaPaga.permessiGoduti),
          residuo: '—',
          godutoCtrl: permessiGodutiCtrl,
        ),
      ],
    );
  }

  Widget _tableHeaderRow(Color labelSecondary) {
    final style = AppTextStyles.cardLabel.copyWith(color: labelSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Expanded(flex: 3, child: SizedBox.shrink()),
          Expanded(
            flex: 2,
            child: Text(
              'Maturato',
              style: style,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Goduto',
              style: style,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Residuo',
              style: style,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableDataRow(
    BuildContext context, {
    required String label,
    required String maturato,
    required String goduto,
    required String residuo,
    TextEditingController? maturatoCtrl,
    TextEditingController? godutoCtrl,
    TextEditingController? residuoCtrl,
  }) {
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final valueStyle = AppTextStyles.cardAmount.copyWith(
      color: labelPrimary,
      fontWeight: FontWeight.w400,
    );

    Widget cell(String value, TextEditingController? controller) {
      if (isEditing && controller != null) {
        return _inlineNumberField(controller, style: valueStyle);
      }
      return Text(value, style: valueStyle, textAlign: TextAlign.center);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: AppTextStyles.subtitle.copyWith(
                color: labelPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(flex: 2, child: cell(maturato, maturatoCtrl)),
          Expanded(flex: 2, child: cell(goduto, godutoCtrl)),
          Expanded(flex: 2, child: cell(residuo, residuoCtrl)),
        ],
      ),
    );
  }
}

/// Barra flottante in basso: chip piatti senza superficie di vetro attorno
/// (nessun "pill" bianco dietro), stesso trattamento del "+" nella sidecar
/// (`_BustePagaSidecar`). Tre stati:
/// - non in modifica + "Da confermare": Conferma (verde, 70%) + Modifica
///   (blu, 30%);
/// - non in modifica + "Confermato": solo Modifica (blu, intera larghezza);
/// - in modifica: Salva (blu, 50%) + Annulla (grigio, 50%).
class _ActionBar extends StatelessWidget {
  final BustaPaga bustaPaga;
  final bool isEditing;
  final VoidCallback onConferma;
  final VoidCallback onModifica;
  final VoidCallback onSalva;
  final VoidCallback onAnnulla;

  const _ActionBar({
    required this.bustaPaga,
    required this.isEditing,
    required this.onConferma,
    required this.onModifica,
    required this.onSalva,
    required this.onAnnulla,
  });

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoDynamicColor.resolve(AppColors.systemBlue, context);
    final greenAccent =
        CupertinoDynamicColor.resolve(AppColors.systemGreen, context);
    final secondaryAccent =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);

    if (isEditing) {
      return Row(
        children: [
          Expanded(
            child: FlatChipButton(
              icon: CupertinoIcons.checkmark_alt,
              label: 'Salva',
              color: accent,
              onPressed: onSalva,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: FlatChipButton(
              icon: CupertinoIcons.xmark,
              label: 'Annulla',
              color: secondaryAccent,
              onPressed: onAnnulla,
            ),
          ),
        ],
      );
    }

    final daConfermare =
        bustaPaga.statoVerifica == StatoVerificaBustaPaga.daConfermare;

    return Row(
      children: [
        if (daConfermare) ...[
          Expanded(
            flex: 7,
            child: FlatChipButton(
              icon: CupertinoIcons.checkmark_alt,
              label: 'Conferma',
              color: greenAccent,
              onPressed: onConferma,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: FlatChipButton(
              icon: CupertinoIcons.pencil,
              label: 'Modifica',
              color: accent,
              onPressed: onModifica,
            ),
          ),
        ] else
          Expanded(
            child: FlatChipButton(
              icon: CupertinoIcons.pencil,
              label: 'Modifica',
              color: accent,
              onPressed: onModifica,
            ),
          ),
      ],
    );
  }
}
