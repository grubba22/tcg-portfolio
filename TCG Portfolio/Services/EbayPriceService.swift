import Foundation

// MARK: - eBay Price Result

struct EbayPriceResult {
    let lastSoldPrice: Double?
    let averagePrice: Double?
    let items: [EbaySoldItem]
    let searchURL: URL?
}

struct EbaySoldItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let price: Double?
    let priceRaw: String?
    let shipping: String?
    let condition: String?
    let soldDate: String?
    let imageURL: String?
    let itemURL: String?
    let productId: String?
    let location: String?
    let sellerName: String?
    let sellerReviews: Int?
    let sellerFeedback: Double?
}

// MARK: - SerpApi Response Models

struct SerpApiEbayResponse: Codable {
    let organicResults: [EbayItemRaw]?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case organicResults = "organic_results"
        case error
    }
}

enum EbayServiceError: LocalizedError {
    case apiError(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .apiError(let msg):     return "SerpApi Fehler: \(msg)"
        case .decodingFailed(let s): return "Parsing-Fehler: \(s)"
        }
    }
}

struct EbayItemRaw: Codable {
    let title: String?
    let subtitle: String?
    let price: EbayItemPrice?
    let shipping: EbayShipping?
    let condition: String?
    let soldDate: String?
    let thumbnail: String?
    let link: String?
    let productId: FlexibleEbayValue?
    let location: String?
    let seller: EbaySeller?

    enum CodingKeys: String, CodingKey {
        case title
        case subtitle
        case price
        case shipping
        case condition
        case soldDate   = "sold_date"
        case thumbnail
        case link
        case productId  = "product_id"
        case location
        case seller
    }
}

struct EbaySeller: Codable {
    let username: String?
    let reviews: Int?
    let positiveFeedbackInPercentage: Double?

    enum CodingKeys: String, CodingKey {
        case username
        case reviews
        case positiveFeedbackInPercentage = "positive_feedback_in_percentage"
    }
}

// product_id can be Int or String in the API response
enum FlexibleEbayValue: Codable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { self = .int(i) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else { self = .string("") }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .int(let v):    try c.encode(v)
        case .string(let v): try c.encode(v)
        }
    }

    var stringValue: String {
        switch self {
        case .int(let v):    return String(v)
        case .string(let v): return v
        }
    }
}

struct EbayItemPrice: Codable {
    let raw: String?
    let extracted: Double?
}

struct EbayShipping: Codable {
    let raw: String?
    let extracted: Double?

    // shipping kann ein Objekt {"raw":"...", "extracted":0.0} ODER ein Plain-String sein
    init(from decoder: Decoder) throws {
        if let str = try? decoder.singleValueContainer().decode(String.self) {
            raw = str
            extracted = nil
        } else {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            raw       = try c.decodeIfPresent(String.self, forKey: .raw)
            extracted = try c.decodeIfPresent(Double.self, forKey: .extracted)
        }
    }

    enum CodingKeys: String, CodingKey { case raw, extracted }
}

// MARK: - Cache Entry

private struct EbayCacheEntry {
    let result: EbayPriceResult
    let cachedAt: Date
}

// MARK: - Service

@MainActor
final class EbayPriceService {
    static let shared = EbayPriceService()
    private let apiKey = "d428b2e753b83a6667116d00778e35f74bb40140b7809da188ab72d2c4b275b7"

    // In-memory cache: key = "cardName|cardNumber", TTL = 1 hour
    private var cache: [String: EbayCacheEntry] = [:]
    private let cacheTTL: TimeInterval = 3600

    // Grading terms to exclude from search
    private let excludeTerms = ["-PSA", "-BGS", "-CGC", "-CSC", "-graded", "-Graded"]

    func fetchSoldPrices(cardName: String, cardNumber: String) async throws -> EbayPriceResult {
        let cacheKey = "\(cardName)|\(cardNumber)"

        if let entry = cache[cacheKey], Date().timeIntervalSince(entry.cachedAt) < cacheTTL {
            return entry.result
        }

        let exclusions = excludeTerms.joined(separator: " ")
        let query = "\(cardName) \(cardNumber) \(exclusions)"
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        let searchURL = URL(string: "https://www.ebay.de/sch/i.html?_nkw=\(encoded)&LH_Sold=1&LH_Complete=1&_sadis=BAe")

        guard let url = URL(string: "https://serpapi.com/search?engine=ebay&ebay_domain=ebay.de&_nkw=\(encoded)&LH_Sold=1&_ipg=10&api_key=\(apiKey)") else {
            return EbayPriceResult(lastSoldPrice: nil, averagePrice: nil, items: [], searchURL: searchURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse)
        }

        // DEBUG: Raw-Response loggen (im Fehlerfall sichtbar in Xcode-Konsole)
        #if DEBUG
        if let raw = String(data: data, encoding: .utf8) {
            print("[EbayPriceService] Raw response (\(data.count) bytes):")
            print(raw.prefix(1000))
        }
        #endif

        let decoded: SerpApiEbayResponse
        do {
            decoded = try JSONDecoder().decode(SerpApiEbayResponse.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[EbayPriceService] Decoding failed: \(error)")
            print("[EbayPriceService] Response was: \(raw.prefix(500))")
            throw EbayServiceError.decodingFailed(error.localizedDescription)
        }

        // SerpApi gibt bei Fehlern HTTP 200 + {"error": "..."} zurück
        if let apiError = decoded.error {
            print("[EbayPriceService] API error: \(apiError)")
            throw EbayServiceError.apiError(apiError)
        }

        let sorted = (decoded.organicResults ?? []).sorted { a, b in
            guard let da = a.soldDate, let db = b.soldDate else { return false }
            return da > db
        }

        let allItems = sorted.map { raw in
            EbaySoldItem(
                title: raw.title ?? "–",
                subtitle: raw.subtitle,
                price: raw.price?.extracted,
                priceRaw: raw.price?.raw,
                shipping: raw.shipping?.raw,
                condition: raw.condition,
                soldDate: raw.soldDate,
                imageURL: raw.thumbnail,
                itemURL: raw.link,
                productId: raw.productId?.stringValue,
                location: raw.location,
                sellerName: raw.seller?.username,
                sellerReviews: raw.seller?.reviews,
                sellerFeedback: raw.seller?.positiveFeedbackInPercentage
            )
        }

        // 1€-Auktionen und Listings ohne Preis herausfiltern
        let items = allItems.filter { ($0.price ?? 0) > 1.0 }

        let prices = items.compactMap { $0.price }
        let lastSold = prices.first
        let average: Double? = prices.isEmpty ? nil : (prices.reduce(0, +) / Double(prices.count) * 100).rounded() / 100

        let result = EbayPriceResult(
            lastSoldPrice: lastSold,
            averagePrice: average,
            items: items,
            searchURL: searchURL
        )
        cache[cacheKey] = EbayCacheEntry(result: result, cachedAt: Date())
        return result
    }
}
