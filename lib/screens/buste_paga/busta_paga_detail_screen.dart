import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/busta_paga.dart';
import '../../providers/buste_paga_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/busta_paga_formatting.dart';
import '../../widgets/app_alert_dialog.dart';
import '../../widgets/busta_paga_competenze_section.dart';
import '../../widgets/busta_paga_documento_chip.dart';
import '../../widgets/busta_paga_hero_card.dart';
import '../../widgets/busta_paga_maturazioni_section.dart';
import '../../widgets/busta_paga_stat_row.dart';
import '../../widgets/flat_chip_button.dart';
import '../../widgets/glass_form_section.dart';
import '../../widgets/trattenuta_edit_row.dart';
import '../../widgets/voce_competenza_edit_row.dart';

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
  late TextEditingController _oreLavorateCtrl;

  late TextEditingController _ferieMaturateCtrl;
  late TextEditingController _ferieGoduteCtrl;
  late TextEditingController _ferieResidueCtrl;

  late TextEditingController _rolMaturatiCtrl;
  late TextEditingController _rolGodutiCtrl;
  late TextEditingController _rolResiduiCtrl;

  late TextEditingController _permessiGodutiCtrl;
  late TextEditingController _permessiGodutiMeseCtrl;

  late TextEditingController _exFestivitaMaturateCtrl;
  late TextEditingController _exFestivitaGoduteCtrl;
  late TextEditingController _exFestivitaResidueCtrl;

  late List<TrattenutaEditRow> _trattenuteEdit;
  late List<VoceCompetenzaEditRow> _competenzeEdit;

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
    _permessiGodutiMeseCtrl =
        TextEditingController(text: formatNumber(corrente.permessiGodutiMese));

    _exFestivitaMaturateCtrl = TextEditingController(
        text: formatNumber(corrente.exFestivitaMaturate));
    _exFestivitaGoduteCtrl = TextEditingController(
        text: formatNumber(corrente.exFestivitaGodute));
    _exFestivitaResidueCtrl = TextEditingController(
        text: formatNumber(corrente.exFestivitaResidue));

    _trattenuteEdit = corrente.trattenute.isEmpty
        ? [TrattenutaEditRow()]
        : corrente.trattenute.entries
            .map((e) => TrattenutaEditRow(
                chiave: e.key, importo: formatNumber(e.value)))
            .toList();

    _competenzeEdit = corrente.competenze.isEmpty
        ? [VoceCompetenzaEditRow()]
        : corrente.competenze
            .map((v) => VoceCompetenzaEditRow(
                  descrizione: v.descrizione,
                  quantita: formatNumber(v.quantita),
                  importo: v.importo == 0 ? '' : formatNumber(v.importo),
                ))
            .toList();
    for (final row in _competenzeEdit) {
      _attachCompetenzaListeners(row);
    }

    // Forza il rebuild dello `_StatRow` (Ferie/ROL residui) ogni volta che
    // cambia il campo "Residuo" corrispondente nella tabella sottostante.
    _ferieResidueCtrl.addListener(_onResiduiChanged);
    _rolResiduiCtrl.addListener(_onResiduiChanged);
    _exFestivitaResidueCtrl.addListener(_onResiduiChanged);

    setState(() => _isEditing = true);
  }

  /// Rebuild forzato ogni volta che descrizione/quantità/importo di una voce
  /// di competenza cambiano, così le celle Lordo/Straordinari (calcolate
  /// dalla lista competenze, sola lettura anche in editing) restano
  /// sincronizzate live — stesso meccanismo di `_onResiduiChanged`.
  void _attachCompetenzaListeners(VoceCompetenzaEditRow row) {
    row.descrizione.addListener(_onResiduiChanged);
    row.quantita.addListener(_onResiduiChanged);
    row.importo.addListener(_onResiduiChanged);
  }

  List<VoceCompetenza> get _competenzeCorrenti => _competenzeEdit
      .where((row) => row.descrizione.text.trim().isNotEmpty)
      .map((row) => VoceCompetenza(
            descrizione: row.descrizione.text.trim(),
            quantita: row.quantitaValue,
            importo: row.importoValue,
          ))
      .toList();

  void _onResiduiChanged() => setState(() {});

  void _disposeEditingControllers() {
    _nettoCtrl.dispose();
    _oreLavorateCtrl.dispose();
    _ferieMaturateCtrl.dispose();
    _ferieGoduteCtrl.dispose();
    _ferieResidueCtrl.dispose();
    _rolMaturatiCtrl.dispose();
    _rolGodutiCtrl.dispose();
    _rolResiduiCtrl.dispose();
    _permessiGodutiCtrl.dispose();
    _permessiGodutiMeseCtrl.dispose();
    _exFestivitaMaturateCtrl.dispose();
    _exFestivitaGoduteCtrl.dispose();
    _exFestivitaResidueCtrl.dispose();
    for (final row in _trattenuteEdit) {
      row.dispose();
    }
    for (final row in _competenzeEdit) {
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
    setState(() => _trattenuteEdit.add(TrattenutaEditRow()));
  }

  void _removeTrattenuta(int index) {
    setState(() {
      _trattenuteEdit[index].dispose();
      _trattenuteEdit.removeAt(index);
    });
  }

  void _addCompetenza() {
    setState(() {
      final row = VoceCompetenzaEditRow();
      _attachCompetenzaListeners(row);
      _competenzeEdit.add(row);
    });
  }

  void _removeCompetenza(int index) {
    setState(() {
      _competenzeEdit[index].dispose();
      _competenzeEdit.removeAt(index);
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
          icon: CupertinoIcons.checkmark_alt,
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

    // Lordo/straordinari sono derivati dalla lista competenze correntemente
    // in editing (vedi computeLordo/computeStraordinari). Se la lista è
    // vuota (busta paga pre-migrazione mai riaperta in modifica, o utente
    // che rimuove tutte le righe) si mantiene il valore precedente invece
    // di azzerarlo — vedi CLAUDE.md/istruzioni task.
    final competenze = _competenzeCorrenti;
    final lordo =
        competenze.isEmpty ? corrente.lordo : computeLordo(competenze);
    final straordinari = competenze.isEmpty
        ? corrente.straordinari
        : computeStraordinari(competenze);

    final candidato = corrente.copyWith(
      periodo: _periodoEdit,
      tipo: _tipoEdit,
      netto: _parse(_nettoCtrl),
      lordo: lordo,
      straordinari: straordinari,
      oreLavorate: _parse(_oreLavorateCtrl),
      ferieMaturate: _parse(_ferieMaturateCtrl),
      ferieGodute: _parse(_ferieGoduteCtrl),
      ferieResidue: _parse(_ferieResidueCtrl),
      rolMaturati: _parse(_rolMaturatiCtrl),
      rolGoduti: _parse(_rolGodutiCtrl),
      rolResidui: _parse(_rolResiduiCtrl),
      permessiGoduti: _parse(_permessiGodutiCtrl),
      permessiGodutiMese: _parse(_permessiGodutiMeseCtrl),
      exFestivitaMaturate: _parse(_exFestivitaMaturateCtrl),
      exFestivitaGodute: _parse(_exFestivitaGoduteCtrl),
      exFestivitaResidue: _parse(_exFestivitaResidueCtrl),
      competenze: competenze,
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
          icon: CupertinoIcons.xmark,
          label: 'Annulla',
          color: labelSecondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppAlertAction(
          icon: CupertinoIcons.checkmark_alt,
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
    addIfChanged('Permessi (mese)', vecchia.permessiGodutiMese,
        nuova.permessiGodutiMese);
    addIfChanged('Ex festività maturate', vecchia.exFestivitaMaturate,
        nuova.exFestivitaMaturate);
    addIfChanged('Ex festività godute', vecchia.exFestivitaGodute,
        nuova.exFestivitaGodute);
    addIfChanged('Ex festività residue', vecchia.exFestivitaResidue,
        nuova.exFestivitaResidue);
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

    // Stesso pattern del diff trattenute, chiave sulla descrizione (unica per
    // voce nell'uso reale di questo layout busta paga).
    final vecchieCompetenze = {
      for (final v in vecchia.competenze) v.descrizione: v
    };
    final nuoveCompetenze = {
      for (final v in nuova.competenze) v.descrizione: v
    };
    final descrizioniCompetenze = {
      ...vecchieCompetenze.keys,
      ...nuoveCompetenze.keys
    };
    for (final descrizione in descrizioniCompetenze) {
      final prima = vecchieCompetenze[descrizione];
      final dopo = nuoveCompetenze[descrizione];
      if (prima == null && dopo != null) {
        diff.add('Competenza $descrizione: aggiunta '
            '(${formatNumber(dopo.quantita)}, € ${formatNumber(dopo.importo)})');
      } else if (prima != null && dopo == null) {
        diff.add('Competenza $descrizione: rimossa '
            '(era ${formatNumber(prima.quantita)}, € ${formatNumber(prima.importo)})');
      } else if (prima != null &&
          dopo != null &&
          (formatNumber(prima.quantita) != formatNumber(dopo.quantita) ||
              formatNumber(prima.importo) != formatNumber(dopo.importo))) {
        diff.add(
          'Competenza $descrizione: ${formatNumber(prima.quantita)}, '
          '€ ${formatNumber(prima.importo)} → ${formatNumber(dopo.quantita)}, '
          '€ ${formatNumber(dopo.importo)}',
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
      navigationBar: const CupertinoNavigationBar(),
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
                  child: BustaPagaHeroCard(
                    isConfermato: corrente.statoVerifica ==
                        StatoVerificaBustaPaga.confermato,
                    periodoLabel: periodoLabelVista,
                    tipo: _isEditing ? _tipoEdit : corrente.tipo,
                    isEditing: _isEditing,
                    lordoDisplay: formatNumber(_isEditing
                        ? computeLordo(_competenzeCorrenti)
                        : corrente.lordo),
                    nettoDisplay: formatNumber(corrente.netto),
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
                          BustaPagaStatRow(items: [
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
                              'Permessi residui',
                              Text(
                                _isEditing
                                    ? formatNumber(_parse(_rolResiduiCtrl))
                                    : formatNumber(corrente.rolResidui),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            (
                              'Ex festività',
                              Text(
                                _isEditing
                                    ? formatNumber(
                                        _parse(_exFestivitaResidueCtrl))
                                    : formatNumber(corrente.exFestivitaResidue),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ]),
                          const SizedBox(height: AppSpacing.lg),
                          if (corrente.fileOrigine != null) ...[
                            BustaPagaDocumentoChip(
                              filePath: corrente.fileOrigine!,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          BustaPagaMaturazioniSection(
                            isEditing: _isEditing,
                            ferieMaturate: formatNumber(corrente.ferieMaturate),
                            ferieGodute: formatNumber(corrente.ferieGodute),
                            ferieResidue: formatNumber(corrente.ferieResidue),
                            rolMaturati: formatNumber(corrente.rolMaturati),
                            rolGoduti: formatNumber(corrente.rolGoduti),
                            rolResidui: formatNumber(corrente.rolResidui),
                            permessiGoduti:
                                formatNumber(corrente.permessiGoduti),
                            exFestivitaMaturate:
                                formatNumber(corrente.exFestivitaMaturate),
                            exFestivitaGodute:
                                formatNumber(corrente.exFestivitaGodute),
                            exFestivitaResidue:
                                formatNumber(corrente.exFestivitaResidue),
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
                            exFestivitaMaturateCtrl:
                                _isEditing ? _exFestivitaMaturateCtrl : null,
                            exFestivitaGoduteCtrl:
                                _isEditing ? _exFestivitaGoduteCtrl : null,
                            exFestivitaResidueCtrl:
                                _isEditing ? _exFestivitaResidueCtrl : null,
                          ),
                          BustaPagaStatRow(items: [
                            (
                              'Ore lavorate',
                              _isEditing
                                  ? inlineNumberField(_oreLavorateCtrl)
                                  : Text(formatNumber(corrente.oreLavorate),
                                      textAlign: TextAlign.center),
                            ),
                            (
                              'Straordinari',
                              Text(
                                '${formatNumber(_isEditing ? computeStraordinari(_competenzeCorrenti) : corrente.straordinari)} h',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            (
                              'Permessi (mese)',
                              _isEditing
                                  ? inlineNumberField(_permessiGodutiMeseCtrl,
                                      suffix: ' h')
                                  : Text(
                                      '${formatNumber(corrente.permessiGodutiMese)} h',
                                      textAlign: TextAlign.center),
                            ),
                          ]),
                          const SizedBox(height: AppSpacing.lg),
                          BustaPagaCompetenzeSection(
                            isEditing: _isEditing,
                            competenze: corrente.competenze,
                            righeEdit: _isEditing ? _competenzeEdit : null,
                            onAggiungi: _isEditing ? _addCompetenza : null,
                            onRimuovi: _isEditing ? _removeCompetenza : null,
                          ),
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
                                      trattenutaEditRow(
                                        _trattenuteEdit[i],
                                        onDismissed: () =>
                                            _removeTrattenuta(i),
                                      ),
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
                          icon: CupertinoIcons.checkmark_alt,
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
