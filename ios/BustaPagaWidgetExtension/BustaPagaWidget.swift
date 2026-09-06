import SwiftUI
import WidgetKit

/// App Group condiviso fra l'app e questo target — deve corrispondere
/// esattamente a `HomeWidgetService.appGroupId`
/// (`lib/services/home_widget_service.dart`) e alla capability "App Groups"
/// che verrà aggiunta al target Xcode quando questo verrà creato.
private let appGroupId = "group.com.buts.buts"

/// Chiave sotto cui l'app Flutter scrive lo snapshot JSON — deve corrispondere
/// esattamente a `homeWidgetSnapshotKey` (`lib/services/home_widget_service.dart`).
private let snapshotKey = "buta_widget_snapshot"

/// Dati di una singola voce della timeline del widget, decodificati dal JSON
/// scritto da Dart. Nessun calcolo qui: tutti i valori arrivano già
/// formattati (stringhe pronte per la UI) dal lato Dart — vedi
/// `HomeWidgetService.aggiorna`.
struct BustaPagaWidgetSnapshot: Decodable {
    let bustaId: String?
    let mese: String?
    let netto: String?
    let statoConfermato: Bool?
    let ferieResidue: String?
    let exFestivitaResidue: String?
    let daImportare: Bool?

    /// Snapshot vuoto/placeholder, usato quando non è ancora stato scritto
    /// nulla dall'app (prima esecuzione, oppure App Group non ancora
    /// raggiungibile) o quando la decodifica del JSON fallisce.
    static let vuoto = BustaPagaWidgetSnapshot(
        bustaId: nil,
        mese: nil,
        netto: nil,
        statoConfermato: nil,
        ferieResidue: nil,
        exFestivitaResidue: nil,
        daImportare: false
    )
}

struct BustaPagaWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: BustaPagaWidgetSnapshot
}

/// `TimelineProvider` semplice (non `IntentTimelineProvider`: il widget non
/// ha nessuna configurazione utente) — legge sempre l'unico snapshot
/// corrente scritto da Dart in `UserDefaults(suiteName: appGroupId)`, non
/// mantiene una vera timeline di eventi futuri: una singola entry "adesso",
/// aggiornata da WidgetKit ogni volta che l'app chiama
/// `HomeWidget.updateWidget`.
struct BustaPagaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BustaPagaWidgetEntry {
        BustaPagaWidgetEntry(date: Date(), snapshot: .vuoto)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (BustaPagaWidgetEntry) -> Void
    ) {
        completion(BustaPagaWidgetEntry(date: Date(), snapshot: leggiSnapshot()))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<BustaPagaWidgetEntry>) -> Void
    ) {
        let entry = BustaPagaWidgetEntry(date: Date(), snapshot: leggiSnapshot())
        // `.never`: non c'è uno schedule interno al widget da mantenere, è
        // l'app a richiamare `HomeWidget.updateWidget` ogni volta che
        // l'archivio cambia (vedi `buste_paga_section_screen.dart`).
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func leggiSnapshot() -> BustaPagaWidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let raw = defaults.string(forKey: snapshotKey),
              let data = raw.data(using: .utf8)
        else {
            return .vuoto
        }
        do {
            return try JSONDecoder().decode(BustaPagaWidgetSnapshot.self, from: data)
        } catch {
            return .vuoto
        }
    }
}

struct BustaPagaWidget: Widget {
    let kind: String = "BustaPagaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: BustaPagaWidgetProvider()
        ) { entry in
            BustaPagaWidgetView(snapshot: entry.snapshot)
                // Aspetto forzato dark, coerente con l'app (dark-only, vedi
                // CLAUDE.md): il widget non deve seguire l'aspetto
                // chiaro/scuro di sistema scelto per la home screen.
                .environment(\.colorScheme, .dark)
        }
        .configurationDisplayName("Buts")
        .description("Netto dell'ultima busta paga e ratei residui.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
