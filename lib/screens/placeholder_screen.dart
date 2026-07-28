import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';

/// Placeholder generico per le schermate non ancora disegnate
/// (dettaglio area, Buste Paga). Da sostituire schermata per schermata.
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final Color? accentColor;

  const PlaceholderScreen({super.key, required this.title, this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CupertinoDynamicColor.resolve(AppColors.backgroundPrimary, context),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: CupertinoDynamicColor.resolve(
                      AppColors.labelPrimary, context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Schermata da progettare',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoDynamicColor.resolve(
                      AppColors.labelSecondary, context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
