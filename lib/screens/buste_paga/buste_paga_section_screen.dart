import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/busta_paga.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/spring_button.dart';
import 'busta_paga_detail_screen.dart';
import 'busta_paga_form_screen.dart';
import 'buste_paga_archivio_view.dart';
import 'buste_paga_statistiche_screen.dart';

/// Sotto-navigazione interna alla sezione Buste Paga (unica sezione
/// dell'app, non c'è una navigazione radice).
enum _BustePagaTab { archivio, statistiche }

/// Schermata radice dell'app: header "Archivio buste paga" + CTA,
/// sotto-navigazione Archivio/Statistiche.
class BustePagaSectionScreen extends ConsumerStatefulWidget {
  const BustePagaSectionScreen({super.key});

  @override
  ConsumerState<BustePagaSectionScreen> createState() =>
      _BustePagaSectionScreenState();
}

class _BustePagaSectionScreenState
    extends ConsumerState<BustePagaSectionScreen> {
  _BustePagaTab _tab = _BustePagaTab.archivio;

  void _openForm(BuildContext context, {BustaPaga? existing}) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => BustaPagaFormScreen(existing: existing),
      ),
    );
  }

  void _openDetail(BuildContext context, BustaPaga bustaPaga) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => BustaPagaDetailScreen(bustaPaga: bustaPaga),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CupertinoDynamicColor.resolve(AppColors.backgroundPrimary, context),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.lg,
                AppSpacing.screenHorizontal,
                AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Archivio buste paga',
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: CupertinoDynamicColor.resolve(
                            AppColors.labelPrimary, context),
                      ),
                    ),
                  ),
                  SpringButton(
                    onPressed: () => _openForm(context),
                    child: Icon(
                      CupertinoIcons.add_circled_solid,
                      size: 30,
                      color: CupertinoDynamicColor.resolve(
                          AppColors.bustePaga, context),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              child: CupertinoSlidingSegmentedControl<_BustePagaTab>(
                groupValue: _tab,
                backgroundColor: CupertinoDynamicColor.resolve(
                    AppColors.backgroundPrimary, context),
                thumbColor: CupertinoDynamicColor.resolve(
                    AppColors.surface, context),
                children: {
                  _BustePagaTab.archivio: _SegmentLabel(
                    label: 'Archivio',
                    selected: _tab == _BustePagaTab.archivio,
                  ),
                  _BustePagaTab.statistiche: _SegmentLabel(
                    label: 'Statistiche',
                    selected: _tab == _BustePagaTab.statistiche,
                  ),
                },
                onValueChanged: (value) {
                  if (value == null) return;
                  setState(() => _tab = value);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: switch (_tab) {
                _BustePagaTab.archivio => BustePagaArchivioView(
                    onOpenDetail: (bustaPaga) =>
                        _openDetail(context, bustaPaga),
                    onAdd: () => _openForm(context),
                  ),
                _BustePagaTab.statistiche =>
                  const BustePagaStatisticheScreen(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  final String label;
  final bool selected;

  const _SegmentLabel({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Text(
        label,
        style: AppTextStyles.subtitle.copyWith(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: CupertinoDynamicColor.resolve(
              AppColors.labelPrimary, context),
        ),
      ),
    );
  }
}
