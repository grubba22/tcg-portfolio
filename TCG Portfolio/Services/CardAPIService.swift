import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case noResults
    case rateLimitReached
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Ungültige URL"
        case .networkError(let e): return "Netzwerkfehler: \(e.localizedDescription)"
        case .decodingError(let e): return "Datenfehler: \(e.localizedDescription)"
        case .noResults: return "Keine Ergebnisse gefunden"
        case .rateLimitReached: return "API-Limit erreicht (99/Tag). Reset um Mitternacht."
        case .serverError(let code): return "Serverfehler: \(code)"
        }
    }
}

@MainActor
final class CardAPIService {
    static let shared = CardAPIService()

    private let apiKey = "973b910ce3msh50f372c62250143p1a6f6fjsnb7339db14509"
    private let host = "cardmarket-api-tcg.p.rapidapi.com"
    private let baseURL = "https://cardmarket-api-tcg.p.rapidapi.com"

    // MARK: - Rate Limiting
    private var requestCount = 0
    private var resetDate = Calendar.current.startOfDay(for: Date())
    static let dailyLimit = 99
    static let warningThreshold = 80

    var remainingRequests: Int {
        resetIfNeeded()
        return Self.dailyLimit - requestCount
    }

    var shouldWarn: Bool {
        resetIfNeeded()
        return requestCount >= Self.warningThreshold
    }

    private func resetIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        if today > resetDate {
            requestCount = 0
            resetDate = today
        }
    }

    private func incrementCount() throws {
        resetIfNeeded()
        guard requestCount < Self.dailyLimit else {
            throw APIError.rateLimitReached
        }
        requestCount += 1
    }

    // MARK: - Endpoint Discovery (DEBUG)

    func testProductsEndpoint() async {
        // Übersetzungs-Selbsttest
        let translationTests: [(input: String, expected: String)] = [
            ("stürmische funken top trainer box",  "Surging Sparks Elite Trainer Box"),
            ("stürmische funken display",          "Surging Sparks Booster Box"),
            ("stürmische funken booster bundle",   "Surging Sparks Booster Bundle"),
            ("stürmische funken booster",          "Surging Sparks Booster"),
            ("phantomflammen ttb",                 "Phantasmal Flames Elite Trainer Box"),
            ("151 booster",                        "151 Booster"),
            ("151 top trainer box",                "151 Elite Trainer Box"),
            ("151 display",                        "151 Booster Box"),
        ]
        print("=== Übersetzungs-Test ===")
        for t in translationTests {
            let result = SetTranslator.translateSealedQuery(query: t.input) ?? "NIL"
            let ok = result == t.expected ? "✅" : "❌"
            print("\(ok) '\(t.input)' → '\(result)'")
            if result != t.expected { print("   erwartet: '\(t.expected)'") }
        }

        // API-Test mit übersetzten Namen
        let testQueries = [
            "/pokemon/products?sort=relevance&search=Surging+Sparks+Elite+Trainer+Box",
            "/pokemon/products?sort=relevance&search=Surging+Sparks+Booster+Box",
            "/pokemon/products?sort=relevance&search=Surging+Sparks+Booster+Bundle",
        ]
        for path in testQueries {
            guard let url = URL(string: "\(baseURL)\(path)") else {
                print("[Products] invalid URL: \(path)"); continue
            }
            var req = URLRequest(url: url)
            req.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
            req.setValue(host, forHTTPHeaderField: "x-rapidapi-host")
            req.timeoutInterval = 15
            if let (data, resp) = try? await URLSession.shared.data(for: req) {
                let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                print("╔══ [\(status)] \(path)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let items = json["data"] as? [[String: Any]] {
                    print("  \(items.count) Produkte:")
                    for item in items {
                        let name = item["name"] as? String ?? "?"
                        let cm = (item["prices"] as? [String: Any])?["cardmarket"] as? [String: Any]
                        let de = cm?["lowest_DE"] ?? cm?["lowest"] ?? "–"
                        print("  · \(name)  |  DE: \(de)€")
                    }
                } else {
                    print("  (kein data-Array)")
                }
                print("╚══")
            }
        }
    }

    func testEndpoints() async {
        // Find sets endpoint
        let setPaths = ["/sets", "/pokemon/sets", "/sets/pokemon", "/pokemon/sets/list"]
        for path in setPaths {
            guard let url = URL(string: "\(baseURL)\(path)") else { continue }
            var req = URLRequest(url: url)
            req.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
            req.setValue(host, forHTTPHeaderField: "x-rapidapi-host")
            req.timeoutInterval = 10
            if let (data, resp) = try? await URLSession.shared.data(for: req) {
                let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                let preview = String(data: data, encoding: .utf8)?.prefix(500) ?? ""
                print("[\(status)] \(path) → \(preview)")
            }
        }
        // Show full card with prices
        guard let url = URL(string: "\(baseURL)/pokemon/cards?search=pikachu&limit=1") else { return }
        var req = URLRequest(url: url)
        req.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        req.setValue(host, forHTTPHeaderField: "x-rapidapi-host")
        req.timeoutInterval = 10
        if let (data, _) = try? await URLSession.shared.data(for: req) {
            let full = String(data: data, encoding: .utf8) ?? ""
            print("=== FULL CARD RESPONSE ===")
            print(full.prefix(2000))
        }
    }

    // MARK: - Search Cards

    func searchCards(query: String) async throws -> [CardSearchResult] {
        let parsed = SetTranslator.parse(query: query)

        // Suchbegriff bestimmen:
        // – Nur Set-Name eingegeben (cardName leer) → englischen Set-Namen suchen, Episode-ID filtert auf richtiges Set
        // – Karte + Set → deutschen Kartennamen DE→EN übersetzen (API indexiert englisch)
        let searchTerm: String
        if parsed.cardName.isEmpty, let setNameEN = parsed.setNameEN {
            searchTerm = setNameEN
        } else {
            searchTerm = PokemonTranslator.bestSearchTerm(for: parsed.cardName)
        }

        #if DEBUG
        print("[CardAPIService] searchCards: '\(query)' → '\(searchTerm)'")
        #endif

        try incrementCount()

        let encodedName = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchTerm
        let urlString = "\(baseURL)/pokemon/cards?search=\(encodedName)"

        guard let url = URL(string: urlString) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.setValue(host, forHTTPHeaderField: "x-rapidapi-host")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200: break
            case 429: throw APIError.rateLimitReached
            default: throw APIError.serverError(httpResponse.statusCode)
            }
        }

        let decoded = try JSONDecoder().decode(CardMarketResponse.self, from: data)
        guard let allCards = decoded.data, !allCards.isEmpty else {
            throw APIError.noResults
        }

        // Filter nach Set, wenn eines angegeben wurde.
        // Primär: Episode-ID (exakt), Fallback: englischer Set-Name im episode.name
        let filtered: [APICard]
        if let setId = parsed.setId {
            let byId = allCards.filter { $0.episode?.id == setId }
            if !byId.isEmpty {
                filtered = byId
            } else if let setNameEN = parsed.setNameEN?.lowercased(), !setNameEN.isEmpty {
                filtered = allCards.filter {
                    $0.episode?.name?.lowercased().contains(setNameEN) == true ||
                    $0.episode?.slug?.lowercased().contains(setNameEN.replacingOccurrences(of: " ", with: "-")) == true
                }
            } else {
                filtered = allCards
            }
        } else if let setNameEN = parsed.setNameEN?.lowercased(), !setNameEN.isEmpty {
            // Kein setId, aber EN-Name bekannt (Sets ohne Episode-ID wie "Ascended Heroes")
            let byName = allCards.filter {
                $0.episode?.name?.lowercased().contains(setNameEN) == true ||
                $0.episode?.slug?.lowercased().contains(setNameEN.replacingOccurrences(of: " ", with: "-")) == true
            }
            filtered = byName.isEmpty ? allCards : byName
        } else {
            filtered = allCards
        }

        let results = filtered.isEmpty ? allCards : filtered

        #if DEBUG
        // ── RAW JSON DUMP via JSONSerialization (bypasses Codable, zeigt echte API-Werte) ──
        if let rawObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let rawCards = rawObj["data"] as? [[String: Any]] {
            for rawCard in rawCards.prefix(3) {
                let cName = rawCard["name"] as? String ?? "?"
                print("╔══ RAW JSON: \(cName) ══")
                // Root-Level Preisfelder
                let rootKeys = ["lowest_near_mint","lowest_near_mint_DE","lowest_near_mint_EU_only",
                                "lowest_near_mint_FR","lowest_near_mint_FR_EU_only",
                                "lowest_near_mint_ES","lowest_near_mint_ES_EU_only",
                                "lowest_near_mint_IT","lowest_near_mint_IT_EU_only",
                                "7d_average","30d_average",
                                "psa10","psa9","psa8","cgc10","cgc9","bgs10","bgs10pristine","bgs9"]
                for k in rootKeys {
                    if let v = rawCard[k] {
                        print("  root.\(k) = \(v)")
                    }
                }
                // Nested prices.cardmarket
                if let prices = rawCard["prices"] as? [String: Any],
                   let cm = prices["cardmarket"] as? [String: Any] {
                    print("  ── prices.cardmarket ──")
                    for k in rootKeys {
                        if let v = cm[k] { print("  nested.\(k) = \(v)") }
                    }
                    if let graded = cm["graded"] {
                        print("  nested.graded = \(graded)")
                    }
                } else {
                    print("  prices.cardmarket: fehlt")
                }
                print("╚══")
            }
        }
        // ── Decoded (Codable) Werte ──
        for card in results.prefix(2) {
            print("[Decoded] ══ \(card.name) #\(card.displayNumber) ══")
            print("  flat.DE=\(card.flatLowestNM_DE.d) FR=\(card.flatLowestNM_FR.d) FR_EU=\(card.flatLowestNM_FR_EU.d)")
            print("  flat.ES=\(card.flatLowestNM_ES.d) ES_EU=\(card.flatLowestNM_ES_EU.d) IT=\(card.flatLowestNM_IT.d) IT_EU=\(card.flatLowestNM_IT_EU.d)")
            print("  flat.psa10=\(card.flatPsa10.d) psa9=\(card.flatPsa9.d) psa8=\(card.flatPsa8.d)")
            print("  flat.cgc10=\(card.flatCgc10.d) cgc9=\(card.flatCgc9.d) bgs10=\(card.flatBgs10.d) bgs9=\(card.flatBgs9.d)")
            print("  nested.DE=\(card.prices?.cardmarket?.lowestNearMintDE.d ?? "nil") FR=\(card.prices?.cardmarket?.lowestNearMintFR.d ?? "nil")")
            print("  nested.psa10=\(card.prices?.cardmarket?.psa10.d ?? "nil") psa9=\(card.prices?.cardmarket?.psa9.d ?? "nil") psa8=\(card.prices?.cardmarket?.psa8.d ?? "nil")")
            print("  nested.cgc10=\(card.prices?.cardmarket?.cgc10.d ?? "nil") bgs9=\(card.prices?.cardmarket?.bgs9.d ?? "nil")")
            print("  resolved.DE=\(card.resolvedLowestNM_DE.d) FR=\(card.resolvedLowestNM_FR.d) ES=\(card.resolvedLowestNM_ES.d) IT=\(card.resolvedLowestNM_IT.d)")
            print("  resolved.psa10=\(card.resolvedPsa10.d) psa9=\(card.resolvedPsa9.d) psa8=\(card.resolvedPsa8.d)")
            print("  resolved.cgc10=\(card.resolvedCgc10.d) bgs9=\(card.resolvedBgs9.d) avg7=\(card.resolvedAvg7.d)")
        }
        #endif

        return results.map { card in
            let epName = card.episode?.name ?? "Unbekannt"
            let epId = card.episode?.id ?? 0
            return CardSearchResult(from: card, setName: epName, setId: epId)
        }
    }

    // MARK: - Search Sealed Products

    /// Sealed-Produkte für ein Set abrufen (für Set-Only-Suche).
    /// Funktioniert mit bekannter Episode-ID (setId != nil) und ohne (Fallback: Episodenname).
    func searchProductsForSet(setId: Int?, setNameEN: String) async throws -> [CardSearchResult] {
        try incrementCount()

        let encoded = setNameEN.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? setNameEN
        let urlString = "\(baseURL)/pokemon/products?sort=relevance&search=\(encoded)"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.setValue(host, forHTTPHeaderField: "x-rapidapi-host")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 429 { throw APIError.rateLimitReached }

        let decoded = try JSONDecoder().decode(ProductMarketResponse.self, from: data)
        let all = decoded.data ?? []

        let filtered: [APIProduct]
        if let id = setId {
            // Bekannte Episode-ID → exakter Filter
            let byId = all.filter { $0.episode?.id == id }
            filtered = byId.isEmpty ? all : byId
        } else {
            // Keine Episode-ID → nach Episodenname filtern
            let nameLower = setNameEN.lowercased()
            let byName = all.filter {
                $0.episode?.name?.lowercased().contains(nameLower) == true ||
                $0.episode?.slug?.lowercased().contains(nameLower.replacingOccurrences(of: " ", with: "-")) == true
            }
            filtered = byName.isEmpty ? all : byName
        }

        return filtered.map { CardSearchResult(from: $0) }
    }

    func searchProducts(query: String) async throws -> [CardSearchResult] {
        guard let englishQuery = SetTranslator.translateSealedQuery(query: query) else {
            throw APIError.noResults
        }

        try incrementCount()

        let encoded = englishQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? englishQuery
        let urlString = "\(baseURL)/pokemon/products?sort=relevance&search=\(encoded)"

        guard let url = URL(string: urlString) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.setValue(host, forHTTPHeaderField: "x-rapidapi-host")
        request.timeoutInterval = 15

        #if DEBUG
        print("[CardAPIService] searchProducts: '\(query)' → '\(englishQuery)'")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200: break
            case 429: throw APIError.rateLimitReached
            default: throw APIError.serverError(httpResponse.statusCode)
            }
        }

        let decoded = try JSONDecoder().decode(ProductMarketResponse.self, from: data)
        guard let allProducts = decoded.data, !allProducts.isEmpty else {
            throw APIError.noResults
        }

        // Nach Set filtern wenn ein Set angegeben wurde (verhindert TTBs anderer Sets)
        let parsed = SetTranslator.parse(query: query)
        let products: [APIProduct]
        if let setId = parsed.setId {
            let byId = allProducts.filter { $0.episode?.id == setId }
            products = byId.isEmpty ? allProducts : byId
        } else {
            products = allProducts
        }

        return products.map { CardSearchResult(from: $0) }
    }

    // MARK: - Fetch Price for Single Card

    func fetchPrice(for card: PortfolioCard) async throws -> Double? {
        try incrementCount()

        let urlString = "\(baseURL)/pokemon/cards?search=\(card.cardName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? card.cardName)"

        guard let url = URL(string: urlString) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.setValue(host, forHTTPHeaderField: "x-rapidapi-host")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoded = try JSONDecoder().decode(CardMarketResponse.self, from: data)
        let match = decoded.data?.first { $0.idString == card.id || $0.displayNumber == card.cardNumber }
        return match?.resolvedBestPrice
    }

    // MARK: - Batch Price Update

    struct CardPriceUpdate {
        let current: Double
        let avg7: Double?
        let avg30: Double?
    }

    func updatePrices(for cards: [PortfolioCard]) async throws -> [String: CardPriceUpdate] {
        var results: [String: CardPriceUpdate] = [:]

        // Group by set to minimize requests
        let grouped = Dictionary(grouping: cards) { $0.setId }

        for (_, setCards) in grouped {
            guard remainingRequests > 0 else { break }
            try incrementCount()

            let urlString = "\(baseURL)/pokemon/cards?search=\(setCards.first?.cardName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            guard let url = URL(string: urlString) else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
            request.setValue(host, forHTTPHeaderField: "x-rapidapi-host")
            request.timeoutInterval = 20

            guard let (data, _) = try? await URLSession.shared.data(for: request),
                  let decoded = try? JSONDecoder().decode(CardMarketResponse.self, from: data),
                  let allCards = decoded.data else { continue }

            for portfolioCard in setCards {
                if let match = allCards.first(where: { $0.idString == portfolioCard.id || $0.displayNumber == portfolioCard.cardNumber }),
                   let price = match.resolvedBestPrice {
                    results[portfolioCard.id] = CardPriceUpdate(
                        current: price,
                        avg7: match.resolvedAvg7,
                        avg30: match.resolvedAvg30
                    )
                }
            }
        }

        return results
    }
}
