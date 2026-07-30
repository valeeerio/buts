import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../../models/busta_paga.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/busta_paga_formatting.dart';
import '../../widgets/glass_form_section.dart';
import '../../widgets/liquid_glass_surface.dart';
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.xl,
          ),
          children: [
            _HeroCard(bustaPaga: bustaPaga, periodoLabel: _periodoLabel),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _MiniCard(
                    label: 'ROL residui',
                    value: formatNumber(bustaPaga.rolResidui),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _MiniCard(
                    label: 'Ore a disposizione',
                    value: formatNumber(bustaPaga.oreLavorate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassFormSection(
              header: 'Periodo',
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
              GlassFormSection(
                header: 'Documento',
                children: [_documentoRow(context, bustaPaga.fileOrigine!)],
              ),
            GlassFormSection(
              header: 'Importi',
              children: [
                _readOnlyRow('Lordo', '€ ${formatNumber(bustaPaga.lordo)}'),
                _readOnlyRow('Straordinari',
                    '€ ${formatNumber(bustaPaga.straordinari)}'),
              ],
            ),
            GlassFormSection(
              header: 'Ferie',
              children: [
                _readOnlyRow('Maturate', formatNumber(bustaPaga.ferieMaturate)),
                _readOnlyRow('Godute', formatNumber(bustaPaga.ferieGodute)),
                _readOnlyRow('Residue', formatNumber(bustaPaga.ferieResidue)),
              ],
            ),
            GlassFormSection(
              header: 'ROL',
              children: [
                _readOnlyRow('Maturati', formatNumber(bustaPaga.rolMaturati)),
                _readOnlyRow('Goduti', formatNumber(bustaPaga.rolGoduti)),
                _readOnlyRow('Residui', formatNumber(bustaPaga.rolResidui)),
              ],
            ),
            GlassFormSection(
              header: 'Permessi e ore',
              children: [
                _readOnlyRow(
                    'Permessi goduti', formatNumber(bustaPaga.permessiGoduti)),
                _readOnlyRow(
                    'Ore lavorate', formatNumber(bustaPaga.oreLavorate)),
              ],
            ),
            GlassFormSection(
              header: 'Trattenute',
              children: bustaPaga.trattenute.isEmpty
                  ? [_readOnlyRow('Nessuna trattenuta', '—')]
                  : bustaPaga.trattenute.entries
                      .map((e) =>
                          _readOnlyRow(e.key, '€ ${formatNumber(e.value)}'))
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _documentoRow(BuildContext context, String filePath) {
    final accent = CupertinoDynamicColor.resolve(AppColors.systemBlue, context);
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

/// Hero card in cima al dettaglio: mese, badge di stato e netto in massima
/// evidenza — colpo d'occhio prima delle sezioni di dettaglio sotto.
class _HeroCard extends StatelessWidget {
  final BustaPaga bustaPaga;
  final String periodoLabel;

  const _HeroCard({required this.bustaPaga, required this.periodoLabel});

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoDynamicColor.resolve(AppColors.bustePaga, context);
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);
    final isConfermato =
        bustaPaga.statoVerifica == StatoVerificaBustaPaga.confermato;
    final badgeColor = CupertinoDynamicColor.resolve(
      isConfermato ? AppColors.systemGreen : AppColors.systemOrange,
      context,
    );

    return LiquidGlassSurface(
      radius: AppRadius.glass,
      tint: accent,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  periodoLabel,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: labelPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
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
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Netto',
            style: AppTextStyles.cardLabel.copyWith(color: labelSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            '€ ${formatNumber(bustaPaga.netto)}',
            style: AppTextStyles.cardAmountLarge.copyWith(
              fontSize: 34,
              color: labelPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini-card di sintesi (ROL residui, ore a disposizione) sotto la hero.
class _MiniCard extends StatelessWidget {
  final String label;
  final String value;

  const _MiniCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);

    return LiquidGlassSurface(
      radius: AppRadius.glassSmall,
      blurSigma: 22,
      elevation: 4,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.cardLabel.copyWith(color: labelSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.cardAmount.copyWith(color: labelPrimary),
          ),
        ],
      ),
    );
  }
}
