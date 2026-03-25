import Foundation
import SQLite3

// MARK: - CardSearchResult DB Init

extension CardSearchResult {
    init(dbCard id: Int, name: String, number: String,
         setId: Int, setName: String, episodeName: String, seriesName: String?,
         totalCards: Int?, image: String, cmURL: String,
         price: Double?, priceDE: Double?, priceEU: Double?,
         priceFR: Double?, priceES: Double?, priceIT: Double?,
         avg7: Double?, avg30: Double?,
         psa10: Double?, psa9: Double?, psa8: Double?,
         cgc10: Double?, cgc9: Double?, bgs9: Double?,
         rarity: String) {
        self.id             = "\(id)"
        self.name           = PokemonTranslator.toLocalName(name)
        self.number         = number
        self.setName        = SetTranslator.localizedSetName(id: setId, fallback: setName)
        self.setId          = setId
        self.imageURL       = image
        self.rarity         = rarity
        self.price          = priceDE ?? price
        self.priceDE        = priceDE
        self.priceEU        = priceEU
        self.priceFR        = priceFR
        self.priceES        = priceES
        self.priceIT        = priceIT
        self.avg7           = avg7
        self.avg30          = avg30
        self.cardmarketURL  = cmURL
        self.psaPrice10     = psa10
        self.psaPrice9      = psa9
        self.psaPrice8      = psa8
        self.cgcPrice10     = cgc10
        self.cgcPrice9      = cgc9
        self.bgsPrice10     = nil
        self.bgsPrice10Pristine = nil
        self.bgsPrice9      = bgs9
        self.seriesName     = seriesName
        self.episodeName    = episodeName
        self.totalCards     = totalCards
        self.isSealed       = false
    }

    init(dbProduct id: Int, name: String,
         setId: Int, setName: String, episodeName: String, seriesName: String?,
         image: String, cmURL: String,
         price: Double?, priceDE: Double?, priceEU: Double?,
         priceFR: Double?, priceES: Double?, priceIT: Double?) {
        self.id             = "sealed-\(id)"
        self.name           = name
        self.number         = ""
        self.setName        = SetTranslator.localizedSetName(id: setId, fallback: setName)
        self.setId          = setId
        self.imageURL       = image
        self.rarity         = "Sealed"
        self.price          = priceDE ?? price
        self.priceDE        = priceDE
        self.priceEU        = priceEU
        self.priceFR        = priceFR
        self.priceES        = priceES
        self.priceIT        = priceIT
        self.avg7           = nil
        self.avg30          = nil
        self.cardmarketURL  = cmURL
        self.psaPrice10     = nil
        self.psaPrice9      = nil
        self.psaPrice8      = nil
        self.cgcPrice10     = nil
        self.cgcPrice9      = nil
        self.bgsPrice10     = nil
        self.bgsPrice10Pristine = nil
        self.bgsPrice9      = nil
        self.seriesName     = seriesName
        self.episodeName    = episodeName
        self.totalCards     = nil
        self.isSealed       = true
    }
}

final class LocalCardDatabase {
    static let shared = LocalCardDatabase()

    private var db: OpaquePointer?

    private init() {
        openDatabase()
    }

    // MARK: - Setup

    private func openDatabase() {
        guard let bundleURL = Bundle.main.url(forResource: "tcggo", withExtension: "db") else {
            print("[LocalCardDatabase] ❌ tcggo.db nicht im Bundle gefunden")
            return
        }

        // DB muss im beschreibbaren Documents-Ordner liegen (WAL-Modus braucht Schreibrechte)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destURL = docs.appendingPathComponent("tcggo.db")

        let needsCopy: Bool
        if FileManager.default.fileExists(atPath: destURL.path) {
            // Bundle-DB neuer oder größer → ersetzen
            let bundleSize = (try? bundleURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            let docsSize   = (try? destURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            needsCopy = bundleSize > docsSize
            if needsCopy { print("[LocalCardDatabase] 🔄 Neuere DB im Bundle – ersetze Documents-Kopie") }
        } else {
            needsCopy = true
        }

        if needsCopy {
            try? FileManager.default.removeItem(at: destURL)
            do {
                try FileManager.default.copyItem(at: bundleURL, to: destURL)
                print("[LocalCardDatabase] ✅ DB nach Documents kopiert")
            } catch {
                print("[LocalCardDatabase] ❌ Kopieren fehlgeschlagen: \(error)")
                return
            }
        }

        if sqlite3_open(destURL.path, &db) != SQLITE_OK {
            print("[LocalCardDatabase] ❌ Fehler beim Öffnen: \(String(cString: sqlite3_errmsg(db)))")
            db = nil
        } else {
            print("[LocalCardDatabase] ✅ DB geöffnet: \(destURL.path)")
        }
    }

    // MARK: - Search Cards

    func searchCards(query: String) -> [CardSearchResult] {
        guard let db else { return [] }

        let sql = """
            SELECT c.id, c.name, c.name_numbered, c.card_number, c.rarity, c.supertype,
                   c.image, c.tcggo_url, c.link_cardmarket,
                   c.cm_lowest_nm, c.cm_lowest_nm_de, c.cm_lowest_nm_eu,
                   c.cm_lowest_nm_fr, c.cm_lowest_nm_es, c.cm_lowest_nm_it,
                   c.cm_avg_7d, c.cm_avg_30d,
                   c.psa10, c.psa9, c.psa8,
                   c.cgc10, c.cgc9,
                   c.bgs9,
                   e.id, e.name, e.series_name, e.cards_total
            FROM cards c
            LEFT JOIN episodes e ON c.episode_id = e.id
            WHERE c.name LIKE ? OR c.name_numbered LIKE ?
            ORDER BY e.released_at DESC, c.cm_lowest_nm DESC
            LIMIT 50
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        let pattern = "%\(query)%"
        sqlite3_bind_text(stmt, 1, (pattern as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (pattern as NSString).utf8String, -1, nil)

        return collectCards(stmt: stmt)
    }

    // MARK: - Search by Set

    func searchCardsBySet(episodeId: Int) -> [CardSearchResult] {
        guard let db else { return [] }

        let sql = """
            SELECT c.id, c.name, c.name_numbered, c.card_number, c.rarity, c.supertype,
                   c.image, c.tcggo_url, c.link_cardmarket,
                   c.cm_lowest_nm, c.cm_lowest_nm_de, c.cm_lowest_nm_eu,
                   c.cm_lowest_nm_fr, c.cm_lowest_nm_es, c.cm_lowest_nm_it,
                   c.cm_avg_7d, c.cm_avg_30d,
                   c.psa10, c.psa9, c.psa8,
                   c.cgc10, c.cgc9,
                   c.bgs9,
                   e.id, e.name, e.series_name, e.cards_total
            FROM cards c
            LEFT JOIN episodes e ON c.episode_id = e.id
            WHERE c.episode_id = ?
            ORDER BY CAST(c.card_number AS INTEGER) ASC
            LIMIT 300
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(episodeId))
        return collectCards(stmt: stmt)
    }

    // MARK: - Search Products

    func searchProducts(query: String) -> [CardSearchResult] {
        guard let db else { return [] }

        let sql = """
            SELECT p.id, p.name, p.slug,
                   p.image, p.tcggo_url, p.link_cardmarket,
                   p.cm_lowest, p.cm_lowest_de, p.cm_lowest_eu,
                   p.cm_lowest_fr, p.cm_lowest_es, p.cm_lowest_it,
                   e.id, e.name, e.series_name
            FROM products p
            LEFT JOIN episodes e ON p.episode_id = e.id
            WHERE p.name LIKE ?
            ORDER BY e.released_at DESC
            LIMIT 30
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        let pattern = "%\(query)%"
        sqlite3_bind_text(stmt, 1, (pattern as NSString).utf8String, -1, nil)

        return collectProducts(stmt: stmt)
    }

    func searchProductsBySet(episodeId: Int) -> [CardSearchResult] {
        guard let db else { return [] }

        let sql = """
            SELECT p.id, p.name, p.slug,
                   p.image, p.tcggo_url, p.link_cardmarket,
                   p.cm_lowest, p.cm_lowest_de, p.cm_lowest_eu,
                   p.cm_lowest_fr, p.cm_lowest_es, p.cm_lowest_it,
                   e.id, e.name, e.series_name
            FROM products p
            LEFT JOIN episodes e ON p.episode_id = e.id
            WHERE p.episode_id = ?
            ORDER BY p.name ASC
            LIMIT 50
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(episodeId))
        return collectProducts(stmt: stmt)
    }

    // MARK: - Episodes

    // MARK: - Price History

    struct PricePoint {
        let date: String
        let cmLow: Double?
        let tcpMarket: Double?
    }

    func priceHistory(tcggoCardId: Int) -> [PricePoint] {
        guard let db else { return [] }
        let sql = """
            SELECT ph.date, ph.cm_low, ph.tcp_market
            FROM price_history ph
            JOIN cards c ON c.cardmarket_id = ph.cardmarket_id
            WHERE c.id = ?
            ORDER BY ph.date ASC
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(tcggoCardId))
        var results: [PricePoint] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let date = col(stmt, 0) ?? ""
            let cmLow = colDouble(stmt, 1)
            let tcp = colDouble(stmt, 2)
            results.append(PricePoint(date: date, cmLow: cmLow, tcpMarket: tcp))
        }
        return results
    }

    /// Findet eine Episode anhand eines Namens.
    /// Bevorzugt exakte Treffer, dann kürzeste LIKE-Übereinstimmung.
    /// Lädt alle Preisdaten einer einzelnen Karte anhand ihrer tcggo-ID.
    func cardById(id: Int) -> CardSearchResult? {
        guard let db else { return nil }

        let sql = """
            SELECT c.id, c.name, c.name_numbered, c.card_number, c.rarity, c.supertype,
                   c.image, c.tcggo_url, c.link_cardmarket,
                   c.cm_lowest_nm, c.cm_lowest_nm_de, c.cm_lowest_nm_eu,
                   c.cm_lowest_nm_fr, c.cm_lowest_nm_es, c.cm_lowest_nm_it,
                   c.cm_avg_7d, c.cm_avg_30d,
                   c.psa10, c.psa9, c.psa8,
                   c.cgc10, c.cgc9,
                   c.bgs9,
                   e.id, e.name, e.series_name, e.cards_total
            FROM cards c
            LEFT JOIN episodes e ON c.episode_id = e.id
            WHERE c.id = ?
            LIMIT 1
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(id))
        let results = collectCards(stmt: stmt)
        return results.first
    }

    /// Gibt cards_printed_total für eine Episode zurück (z.B. 191 bei Surging Sparks).
    func printedTotal(forEpisodeId id: Int) -> Int? {
        guard let db else { return nil }
        let sql = "SELECT cards_printed_total FROM episodes WHERE id = ? LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(id))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        let val = Int(sqlite3_column_int(stmt, 0))
        return val > 0 ? val : nil
    }

    func findEpisode(name: String) -> (id: Int, name: String)? {
        guard let db else { return nil }

        // Exakter Match zuerst (case-insensitiv), dann LIKE – kürzester Name gewinnt
        let sql = """
            SELECT id, name FROM episodes
            WHERE LOWER(name) = LOWER(?) OR name LIKE ?
            ORDER BY
                CASE WHEN LOWER(name) = LOWER(?) THEN 0 ELSE 1 END,
                LENGTH(name) ASC
            LIMIT 1
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        let exact   = name as NSString
        let pattern = "%\(name)%" as NSString
        sqlite3_bind_text(stmt, 1, exact.utf8String,   -1, nil)
        sqlite3_bind_text(stmt, 2, pattern.utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, exact.utf8String,   -1, nil)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        let id     = Int(sqlite3_column_int(stmt, 0))
        let epName = String(cString: sqlite3_column_text(stmt, 1))
        return (id, epName)
    }

    /// Sucht Karten innerhalb eines Sets nach Kartenname.
    func searchCardsInSet(episodeId: Int, cardName: String) -> [CardSearchResult] {
        guard let db else { return [] }

        let sql = """
            SELECT c.id, c.name, c.name_numbered, c.card_number, c.rarity, c.supertype,
                   c.image, c.tcggo_url, c.link_cardmarket,
                   c.cm_lowest_nm, c.cm_lowest_nm_de, c.cm_lowest_nm_eu,
                   c.cm_lowest_nm_fr, c.cm_lowest_nm_es, c.cm_lowest_nm_it,
                   c.cm_avg_7d, c.cm_avg_30d,
                   c.psa10, c.psa9, c.psa8,
                   c.cgc10, c.cgc9, c.bgs9,
                   e.id, e.name, e.series_name, e.cards_total
            FROM cards c
            LEFT JOIN episodes e ON c.episode_id = e.id
            WHERE c.episode_id = ? AND (c.name LIKE ? OR c.name_numbered LIKE ?)
            ORDER BY CAST(c.card_number AS INTEGER) ASC
            LIMIT 100
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        let pattern = "%\(cardName)%" as NSString
        sqlite3_bind_int(stmt,  1, Int32(episodeId))
        sqlite3_bind_text(stmt, 2, pattern.utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, pattern.utf8String, -1, nil)

        return collectCards(stmt: stmt)
    }

    /// Versucht einen Episode-Namen in einem Query-String zu finden.
    /// Probiert alle zusammenhängenden Wortfolgen (längste zuerst), bevorzugt exakte Treffer.
    /// Gibt (episodeId, verbleibender Kartenname) zurück.
    func findEpisodeInQuery(_ query: String) -> (episodeId: Int, cardName: String)? {
        let words = query.lowercased().components(separatedBy: " ").filter { !$0.isEmpty }
        guard !words.isEmpty else { return nil }

        // Nicht-Karten-Wörter die vom Kartenname-Rest gefiltert werden
        let stopWords: Set<String> = ["set", "edition", "the", "a", "an", "der", "die", "das"]

        var bestMatch: (episodeId: Int, cardName: String, isExact: Bool)? = nil

        for length in stride(from: words.count, through: 1, by: -1) {
            for start in 0...(words.count - length) {
                let candidate = words[start..<(start + length)].joined(separator: " ")
                guard candidate.count >= 3 else { continue }

                if let ep = findEpisode(name: candidate) {
                    let remainingWords = Array(words[0..<start]) + Array(words[(start + length)...])
                    let filtered = remainingWords.filter { !stopWords.contains($0) }
                    let cardName = filtered.joined(separator: " ").capitalized
                    let isExact  = ep.name.lowercased() == candidate.lowercased()

                    if isExact { return (ep.id, cardName) }
                    if bestMatch == nil { bestMatch = (ep.id, cardName, false) }
                }
            }
        }
        return bestMatch.map { ($0.episodeId, $0.cardName) }
    }

    // MARK: - Helpers

    private func collectCards(stmt: OpaquePointer?) -> [CardSearchResult] {
        var results: [CardSearchResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let result = CardSearchResult(
                dbCard:     Int(sqlite3_column_int(stmt, 0)),
                name:       col(stmt, 1) ?? "",
                number:     col(stmt, 3) ?? "",
                setId:      Int(sqlite3_column_int(stmt, 23)),
                setName:    col(stmt, 24) ?? "",
                episodeName: col(stmt, 24) ?? "",
                seriesName: col(stmt, 25),
                totalCards: sqlite3_column_type(stmt, 26) != SQLITE_NULL
                            ? Int(sqlite3_column_int(stmt, 26)) : nil,
                image:      col(stmt, 6) ?? "",
                cmURL:      col(stmt, 8) ?? col(stmt, 7) ?? "",
                price:      colDouble(stmt, 9),
                priceDE:    colDouble(stmt, 10),
                priceEU:    colDouble(stmt, 11),
                priceFR:    colDouble(stmt, 12),
                priceES:    colDouble(stmt, 13),
                priceIT:    colDouble(stmt, 14),
                avg7:       colDouble(stmt, 15),
                avg30:      colDouble(stmt, 16),
                psa10:      colDouble(stmt, 17),
                psa9:       colDouble(stmt, 18),
                psa8:       colDouble(stmt, 19),
                cgc10:      colDouble(stmt, 20),
                cgc9:       colDouble(stmt, 21),
                bgs9:       colDouble(stmt, 22),
                rarity:     col(stmt, 4) ?? ""
            )
            results.append(result)
        }
        return results
    }

    private func collectProducts(stmt: OpaquePointer?) -> [CardSearchResult] {
        var results: [CardSearchResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let result = CardSearchResult(
                dbProduct:   Int(sqlite3_column_int(stmt, 0)),
                name:        col(stmt, 1) ?? "",
                setId:       Int(sqlite3_column_int(stmt, 12)),
                setName:     col(stmt, 13) ?? "",
                episodeName: col(stmt, 13) ?? "",
                seriesName:  col(stmt, 14),
                image:       col(stmt, 3) ?? "",
                cmURL:       col(stmt, 5) ?? col(stmt, 4) ?? "",
                price:       colDouble(stmt, 6),
                priceDE:     colDouble(stmt, 7),
                priceEU:     colDouble(stmt, 8),
                priceFR:     colDouble(stmt, 9),
                priceES:     colDouble(stmt, 10),
                priceIT:     colDouble(stmt, 11)
            )
            results.append(result)
        }
        return results
    }

    private func col(_ stmt: OpaquePointer?, _ idx: Int32) -> String? {
        guard sqlite3_column_type(stmt, idx) != SQLITE_NULL,
              let cStr = sqlite3_column_text(stmt, idx) else { return nil }
        return String(cString: cStr)
    }

    private func colDouble(_ stmt: OpaquePointer?, _ idx: Int32) -> Double? {
        guard sqlite3_column_type(stmt, idx) != SQLITE_NULL else { return nil }
        return sqlite3_column_double(stmt, idx)
    }
}
