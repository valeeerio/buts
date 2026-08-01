import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'glass_form_section.dart';
import 'trattenuta_edit_row.dart';

/// Tabella unica Ferie/ROL/Permessi con colonne Maturato/Goduto/Residuo:
/// sostituisce sezioni separate che ripetono la stessa struttura a righe per
/// ciascuna categoria. In modifica le celle Ferie/ROL diventano campi di
/// testo numerici; nella riga Permessi solo "Goduto" è editabile
/// (Maturato/Residuo non esistono come campi nel modello per i permessi,
/// restano "—" fissi anche in modifica).
class BustaPagaMaturazioniSection extends StatelessWidget {
  final bool isEditing;

  final String ferieMaturate;
  final String ferieGodute;
  final String ferieResidue;
  final String rolMaturati;
  final String rolGoduti;
  final String rolResidui;
  final String permessiGoduti;

  final TextEditingController? ferieMaturateCtrl;
  final TextEditingController? ferieGoduteCtrl;
  final TextEditingController? ferieResidueCtrl;
  final TextEditingController? rolMaturatiCtrl;
  final TextEditingController? rolGodutiCtrl;
  final TextEditingController? rolResiduiCtrl;
  final TextEditingController? permessiGodutiCtrl;

  const BustaPagaMaturazioniSection({
    super.key,
    required this.isEditing,
    required this.ferieMaturate,
    required this.ferieGodute,
    required this.ferieResidue,
    required this.rolMaturati,
    required this.rolGoduti,
    required this.rolResidui,
    required this.permessiGoduti,
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
          maturato: ferieMaturate,
          goduto: ferieGodute,
          residuo: ferieResidue,
          maturatoCtrl: ferieMaturateCtrl,
          godutoCtrl: ferieGoduteCtrl,
          residuoCtrl: ferieResidueCtrl,
        ),
        _tableDataRow(
          context,
          label: 'ROL',
          maturato: rolMaturati,
          goduto: rolGoduti,
          residuo: rolResidui,
          maturatoCtrl: rolMaturatiCtrl,
          godutoCtrl: rolGodutiCtrl,
          residuoCtrl: rolResiduiCtrl,
        ),
        _tableDataRow(
          context,
          label: 'Permessi',
          maturato: '—',
          goduto: permessiGoduti,
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
