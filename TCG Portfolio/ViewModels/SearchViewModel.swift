import Foundation
import SwiftUI

@MainActor
@Observable
final class SearchViewModel {
    var searchText = ""
    var results: [CardSearchResult] = []
    var isLoading = false
    var errorMessage: String?
    var showRateLimitWarning = false

    private var searchTask: Task<Void, Never>?

    func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { results = []; return }

        searchTask?.cancel()
        isLoading = true
        errorMessage = nil

        let task = Task {
            let db   = LocalCardDatabase.shared
            var found: [CardSearchResult] = []

            if SetTranslator.isSealedProduct(query: query) {
                // Sealed-Produkt: DE→EN übersetzen und suchen
                let enQuery = SetTranslator.translateSealedQuery(query: query) ?? query
                found = db.searchProducts(query: enQuery)

            } else {
                // SetTranslator: erkennt bekannte Sets (DE + EN) inkl. Aliase
                let parsed = SetTranslator.parse(query: query)

                if let setNameEN = parsed.setNameEN {
                    // Bekanntes Set erkannt → Episode-ID via DB-Lookup (IDs können abweichen)
                    let epId = db.findEpisode(name: setNameEN)?.id ?? 0
                    if epId > 0 {
                        found = setSearch(db: db, episodeId: epId, cardName: parsed.cardName)
                    } else {
                        // Episode nicht in DB – als Kartensuche fallback
                        found = db.searchCards(query: parsed.cardName.isEmpty ? query : parsed.cardName)
                    }
                } else {
                    // Unbekanntes Set (z.B. "base set", "jungle", "basis edition"):
                    // Suche direkt in DB-Episode-Namen
                    if let (epId, cardName) = db.findEpisodeInQuery(query) {
                        found = setSearch(db: db, episodeId: epId, cardName: cardName)
                    } else {
                        // Kein Set gefunden – reine Kartensuche
                        found = db.searchCards(query: query)
                    }
                }
            }

            guard !Task.isCancelled else { return }
            results = found
            errorMessage = found.isEmpty ? "Keine Ergebnisse für \"\(query)\"" : nil
            isLoading = false
        }
        searchTask = task
        await task.value
    }

    /// Gibt alle Karten+Produkte eines Sets zurück, optional gefiltert nach Kartenname.
    private func setSearch(db: LocalCardDatabase, episodeId: Int, cardName: String) -> [CardSearchResult] {
        if cardName.isEmpty {
            // Nur Set → alles aus dem Set, nach Preis sortiert
            let cards  = db.searchCardsBySet(episodeId: episodeId)
            let sealed = db.searchProductsBySet(episodeId: episodeId)
            return (cards + sealed).sorted { ($0.price ?? 0) > ($1.price ?? 0) }
        } else {
            // Set + Kartenname → gefilterte Kartensuche im Set
            return db.searchCardsInSet(episodeId: episodeId, cardName: cardName)
        }
    }

    func clear() {
        searchText = ""
        results = []
        errorMessage = nil
        searchTask?.cancel()
    }

    var remainingRequests: Int { 0 }
}
