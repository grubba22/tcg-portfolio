import Foundation
import SwiftData

// MARK: - SwiftData Models

@Model
final class PortfolioCard {
    var id: String
    var cardName: String
    var setName: String
    var setId: Int
    var cardNumber: String
    var imageURL: String
    var purchasePrice: Double
    var currentPrice: Double
    var quantity: Int
    var dateAdded: Date
    var priceHistory: [PriceEntry]
    var rarity: String
    var cardmarketURL: String
    var avg7Price: Double?
    var avg30Price: Double?

    /// Sealed-Produkte haben keine Kartennummer — wird daraus abgeleitet, kein gespeichertes Feld.
    var isSealed: Bool { cardNumber.isEmpty }

    init(
        id: String,
        cardName: String,
        setName: String,
        setId: Int,
        cardNumber: String,
        imageURL: String,
        purchasePrice: Double,
        currentPrice: Double,
        quantity: Int = 1,
        rarity: String = "",
        cardmarketURL: String = "",
        avg7Price: Double? = nil,
        avg30Price: Double? = nil
    ) {
        self.id = id
        self.cardName = cardName
        self.setName = setName
        self.setId = setId
        self.cardNumber = cardNumber
        self.imageURL = imageURL
        self.purchasePrice = purchasePrice
        self.currentPrice = currentPrice
        self.quantity = quantity
        self.dateAdded = Date()
        self.priceHistory = [PriceEntry(price: currentPrice, date: Date())]
        self.rarity = rarity
        self.cardmarketURL = cardmarketURL
        self.avg7Price = avg7Price
        self.avg30Price = avg30Price
    }

    /// Lokalisierter Anzeigename – übersetzt englische API-Namen in die Sprache der App.
    var displayName: String { PokemonTranslator.toLocalName(cardName) }

    /// Deutscher Set-Name – nutzt SetTranslator, Fallback auf gespeicherten Namen (ältere Einträge).
    var localizedSetName: String { SetTranslator.localizedSetName(id: setId, fallback: setName) }

    var totalValue: Double { currentPrice * Double(quantity) }
    var totalCost: Double { purchasePrice * Double(quantity) }
    var profitLoss: Double { totalValue - totalCost }
    var profitLossPercent: Double {
        guard totalCost > 0 else { return 0 }
        return (profitLoss / totalCost) * 100
    }

    /// 7-Tage-Durchschnitt: API-Wert oder Berechnung aus priceHistory
    var average7Day: Double {
        if let v = avg7Price { return v }
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = priceHistory.filter { $0.date >= cutoff }
        guard !recent.isEmpty else { return currentPrice }
        return recent.reduce(0) { $0 + $1.price } / Double(recent.count)
    }

    /// 30-Tage-Durchschnitt: API-Wert oder Berechnung aus priceHistory
    var average30Day: Double {
        if let v = avg30Price { return v }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recent = priceHistory.filter { $0.date >= cutoff }
        guard !recent.isEmpty else { return currentPrice }
        return recent.reduce(0) { $0 + $1.price } / Double(recent.count)
    }
}

@Model
final class PriceEntry {
    var price: Double
    var date: Date

    init(price: Double, date: Date) {
        self.price = price
        self.date = date
    }
}

@Model
final class AppSettings {
    var lastPriceUpdate: Date?
    var dailyRequestCount: Int
    var requestCountResetDate: Date
    var warningShown: Bool

    init() {
        self.lastPriceUpdate = nil
        self.dailyRequestCount = 0
        self.requestCountResetDate = Calendar.current.startOfDay(for: Date())
        self.warningShown = false
    }
}

// MARK: - Watchlist

@Model
final class WatchlistItem {
    var id: String
    var cardName: String
    var setName: String
    var setId: Int
    var cardNumber: String
    var imageURL: String
    var rarity: String
    var price: Double?
    var dateAdded: Date

    var isSealed: Bool { cardNumber.isEmpty }
    var displayName: String {
        if isSealed { return SetTranslator.localizeProductName(cardName, setId: setId) }
        return PokemonTranslator.toLocalName(cardName)
    }
    var localizedSetName: String { SetTranslator.localizedSetName(id: setId, fallback: setName) }

    init(from card: CardSearchResult) {
        self.id          = card.id
        self.cardName    = card.name
        self.setName     = card.setName
        self.setId       = card.setId
        self.cardNumber  = card.number
        self.imageURL    = card.imageURL
        self.rarity      = card.rarity
        self.price       = card.price
        self.dateAdded   = Date()
    }
}

// MARK: - API Response Models

struct CardMarketResponse: Codable {
    let data: [APICard]?
    let error: String?
}

struct APICard: Codable, Identifiable {
    let rawId: FlexibleValue
    let name: String
    let number: FlexibleValue?
    let image: String?
    let prices: CardPrices?
    let episode: APIEpisode?
    let rarity: String?
    let seriesName: String?

    // Flat-Struktur: Preisfelder direkt am Card-Objekt (alternative API-Response-Form)
    let flatCurrency:       String?
    let flatLowestNM:       Double?
    let flatLowestNM_DE:    Double?
    let flatLowestNM_EU:    Double?
    let flatLowestNM_FR:    Double?
    let flatLowestNM_ES:    Double?
    let flatLowestNM_IT:    Double?
    // _EU_only Varianten (alternative Schlüsselnamen der API)
    let flatLowestNM_FR_EU: Double?
    let flatLowestNM_ES_EU: Double?
    let flatLowestNM_IT_EU: Double?
    let flatAvg7:           Double?
    let flatAvg30:          Double?
    let flatPsa10:          Double?
    let flatPsa9:           Double?
    let flatPsa8:           Double?
    let flatCgc10:          Double?
    let flatCgc9:           Double?
    let flatBgs10:          Double?
    let flatBgs10Pristine:  Double?
    let flatBgs9:           Double?

    enum CodingKeys: String, CodingKey {
        case rawId = "id"
        case name
        case number = "card_number"
        case image
        case prices, episode
        case rarity
        case seriesName          = "series_name"
        case flatCurrency        = "currency"
        case flatLowestNM        = "lowest_near_mint"
        case flatLowestNM_DE     = "lowest_near_mint_DE"
        case flatLowestNM_EU     = "lowest_near_mint_EU_only"
        case flatLowestNM_FR     = "lowest_near_mint_FR"
        case flatLowestNM_ES     = "lowest_near_mint_ES"
        case flatLowestNM_IT     = "lowest_near_mint_IT"
        case flatLowestNM_FR_EU  = "lowest_near_mint_FR_EU_only"
        case flatLowestNM_ES_EU  = "lowest_near_mint_ES_EU_only"
        case flatLowestNM_IT_EU  = "lowest_near_mint_IT_EU_only"
        case flatAvg7            = "7d_average"
        case flatAvg30           = "30d_average"
        case flatPsa10           = "psa10"
        case flatPsa9            = "psa9"
        case flatPsa8            = "psa8"
        case flatCgc10           = "cgc10"
        case flatCgc9            = "cgc9"
        case flatBgs10           = "bgs10"
        case flatBgs10Pristine   = "bgs10pristine"
        case flatBgs9            = "bgs9"
    }

    var id: String { rawId.stringValue }
    var idString: String { rawId.stringValue }

    var displayNumber: String {
        number?.stringValue ?? "?"
    }

    // Flat-Werte (direkt am Card-Objekt) haben Vorrang – sie sind die autoritativen Werte.
    // Nested prices.cardmarket dient als Fallback. Plausibilitätsprüfung gilt für ALLE Quellen.
    var resolvedLowestNM:    Double? { firstPlausiblePrice([flatLowestNM,    prices?.cardmarket?.lowestNearMint]) }
    var resolvedLowestNM_DE: Double? { firstPlausiblePrice([flatLowestNM_DE, prices?.cardmarket?.lowestNearMintDE]) }
    var resolvedLowestNM_EU: Double? { firstPlausiblePrice([flatLowestNM_EU, prices?.cardmarket?.lowestNearMintEU]) }
    var resolvedLowestNM_FR: Double? { firstPlausiblePrice([flatLowestNM_FR, flatLowestNM_FR_EU, prices?.cardmarket?.lowestNearMintFR]) }
    var resolvedLowestNM_ES: Double? { firstPlausiblePrice([flatLowestNM_ES, flatLowestNM_ES_EU, prices?.cardmarket?.lowestNearMintES]) }
    var resolvedLowestNM_IT: Double? { firstPlausiblePrice([flatLowestNM_IT, flatLowestNM_IT_EU, prices?.cardmarket?.lowestNearMintIT]) }
    var resolvedAvg7:        Double? { firstPlausiblePrice([flatAvg7,   prices?.cardmarket?.avg7]) }
    var resolvedAvg30:       Double? { firstPlausiblePrice([flatAvg30,  prices?.cardmarket?.avg30]) }
    var resolvedPsa10:       Double? { firstPlausiblePrice([flatPsa10,  prices?.cardmarket?.psa10], minValue: 1.0) }
    var resolvedPsa9:        Double? { firstPlausiblePrice([flatPsa9,   prices?.cardmarket?.psa9],  minValue: 1.0) }
    var resolvedPsa8:        Double? { firstPlausiblePrice([flatPsa8,   prices?.cardmarket?.psa8],  minValue: 1.0) }
    var resolvedCgc10:       Double? { firstPlausiblePrice([flatCgc10,  prices?.cardmarket?.cgc10], minValue: 1.0) }
    var resolvedCgc9:        Double? { firstPlausiblePrice([flatCgc9,   prices?.cardmarket?.cgc9],  minValue: 1.0) }
    var resolvedBgs10:       Double? { firstPlausiblePrice([flatBgs10,  prices?.cardmarket?.bgs10], minValue: 1.0) }
    var resolvedBgs10Pristine: Double? { firstPlausiblePrice([flatBgs10Pristine, prices?.cardmarket?.bgs10Pristine], minValue: 1.0) }
    var resolvedBgs9:        Double? { firstPlausiblePrice([flatBgs9,   prices?.cardmarket?.bgs9],  minValue: 1.0) }
    var resolvedBestPrice:   Double? { resolvedLowestNM_DE ?? resolvedLowestNM }

    /// Gibt den ersten plausiblen Preis aus der Kandidatenliste zurück.
    /// - Werte ≤ 0 werden übersprungen.
    /// - `minValue`: absoluter Mindestwert (Standard 0). Nützlich um Werte < 1€ für Grading-Preise auszuschließen.
    /// - Plausibilitätscheck vs. DE-Preis: Wenn ein Kandidat < flatLowestNM_DE / 50 ist und DE > 5€,
    ///   wird er als API-Einheitenfehler betrachtet und übersprungen.
    private func firstPlausiblePrice(_ candidates: [Double?], minValue: Double = 0) -> Double? {
        let deRef = flatLowestNM_DE
        for candidate in candidates {
            guard let v = candidate, v > minValue else { continue }
            if let ref = deRef, ref > 5.0, v < ref / 50 {
                #if DEBUG
                print("[APICard] plausibility filter: \(v) rejected (DE=\(ref), factor=\(Int(ref/v))×)")
                #endif
                continue
            }
            return v
        }
        return nil
    }
}

struct APISet: Codable {
    let id: Int?
    let name: String?
}

struct APIEpisode: Codable {
    let id: Int?
    let name: String?
    let slug: String?
    let code: String?
    let totalCards: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, code
        case totalCards = "total_cards"
    }
}

struct CardPrices: Codable {
    let cardmarket: CardmarketPrices?

    var bestPrice: Double? { cardmarket?.bestPrice }
}

struct CardmarketPrices: Codable {
    let currency: String?
    let lowestNearMint: Double?
    let lowestNearMintDE: Double?
    let lowestNearMintEU: Double?
    let lowestNearMintFR: Double?
    let lowestNearMintES: Double?
    let lowestNearMintIT: Double?
    let avg7: Double?
    let avg30: Double?
    let graded: GradedPrices?
    // Direkte Grading-Felder (Fallback für Karten, die sie außerhalb von graded liefern)
    let psa10: Double?
    let psa9: Double?
    let psa8: Double?
    let cgc10: Double?
    let cgc9: Double?
    let bgs10: Double?
    let bgs10Pristine: Double?
    let bgs9: Double?

    enum CodingKeys: String, CodingKey {
        case currency
        case lowestNearMint    = "lowest_near_mint"
        case lowestNearMintDE  = "lowest_near_mint_DE"
        case lowestNearMintEU  = "lowest_near_mint_EU_only"
        case lowestNearMintFR  = "lowest_near_mint_FR"
        case lowestNearMintES  = "lowest_near_mint_ES"
        case lowestNearMintIT  = "lowest_near_mint_IT"
        case avg7              = "7d_average"
        case avg30             = "30d_average"
        case graded
        case psa10, psa9, psa8
        case cgc10, cgc9
        case bgs10, bgs9
        case bgs10Pristine     = "bgs10pristine"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currency         = try c.decodeIfPresent(String.self,       forKey: .currency)
        lowestNearMint   = try c.decodeIfPresent(Double.self,       forKey: .lowestNearMint)
        lowestNearMintDE = try c.decodeIfPresent(Double.self,       forKey: .lowestNearMintDE)
        lowestNearMintEU = try c.decodeIfPresent(Double.self,       forKey: .lowestNearMintEU)
        lowestNearMintFR = try c.decodeIfPresent(Double.self,       forKey: .lowestNearMintFR)
        lowestNearMintES = try c.decodeIfPresent(Double.self,       forKey: .lowestNearMintES)
        lowestNearMintIT = try c.decodeIfPresent(Double.self,       forKey: .lowestNearMintIT)
        avg7             = try c.decodeIfPresent(Double.self,       forKey: .avg7)
        avg30            = try c.decodeIfPresent(Double.self,       forKey: .avg30)
        // GradedPrices: dekodiert prices.cardmarket.graded.psa/cgc/bgs korrekt
        graded           = try c.decodeIfPresent(GradedPrices.self, forKey: .graded)

        // Direkte Felder (selten, aber als Fallback)
        let rawPsa10  = try c.decodeIfPresent(Double.self, forKey: .psa10)
        let rawPsa9   = try c.decodeIfPresent(Double.self, forKey: .psa9)
        let rawPsa8   = try c.decodeIfPresent(Double.self, forKey: .psa8)
        let rawCgc10  = try c.decodeIfPresent(Double.self, forKey: .cgc10)
        let rawCgc9   = try c.decodeIfPresent(Double.self, forKey: .cgc9)
        let rawBgs10  = try c.decodeIfPresent(Double.self, forKey: .bgs10)
        let rawBgs10P = try c.decodeIfPresent(Double.self, forKey: .bgs10Pristine)
        let rawBgs9   = try c.decodeIfPresent(Double.self, forKey: .bgs9)

        // Priorisierung: graded-Objekt > direkte Felder (graded ist die Hauptquelle)
        psa10         = graded?.psa10 ?? rawPsa10
        psa9          = graded?.psa9  ?? rawPsa9
        psa8          = graded?.psa8  ?? rawPsa8
        cgc10         = graded?.cgc10 ?? rawCgc10
        cgc9          = graded?.cgc9  ?? rawCgc9
        bgs10         = graded?.bgs10 ?? rawBgs10
        bgs10Pristine = graded?.bgs10Pristine ?? rawBgs10P
        bgs9          = graded?.bgs9  ?? rawBgs9
    }

    var bestPrice: Double? { lowestNearMintDE ?? lowestNearMint }
}

// Debug-Helfer: Optional<Double> → kurze String-Darstellung
extension Optional where Wrapped == Double {
    var d: String { self.map { String(format: "%.4g", $0) } ?? "nil" }
}

private struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

/// Dekodiert prices.cardmarket.graded – entweder [] (leeres Array) oder {"psa":{...},"cgc":{...},"bgs":{...}}
struct GradedPrices: Codable {
    let psa10: Double?
    let psa9: Double?
    let psa8: Double?
    let cgc10: Double?
    let cgc9: Double?
    let bgs10: Double?
    let bgs9: Double?
    let bgs10Pristine: Double?

    private struct PSAData: Codable {
        let psa10: Double?; let psa9: Double?; let psa8: Double?
    }
    private struct CGCData: Codable {
        let cgc10: Double?; let cgc9: Double?
        // Fallback: einige Karten haben PSA-Preise im cgc-Objekt
        let psa10: Double?; let psa9: Double?
    }
    private struct BGSData: Codable {
        let bgs10: Double?; let bgs9: Double?; let bgs10Pristine: Double?
        enum CodingKeys: String, CodingKey {
            case bgs10, bgs9
            case bgs10Pristine = "bgs10pristine"
        }
    }
    private struct GradedObject: Codable {
        let psa: PSAData?; let cgc: CGCData?; let bgs: BGSData?
    }

    init(from decoder: Decoder) throws {
        let sv = try decoder.singleValueContainer()
        // Fall A: leeres Array []
        if (try? sv.decode([String].self)) != nil {
            (psa10, psa9, psa8, cgc10, cgc9, bgs10, bgs9, bgs10Pristine) = (nil,nil,nil,nil,nil,nil,nil,nil)
            return
        }
        // Fall B: Objekt {"psa":{...}, "cgc":{...}, "bgs":{...}}
        if let obj = try? sv.decode(GradedObject.self) {
            psa10 = obj.psa?.psa10 ?? obj.cgc?.psa10
            psa9  = obj.psa?.psa9  ?? obj.cgc?.psa9
            psa8  = obj.psa?.psa8
            cgc10 = obj.cgc?.cgc10
            cgc9  = obj.cgc?.cgc9
            bgs10 = obj.bgs?.bgs10
            bgs9  = obj.bgs?.bgs9
            bgs10Pristine = obj.bgs?.bgs10Pristine
            return
        }
        (psa10, psa9, psa8, cgc10, cgc9, bgs10, bgs9, bgs10Pristine) = (nil,nil,nil,nil,nil,nil,nil,nil)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encodeNil()
    }
}

// MARK: - Flexible Decoding Helpers

enum FlexibleValue: Codable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else {
            throw DecodingError.typeMismatch(
                FlexibleValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Int or String")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        }
    }

    var stringValue: String {
        switch self {
        case .int(let v): return String(v)
        case .string(let v): return v
        }
    }
}

// MARK: - Sealed Product API Models

struct ProductMarketResponse: Codable {
    let data: [APIProduct]?
    let error: String?
}

struct APIProduct: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String?
    let image: String?
    let prices: ProductPrices?
    let episode: APIEpisode?
    let tcggoURL: String?
    let links: ProductLinks?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, image, prices, episode, links
        case tcggoURL = "tcggo_url"
    }

    var idString: String { String(id) }
}

struct ProductLinks: Codable {
    let cardmarket: String?
}

struct ProductPrices: Codable {
    let cardmarket: ProductCardmarketPrices?
}

struct ProductCardmarketPrices: Codable {
    let currency: String?
    let lowest: Double?
    let lowestEU: Double?
    let lowestDE: Double?
    let lowestDE_EU: Double?
    let lowestFR: Double?
    let lowestFR_EU: Double?
    let lowestES: Double?
    let lowestES_EU: Double?
    let lowestIT: Double?
    let lowestIT_EU: Double?

    enum CodingKeys: String, CodingKey {
        case currency
        case lowest
        case lowestEU    = "lowest_EU_only"
        case lowestDE    = "lowest_DE"
        case lowestDE_EU = "lowest_DE_EU_only"
        case lowestFR    = "lowest_FR"
        case lowestFR_EU = "lowest_FR_EU_only"
        case lowestES    = "lowest_ES"
        case lowestES_EU = "lowest_ES_EU_only"
        case lowestIT    = "lowest_IT"
        case lowestIT_EU = "lowest_IT_EU_only"
    }
}

// MARK: - Search Result (UI Model)

struct CardSearchResult: Identifiable {
    let id: String
    let name: String
    let number: String
    let setName: String
    let setId: Int
    let imageURL: String
    let rarity: String
    let price: Double?
    let priceDE: Double?
    let priceEU: Double?
    let priceFR: Double?
    let priceES: Double?
    let priceIT: Double?
    let avg7: Double?
    let avg30: Double?
    let cardmarketURL: String
    let psaPrice10: Double?
    let psaPrice9: Double?
    let psaPrice8: Double?
    let cgcPrice10: Double?
    let cgcPrice9: Double?
    let bgsPrice10: Double?
    let bgsPrice10Pristine: Double?
    let bgsPrice9: Double?
    let seriesName: String?
    let episodeName: String?
    let totalCards: Int?
    let isSealed: Bool

    init(from card: APICard, setName: String, setId: Int) {
        self.id = card.idString
        self.name = PokemonTranslator.toLocalName(card.name)
        self.number = card.displayNumber
        self.setName = SetTranslator.localizedSetName(id: setId, fallback: setName)
        self.setId = setId
        self.imageURL = card.image ?? ""
        self.rarity = card.rarity ?? ""
        // Preise: resolved* prüft verschachtelt UND flach
        self.price    = card.resolvedBestPrice
        self.priceDE  = card.resolvedLowestNM_DE
        self.priceEU  = card.resolvedLowestNM_EU
        self.priceFR  = card.resolvedLowestNM_FR
        self.priceES  = card.resolvedLowestNM_ES
        self.priceIT  = card.resolvedLowestNM_IT
        self.avg7     = card.resolvedAvg7
        self.avg30    = card.resolvedAvg30
        self.cardmarketURL = "https://www.tcggo.com/external/cm/\(card.idString)"
        self.psaPrice10 = card.resolvedPsa10
        self.psaPrice9  = card.resolvedPsa9
        self.psaPrice8  = card.resolvedPsa8
        self.cgcPrice10        = card.resolvedCgc10
        self.cgcPrice9         = card.resolvedCgc9
        self.bgsPrice10        = card.resolvedBgs10
        self.bgsPrice10Pristine = card.resolvedBgs10Pristine
        self.bgsPrice9         = card.resolvedBgs9
        self.seriesName  = card.seriesName
        self.episodeName = card.episode?.name
        self.totalCards  = card.episode?.totalCards
        self.isSealed    = false

        #if DEBUG
        print("[CardSearchResult] \(card.name) #\(card.displayNumber)")
        print("  DE=\(String(describing: self.priceDE))  FR=\(String(describing: self.priceFR))")
        print("  PSA10=\(String(describing: self.psaPrice10))  PSA9=\(String(describing: self.psaPrice9))  PSA8=\(String(describing: self.psaPrice8))")
        print("  avg7=\(String(describing: self.avg7))  avg30=\(String(describing: self.avg30))")
        print("  source: \(card.prices?.cardmarket != nil ? "nested" : "flat")")
        #endif
    }

    init(from product: APIProduct) {
        let cm = product.prices?.cardmarket
        let epId            = product.episode?.id ?? 0
        self.id             = product.idString
        self.name           = SetTranslator.localizeProductName(product.name, setId: epId)
        self.number         = ""
        self.setName        = SetTranslator.localizedSetName(id: epId, fallback: product.episode?.name ?? "Unbekannt")
        self.setId          = epId
        self.imageURL       = product.image ?? ""
        self.rarity         = ""
        self.price          = cm?.lowestDE ?? cm?.lowestDE_EU ?? cm?.lowest
        self.priceDE        = cm?.lowestDE ?? cm?.lowestDE_EU
        self.priceEU        = cm?.lowestEU
        self.priceFR        = cm?.lowestFR ?? cm?.lowestFR_EU
        self.priceES        = cm?.lowestES ?? cm?.lowestES_EU
        self.priceIT        = cm?.lowestIT ?? cm?.lowestIT_EU
        self.avg7           = nil
        self.avg30          = nil
        self.cardmarketURL  = product.links?.cardmarket ?? product.tcggoURL ?? ""
        self.psaPrice10     = nil
        self.psaPrice9      = nil
        self.psaPrice8      = nil
        self.cgcPrice10     = nil
        self.cgcPrice9      = nil
        self.bgsPrice10     = nil
        self.bgsPrice10Pristine = nil
        self.bgsPrice9      = nil
        self.seriesName     = nil
        self.episodeName    = product.episode?.name
        self.totalCards     = product.episode?.totalCards
        self.isSealed       = true

        #if DEBUG
        print("[ProductSearchResult] \(product.name)")
        print("  DE=\(String(describing: self.priceDE))  FR=\(String(describing: self.priceFR))  IT=\(String(describing: self.priceIT))")
        #endif
    }

    /// Erstellt ein CardSearchResult aus einem WatchlistItem für Navigation zur Detailansicht.
    init(from item: WatchlistItem) {
        self.id          = item.id
        self.name        = item.cardName
        self.number      = item.cardNumber
        self.setName     = item.localizedSetName
        self.setId       = item.setId
        self.imageURL    = item.imageURL
        self.rarity      = item.rarity
        self.price       = item.price
        self.priceDE     = item.price
        self.priceEU     = nil
        self.priceFR     = nil
        self.priceES     = nil
        self.priceIT     = nil
        self.avg7        = nil
        self.avg30       = nil
        self.cardmarketURL     = ""
        self.psaPrice10        = nil
        self.psaPrice9         = nil
        self.psaPrice8         = nil
        self.cgcPrice10        = nil
        self.cgcPrice9         = nil
        self.bgsPrice10        = nil
        self.bgsPrice10Pristine = nil
        self.bgsPrice9         = nil
        self.seriesName  = nil
        self.episodeName = nil
        self.totalCards  = nil
        self.isSealed    = item.isSealed
    }
}
