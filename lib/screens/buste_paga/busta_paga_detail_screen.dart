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
import '../../widgets/flat_chip_button.dart';
import '../../widgets/glass_form_section.dart';
import '../../widgets/liquid_glass_surface.dart';
import '../../widgets/spring_button.dart';
import 'busta_paga_form_screen.dart';

/// Altezza approssimativa riservata alla barra flottante "Conferma/Modifica"
/// in basso (barra + margini), da sottrarre al contenuto scrollabile
/// sottostante perché non finisca nascosto dietro di essa — stessa logica
/// di `_sidecarReservedHeight` in `buste_paga_section_screen.dart`.
const double _actionBarReservedHeight = 88;

/// Vista di sola lettura di una busta paga: hero con i dati principali,
/// tabella riepilogativa di Ferie/ROL/Permessi e sezioni di dettaglio per
/// documento, importi e trattenute. La barra flottante in basso permette di
/// confermare lo stato o aprire `BustaPagaFormScreen` precompilato.
///
/// `ConsumerWidget` invece di `StatelessWidget`: `bustaPaga` arriva per
/// valore da chi apre il dettaglio, ma va sempre riletta dal provider
/// (`corrente`) così la UI si aggiorna subito dopo "Conferma" o al ritorno
/// da "Modifica", senza mostrare dati non più aggiornati.
class BustaPagaDetailScreen extends ConsumerWidget {
  final BustaPaga bustaPaga;

  const BustaPagaDetailScreen({super.key, required this.bustaPaga});

  String _periodoLabel(BustaPaga busta) {
    final formatted = DateFormat('MMMM yyyy', 'it_IT').format(busta.periodo);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buste = ref.watch(busteRepositoryProvider);
    final corrente =
        buste.firstWhere((b) => b.id == bustaPaga.id, orElse: () => bustaPaga);
    final periodoLabel = _periodoLabel(corrente);

    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoDynamicColor.resolve(AppColors.backgroundPrimary, context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(periodoLabel),
      ),
      child: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.sm,
                AppSpacing.screenHorizontal,
                AppSpacing.xl + _actionBarReservedHeight,
              ),
              children: [
                _HeroCard(bustaPaga: corrente, periodoLabel: periodoLabel),
                const SizedBox(height: AppSpacing.lg),
                _StatRow(items: [
                  ('Ferie residue', formatNumber(corrente.ferieResidue)),
                  ('ROL residui', formatNumber(corrente.rolResidui)),
                  ('Ore lavorate', formatNumber(corrente.oreLavorate)),
                ]),
                const SizedBox(height: AppSpacing.lg),
                if (corrente.fileOrigine != null) ...[
                  _DocumentoChip(filePath: corrente.fileOrigine!),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _MaturazioniSection(bustaPaga: corrente),
                _StatRow(items: [
                  ('Lordo', '€ ${formatNumber(corrente.lordo)}'),
                  ('Straordinari', '€ ${formatNumber(corrente.straordinari)}'),
                ]),
                const SizedBox(height: AppSpacing.lg),
                GlassFormSection(
                  children: corrente.trattenute.isEmpty
                      ? [_trattenutaRow('Nessuna trattenuta', '—')]
                      : corrente.trattenute.entries
                          .map((e) => _trattenutaRow(
                              e.key, '− € ${formatNumber(e.value)}'))
                          .toList(),
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
                child: _ConfermaModificaBar(
                  bustaPaga: corrente,
                  onConferma: () => ref
                      .read(busteRepositoryProvider.notifier)
                      .update(corrente.copyWith(
                        statoVerifica: StatoVerificaBustaPaga.confermato,
                      )),
                  onModifica: () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => BustaPagaFormScreen(existing: corrente),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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

/// Hero card in cima al dettaglio: mese, badge di stato e netto in massima
/// evidenza — colpo d'occhio prima delle sezioni di dettaglio sotto.
class _HeroCard extends StatelessWidget {
  final BustaPaga bustaPaga;
  final String periodoLabel;

  const _HeroCard({required this.bustaPaga, required this.periodoLabel});

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

    return LiquidGlassSurface(
      radius: AppRadius.glass,
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

/// Riga di statistiche compatte (residui, importi): **una sola**
/// `LiquidGlassSurface` con scomparti interni separati da `VerticalDivider`,
/// invece di N `LiquidGlassSurface` affiancate — più `BackdropFilter`
/// ravvicinati (distanza di pochi pixel) producevano un artefatto di
/// rendering visibile come una "cucitura" netta tra una card e l'altra.
/// Stessa filosofia della sidecar in basso (`_BustePagaSidecar` in
/// `buste_paga_section_screen.dart`): un'unica superficie di vetro con
/// scomparti piatti dentro, mai vetro annidato.
class _StatRow extends StatelessWidget {
  final List<(String label, String value)> items;

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
                    Text(
                      items[i].$2,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.cardAmount.copyWith(
                        color: labelPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
/// condivisione di sistema. Sostituisce la vecchia `CupertinoFormRow` dentro
/// una `GlassFormSection` — un solo elemento non aveva senso come "lista".
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
            const SizedBox(width: 4),
            Icon(CupertinoIcons.square_arrow_up, size: 16, color: accent),
          ],
        ),
      ),
    );
  }
}

/// Tabella unica Ferie/ROL/Permessi con colonne Maturato/Goduto/Residuo:
/// sostituisce le 3 sezioni separate precedenti, che ripetevano la stessa
/// struttura a righe per ciascuna categoria.
class _MaturazioniSection extends StatelessWidget {
  final BustaPaga bustaPaga;

  const _MaturazioniSection({required this.bustaPaga});

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
        ),
        _tableDataRow(
          context,
          label: 'ROL',
          maturato: formatNumber(bustaPaga.rolMaturati),
          goduto: formatNumber(bustaPaga.rolGoduti),
          residuo: formatNumber(bustaPaga.rolResidui),
        ),
        _tableDataRow(
          context,
          label: 'Permessi',
          maturato: '—',
          goduto: formatNumber(bustaPaga.permessiGoduti),
          residuo: '—',
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
  }) {
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final valueStyle = AppTextStyles.cardAmount.copyWith(
      color: labelPrimary,
      fontWeight: FontWeight.w400,
    );

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
            child: Text(maturato, style: valueStyle, textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 2,
            child: Text(goduto, style: valueStyle, textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 2,
            child: Text(residuo, style: valueStyle, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

/// Barra flottante in basso: chip piatti senza superficie di vetro attorno
/// (nessun "pill" bianco dietro), stesso trattamento del "+" nella sidecar
/// (`_BustePagaSidecar`). Mostra "Conferma" solo se lo stato è ancora
/// "Da confermare"; "Modifica" è sempre presente (sostituisce il bottone
/// che prima stava nella nav bar).
class _ConfermaModificaBar extends StatelessWidget {
  final BustaPaga bustaPaga;
  final VoidCallback onConferma;
  final VoidCallback onModifica;

  const _ConfermaModificaBar({
    required this.bustaPaga,
    required this.onConferma,
    required this.onModifica,
  });

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoDynamicColor.resolve(AppColors.systemBlue, context);
    final greenAccent =
        CupertinoDynamicColor.resolve(AppColors.systemGreen, context);
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
