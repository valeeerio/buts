import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_section.dart';

/// Sezione attualmente attiva (Buste Paga o Budget). Unica fonte di verità,
/// aggiornata solo da PageView.onPageChanged in app_root_scaffold.dart —
/// il tap sulla freccia dell'header anima il PageController, che a sua
/// volta triggera onPageChanged e quindi questo stato.
final activeSectionProvider = StateProvider<AppSection>(
  (ref) => AppSection.bustePaga,
);
