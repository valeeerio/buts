import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../../models/busta_paga.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'busta_paga_form_screen.dart';

/// Vista di sola lettura di tutti i campi di una busta paga, con lo stesso
/// raggruppamento a sezioni del form. Il pulsante "Modifica" nella
/// navigation bar apre `BustaPagaFormScreen` precompilato.
class BustaPagaDetailScreen extends StatelessWidget {
  final BustaPaga bustaPaga;

  const BustaPagaDetailScreen({super.key, required this.bustaPaga});

  String get _periodoLabel {
    final formatted = DateFormat('MMMM yyyy', 'it_IT').format(bustaPaga.periodo);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoDynamicColor.resolve(AppColors.backgroundPrimary, context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(_periodoLabel),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => BustaPagaFormScreen(existing: bustaPaga),
              ),
            );
          },
          child: const Text('Modifica'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            CupertinoFormSection.insetGrouped(
              header: const Text('Periodo'),
              children: [
                _readOnlyRow('Mese', _periodoLabel),
                _readOnlyRow(
                  'Stato verifica',
                  bustaPaga.statoVerifica == StatoVerificaBustaPaga.confermato
                      ? 'Confermato'
                      : 'Da confermare',
                ),
              ],
            ),
            if (bustaPaga.fileOrigine != null)
              CupertinoFormSection.insetGrouped(
                header: const Text('Documento'),
                children: [_documentoRow(context, bustaPaga.fileOrigine!)],
              ),
            CupertinoFormSection.insetGrouped(
              header: const Text('Importi'),
              children: [
                _readOnlyRow('Lordo', '€ ${_formatNumber(bustaPaga.lordo)}'),
                _readOnlyRow('Netto', '€ ${_formatNumber(bustaPaga.netto)}'),
                _readOnlyRow('Straordinari',
                    '€ ${_formatNumber(bustaPaga.straordinari)}'),
              ],
            ),
            CupertinoFormSection.insetGrouped(
              header: const Text('Ferie'),
              children: [
                _readOnlyRow('Maturate', _formatNumber(bustaPaga.ferieMaturate)),
                _readOnlyRow('Godute', _formatNumber(bustaPaga.ferieGodute)),
                _readOnlyRow('Residue', _formatNumber(bustaPaga.ferieResidue)),
              ],
            ),
            CupertinoFormSection.insetGrouped(
              header: const Text('ROL'),
              children: [
                _readOnlyRow('Maturati', _formatNumber(bustaPaga.rolMaturati)),
                _readOnlyRow('Goduti', _formatNumber(bustaPaga.rolGoduti)),
                _readOnlyRow('Residui', _formatNumber(bustaPaga.rolResidui)),
              ],
            ),
            CupertinoFormSection.insetGrouped(
              header: const Text('Permessi e ore'),
              children: [
                _readOnlyRow(
                    'Permessi goduti', _formatNumber(bustaPaga.permessiGoduti)),
                _readOnlyRow(
                    'Ore lavorate', _formatNumber(bustaPaga.oreLavorate)),
              ],
            ),
            CupertinoFormSection.insetGrouped(
              header: const Text('Trattenute'),
              children: bustaPaga.trattenute.isEmpty
                  ? [_readOnlyRow('Nessuna trattenuta', '—')]
                  : bustaPaga.trattenute.entries
                      .map((e) =>
                          _readOnlyRow(e.key, '€ ${_formatNumber(e.value)}'))
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _documentoRow(BuildContext context, String filePath) {
    final accent = CupertinoDynamicColor.resolve(AppColors.bustePaga, context);
    return CupertinoFormRow(
      prefix: const Text('PDF'),
      child: GestureDetector(
        onTap: () => Share.shareXFiles([XFile(filePath)]),
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                p.basename(filePath),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: CupertinoDynamicColor.resolve(
                      AppColors.labelSecondary, context),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(CupertinoIcons.square_arrow_up, size: 16, color: accent),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyRow(String label, String value) {
    return CupertinoFormRow(
      prefix: Text(label),
      child: Builder(
        builder: (context) => Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            color: CupertinoDynamicColor.resolve(
                AppColors.labelPrimary, context),
          ),
        ),
      ),
    );
  }
}
