import Foundation
import SwiftData

@MainActor
@Observable
final class WatchlistViewModel {

    /// Fügt eine Karte zur Watchlist hinzu. Doppelte Einträge werden verhindert.
    func add(_ card: CardSearchResult, context: ModelContext) {
        let id = card.id
        let existing = (try? context.fetch(
            FetchDescriptor<WatchlistItem>(predicate: #Predicate { $0.id == id })
        )) ?? []
        guard existing.isEmpty else { return }
        context.insert(WatchlistItem(from: card))
    }

    /// Entfernt eine Karte aus der Watchlist.
    func remove(id: String, context: ModelContext) {
        let existing = (try? context.fetch(
            FetchDescriptor<WatchlistItem>(predicate: #Predicate { $0.id == id })
        )) ?? []
        existing.forEach { context.delete($0) }
    }

    /// Gibt zurück ob eine Karte bereits in der Watchlist ist.
    func contains(_ cardId: String, in items: [WatchlistItem]) -> Bool {
        items.contains { $0.id == cardId }
    }
}
