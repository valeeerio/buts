import SwiftUI
import WidgetKit

/// Entry point del target Widget Extension `BustaPagaWidgetExtension`. Un
/// solo Widget (`BustaPagaWidget`), che supporta le famiglie `.systemSmall`
/// (solo netto ultima busta paga) e `.systemMedium` (netto + Ferie/Ex
/// festività residue) — vedi `BustaPagaWidget.swift`.
@main
struct BustaPagaWidgetBundle: WidgetBundle {
    var body: some Widget {
        BustaPagaWidget()
    }
}
