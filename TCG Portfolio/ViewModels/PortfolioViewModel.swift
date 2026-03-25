import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class PortfolioViewModel {
    var isUpdatingPrices = false
    var updateError: String?
    var lastUpdateText = "Nie aktualisiert"

    // MARK: - Portfolio Stats

    func totalValue(cards: [PortfolioCard]) -> Double {
        cards.reduce(0) { $0 + $1.totalValue }
    }

    func totalCost(cards: [PortfolioCard]) -> Double {
        cards.reduce(0) { $0 + $1.totalCost }
    }

    func totalProfitLoss(cards: [PortfolioCard]) -> Double {
        totalValue(cards: cards) - totalCost(cards: cards)
    }

    func totalProfitLossPercent(cards: [PortfolioCard]) -> Double {
        let cost = totalCost(cards: cards)
        guard cost > 0 else { return 0 }
        return (totalProfitLoss(cards: cards) / cost) * 100
    }

    // MARK: - Add Card

    func addCard(_ result: CardSearchResult, purchasePrice: Double, quantity: Int, context: ModelContext) {
        let cardId = result.id
        let descriptor = FetchDescriptor<PortfolioCard>(
            predicate: #Predicate { $0.id == cardId }
        )
        if let existing = try? context.fetch(descriptor), let card = existing.first {
            card.quantity += quantity
            return
        }

        let card = PortfolioCard(
            id: result.id,
            cardName: result.name,
            setName: result.setName,
            setId: result.setId,
            cardNumber: result.number,
            imageURL: result.imageURL,
            purchasePrice: purchasePrice,
            currentPrice: result.price ?? purchasePrice,
            quantity: quantity,
            rarity: result.rarity,
            cardmarketURL: result.cardmarketURL,
            avg7Price: result.avg7,
            avg30Price: result.avg30
        )
        context.insert(card)
    }

    // MARK: - Remove Card

    func removeCards(at offsets: IndexSet, from cards: [PortfolioCard], context: ModelContext) {
        for index in offsets {
            context.delete(cards[index])
        }
    }

    func removeCard(_ card: PortfolioCard, context: ModelContext) {
        context.delete(card)
    }

    // MARK: - Update Prices

    func updateAllPrices(cards: [PortfolioCard], context: ModelContext) async {
        guard !cards.isEmpty else { return }

        isUpdatingPrices = true
        updateError = nil

        let db = LocalCardDatabase.shared
        var updatedCount = 0

        for card in cards {
            guard let cardIdInt = Int(card.id),
                  let result = db.cardById(id: cardIdInt) else { continue }

            let newPrice = result.priceDE ?? result.price ?? card.currentPrice
            card.currentPrice = newPrice
            card.avg7Price    = result.avg7
            card.avg30Price   = result.avg30
            card.priceHistory.append(PriceEntry(price: newPrice, date: Date()))
            if card.priceHistory.count > 90 {
                card.priceHistory.removeFirst(card.priceHistory.count - 90)
            }
            updatedCount += 1
        }

        if updatedCount > 0 {
            lastUpdateText = "Aktualisiert: \(formattedNow())"
        } else {
            updateError = "Keine Karten in der Datenbank gefunden."
        }

        isUpdatingPrices = false
    }

    // MARK: - Daily Snapshot

    /// Speichert einmal pro Tag den aktuellen Preis jeder Karte.
    /// Wird beim Öffnen der Portfolio-Ansicht aufgerufen.
    /// Nur wenn noch kein Eintrag für heute existiert, wird ein neuer angelegt.
    func snapshotTodayIfNeeded(cards: [PortfolioCard], context: ModelContext) {
        guard !cards.isEmpty else { return }
        let today = Calendar.current.startOfDay(for: Date())
        var changed = false

        for card in cards {
            let hasToday = card.priceHistory.contains {
                Calendar.current.startOfDay(for: $0.date) >= today
            }
            guard !hasToday else { continue }

            card.priceHistory.append(PriceEntry(price: card.currentPrice, date: Date()))
            // Historie auf max. 365 Einträge begrenzen
            if card.priceHistory.count > 365 {
                card.priceHistory.removeFirst(card.priceHistory.count - 365)
            }
            changed = true
        }

        if changed {
            try? context.save()
            #if DEBUG
            let total = cards.reduce(0.0) { $0 + $1.currentPrice * Double($1.quantity) }
            print("[Portfolio] Tages-Snapshot gespeichert – \(cards.count) Karten, Gesamtwert: \(total)")
            #endif
        } else {
            #if DEBUG
            print("[Portfolio] Snapshot bereits vorhanden für heute")
            #endif
        }
    }

    // MARK: - Chart Data

    func chartData(for card: PortfolioCard) -> [(date: Date, value: Double)] {
        card.priceHistory.sorted { $0.date < $1.date }.map { (date: $0.date, value: $0.price) }
    }

    func portfolioValueHistory(cards: [PortfolioCard]) -> [(date: Date, value: Double)] {
        guard !cards.isEmpty else { return [] }

        let calendar = Calendar.current

        // Einmalig sortieren – nicht in jeder Tag-Iteration neu
        let sortedHistories: [(card: PortfolioCard, history: [PriceEntry])] = cards.map {
            ($0, $0.priceHistory.sorted { $0.date < $1.date })
        }

        let allDates = sortedHistories.flatMap { $0.history.map { $0.date } }
        let uniqueDays = Set(allDates.map { calendar.startOfDay(for: $0) }).sorted()

        #if DEBUG
        print("[Portfolio] portfolioValueHistory: \(uniqueDays.count) Tage, \(allDates.count) Einträge gesamt")
        #endif

        guard uniqueDays.count >= 2 else {
            #if DEBUG
            print("[Portfolio] Zu wenig Datenpunkte für Diagramm (min. 2 benötigt)")
            #endif
            return []
        }

        return uniqueDays.map { day in
            let value = sortedHistories.reduce(0.0) { total, item in
                // Letzten Eintrag bis einschließlich diesem Tag nehmen (sortiert → .last ist korrekt)
                let entry = item.history.last { calendar.startOfDay(for: $0.date) <= day }
                return total + (entry?.price ?? item.card.currentPrice) * Double(item.card.quantity)
            }
            return (date: day, value: value)
        }
    }

    // MARK: - Helpers

    private func formattedNow() -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: Date())
    }

    func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: NSNumber(value: value)) ?? "\(value) €"
    }

    func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
}
