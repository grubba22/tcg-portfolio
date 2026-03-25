import SwiftUI
import SwiftData

@main
struct TCGPortfolioApp: App {
    let container: ModelContainer

    init() {
        let c = try! ModelContainer(for: PortfolioCard.self, PriceEntry.self, AppSettings.self, WatchlistItem.self)
        migrateToGermanNames(in: c)
        container = c
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await DatabaseUpdateService.shared.updateIfNeeded()
                }
        }
        .modelContainer(container)
    }
}

/// Einmalige DB-Migration: patcht englische Karten-/Set-Namen auf Deutsch.
/// Flag "didMigrateDE_v1" verhindert erneute Ausführung.
private func migrateToGermanNames(in container: ModelContainer) {
    guard !UserDefaults.standard.bool(forKey: "didMigrateDE_v4") else { return }

    let ctx = ModelContext(container)
    guard let cards = try? ctx.fetch(FetchDescriptor<PortfolioCard>()) else { return }

    for card in cards {
        let deName = card.isSealed
            ? SetTranslator.localizeProductName(card.cardName, setId: card.setId)
            : PokemonTranslator.toLocalName(card.cardName)
        let deSet = SetTranslator.localizedSetName(id: card.setId, fallback: card.setName)

        if card.cardName != deName { card.cardName = deName }
        if card.setName  != deSet  { card.setName  = deSet  }
    }
    try? ctx.save()
    UserDefaults.standard.set(true, forKey: "didMigrateDE_v4")
}
