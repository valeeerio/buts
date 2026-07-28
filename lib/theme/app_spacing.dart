/// Scala di spaziature e corner radius coerente in tutta l'app.
/// Corner radius volutamente contenuto (8-12px): stile Apple/iOS nativo,
/// non pill/capsule stile Revolut.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;

  // Padding standard schermo
  static const double screenHorizontal = 20;
}

class AppRadius {
  AppRadius._();

  static const double small = 8;
  static const double medium = 10;
  static const double large = 12;
  static const double card = 16; // usato per card più grandi (es. donut summary)
}
