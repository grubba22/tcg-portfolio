import SwiftUI
import Charts

// MARK: - Color Hex Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Design Tokens

extension Color {
    static let appBG   = Color(hex: "0e0e12")
    static let surface = Color(hex: "17171e")
    static let border  = Color(hex: "2a2a35")
    static let accent  = Color(hex: "f5c518")
    static let profit  = Color(hex: "34d87a")
    static let loss    = Color(hex: "ff5555")
    static let dim     = Color(hex: "7a7a8c")
}

extension ShapeStyle where Self == Color {
    static var accent:  Color { Color(hex: "f5c518") }
    static var profit:  Color { Color(hex: "34d87a") }
    static var loss:    Color { Color(hex: "ff5555") }
    static var dim:     Color { Color(hex: "7a7a8c") }
    static var surface: Color { Color(hex: "17171e") }
    static var appBG:   Color { Color(hex: "0e0e12") }
}

// MARK: - Surface Card Modifier

extension View {
    func surfaceCard() -> some View {
        self
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.border, lineWidth: 1))
    }
}

// MARK: - Cross-platform Helpers

extension View {
    func decimalKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

// MARK: - Currency Formatter

func formatEUR(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "EUR"
    f.locale = Locale(identifier: "de_DE")
    return f.string(from: NSNumber(value: value)) ?? String(format: "%.2f €", value)
}

// MARK: - Card Image View

struct CardImageView: View {
    let url: String
    var width: CGFloat = 100
    var height: CGFloat = 140

    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .empty:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.surface)
                    .overlay(ProgressView().tint(Color.dim))
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            case .failure:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.surface)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(Color.dim)
                    )
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Profit Label

struct ProfitLabel: View {
    let value: Double
    let percent: Double
    var showPercent: Bool = true

    private var isPos: Bool { value >= 0 }
    private var color: Color { isPos ? .profit : .loss }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isPos ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.bold())
            Text(formatEUR(abs(value)))
                .font(.caption.bold())
                .monospacedDigit()
            if showPercent {
                Text("(\(String(format: "%.1f", abs(percent)))%)")
                    .font(.caption2)
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Compact Profit Badge (inline, kein Hintergrund)

struct CompactProfitBadge: View {
    let value: Double
    let percent: Double

    private var isPos: Bool { value >= 0 }
    private var color: Color { isPos ? .profit : .loss }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: isPos ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .bold))
            Text("\(String(format: "%.1f", abs(percent)))%")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(color)
    }
}

// MARK: - Card Display Helpers

enum CardDisplay {
    enum Context { case search, portfolio }

    /// Ab dieser Zeichenanzahl erhält ein Name kleinere Schrift.
    static let longNameThreshold = 20

    /// Zentrale Formatierungsfunktion – kürzt Produkttyp-Suffixe ab.
    /// Längere Phrasen werden zuerst ersetzt (verhindert "ETB Case" → "TTB Case" ✓).
    /// - search:    "Elite/Top Trainer Box" → "TTB"
    /// - portfolio: zusätzlich "Booster Bundle" → "BB"
    static func format(_ name: String, context: Context = .search) -> String {
        var s = name
        s = s.replacingOccurrences(of: "Elite Trainer Box Case", with: "TTB Case", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "Top Trainer Box Case",   with: "TTB Case", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "Elite Trainer Box",      with: "TTB",      options: .caseInsensitive)
        s = s.replacingOccurrences(of: "Top Trainer Box",        with: "TTB",      options: .caseInsensitive)
        if context == .portfolio {
            s = s.replacingOccurrences(of: "Booster Bundle Display", with: "BB Display", options: .caseInsensitive)
            s = s.replacingOccurrences(of: "Booster Bundle",         with: "BB",         options: .caseInsensitive)
        }
        return s
    }

    /// Zwei Schriftgrößen: 14pt für kurze Namen (≤ 20 Zeichen), 12pt für lange.
    static func nameFont(for name: String) -> Font {
        .system(size: name.count > longNameThreshold ? 12 : 14, weight: .bold)
    }
}

// MARK: - Rarity Color

func rarityColor(_ rarity: String) -> Color {
    let l = rarity.lowercased()
    if l.contains("special illustration") || l.contains("sir") { return Color(hex: "a855f7") }
    if l.contains("hyper rare") || l.contains("ultra rare") { return Color.accent }
    if l.contains("double rare") { return Color(hex: "f97316") }
    if l.contains("rare") { return Color(hex: "60a5fa") }
    return Color.dim
}

// MARK: - Rarity Badge

struct RarityBadge: View {
    let rarity: String

    var body: some View {
        Text(rarity)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(rarityColor(rarity))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(rarityColor(rarity).opacity(0.15))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(rarityColor(rarity).opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Portfolio Line Chart

struct PortfolioLineChart: View {
    let data: [(date: Date, value: Double)]
    @State private var selectedRange: ChartRange = .week

    enum ChartRange: String, CaseIterable {
        case week        = "1W"
        case month       = "1M"
        case threeMonths = "3M"
        case sixMonths   = "6M"
        case all         = "MAX"

        func filtered(_ data: [(date: Date, value: Double)]) -> [(date: Date, value: Double)] {
            let now = Date()
            let calendar = Calendar.current
            let cutoff: Date?
            switch self {
            case .week:        cutoff = calendar.date(byAdding: .day,   value: -7,  to: now)
            case .month:       cutoff = calendar.date(byAdding: .month, value: -1,  to: now)
            case .threeMonths: cutoff = calendar.date(byAdding: .month, value: -3,  to: now)
            case .sixMonths:   cutoff = calendar.date(byAdding: .month, value: -6,  to: now)
            case .all:         cutoff = nil
            }
            if let cutoff { return data.filter { $0.date >= cutoff } }
            return data
        }
    }

    private var filtered: [(date: Date, value: Double)] {
        let f = selectedRange.filtered(data)
        return f.count >= 2 ? f : data
    }

    private var minVal: Double { filtered.map(\.value).min() ?? 0 }

    var body: some View {
        VStack(spacing: 12) {
            if filtered.count >= 2 {
                Chart {
                    ForEach(filtered, id: \.date) { entry in
                        LineMark(
                            x: .value("Datum", entry.date),
                            y: .value("Wert", entry.value)
                        )
                        .foregroundStyle(Color.accent)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Datum", entry.date),
                            yStart: .value("Min", minVal),
                            yEnd: .value("Wert", entry.value)
                        )
                        .foregroundStyle(LinearGradient(
                            colors: [Color.accent.opacity(0.4), Color.accent.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .frame(height: 130)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.surface)
                    .frame(height: 130)
                    .overlay(
                        Text("Noch keine Verlaufsdaten")
                            .font(.caption)
                            .foregroundStyle(Color.dim)
                    )
            }

            // Time range buttons
            HStack(spacing: 6) {
                ForEach(ChartRange.allCases, id: \.self) { range in
                    Button(range.rawValue) {
                        withAnimation(.spring(response: 0.25)) { selectedRange = range }
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedRange == range ? Color.accent : Color.surface)
                    .foregroundStyle(selectedRange == range ? Color(hex: "0e0e12") : Color.dim)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(
                            selectedRange == range ? Color.clear : Color.border,
                            lineWidth: 1
                        )
                    )
                    .animation(.spring(response: 0.25), value: selectedRange)
                }
            }
        }
        .padding(16)
        .surfaceCard()
    }
}
