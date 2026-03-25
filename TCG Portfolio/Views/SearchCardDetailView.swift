import SwiftUI
import SwiftData
import Charts

// MARK: - Unified Card Detail View

struct SearchCardDetailView: View {

    // MARK: - Data Source

    enum Source {
        case portfolio(PortfolioCard)
        case preview(CardSearchResult)
    }

    let source: Source
    let portfolioVM: PortfolioViewModel
    let watchlistVM: WatchlistViewModel?

    // MARK: - Environment

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WatchlistItem.dateAdded, order: .reverse) private var watchlistItems: [WatchlistItem]
    @Environment(\.openURL) private var openURL

    // MARK: - Portfolio Editing State

    @State private var editingQuantity: Int
    @State private var editingPurchasePrice: String
    @State private var isEditingPrice = false
    @State private var showDeleteAlert = false

    // MARK: - Preview State

    @State private var showAddSheet = false

    // MARK: - eBay State

    @State private var ebayResult: EbayPriceResult?
    @State private var ebayItems: [EbaySoldItem] = []
    @State private var isFetchingEbay = false
    @State private var ebayError: String?
    @State private var showEbaySheet = false

    // Price History
    @State private var priceHistory: [LocalCardDatabase.PricePoint] = []
    @State private var chartMonths: Int = 3
    @State private var selectedChartDate: Date? = nil
    @State private var chartDragX: CGFloat = 0
    @State private var showFullscreenImage = false
    @State private var showRegionalPrices = false
    @State private var cardsPrintedTotal: Int? = nil
    @State private var portfolioIconScale: CGFloat = 1.0
    @Query private var portfolioCards: [PortfolioCard]

    // Live-Preisdaten für Portfolio-Karten (werden per API nachgeladen)
    @State private var livePsa10:    Double? = nil
    @State private var livePsa9:     Double? = nil
    @State private var livePsa8:     Double? = nil
    @State private var liveCgc10:    Double? = nil
    @State private var liveCgc9:     Double? = nil
    @State private var liveBgs10:    Double? = nil
    @State private var liveBgs10Pristine: Double? = nil
    @State private var liveBgs9:     Double? = nil
    @State private var livePriceFR:  Double? = nil
    @State private var livePriceES:  Double? = nil
    @State private var livePriceIT:  Double? = nil
    @State private var liveAvg7:     Double? = nil
    @State private var liveAvg30:    Double? = nil

    // MARK: - Inits

    init(portfolioCard: PortfolioCard, portfolioVM: PortfolioViewModel, watchlistVM: WatchlistViewModel? = nil) {
        self.source = .portfolio(portfolioCard)
        self.portfolioVM = portfolioVM
        self.watchlistVM = watchlistVM
        _editingQuantity = State(initialValue: portfolioCard.quantity)
        _editingPurchasePrice = State(initialValue: String(format: "%.2f", portfolioCard.purchasePrice))
    }

    init(searchCard: CardSearchResult, portfolioVM: PortfolioViewModel, watchlistVM: WatchlistViewModel? = nil) {
        self.source = .preview(searchCard)
        self.portfolioVM = portfolioVM
        self.watchlistVM = watchlistVM
        _editingQuantity = State(initialValue: 1)
        _editingPurchasePrice = State(initialValue: "0.00")
    }

    // MARK: - Computed Properties

    private var imageURL: String {
        switch source {
        case .portfolio(let c): return c.imageURL
        case .preview(let c):   return c.imageURL
        }
    }

    private var cardName: String {
        switch source {
        case .portfolio(let c): return CardDisplay.format(c.displayName, context: .portfolio)
        case .preview(let c):   return CardDisplay.format(c.name)
        }
    }

    private var setName: String {
        switch source {
        case .portfolio(let c): return c.localizedSetName   // gespeicherte Karten: DE via setId
        case .preview(let c):   return c.setName            // bereits in CardSearchResult lokalisiert
        }
    }

    private var cardNumber: String {
        switch source {
        case .portfolio(let c): return c.cardNumber
        case .preview(let c):   return c.number
        }
    }

    private var rarity: String {
        switch source {
        case .portfolio(let c): return c.rarity
        case .preview(let c):   return c.rarity
        }
    }

    private var lowestPriceDE: Double? {
        switch source {
        case .portfolio(let c): return c.currentPrice > 0 ? c.currentPrice : nil
        case .preview(let c):   return c.priceDE ?? c.price
        }
    }

    private var avg7: Double? {
        switch source {
        case .portfolio(let c):
            return c.avg7Price
                ?? liveAvg7
                ?? (c.average7Day != c.currentPrice ? c.average7Day : nil)
        case .preview(let c): return c.avg7
        }
    }

    private var avg30: Double? {
        switch source {
        case .portfolio(let c):
            return c.avg30Price
                ?? liveAvg30
                ?? (c.average30Day != c.currentPrice ? c.average30Day : nil)
        case .preview(let c): return c.avg30
        }
    }

    private var purchasePrice: Double? {
        if case .portfolio(let c) = source { return c.purchasePrice }
        return nil
    }

    private var cardmarketURL: String {
        switch source {
        case .portfolio(let c): return c.cardmarketURL
        case .preview(let c):   return c.cardmarketURL
        }
    }

    private var priceFR: Double? {
        if case .preview(let c) = source { return c.priceFR }
        return livePriceFR
    }

    private var priceES: Double? {
        if case .preview(let c) = source { return c.priceES }
        return livePriceES
    }

    private var priceIT: Double? {
        if case .preview(let c) = source { return c.priceIT }
        return livePriceIT
    }

    private var psaPrice10: Double? {
        if case .preview(let c) = source { return c.psaPrice10 }
        return livePsa10
    }

    private var psaPrice9: Double? {
        if case .preview(let c) = source { return c.psaPrice9 }
        return livePsa9
    }

    private var psaPrice8: Double? {
        if case .preview(let c) = source { return c.psaPrice8 }
        return livePsa8
    }

    private var cgcPrice10: Double? {
        if case .preview(let c) = source { return c.cgcPrice10 }
        return liveCgc10
    }

    private var cgcPrice9: Double? {
        if case .preview(let c) = source { return c.cgcPrice9 }
        return liveCgc9
    }

    private var bgsPrice10: Double? {
        if case .preview(let c) = source { return c.bgsPrice10 }
        return liveBgs10
    }

    private var bgsPrice10Pristine: Double? {
        if case .preview(let c) = source { return c.bgsPrice10Pristine }
        return liveBgs10Pristine
    }

    private var bgsPrice9: Double? {
        if case .preview(let c) = source { return c.bgsPrice9 }
        return liveBgs9
    }

    private var seriesName: String? {
        if case .preview(let c) = source { return c.seriesName }
        return nil
    }

    private var episodeName: String? {
        switch source {
        case .portfolio(let c): return c.localizedSetName   // immer DE, auch für alte Einträge
        case .preview(let c):   return c.setName            // setName ist bereits lokalisiert
        }
    }

    private var totalCards: Int? {
        if case .preview(let c) = source { return c.totalCards }
        return nil
    }

    private var isPortfolioMode: Bool {
        if case .portfolio = source { return true }
        return false
    }

    private var performance7: Double? {
        guard let price = lowestPriceDE, let a7 = avg7, a7 > 0 else { return nil }
        return ((price - a7) / a7) * 100
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Hero: Bild links + Karteninfos rechts
                HStack(alignment: .top, spacing: 16) {

                    // Linke Seite: Bild + Rarity
                    VStack(spacing: 8) {
                        CardImageView(url: imageURL, width: 120, height: 168)
                            .shadow(color: Color(hex: "a855f7").opacity(0.4),
                                    radius: 16, x: 0, y: 8)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showFullscreenImage = true
                                }
                            }
                        if !rarity.isEmpty {
                            RarityBadge(rarity: rarity)
                        }
                    }

                    // Rechte Seite: Name, Set, Karte, Portfolio
                    VStack(alignment: .leading, spacing: 14) {

                        // 1. NAME
                        Text(cardName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        // 2. SET
                        if let episode = episodeName {
                            cardInfoField("Set", episode)
                        }

                        // 3. KARTE
                        if !cardNumber.isEmpty {
                            let totalLabel: String = {
                                if let printed = cardsPrintedTotal {
                                    return "\(cardNumber) / \(printed)"
                                } else if let total = totalCards {
                                    return "\(cardNumber) / \(total)"
                                }
                                return cardNumber
                            }()
                            cardInfoField("Karte", totalLabel)
                        }

                        // 4. PORTFOLIO
                        portfolioStatusField
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                .padding(.top, 8)


                // CM Preise: Lowest + Ø 7 Tage + Ø 30 Tage
                cmPriceStatsSection

                // Price History Chart (nur wenn Daten vorhanden)
                if !priceHistory.isEmpty {
                    priceHistoryChart
                }

                // Weitere Sprachen (ausklappbar)
                regionalPricesBox

                // PSA Grading Preise
                psaGradingBox

                // eBay Sektion
                ebaySection

                // CardMarket-Link
                if !cardmarketURL.isEmpty, let url = URL(string: cardmarketURL) {
                    Button {
                        openURL(url)
                    } label: {
                        Label("Auf CardMarket ansehen", systemImage: "arrow.up.right.square")
                            .font(.subheadline)
                            .foregroundStyle(Color.dim)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .surfaceCard()
                    }
                    .padding(.horizontal)
                }

                // Portfolio: Bearbeiten-Sektion
                if case .portfolio(let card) = source {
                    editSection(card: card)
                }

                // Preview: Hinzufügen-Buttons
                if !isPortfolioMode {
                    VStack(spacing: 10) {
                        Button {
                            showAddSheet = true
                        } label: {
                            Label("Zum Portfolio hinzufügen", systemImage: "plus")
                                .font(.headline)
                                .foregroundStyle(Color(hex: "0e0e12"))
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(Color.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        if let wvm = watchlistVM, case .preview(let card) = source {
                            let inWatchlist = wvm.contains(card.id, in: watchlistItems)
                            Button {
                                if inWatchlist {
                                    wvm.remove(id: card.id, context: context)
                                } else {
                                    wvm.add(card, context: context)
                                }
                            } label: {
                                Label(
                                    inWatchlist ? "Von Watchlist entfernen" : "Zur Watchlist hinzufügen",
                                    systemImage: inWatchlist ? "heart.slash" : "heart"
                                )
                                .font(.subheadline.bold())
                                .foregroundStyle(inWatchlist ? Color.loss : Color.dim)
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background((inWatchlist ? Color.loss : Color.dim).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke((inWatchlist ? Color.loss : Color.dim).opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Portfolio: Löschen-Button
                if case .portfolio = source {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Text("Aus Portfolio entfernen")
                            .font(.subheadline)
                            .foregroundStyle(Color.loss)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color.loss.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.loss.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)
                }

                Spacer().frame(height: 32)
            }
        }
        .background(Color.appBG.ignoresSafeArea())
        .foregroundStyle(.white)
        .inlineNavigationTitle()
        .navigationTitle(cardName)
        .overlay {
            if showFullscreenImage {
                ZStack {
                    // Dunkler Hintergrund
                    Color.black.opacity(0.85)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showFullscreenImage = false
                            }
                        }

                    // Kartenbild
                    CardImageView(url: imageURL, width: 280, height: 392)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.6), radius: 24, x: 0, y: 12)
                        .allowsHitTesting(false)

                    // X-Button oben rechts
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showFullscreenImage = false
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            .padding(.trailing, 20)
                            .padding(.top, 16)
                        }
                        Spacer()
                    }
                }
                .transition(.opacity)
            }
        }
        .task {
            // Price History aus lokaler DB laden
            let tcggoId: Int?
            switch source {
            case .preview(let c): tcggoId = c.isSealed ? nil : Int(c.id)
            case .portfolio(let c): tcggoId = Int(c.id)
            }
            if let tid = tcggoId {
                priceHistory = LocalCardDatabase.shared.priceHistory(tcggoCardId: tid)
            }
            // cards_printed_total für Karten-ID Anzeige
            let epId: Int
            switch source {
            case .preview(let c):   epId = c.setId
            case .portfolio(let c): epId = c.setId
            }
            if epId > 0 {
                cardsPrintedTotal = LocalCardDatabase.shared.printedTotal(forEpisodeId: epId)
            }
            // Preise für Portfolio-Karten aus lokaler DB laden (Regional, Avg, PSA, CGC)
            if case .portfolio(let card) = source, livePsa10 == nil {
                loadPricesFromDB(cardId: card.id)
            }
        }
        .alert("Karte entfernen?", isPresented: $showDeleteAlert) {
            Button("Entfernen", role: .destructive) {
                if case .portfolio(let card) = source {
                    portfolioVM.removeCard(card, context: context)
                }
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("\"\(cardName)\" wird aus dem Portfolio entfernt.")
        }
        .sheet(isPresented: $showAddSheet) {
            if case .preview(let card) = source {
                AddCardSheet(card: card, portfolioVM: portfolioVM)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showEbaySheet) {
            EbaySoldItemsSheet(
                cardName: cardName,
                cardNumber: cardNumber,
                items: $ebayItems,
                searchURL: ebayResult?.searchURL
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Preisbox

    private var priceBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Portfolio: Gekauft + P&L
            if let purchase = purchasePrice {
                priceStatRow("Gekauft", value: formatEUR(purchase))
            }
            if case .portfolio(let card) = source {
                ProfitLabel(value: card.profitLoss, percent: card.profitLossPercent)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
    }

    private func pricePerformanceBadge(_ perf: Double) -> some View {
        let color: Color = perf >= 0 ? Color.profit : Color.loss
        return HStack(spacing: 2) {
            Image(systemName: perf >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .bold))
            Text(String(format: "%.1f%%", abs(perf)))
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func priceStatRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.dim)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    // MARK: - CM Preis-Stats Section

    private var cmPriceStatsSection: some View {
        HStack(spacing: 0) {
            // CM Lowest: Hauptwert – prominent in Akzentfarbe
            VStack(spacing: 5) {
                Text("CM Lowest")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.dim)
                Text(lowestPriceDE.map { formatEUR($0) } ?? "–")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(lowestPriceDE != nil ? Color.accent : Color.dim)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40).background(Color.border)
            cmStatItem("Ø 7 Tage", value: avg7)
            Divider().frame(height: 40).background(Color.border)
            cmStatItem("Ø 30 Tage", value: avg30)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .surfaceCard()
        .padding(.horizontal)
    }

    private func cmStatItem(_ label: String, value: Double?) -> some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.dim)
            Text(value.map { formatEUR($0) } ?? "–")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(value != nil ? Color.white : Color.dim)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Price History Chart

    private var priceHistoryChart: some View {
        // 1. Alle Punkte parsen
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let allPoints: [(Date, Double)] = priceHistory.compactMap { p in
            guard let price = p.cmLow, let date = fmt.date(from: p.date) else { return nil }
            return (date, price)
        }.sorted { $0.0 < $1.0 }

        // 2. Nach gewähltem Zeitraum filtern
        let cutoff = Calendar.current.date(byAdding: .month, value: -chartMonths, to: Date()) ?? Date()
        let filtered = allPoints.filter { $0.0 >= cutoff }

        // 3. Glättung: 5-Tage gleitender Durchschnitt
        let window = 5
        let smoothed: [(Date, Double)] = filtered.enumerated().map { i, point in
            let lo = max(0, i - window / 2)
            let hi = min(filtered.count - 1, i + window / 2)
            let avg = filtered[lo...hi].map(\.1).reduce(0, +) / Double(hi - lo + 1)
            return (point.0, avg)
        }

        let prices    = smoothed.map(\.1)
        let minPrice  = prices.min() ?? 0
        let maxPrice  = prices.max() ?? 1
        let pad       = (maxPrice - minPrice) * 0.12

        // Aktueller Preis = letzter Datenpunkt im Zeitraum
        let currentPrice = smoothed.last?.1

        // 4. Selektierter Punkt beim Drag
        let selPoint: (Date, Double)? = selectedChartDate.flatMap { selDate in
            smoothed.min(by: { abs($0.0.timeIntervalSince(selDate)) < abs($1.0.timeIntervalSince(selDate)) })
        }

        // X-Achsen-Schritte je Zeitraum
        let xStride: Calendar.Component = chartMonths <= 1 ? .weekOfYear : .month
        let xCount   = chartMonths <= 1 ? 1 : chartMonths <= 3 ? 1 : 2

        // Deutsches Datumsformat für Tooltip
        let tooltipFmt       = DateFormatter()
        tooltipFmt.locale    = Locale(identifier: "de_DE")
        tooltipFmt.dateFormat = "d. MMMM yyyy"

        return VStack(alignment: .leading, spacing: 14) {

            // ── Header: Titel + prominenter Preis ──────────────────────────
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Preisverlauf")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text("CardMarket · NM")
                        .font(.caption2)
                        .foregroundStyle(Color.dim)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    if let sel = selPoint {
                        Text(String(format: "€ %.2f", sel.1))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.accent)
                            .monospacedDigit()
                            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
                        Text(tooltipFmt.string(from: sel.0))
                            .font(.caption2)
                            .foregroundStyle(Color.dim)
                            .transition(.opacity)
                    } else if let price = currentPrice {
                        Text(String(format: "€ %.2f", price))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        Text("Aktuell")
                            .font(.caption2)
                            .foregroundStyle(Color.dim)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: selPoint?.0)
            }

            // ── Zeitraum-Picker ────────────────────────────────────────────
            HStack(spacing: 6) {
                ForEach([1, 3, 6, 12], id: \.self) { m in
                    Button {
                        chartMonths       = m
                        selectedChartDate = nil
                    } label: {
                        Text(m == 12 ? "1J" : "\(m)M")
                            .font(.caption.bold())
                            .foregroundStyle(chartMonths == m ? Color(hex: "0e0e12") : Color.dim)
                            .frame(minWidth: 36)
                            .padding(.vertical, 5)
                            .background(chartMonths == m ? Color.accent : Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                Spacer()
            }

            // ── Chart ──────────────────────────────────────────────────────
            Chart {
                ForEach(Array(smoothed.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Datum", point.0),
                        y: .value("Preis", point.1)
                    )
                    .foregroundStyle(Color.accent)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Datum", point.0),
                        yStart: .value("Min", minPrice - pad),
                        yEnd:   .value("Preis", point.1)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accent.opacity(0.22), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }

                if let sel = selPoint {
                    RuleMark(x: .value("Datum", sel.0))
                        .foregroundStyle(Color.white.opacity(0.25))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    PointMark(
                        x: .value("Datum", sel.0),
                        y: .value("Preis", sel.1)
                    )
                    .foregroundStyle(Color.accent)
                    .symbolSize(55)
                }
            }
            .chartYScale(domain: (minPrice - pad)...(maxPrice + pad))
            .chartXAxis {
                AxisMarks(values: .stride(by: xStride, count: xCount)) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel(
                        format: chartMonths <= 1
                            ? .dateTime.day().month(.abbreviated)
                            : .dateTime.month(.abbreviated)
                    )
                    .foregroundStyle(Color.dim)
                    .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v >= 1000
                                 ? String(format: "%.0fk€", v / 1000)
                                 : String(format: "%.0f€", v))
                                .foregroundStyle(Color.dim)
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 180)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    // ── Floating Tooltip Bubble ────────────────────────────
                    if let sel = selPoint, let plotFrame = proxy.plotFrame {
                        let plotOriginX = geo[plotFrame].origin.x
                        let plotWidth   = geo[plotFrame].width
                        // Bubble-X aus dem gespeicherten Drag-Wert, geklammert auf Plot-Bereich
                        let rawBubbleX  = chartDragX
                        let bubbleX     = min(max(rawBubbleX, plotOriginX + 52),
                                              plotOriginX + plotWidth - 52)

                        VStack(spacing: 3) {
                            Text(tooltipFmt.string(from: sel.0))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.dim)
                            Text(String(format: "€ %.2f", sel.1))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color(hex: "1c1c24"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.border, lineWidth: 1))
                        .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
                        .position(x: bubbleX, y: geo[plotFrame].origin.y + 30)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.08), value: sel.0)
                        .allowsHitTesting(false)
                    }

                    // ── Drag Gesture ───────────────────────────────────────
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { val in
                                    chartDragX = val.location.x
                                    let x = val.location.x - geo[proxy.plotFrame!].origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        selectedChartDate = date
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        selectedChartDate = nil
                                    }
                                }
                        )
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: chartMonths)
        .padding(16)
        .surfaceCard()
        .padding(.horizontal)
    }

    // MARK: - Regionale Preise

    private var regionalPricesBox: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header-Zeile: Titel + Pfeil
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showRegionalPrices.toggle()
                }
            } label: {
                HStack {
                    Text("Weitere Sprachen")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    // Flags-Vorschau wenn eingeklappt
                    if !showRegionalPrices {
                        Text("🇩🇪 🇫🇷 🇪🇸 🇮🇹")
                            .font(.system(size: 12))
                    }
                    Image(systemName: showRegionalPrices ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.dim)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            // Ausgeklappter Inhalt
            if showRegionalPrices {
                Divider().background(Color.border)
                HStack(spacing: 0) {
                    regionalItem("🇩🇪 DE", price: lowestPriceDE)
                    Divider().frame(height: 36).background(Color.border)
                    regionalItem("🇫🇷 FR", price: priceFR)
                    Divider().frame(height: 36).background(Color.border)
                    regionalItem("🇪🇸 ES", price: priceES)
                    Divider().frame(height: 36).background(Color.border)
                    regionalItem("🇮🇹 IT", price: priceIT)
                }
                .padding(.vertical, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .surfaceCard()
        .padding(.horizontal)
    }

    private func regionalItem(_ label: String, price: Double?) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.dim)
            Text(price.map { formatEUR($0) } ?? "–")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(price != nil ? Color.white : Color.dim)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - PSA Grading Preise

    private var psaGradingBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            // DEBUG: PSA-Werte direkt vor dem Rendern
            let _ = {
                #if DEBUG
                print("[PSABox] source=\(isPortfolioMode ? "portfolio" : "preview")  psa10=\(psaPrice10.d)  psa9=\(psaPrice9.d)  psa8=\(psaPrice8.d)  cgc10=\(cgcPrice10.d)  bgs9=\(bgsPrice9.d)")
                #endif
                return ()
            }()
            Text("GRADING PREISE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.dim)
                .kerning(1)

            // PSA-Zeile
            HStack(spacing: 0) {
                psaItem("PSA 10", price: psaPrice10)
                Divider().frame(height: 36).background(Color.border)
                psaItem("PSA 9",  price: psaPrice9)
                Divider().frame(height: 36).background(Color.border)
                psaItem("PSA 8",  price: psaPrice8)
            }

            // CGC-Zeile (nur anzeigen wenn mindestens ein Wert vorhanden)
            if cgcPrice10 != nil || cgcPrice9 != nil {
                Divider().background(Color.border)
                HStack(spacing: 0) {
                    psaItem("CGC 10", price: cgcPrice10)
                    Divider().frame(height: 36).background(Color.border)
                    psaItem("CGC 9",  price: cgcPrice9)
                    Divider().frame(height: 36).background(Color.border)
                    Color.clear.frame(maxWidth: .infinity)
                }
            }

            // BGS-Zeile (nur anzeigen wenn mindestens ein Wert vorhanden)
            if bgsPrice10 != nil || bgsPrice10Pristine != nil || bgsPrice9 != nil {
                Divider().background(Color.border)
                HStack(spacing: 0) {
                    psaItem("BGS 10",       price: bgsPrice10)
                    Divider().frame(height: 36).background(Color.border)
                    psaItem("BGS 9",        price: bgsPrice9)
                    Divider().frame(height: 36).background(Color.border)
                    psaItem("BGS Pristine", price: bgsPrice10Pristine)
                }
            }
        }
        .padding(16)
        .surfaceCard()
        .padding(.horizontal)
    }

    private func psaItem(_ label: String, price: Double?) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.dim)
            if let price {
                Text(formatEUR(price))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            } else {
                Text("–")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.dim)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Portfolio Status Feld

    private var isInPortfolio: Bool {
        switch source {
        case .portfolio: return true
        case .preview(let c): return portfolioCards.contains { $0.id == c.id }
        }
    }

    @ViewBuilder
    private var portfolioStatusField: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Portfolio")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.dim)
                .kerning(0.5)

            Button {
                if isInPortfolio {
                    // Aus Portfolio entfernen
                    if case .portfolio(let card) = source {
                        withAnimation(.easeInOut(duration: 0.2)) { portfolioIconScale = 0.5 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            portfolioVM.removeCard(card, context: context)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                portfolioIconScale = 1.2
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.easeInOut(duration: 0.15)) { portfolioIconScale = 1.0 }
                            }
                        }
                        dismiss()
                    }
                } else {
                    // Zum Portfolio hinzufügen → Sheet
                    showAddSheet = true
                }
            } label: {
                Image(systemName: isInPortfolio ? "checkmark.circle.fill" : "minus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(isInPortfolio ? Color.profit : Color.loss)
                    .scaleEffect(portfolioIconScale)
            }
            .buttonStyle(.plain)
            .onChange(of: isInPortfolio) { _, newVal in
                // Einblend-Animation wenn Status sich ändert
                portfolioIconScale = 0.5
                withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                    portfolioIconScale = 1.2
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 0.15)) { portfolioIconScale = 1.0 }
                }
            }
        }
    }

    // MARK: - Karten-Info Feld (Hero-Bereich)

    private func cardInfoField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.dim)
                .kerning(0.5)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - eBay Sektion

    private var ebaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EBAY VERKÄUFE (DE)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.dim)
                .kerning(1)

            HStack(spacing: 0) {
                Button {
                    Task { await fetchEbayPrices() }
                } label: {
                    VStack(spacing: 4) {
                        if isFetchingEbay {
                            ProgressView()
                                .tint(Color.accent)
                                .scaleEffect(0.8)
                                .frame(width: 32, height: 20)
                        } else {
                            Text("eBay")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(height: 20)
                        }
                        Text("Abrufen")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.dim)
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isFetchingEbay)

                Divider().frame(height: 36).background(Color.border)

                VStack(spacing: 4) {
                    let liveLastSold = ebayItems.compactMap { $0.price }.first
                    if let price = liveLastSold {
                        Text(formatEUR(price))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    } else {
                        Text("N/A")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.dim)
                    }
                    Text("Zuletzt verkauft")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dim)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 36).background(Color.border)

                VStack(spacing: 4) {
                    let prices = ebayItems.compactMap { $0.price }
                    let liveAvg: Double? = prices.isEmpty ? nil
                        : (prices.reduce(0, +) / Double(prices.count) * 100).rounded() / 100
                    if let avg = liveAvg {
                        Text(formatEUR(avg))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    } else {
                        Text("N/A")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.dim)
                    }
                    Text("Ø \(ebayItems.count) Verkäufe")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dim)
                }
                .frame(maxWidth: .infinity)
            }

            if let error = ebayError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.loss)
            }

            if !ebayItems.isEmpty {
                Button {
                    showEbaySheet = true
                } label: {
                    Label("Alle \(ebayItems.count) Verkäufe anzeigen", systemImage: "list.bullet")
                        .font(.caption.bold())
                        .foregroundStyle(Color.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accent.opacity(0.3), lineWidth: 1))
                }
            }
        }
        .padding(16)
        .surfaceCard()
        .padding(.horizontal)
    }

    // MARK: - Portfolio Bearbeiten-Sektion

    private func editSection(card: PortfolioCard) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text("Anzahl")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
                Stepper("\(editingQuantity)", value: $editingQuantity, in: 1...99)
                    .foregroundStyle(.white)
                    .onChange(of: editingQuantity) { _, v in card.quantity = v }
            }
            .padding(14)
            .surfaceCard()

            HStack {
                Text("Kaufpreis")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
                if isEditingPrice {
                    HStack {
                        TextField("0,00", text: $editingPurchasePrice)
                            .decimalKeyboard()
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.white)
                            .frame(width: 80)
                        Text("€")
                            .foregroundStyle(Color.dim)
                        Button("OK") {
                            if let p = Double(
                                editingPurchasePrice.replacingOccurrences(of: ",", with: ".")
                            ) {
                                card.purchasePrice = p
                            }
                            isEditingPrice = false
                        }
                        .font(.caption.bold())
                        .foregroundStyle(Color.accent)
                    }
                } else {
                    Button(formatEUR(card.purchasePrice)) {
                        isEditingPrice = true
                    }
                    .foregroundStyle(Color.accent)
                    .monospacedDigit()
                }
            }
            .padding(14)
            .surfaceCard()
        }
        .padding(.horizontal)
    }

    // MARK: - eBay Fetch

    private func fetchEbayPrices() async {
        isFetchingEbay = true
        ebayError = nil
        do {
            let result = try await EbayPriceService.shared.fetchSoldPrices(
                cardName: cardName,
                cardNumber: cardNumber
            )
            ebayResult = result
            ebayItems = result.items
        } catch {
            ebayError = "Fehler: \(error.localizedDescription)"
        }
        isFetchingEbay = false
    }

    // MARK: - Live-Preisfetch für Portfolio-Karten
    private func loadPricesFromDB(cardId: String) {
        guard let id = Int(cardId),
              let result = LocalCardDatabase.shared.cardById(id: id) else { return }

        livePriceFR       = result.priceFR
        livePriceES       = result.priceES
        livePriceIT       = result.priceIT
        liveAvg7          = result.avg7
        liveAvg30         = result.avg30
        livePsa10         = result.psaPrice10
        livePsa9          = result.psaPrice9
        livePsa8          = result.psaPrice8
        liveCgc10         = result.cgcPrice10
        liveCgc9          = result.cgcPrice9
        liveBgs10         = result.bgsPrice10
        liveBgs10Pristine = result.bgsPrice10Pristine
        liveBgs9          = result.bgsPrice9
    }

}

// MARK: - eBay Sold Items Sheet

struct EbaySoldItemsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let cardName: String
    let cardNumber: String
    @Binding var items: [EbaySoldItem]
    let searchURL: URL?

    var body: some View {
        ZStack {
            Color(hex: "0e0e12").ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("eBay Verkäufe")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("\(cardName) · \(cardNumber) · \(items.count) Einträge")
                            .font(.caption)
                            .foregroundStyle(Color.dim)
                    }
                    Spacer()
                    if let url = searchURL {
                        Button {
                            openURL(url)
                        } label: {
                            Label("eBay öffnen", systemImage: "arrow.up.right.square")
                                .font(.caption.bold())
                                .foregroundStyle(Color.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.accent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.dim)
                    }
                    .padding(.leading, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

                Divider().background(Color.border)

                if items.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "cart.badge.questionmark")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.dim)
                        Text("Keine Verkäufe vorhanden")
                            .foregroundStyle(Color.dim)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(items) { item in
                                EbaySoldRow(item: item) {
                                    items.removeAll { $0.id == item.id }
                                }
                            }
                        }
                        .padding(16)
                    }
                    Text("Tippe auf einen Verkauf für Details · X zum Entfernen")
                        .font(.caption)
                        .foregroundStyle(Color.dim)
                        .padding(.bottom, 8)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - eBay Sold Row

struct EbaySoldRow: View {
    let item: EbaySoldItem
    let onDelete: () -> Void
    @State private var showDetail = false

    var body: some View {
        HStack(spacing: 8) {
            Button { showDetail = true } label: {
                HStack(spacing: 12) {
                    if let imgURL = item.imageURL, let url = URL(string: imgURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fill)
                            default:
                                Color.surface
                            }
                        }
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.surface)
                            .frame(width: 52, height: 52)
                            .overlay(Image(systemName: "photo").foregroundStyle(Color.dim))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                        if let date = item.soldDate {
                            Text(date)
                                .font(.caption)
                                .foregroundStyle(Color.dim)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        if let price = item.price {
                            Text(formatEUR(price))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.accent)
                                .monospacedDigit()
                        } else if let raw = item.priceRaw {
                            Text(raw)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.accent)
                        } else {
                            Text("–").foregroundStyle(Color.dim)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(Color.dim)
                    }
                }
                .padding(12)
                .background(Color(hex: "17171e"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "2a2a35"), lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Entfernen-Button
            Button {
                withAnimation(.spring(response: 0.25)) { onDelete() }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.loss.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showDetail) {
            EbaySoldItemDetailSheet(item: item)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - eBay Item Detail Sheet

struct EbaySoldItemDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let item: EbaySoldItem

    var body: some View {
        ZStack {
            Color(hex: "0e0e12").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    if let imgURL = item.imageURL, let url = URL(string: imgURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            default:
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.surface)
                                    .frame(height: 160)
                                    .overlay(Image(systemName: "photo").foregroundStyle(Color.dim))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 220)
                        .padding(.horizontal)
                    }

                    Text(item.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    if let sub = item.subtitle {
                        Text(sub)
                            .font(.subheadline)
                            .foregroundStyle(Color.dim)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }

                    VStack(spacing: 1) {
                        if let price = item.price {
                            detailRow("Preis", value: formatEUR(price), highlight: true)
                        } else if let raw = item.priceRaw {
                            detailRow("Preis", value: raw, highlight: true)
                        }
                        if let shipping  = item.shipping    { detailRow("Versand",      value: shipping) }
                        if let date      = item.soldDate    { detailRow("Verkauft am",  value: date) }
                        if let condition = item.condition   { detailRow("Zustand",      value: condition) }
                        if let location  = item.location    { detailRow("Standort",     value: location) }
                        if let pid       = item.productId   { detailRow("Artikel-Nr.",  value: pid) }
                        if let seller    = item.sellerName  { detailRow("Verkäufer",    value: seller) }
                        if let fb        = item.sellerFeedback   { detailRow("Bewertung",    value: String(format: "%.1f%% positiv", fb)) }
                        if let reviews   = item.sellerReviews    { detailRow("Bewertungen",  value: "\(reviews)") }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.border, lineWidth: 1))
                    .padding(.horizontal)

                    if let link = item.itemURL, let url = URL(string: link) {
                        Button {
                            openURL(url)
                        } label: {
                            Label("Auf eBay ansehen", systemImage: "arrow.up.right.square")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color(hex: "0e0e12"))
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(Color.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.top, 24)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func detailRow(_ label: String, value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.dim)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(highlight ? Color.accent : .white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surface)
    }
}
