/// Scala di spaziature e corner radius coerente in tutta l'app.
/// I raggi piccoli (`small`/`medium`/`large`/`card`) restano per dettagli
/// minuti (badge, barre di grafici); le superfici/card usano invece i
/// raggi "squircle" più generosi in `AppRadius.glass`/`AppRadius.glassSmall`
/// — vedi `lib/widgets/liquid_glass_surface.dart`.
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

  // --- Liquid Glass ---
  // Curve più generose e "continue" (vedi `lib/widgets/squircle_clipper.dart`)
  // usate da `LiquidGlassSurface`/`LiquidGlassButton`, gli standard di
  // superficie/card di tutta l'app.
  static const double glass = 28; // hero card, contenitori principali
  static const double glassSmall = 18; // righe elenco, chip, CTA compatte
}
