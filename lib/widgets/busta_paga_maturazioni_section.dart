import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'glass_form_section.dart';
import 'trattenuta_edit_row.dart';

/// Tabella unica Ferie/Permessi/Ex festività con colonne
/// Maturato/Goduto/Residuo: sostituisce sezioni separate che ripetono la
/// stessa struttura a righe per ciascuna categoria. In modifica tutte le
/// celle diventano campi di testo numerici.
///
/// Ordine righe allineato all'intestazione della tabella ratei nel PDF
/// (FERIE / PERMESSI (R.O.L.) / EX FESTIVITA'): "Permessi" qui rappresenta
/// i ROL (rolMaturati/rolGoduti/rolResidui, rinominati da "ROL" per
/// coerenza con l'etichetta del PDF).
class BustaPagaMaturazioniSection extends StatelessWidget {
  final bool isEditing;

  final String ferieMaturate;
  final String ferieGodute;
  final String ferieResidue;
  final String rolMaturati;
  final String rolGoduti;
  final String rolResidui;
  final String exFestivitaMaturate;
  final String exFestivitaGodute;
  final String exFestivitaResidue;

  final TextEditingController? ferieMaturateCtrl;
  final TextEditingController? ferieGoduteCtrl;
  final TextEditingController? ferieResidueCtrl;
  final TextEditingController? rolMaturatiCtrl;
  final TextEditingController? rolGodutiCtrl;
  final TextEditingController? rolResiduiCtrl;
  final TextEditingController? exFestivitaMaturateCtrl;
  final TextEditingController? exFestivitaGoduteCtrl;
  final TextEditingController? exFestivitaResidueCtrl;

  const BustaPagaMaturazioniSection({
    super.key,
    required this.isEditing,
    required this.ferieMaturate,
    required this.ferieGodute,
    required this.ferieResidue,
    required this.rolMaturati,
    required this.rolGoduti,
    required this.rolResidui,
    required this.exFestivitaMaturate,
    required this.exFestivitaGodute,
    required this.exFestivitaResidue,
    this.ferieMaturateCtrl,
    this.ferieGoduteCtrl,
    this.ferieResidueCtrl,
    this.rolMaturatiCtrl,
    this.rolGodutiCtrl,
    this.rolResiduiCtrl,
    this.exFestivitaMaturateCtrl,
    this.exFestivitaGoduteCtrl,
    this.exFestivitaResidueCtrl,
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
          maturato: ferieMaturate,
          goduto: ferieGodute,
          residuo: ferieResidue,
          maturatoCtrl: ferieMaturateCtrl,
          godutoCtrl: ferieGoduteCtrl,
          residuoCtrl: ferieResidueCtrl,
        ),
        _tableDataRow(
          context,
          label: 'Permessi',
          maturato: rolMaturati,
          goduto: rolGoduti,
          residuo: rolResidui,
          maturatoCtrl: rolMaturatiCtrl,
          godutoCtrl: rolGodutiCtrl,
          residuoCtrl: rolResiduiCtrl,
        ),
        _tableDataRow(
          context,
          label: 'Ex festività',
          maturato: exFestivitaMaturate,
          goduto: exFestivitaGodute,
          residuo: exFestivitaResidue,
          maturatoCtrl: exFestivitaMaturateCtrl,
          godutoCtrl: exFestivitaGoduteCtrl,
          residuoCtrl: exFestivitaResidueCtrl,
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
        return inlineNumberField(controller, style: valueStyle);
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
