import Foundation

struct PokemonTranslator {

    // DE → EN translation for common Pokémon names used in searches
    private static let translations: [String: String] = [
        // Gen 1
        "bisasam": "bulbasaur", "bisaknosp": "ivysaur", "bisaflor": "venusaur",
        "glumanda": "charmander", "glutexo": "charmeleon", "glurak": "charizard",
        "schiggy": "squirtle", "schillok": "wartortle", "turtok": "blastoise",
        "raupy": "caterpie", "metapod": "metapod", "smettbo": "butterfree",
        "hornliu": "weedle", "kokuna": "kakuna", "bibor": "beedrill",
        "taubsi": "pidgey", "tauboga": "pidgeotto", "tauboss": "pidgeot",
        "rattfratz": "rattata", "rattikarl": "raticate",
        "habitak": "spearow", "ibitak": "fearow",
        "pikachu": "pikachu", "raichu": "raichu",
        "sandkeks": "sandshrew", "sandamer": "sandslash",
        "nidoran": "nidoran", "nidorina": "nidorina", "nidoqueen": "nidoqueen",
        "nidorino": "nidorino", "nidoking": "nidoking",
        "pummeluff": "jigglypuff", "knuddeluff": "wigglytuff",
        "zubat": "zubat", "golbat": "golbat",
        "myrapla": "oddish", "duflor": "gloom", "giflor": "vileplume",
        "paras": "paras", "parasek": "parasect",
        "bluzuk": "venonat", "omot": "venomoth",
        "digda": "diglett", "digdri": "dugtrio",
        "mauzi": "meowth", "snobilikat": "persian",
        "golduck": "psyduck", "enton": "golduck",
        "äffchen": "mankey", "rasaff": "primeape",
        "fukano": "growlithe", "arkani": "arcanine",
        "quapsel": "poliwag", "quaputzi": "poliwhirl", "quappo": "poliwrath",
        "abra": "abra", "kadabra": "kadabra", "simsala": "alakazam",
        "machollo": "machop", "maschock": "machoke", "machomei": "machamp",
        "knofensa": "bellsprout", "ultrigaria": "weepinbell", "sarzenia": "victreebel",
        "tentacha": "tentacool", "tentoxa": "tentacruel",
        "geowaz": "geodude", "graviator": "graveler", "golem": "golem",
        "ponita": "ponyta", "gallopa": "rapidash",
        "flegmon": "slowpoke", "fleglair": "slowbro",
        "magnetilo": "magnemite", "magneton": "magneton",
        "uixx": "farfetchd",
        "dodu": "doduo", "dodri": "dodrio",
        "jurob": "seel", "jugong": "dewgong",
        "sleima": "grimer", "sleimok": "muk",
        "muschas": "shellder", "austos": "cloyster",
        "gastly": "gastly", "haunter": "haunter", "gengar": "gengar",
        "onix": "onix",
        "traumato": "drowzee", "hypno": "hypno",
        "krabby": "krabby", "kingler": "kingler",
        "voltobal": "voltorb", "lektrobal": "electrode",
        "owei": "exeggcute", "kokowei": "exeggutor",
        "tragosso": "cubone", "knogga": "marowak",
        "kicklee": "hitmonlee", "nockchan": "hitmonchan",
        "schlurp": "lickitung",
        "smogon": "koffing", "smogmog": "weezing",
        "rizeros": "rhyhorn", "rizard": "rhydon",
        "chansey": "chansey",
        "tangela": "tangela",
        "kangama": "kangaskhan",
        "seeper": "horsea", "seemon": "seadra",
        "goldini": "goldeen", "golking": "seaking",
        "sterndu": "staryu", "starmie": "starmie",
        "pantimos": "mr-mime",
        "sichlor": "scyther",
        "jurz": "jynx",
        "elektek": "electabuzz",
        "magmar": "magmar",
        "pinsir": "pinsir",
        "tauros": "tauros",
        "karpador": "magikarp", "garados": "gyarados",
        "lapras": "lapras",
        "ditto": "ditto",
        "evoli": "eevee",
        "aquana": "vaporeon", "blitza": "jolteon", "flamara": "flareon",
        "porygon": "porygon",
        "amonitas": "omanyte", "amoroso": "omastar",
        "kabuto": "kabuto", "kabutops": "kabutops",
        "aerodactyl": "aerodactyl",
        "relaxo": "snorlax",
        "arktos": "articuno", "zapdos": "zapdos", "lavados": "moltres",
        "dratini": "dratini", "dragonir": "dragonair", "dragoran": "dragonite",
        "mewtu": "mewtwo", "mew": "mew",

        // Gen 2
        "endivie": "chikorita", "bayleef": "bayleef", "meganie": "meganium",
        "feurigel": "cyndaquil", "igelavar": "quilava", "tornupto": "typhlosion",
        "karnimani": "totodile", "tyracroc": "croconaw", "impergator": "feraligatr",
        "hoothoot": "hoothoot", "noctuh": "noctowl",
        "ledyba": "ledyba", "ledian": "ledian",
        "webarak": "spinarak", "ariados": "ariados",
        "crobat": "crobat",
        "lanturn": "lanturn", "lampi": "chinchou",
        "pichu": "pichu", "cleffa": "cleffa", "fluffeluff": "igglybuff",
        "togepi": "togepi", "togetic": "togetic",
        "natu": "natu", "xatu": "xatu",
        "voltilamm": "mareep", "lampton": "flaaffy", "ampharos": "ampharos",
        "marigold": "bellossom", "hopplo": "marill", "azumarill": "azumarill",
        "mogelbaum": "sudowoodo",
        "politoed": "politoed",
        "hoppspross": "hoppip", "hubelupf": "skiploom", "papungha": "jumpluff",
        "griffel": "aipom",
        "sonnkern": "sunkern", "sonnflora": "sunflora",
        "yanma": "yanma",
        "dunsparce": "dunsparce",
        "granbull": "granbull", "snubbull": "snubbull",
        "qwilfish": "qwilfish",
        "scherox": "scizor",
        "magcargo": "magcargo", "schneckmag": "slugma",
        "quiekel": "swinub", "keifel": "piloswine",
        "corasonn": "corsola",
        "remoraid": "remoraid", "oktorok": "octillery",
        "delibird": "delibird",
        "mantax": "mantine",
        "magbrant": "magby", "elektiff": "elekid",
        "donphan": "donphan", "phanpy": "phanpy",
        "porygon2": "porygon2",
        "stantler": "stantler",
        "smaragrüx": "smeargle",
        "tyrogue": "tyrogue", "kapoera": "hitmontop",
        "togechampf": "togekiss", // actually togekiss is gen 4
        "miltank": "miltank",
        "blissey": "blissey",
        // Evoli-Entwicklungen Gen 2
        "nachtara": "umbreon", "psiana": "espeon",
        "raikou": "raikou", "entei": "entei", "suicune": "suicune",
        "larvitar": "larvitar", "pupitar": "pupitar", "despotar": "tyranitar",
        "lugia": "lugia", "ho-oh": "ho-oh",
        "celebi": "celebi",

        // Gen 3
        "geckarbor": "treecko", "reptain": "grovyle", "gewaldro": "sceptile",
        "flemmli": "torchic", "jungglut": "combusken", "lohgock": "blaziken",
        "hydropi": "mudkip", "moorabbel": "marshtomp", "sumpex": "swampert",
        "zigzachs": "zigzagoon", "geradaks": "linoone",
        "waumpel": "wurmple", "schaloko": "silcoon", "papinella": "beautifly",
        "cascoon": "cascoon", "pudox": "dustox",
        "loturzel": "lotad", "lombrero": "lombre", "kappalores": "ludicolo",
        "samurzel": "seedot", "nuzleaf": "nuzleaf", "tengulist": "shiftry",
        "schwalbini": "taillow", "schwalboss": "swellow",
        "wingull": "wingull", "pelipper": "pelipper",
        "ralts": "ralts", "kirlia": "kirlia", "gardevoir": "gardevoir",
        "knilz": "surskit", "masschiff": "masquerain",
        "waldyoro": "shroomish", "kapilz": "breloom",
        "bummelz": "slakoth", "muntier": "vigoroth", "letarking": "slaking",
        "nincada": "nincada", "ninjask": "ninjask", "ninjatom": "shedinja",
        "laulong": "whismur", "lärmon": "loudred", "exploud": "exploud",
        "makuhita": "makuhita", "hariyama": "hariyama",
        "azurill": "azurill", "nasgnet": "nosepass",
        "skitty": "skitty", "eneco": "delcatty",
        "zobiris": "sableye", "rohling": "mawile",
        "aron": "aron", "larion": "lairon", "aggron": "aggron",
        "meditie": "meditite", "meditalis": "medicham",
        "frizelbliz": "electrike", "voltenso": "manectric",
        "plusle": "plusle", "minun": "minun",
        "volbeat": "volbeat", "illumise": "illumise",
        "roselia": "roselia",
        "schlukwech": "gulpin", "schlukoth": "swalot",
        "wailmer": "wailmer", "wailord": "wailord",
        "camaub": "numel", "camerupt": "camerupt",
        "torkoal": "torkoal",
        "spoink": "spoink", "groink": "grumpig",
        "spinda": "spinda",
        "trapinch": "trapinch", "vibrava": "vibrava", "libelldra": "flygon",
        "kakteen": "cacnea", "kaktusara": "cacturne",
        "wablu": "swablu", "altaria": "altaria",
        "zangoose": "zangoose",
        "seviper": "seviper",
        "lunastein": "lunatone", "sonnfel": "solrock",
        "barschwa": "barboach", "welsar": "whiscash",
        "korpikrupp": "corphish", "krebutak": "crawdaunt",
        "liliep": "lileep", "wielie": "cradily",
        "anorith": "anorith", "armaldo": "armaldo",
        "kecleon": "kecleon",
        "shuppet": "shuppet", "banette": "banette",
        "zwirrlicht": "duskull", "dusclops": "dusclops",
        "tropius": "tropius",
        "chimecho": "chimecho",
        "absol": "absol",
        "schnebedeck": "wynaut",
        "snorunt": "snorunt", "glalie": "glalie",
        "spheal": "spheal", "sealeo": "sealeo", "walross": "walrein",
        "perlu": "clamperl", "muscadet": "huntail", "coreola": "gorebyss",
        "relicanth": "relicanth",
        "liebiskus": "luvdisc",
        "drachini": "bagon", "draschel": "shelgon", "brutalanda": "salamence",
        "metang": "beldum", "metargo": "metang", "metagross": "metagross",
        "regirock": "regirock", "regice": "regice", "registeel": "registeel",
        "latias": "latias", "latios": "latios",
        "kyogre": "kyogre", "groudon": "groudon", "rayquaza": "rayquaza",
        "jirachi": "jirachi", "deoxys": "deoxys",

        // Gen 4 popular
        "chelast": "turtwig", "chelcarain": "grotle", "chelterrar": "torterra",
        "panflam": "chimchar", "monferno": "monferno", "infernape": "infernape",
        "plinfa": "piplup", "empoleon": "empoleon",
        "staralili": "starly", "staravia": "staravia", "staraptor": "staraptor",
        "bidiza": "bidoof", "biber": "bibarel",
        "kricket": "kricketot", "kricketune": "kricketune",
        "shieldon": "shieldon", "bastiodon": "bastiodon",
        "cranidos": "cranidos", "rameidon": "rampardos",
        "lucario": "lucario", "riolu": "riolu",
        "glaceo": "glaceon", "leafeon": "leafeon",
        "gible": "gible", "knarksel": "gabite", "garchomp": "garchomp",
        "garmeil": "munchlax",
        "hippopotas": "hippopotas", "hippoterus": "hippowdon",
        "skorupi": "skorupi", "drapion": "drapion",
        "toxiquak": "toxicroak", "glibunkel": "croagunk",
        "weavile": "weavile", "snibunna": "sneasel",
        "togekiss": "togekiss",
        "gallade": "gallade",
        "roserade": "roserade",
        "magmortar": "magmortar", "elektross": "electivire",
        "giratina": "giratina", "dialga": "dialga", "palkia": "palkia",
        "darkrai": "darkrai", "arceus": "arceus", "shaymin": "shaymin",

        // Gen 5 popular
        "floink": "tepig", "ferkokel": "pignite", "eber": "emboar",
        "serpifeu": "snivy", "zerdaff": "servine", "serpiroyal": "serperior",
        "ottaro": "oshawott", "zwottronin": "dewott", "admurai": "samurott",
        "flampion": "reshiram", "zekrom": "zekrom",
        "zoroark": "zoroark", "zorua": "zorua",

        // Gen 6 popular
        "igamaro": "chespin", "igastarnix": "quilladin", "chesnaught": "chesnaught",
        "fynx": "fennekin", "rutena": "braixen", "fennexis": "delphox",
        "froxy": "froakie", "froshki": "frogadier", "quajutsu": "greninja",
        "xerneas": "xerneas", "yveltal": "yveltal", "zygarde": "zygarde",
        "sylveon": "sylveon",

        // Gen 7 popular
        "bauz": "rowlet", "dartiri": "dartrix", "silvarro": "decidueye",
        "hepplo": "litten", "flambino": "torracat", "fuegro": "incineroar",
        "robball": "popplio", "moorking": "brionne", "swimmer": "primarina",
        "cosmog": "cosmog", "cosmoem": "cosmoem", "solgaleo": "solgaleo", "lunala": "lunala",
        "marshadow": "marshadow",

        // Gen 8 popular
        "grookey": "grookey", "thwackey": "thwackey", "rillaboom": "rillaboom",
        "scorbunny": "scorbunny", "raboot": "raboot", "cinderace": "cinderace",
        "sobble": "sobble", "drizzile": "drizzile", "inteleon": "inteleon",
        "zacian": "zacian", "zamazenta": "zamazenta",
        "dragapult": "dragapult",

        // Gen 9 popular (Scarlet & Violet)
        "felori": "sprigatito", "floragato": "floragato", "meowscarada": "meowscarada",
        "krokel": "fuecoco", "crocalor": "crocalor", "skelokrok": "skeledirge",
        "kwaks": "quaxly", "kwabloso": "quaxwell", "quaquaval": "quaquaval",
        "koraidon": "koraidon", "miraidon": "miraidon",
        "gimmighoul": "gimmighoul", "gholdengo": "gholdengo",
        "lechonk": "lechonk", "oinkologne": "oinkologne",
        "pawmi": "pawmi", "pawmo": "pawmo", "pawmot": "pawmot",
    ]

    // EN → DE: automatisch aus translations aufgebaut (Laufzeit-Konstante)
    private static let reverseTranslations: [String: String] = {
        var map: [String: String] = [:]
        for (de, en) in translations {
            // Deutschen Namen für die Anzeige kapitalisieren
            let deDisplay = de.prefix(1).uppercased() + de.dropFirst()
            // Englischen Namen normalisieren: Bindestriche → Leerzeichen (mr-mime → mr mime)
            let enKey = en.replacingOccurrences(of: "-", with: " ")
            map[enKey] = deDisplay
        }
        return map
    }()

    // MARK: - DE → EN (für API-Suche)

    static func toEnglish(_ germanName: String) -> String {
        let lower = germanName.lowercased()
        return translations[lower] ?? germanName
    }

    static func bestSearchTerm(for query: String) -> String {
        let translated = toEnglish(query)
        if translated != query { return translated }

        // Fallback: Wortgrenzen-Matching (nie als Teilstring!).
        // Verhindert z.B. "charizard".contains("rizard") → Rhydon-Fehler.
        // Bindestriche normalisieren damit "Mega-Glurak" die Wörter ["mega","glurak"] ergibt.
        let normalized = query.lowercased()
            .replacingOccurrences(of: "-", with: " ")
        let queryWords = normalized
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        for (de, en) in translations {
            if queryWords.contains(de) {
                return en
            }
        }
        return query
    }

    // MARK: - EN → Lokal (für Anzeige nach API-Antwort)

    /// Übersetzt einen englischen Kartennamen in den lokalen Anzeigenamen.
    /// Beispiel: "Blastoise EX" → "Turtok EX"
    /// Unbekannte Namen werden unverändert zurückgegeben.
    static func toLocalName(_ englishCardName: String) -> String {
        // Vollständigen Namen normalisieren (Bindestriche → Leerzeichen, Lowercase)
        let fullNormalized = englishCardName
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")

        // Exakter Treffer (z. B. reiner Pokémon-Name ohne Suffix)
        if let hit = reverseTranslations[fullNormalized] {
            return hit
        }

        // Wörter aufspalten; längsten Präfix suchen der übersetzt werden kann
        let words = englishCardName.split(separator: " ").map(String.init)
        for length in stride(from: words.count, through: 1, by: -1) {
            let prefix = words.prefix(length)
                .joined(separator: " ")
                .lowercased()
                .replacingOccurrences(of: "-", with: " ")
            if let hit = reverseTranslations[prefix] {
                let suffix = words.dropFirst(length).joined(separator: " ")
                return suffix.isEmpty ? hit : "\(hit) \(suffix)"
            }
        }

        // Fallback: englischer Originalname
        return englishCardName
    }
}
