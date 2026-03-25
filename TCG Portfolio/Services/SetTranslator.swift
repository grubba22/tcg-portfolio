import Foundation

struct SetTranslator {

    // MARK: - Known Set Cache (Episode ID → Set Info)
    // Neue Sets hier eintragen – DE- und EN-Name werden automatisch als Suchkeywords erkannt.
    static let knownSets: [Int: SetInfo] = [
        172: SetInfo(id: 172, nameDE: "Stürmische Funken",       nameEN: "Surging Sparks",        code: "SSP"),
        212: SetInfo(id: 212, nameDE: "Prismatische Entwicklungen", nameEN: "Prismatic Evolutions",  code: "PRE"),
        231: SetInfo(id: 231, nameDE: "Fatale Flammen",           nameEN: "Phantasmal Flames",     code: "PHF"),
        220: SetInfo(id: 220, nameDE: "Reisegefährten",           nameEN: "Journey Together",      code: "JTG"),
        221: SetInfo(id: 221, nameDE: "Ewige Rivalen",            nameEN: "Destined Rivals",       code: "DRV"),
        17:  SetInfo(id: 17,  nameDE: "Obsidianflammen",          nameEN: "Obsidian Flames",       code: "OBF"),
        18:  SetInfo(id: 18,  nameDE: "Entwicklungen in Paldea",  nameEN: "Paldea Evolved",        code: "PAL"),
        19:  SetInfo(id: 19,  nameDE: "Karmesin & Purpur",        nameEN: "Scarlet & Violet",      code: "SVI"),
        20:  SetInfo(id: 20,  nameDE: "Paradoxrift",              nameEN: "Paradox Rift",          code: "PAR"),
        21:  SetInfo(id: 21,  nameDE: "Paldeas Schicksale",       nameEN: "Paldean Fates",         code: "PAF"),
        22:  SetInfo(id: 22,  nameDE: "Gewalten der Zeit",        nameEN: "Temporal Forces",       code: "TEF"),
        23:  SetInfo(id: 23,  nameDE: "Maskerade im Zwielicht",   nameEN: "Twilight Masquerade",   code: "TWM"),
        24:  SetInfo(id: 24,  nameDE: "Nebel der Sagen",          nameEN: "Shrouded Fable",        code: "SFA"),
        25:  SetInfo(id: 25,  nameDE: "Stellar Krone",            nameEN: "Stellar Crown",         code: "SCR"),
    ]

    // MARK: - Manual Keyword Aliases
    // NUR für Abkürzungen, Singularvarianten und Sonderfälle, die NICHT aus knownSets ableitbar sind.
    // Vollständige DE/EN-Namen werden automatisch via matchSet() erkannt.
    private static let deKeywords: [(keywords: [String], id: Int)] = [
        (["ssf", "ssp"],                                                   172),
        (["pre"],                                                          212),
        (["prismatische entwicklung"],                                     212), // Singular
        (["phf"],                                                          231),
        (["phantomflammen", "phantomflamme"],                              231), // alter DE-Name
        (["jtg"],                                                          220),
        (["gemeinsame reise"],                                             220), // alter DE-Name
        (["drv"],                                                          221),
        (["ewige rival"],                                                  221),
        (["obf"],                                                          17),
        (["obsidianflamme"],                                               17),  // Singular
        (["pal"],                                                          18),
        (["paldea evolved"],                                               18),
        (["svi"],                                                          19),
        (["par"],                                                          20),
        (["paf", "schicksale", "paldea schicksale"],                       21),
        (["tef"],                                                          22),
        (["zeitliche kräfte", "zeitliche kraft", "temporal forces"],       22),  // alter DE-Name
        (["twm", "masken des wandels", "twilight masquerade"],             23),  // alter DE-Name
        (["sfa"],                                                          24),
        (["siedende fusionen", "siedende fusion", "shrouded fable"],       24),  // alter DE-Name
        (["scr"],                                                          25),
        (["stellar crown"],                                                25),  // alter DE-Name
    ]

    // MARK: - Auto-Keyword-Generierung aus knownSets

    /// Leitet automatisch Suchkeywords aus den Set-Infos ab:
    /// DE-Name, EN-Name, Umlaut-Varianten, Sub-Set-Kurzformen (ohne "Karmesin & Purpur – ").
    private static func autoKeywords(for setInfo: SetInfo) -> [String] {
        var kws: [String] = []
        let de = setInfo.nameDE.lowercased()
        let en = setInfo.nameEN.lowercased()

        kws.append(de)
        kws.append(en)

        // Sub-Set-Prefix entfernen: "karmesin & purpur – masken des wandels" → "masken des wandels"
        for prefix in ["karmesin & purpur – ", "scarlet & violet – "] {
            if de.hasPrefix(prefix) { kws.append(String(de.dropFirst(prefix.count))) }
            if en.hasPrefix(prefix) { kws.append(String(en.dropFirst(prefix.count))) }
        }

        // Umlaut-tolerante Variante (ä→a, ö→o, ü→u, ß→ss)
        let deNorm = de
            .replacingOccurrences(of: "ä", with: "a")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ß", with: "ss")
        if deNorm != de { kws.append(deNorm) }

        // Deduplizieren, Mindestlänge 4, längste zuerst (verhindert Partial-Matches)
        return Array(Set(kws)).filter { $0.count >= 4 }.sorted { $0.count > $1.count }
    }

    // MARK: - Unified Set Matcher

    /// Findet das passende Set in einem lowercased Query-String.
    /// Alle Kandidaten (Auto-Keywords + manuelle Aliases) werden nach Länge absteigend geprüft,
    /// damit z.B. "paradoxrift" (10 Zeichen) vor "par" (3 Zeichen) matcht.
    static func matchSet(in lower: String) -> (id: Int, keyword: String)? {
        var candidates: [(keyword: String, id: Int)] = []

        // Auto-Keywords aus knownSets (DE-Name, EN-Name, Varianten)
        for setInfo in knownSets.values {
            for kw in autoKeywords(for: setInfo) {
                candidates.append((kw, setInfo.id))
            }
        }

        // Manuelle Aliases/Abkürzungen
        for (keywords, setId) in deKeywords {
            for kw in keywords {
                candidates.append((kw, setId))
            }
        }

        // Längste Keywords zuerst prüfen – verhindert Partial-Matches wie "par" in "paradoxrift"
        let words = lower.components(separatedBy: CharacterSet.alphanumerics.inverted)
        for (keyword, id) in candidates.sorted(by: { $0.keyword.count > $1.keyword.count }) {
            if keyword.count <= 3 {
                // Kurze Codes (≤ 3 Zeichen) nur als eigenständiges Wort matchen,
                // damit "par" nicht "Parasect" trifft, "pal" nicht "Palossand" etc.
                if words.contains(keyword) { return (id, keyword) }
            } else {
                if lower.contains(keyword) { return (id, keyword) }
            }
        }

        return nil
    }

    // MARK: - Sealed Product Translations

    /// Produkt-Typ-Mappings DE → EN.
    /// WICHTIG: Längere/spezifischere Phrasen MÜSSEN vor kürzeren stehen.
    private static let productTypes: [(de: String, en: String)] = [
        // ETB / TTB – Case zuerst (länger als ETB allein)
        ("10 top trainer box case",   "10 Elite Trainer Box Case"),
        ("10 elite trainer box case", "10 Elite Trainer Box Case"),
        ("top trainer box case",      "Elite Trainer Box Case"),
        ("elite trainer box case",    "Elite Trainer Box Case"),
        ("top trainer box",           "Elite Trainer Box"),
        ("elite trainer box",         "Elite Trainer Box"),
        ("etb",                       "Elite Trainer Box"),
        ("ttb",                       "Elite Trainer Box"),
        // Display-Varianten (spezifisch vor generisch)
        ("booster bundle display",    "Booster Bundle Display"),
        ("mini tin display",          "Mini Tin Display"),
        ("display",                   "Booster Box"),
        ("booster box",               "Booster Box"),
        // Booster-Varianten
        ("booster bundle",            "Booster Bundle"),
        ("booster",                   "Booster"),
        // Collections
        ("super-premium collection",  "Super-Premium Collection"),
        ("super premium collection",  "Super-Premium Collection"),
        ("super-premium kollektion",  "Super-Premium Collection"),
        ("super premium kollektion",  "Super-Premium Collection"),
        ("binder collection",         "Binder Collection"),
        ("binder kollektion",         "Binder Collection"),
        ("poster kollektion",         "Poster Collection"),
        ("poster collection",         "Poster Collection"),
        ("kollektion box",            "Collection Box"),
        ("collection box",            "Collection Box"),
        // Sonstiges
        ("surprise box",              "Surprise Box"),
        ("mini tin",                  "Mini Tin"),
        ("build and battle",          "Build and Battle"),
        ("poster bundle",             "Poster Bundle"),
        ("blister",                   "Blister"),
    ]

    private static let sealedKeywords: [String] = [
        "trainer box", "etb", "ttb",
        "display", "booster box", "booster bundle", "booster",
        "super-premium", "super premium", "binder kollektion", "binder collection",
        "poster kollektion", "poster collection", "poster bundle",
        "collection box", "kollektion box",
        "surprise box", "mini tin", "blister", "build and battle",
    ]

    /// Prüft, ob die Anfrage ein Sealed-Produkt beschreibt.
    static func isSealedProduct(query: String) -> Bool {
        let lower = query.lowercased()
        return sealedKeywords.contains { lower.contains($0) }
    }

    /// Übersetzt eine Sealed-Produkt-Anfrage vollständig ins Englische.
    /// "paldeas schicksale top trainer box" → "Paldean Fates Elite Trainer Box"
    static func translateSealedQuery(query: String) -> String? {
        guard isSealedProduct(query: query) else { return nil }

        let lower = query.lowercased()
        var remaining = lower

        // Set erkennen und aus remaining entfernen
        var setNameEN: String? = nil
        if let match = matchSet(in: lower) {
            setNameEN = knownSets[match.id]?.nameEN
            remaining = remaining
                .replacingOccurrences(of: match.keyword, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Produkt-Typ übersetzen (längste Matches zuerst durch Array-Reihenfolge)
        var productEN: String? = nil
        for (de, en) in productTypes {
            if remaining.contains(de) {
                productEN = en
                remaining = remaining
                    .replacingOccurrences(of: de, with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        guard setNameEN != nil || productEN != nil else { return nil }

        // Set-Prefix: bekannter EN-Name ODER verbleibender Text (z.B. "151", "sv3")
        let prefix = setNameEN ?? remaining
        let parts = [prefix.isEmpty ? nil : prefix.capitalized, productEN]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }

    struct SetInfo {
        let id: Int
        let nameDE: String
        let nameEN: String
        let code: String
    }

    // MARK: - Parse search query into card name + set ID

    struct ParsedQuery {
        let cardName: String
        let setId: Int?
        let setName: String?
        let setNameEN: String?
    }

    static func parse(query: String) -> ParsedQuery {
        let lower = query.lowercased()
        // Bindestrich-normalisierte Variante: "mega entwicklung" matcht "mega-entwicklung"
        let lowerNorm = lower.replacingOccurrences(of: "-", with: " ")

        // 1. Bekannte Sets via knownSets + deKeywords (haben Episode-ID)
        if let match = matchSet(in: lower) {
            let cardName = lower
                .replacingOccurrences(of: match.keyword, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .capitalized
            let setInfo = knownSets[match.id]
            return ParsedQuery(
                cardName: cardName,
                setId: match.id,
                setName: setInfo?.nameDE,
                setNameEN: setInfo?.nameEN
            )
        }

        // 2. Fallback: DE-Name aus deToEN (Sets ohne bekannte Episode-ID, z.B. "Erhabene Helden")
        // Bindestriche normalisiert: "mega entwicklung" → matcht "mega-entwicklung"
        for (de, en) in deToEN.sorted(by: { $0.key.count > $1.key.count }) {
            let deNorm = de.replacingOccurrences(of: "-", with: " ")
            guard lowerNorm.contains(deNorm) else { continue }
            let cardName = lowerNorm
                .replacingOccurrences(of: deNorm, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .capitalized
            return ParsedQuery(
                cardName: cardName,
                setId: nil,
                setName: enToDE[en],
                setNameEN: en
            )
        }

        // 3. Fallback: EN-Name aus enToDE (User tippt englischen Set-Namen, z.B. "mega evolution")
        for (en, de) in enToDE.sorted(by: { $0.key.count > $1.key.count }) {
            guard en.count >= 4, lower.contains(en) else { continue }
            let cardName = lower
                .replacingOccurrences(of: en, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .capitalized
            return ParsedQuery(
                cardName: cardName,
                setId: nil,
                setName: de,
                setNameEN: en
            )
        }

        return ParsedQuery(cardName: query, setId: nil, setName: nil, setNameEN: nil)
    }

    // MARK: - DE → EN Reverse-Map (für Sets ohne bekannte API-Episode-ID)

    /// Umgekehrte Tabelle: Deutscher Set-Name (lowercase) → Englischer Set-Name (lowercase).
    /// Wird in parse() genutzt damit "erhabene helden" → setNameEN = "ascended heroes".
    static let deToEN: [String: String] = Dictionary(uniqueKeysWithValues:
        enToDE.compactMap { en, de -> (String, String)? in
            let deLower = de.lowercased()
            guard deLower != en else { return nil }  // identische DE/EN überspringen (z.B. "Celebrations")
            return (deLower, en)
        }
    )

    static func setName(forId id: Int) -> String {
        knownSets[id]?.nameDE ?? "Set #\(id)"
    }

    static func setNameEN(forId id: Int) -> String {
        knownSets[id]?.nameEN ?? "Set #\(id)"
    }

    // MARK: - Vollständige EN→DE Übersetzungstabelle (für Sets ohne bekannte API-Episode-ID)

    /// Wird automatisch aus knownSets befüllt und um weitere Sets aus offiziellen Quellen ergänzt.
    /// Dient als Fallback in localizedSetName() wenn die episode.id nicht bekannt ist.
    static let enToDE: [String: String] = {
        // Basis: alle bereits bekannten Sets aus knownSets
        var map = Dictionary(uniqueKeysWithValues:
            knownSets.values.map { ($0.nameEN.lowercased(), $0.nameDE) }
        )
        // Ergänzung: weitere Sets aus offiziellen DE-Quellen (ohne bekannte API-ID)
        let extras: [(en: String, de: String)] = [
            // Karmesin & Purpur – zukünftige Sets
            ("Ascended Heroes",      "Erhabene Helden"),
            ("Black Bolt",           "Schwarzer Blitz"),
            ("White Flare",          "Weiße Flamme"),
            // Schwert & Schild
            ("Sword & Shield",       "Schwert & Schild"),
            ("Rebel Clash",          "Clash der Rebellen"),
            ("Darkness Ablaze",      "Flammende Finsternis"),
            ("Champion's Path",      "Weg des Champs"),
            ("Vivid Voltage",        "Farbenschock"),
            ("Shining Fates",        "Glänzendes Schicksal"),
            ("Battle Styles",        "Kampfstile"),
            ("Chilling Reign",       "Schaurige Herrschaft"),
            ("Evolving Skies",       "Drachenwandel"),
            ("Celebrations",         "Celebrations"),
            ("Fusion Strike",        "Fusionsangriff"),
            ("Brilliant Stars",      "Strahlende Sterne"),
            ("Astral Radiance",      "Astralglanz"),
            ("Pokémon GO",           "Pokémon GO"),
            ("Lost Origin",          "Verlorener Ursprung"),
            ("Silver Tempest",       "Silberne Sturmwinde"),
            ("Crown Zenith",         "Zenit der Könige"),
            // Sonne & Mond
            ("Sun & Moon",           "Sonne & Mond"),
            ("Guardians Rising",     "Stunde der Wächter"),
            ("Burning Shadows",      "Nacht in Flammen"),
            ("Shining Legends",      "Schimmernde Legenden"),
            ("Crimson Invasion",     "Aufziehen der Sturmröte"),
            ("Ultra Prism",          "Ultra-Prisma"),
            ("Forbidden Light",      "Grauen der Lichtfinsternis"),
            ("Celestial Storm",      "Sturm am Firmament"),
            ("Dragon Majesty",       "Majestät der Drachen"),
            ("Lost Thunder",         "Echo des Donners"),
            ("Team Up",              "Teams sind Trumpf"),
            ("Unbroken Bonds",       "Kräfte im Einklang"),
            ("Unified Minds",        "Bund der Gleichgesinnten"),
            ("Hidden Fates",         "Verborgenes Schicksal"),
            ("Cosmic Eclipse",       "Welten im Wandel"),
            // XY
            ("XY",                   "XY"),
            ("Flashfire",            "Flammenmeer"),
            ("Furious Fists",        "Fliegende Fäuste"),
            ("Phantom Forces",       "Phantomkräfte"),
            ("Primal Clash",         "Protoschock"),
            ("Roaring Skies",        "Drachenleuchten"),
            ("Ancient Origins",      "Ewiger Anfang"),
            ("BREAKthrough",         "TURBOstart"),
            ("BREAKpoint",           "TURBOfieber"),
            ("Fates Collide",        "Schicksalsschmiede"),
            ("Steam Siege",          "Dampfkessel"),
            ("Evolutions",           "Entwicklungen"),
            ("Generations",          "Generationen"),
            ("Double Crisis",        "Doppelte Krise"),
            ("Mega Evolution",       "Mega-Entwicklung"),
            // Schwarz & Weiß
            ("Black & White",        "Schwarz & Weiß"),
            ("Emerging Powers",      "Edler Angriff"),
            ("Noble Victories",      "Siegestrophäe"),
            ("Next Destinies",       "Schicksal der Nachfolger"),
            ("Dark Explorers",       "Ausgrabungen"),
            ("Dragons Exalted",      "Erhabene Drachen"),
            ("Dragon Vault",         "Drachentresor"),
            ("Boundaries Crossed",   "Grenzen des Kosmos"),
            ("Plasma Storm",         "Plasma-Sturm"),
            ("Plasma Freeze",        "Plasma-Eis"),
            ("Plasma Blast",         "Plasma-Blast"),
            ("Legendary Treasures",  "Legendäre Schätze"),
            ("Radiant Collection",   "Strahlende Kollektion"),
        ]
        for (en, de) in extras { map[en.lowercased()] = de }
        return map
    }()

    /// Gibt den deutschen Set-Namen zurück.
    /// 1. Lookup via API-Episode-ID (knownSets)
    /// 2. Lookup via englischem Namen (enToDE) – greift für Sets ohne bekannte ID
    /// 3. Fallback: englischer Originalname
    static func localizedSetName(id: Int, fallback: String) -> String {
        if id != 0, let info = knownSets[id] { return info.nameDE }
        return enToDE[fallback.lowercased()] ?? fallback
    }

    /// Ersetzt den englischen Set-Namen in einem Produktnamen durch den deutschen.
    /// "Shining Fates Elite Trainer Box" → "Glänzendes Schicksal Elite Trainer Box"
    /// Funktioniert auch für Sets ohne bekannte API-Episode-ID via enToDE.
    static func localizeProductName(_ name: String, setId: Int) -> String {
        // 1. Direkt via setId (bekannte Sets)
        if let setInfo = knownSets[setId] {
            let result = name.replacingOccurrences(of: setInfo.nameEN, with: setInfo.nameDE, options: .caseInsensitive)
            if result != name { return result }
        }
        // 2. Alle EN-Namen in enToDE durchsuchen (längste zuerst = kein Partial-Match)
        let nameLower = name.lowercased()
        for (en, de) in enToDE.sorted(by: { $0.key.count > $1.key.count }) {
            guard en != de.lowercased(), nameLower.contains(en) else { continue }
            return name.replacingOccurrences(of: en, with: de, options: .caseInsensitive)
        }
        return name
    }

    // Sorted list for UI display
    static var allSets: [SetInfo] {
        knownSets.values.sorted { $0.nameDE < $1.nameDE }
    }
}
