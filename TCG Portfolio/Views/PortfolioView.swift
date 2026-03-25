import SwiftUI
import SwiftData
import Charts

struct PortfolioView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PortfolioCard.dateAdded, order: .reverse) private var cards: [PortfolioCard]
    @State private var vm = PortfolioViewModel()
    @State private var sortOrder: SortOrder = .value
    @State private var isEditMode = false
    @State private var activeFilter: FilterType? = nil

    // MARK: - Enums

    enum SortOrder: String, CaseIterable {
        case dateAdded = "Datum"
        case name      = "Name"
        case value     = "Wert"
        case profit    = "Gewinn"
    }

    enum FilterType: Equatable {
        case karten, sealed
    }

    /// Unterkategorien für Sealed-Produkte – Reihenfolge bestimmt Anzeigereihenfolge.
    enum SealedGroup: String, CaseIterable {
        case display  = "Display / Booster Box"
        case ttb      = "Top Trainer Box"
        case bb       = "Booster Bundle"
        case sonstige = "Sonstige"
    }

    // MARK: - Derived Data

    var singleCards: [PortfolioCard] { cards.filter { !$0.isSealed } }
    var sealedCards: [PortfolioCard] { cards.filter {  $0.isSealed } }

    /// Karten, die nach aktivem Filter angezeigt werden sollen.
    var shownSingleCards: [PortfolioCard] { activeFilter == .sealed ? [] : singleCards }
    var shownSealedCards: [PortfolioCard] { activeFilter == .karten ? [] : sealedCards }

    func sorted(_ list: [PortfolioCard]) -> [PortfolioCard] {
        switch sortOrder {
        case .dateAdded: return list
        case .name:      return list.sorted { $0.displayName < $1.displayName }
        case .value:     return list.sorted { $0.totalValue > $1.totalValue }
        case .profit:    return list.sorted { $0.profitLoss > $1.profitLoss }
        }
    }

    // MARK: - Sealed Subcategory Helpers

    /// Ordnet ein Sealed-Produkt seiner Unterkategorie zu.
    /// Prüft den gespeicherten `cardName` (englische Schlüsselwörter bleiben nach localizeProductName erhalten).
    func sealedGroup(for card: PortfolioCard) -> SealedGroup {
        let n = card.cardName.lowercased()
        if n.contains("elite trainer box") || n.contains("top trainer box") { return .ttb }
        if n.contains("booster bundle display") || n.contains("display") || n.contains("booster box") { return .display }
        if n.contains("booster bundle") { return .bb }
        return .sonstige
    }

    /// Karten einer Gruppe, nach Wert absteigend sortiert.
    func sealedCards(in group: SealedGroup) -> [PortfolioCard] {
        shownSealedCards
            .filter { sealedGroup(for: $0) == group }
            .sorted { $0.totalValue > $1.totalValue }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Header
                    HStack {
                        Text("Portfolio")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            Task { await vm.updateAllPrices(cards: cards, context: context) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.accent)
                                .rotationEffect(vm.isUpdatingPrices ? .degrees(360) : .degrees(0))
                                .animation(
                                    vm.isUpdatingPrices
                                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                                        : .default,
                                    value: vm.isUpdatingPrices
                                )
                                .padding(10)
                                .background(Color.surface)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.border, lineWidth: 1))
                        }
                        .disabled(cards.isEmpty)
                    }
                    .padding(.horizontal)

                    // Gesamtwert
                    VStack(spacing: 6) {
                        Text("Gesamtwert")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.dim)
                        Text(formatEUR(vm.totalValue(cards: cards)))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        ProfitLabel(
                            value: vm.totalProfitLoss(cards: cards),
                            percent: vm.totalProfitLossPercent(cards: cards)
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    // Stats
                    HStack(spacing: 0) {
                        statItem("Karten", value: "\(singleCards.count)")
                        Divider().frame(height: 28).background(Color.border)
                        statItem("Sealed", value: "\(sealedCards.count)")
                        Divider().frame(height: 28).background(Color.border)
                        statItem("Top-Karte", value: formatEUR(cards.map(\.currentPrice).max() ?? 0))
                    }
                    .padding(.horizontal)

                    // Chart
                    PortfolioLineChart(data: vm.portfolioValueHistory(cards: cards))
                        .padding(.horizontal)

                    if cards.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.dim)
                            Text("Noch keine Einträge")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Suche nach Karten oder Sealed-Produkten\nund füge sie deinem Portfolio hinzu.")
                                .font(.subheadline)
                                .foregroundStyle(Color.dim)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(48)
                    } else {
                        // Controls: Filter + Sort + Edit
                        HStack(spacing: 8) {
                            filterPill(.karten, label: "Karten")
                            filterPill(.sealed, label: "Sealed")
                            Spacer()
                            // Sort nur bei Karten-Ansicht sinnvoll (Sealed-Unterkategorien immer nach Wert)
                            if activeFilter != .sealed {
                                Menu {
                                    ForEach(SortOrder.allCases, id: \.self) { order in
                                        Button(order.rawValue) { sortOrder = order }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(sortOrder.rawValue)
                                            .font(.caption)
                                        Image(systemName: "chevron.down")
                                            .font(.caption2)
                                    }
                                    .foregroundStyle(Color.dim)
                                }
                            }
                            Button(isEditMode ? "Fertig" : "Bearbeiten") {
                                withAnimation { isEditMode.toggle() }
                            }
                            .font(.caption)
                            .foregroundStyle(Color.accent)
                            .padding(.leading, 4)
                        }
                        .padding(.horizontal)

                        // Karten-Sektion
                        if !shownSingleCards.isEmpty {
                            categorySectionHeader(
                                title: "Karten",
                                count: shownSingleCards.count,
                                value: vm.totalValue(cards: shownSingleCards)
                            )
                            cardList(sorted(shownSingleCards))
                        }

                        // Sealed-Sektion
                        if activeFilter == .sealed {
                            // Mit Unterkategorien
                            ForEach(SealedGroup.allCases, id: \.self) { group in
                                sealedGroupSection(group)
                            }
                        } else if !shownSealedCards.isEmpty {
                            categorySectionHeader(
                                title: "Sealed",
                                count: shownSealedCards.count,
                                value: vm.totalValue(cards: shownSealedCards)
                            )
                            cardList(sorted(shownSealedCards))
                        }
                    }

                    Spacer().frame(height: 80)
                }
                .padding(.top, 16)
            }
            .background(Color.appBG.ignoresSafeArea())
            .navigationBarHidden(true)
            .task(id: cards.count) {
                vm.snapshotTodayIfNeeded(cards: cards, context: context)
            }
        }
    }

    // MARK: - Filter Pill

    private func filterPill(_ type: FilterType, label: String) -> some View {
        let isActive = activeFilter == type
        return Button {
            withAnimation(.spring(response: 0.25)) {
                activeFilter = isActive ? nil : type
            }
        } label: {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? Color.accent : Color.surface)
                .foregroundStyle(isActive ? Color(hex: "0e0e12") : Color.dim)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isActive ? Color.clear : Color.border, lineWidth: 1))
        }
        .animation(.spring(response: 0.25), value: isActive)
    }

    // MARK: - Sealed Group Section

    @ViewBuilder
    private func sealedGroupSection(_ group: SealedGroup) -> some View {
        let items = sealedCards(in: group)
        if !items.isEmpty {
            categorySectionHeader(
                title: group.rawValue,
                count: items.count,
                value: vm.totalValue(cards: items)
            )
            cardList(items)
        }
    }

    // MARK: - Section Header

    private func categorySectionHeader(title: String, count: Int, value: Double) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
            Text("\(count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accent.opacity(0.15))
                .clipShape(Capsule())
            Spacer()
            Text(formatEUR(value))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.dim)
                .monospacedDigit()
        }
        .padding(.horizontal)
    }

    // MARK: - Card List

    private func cardList(_ list: [PortfolioCard]) -> some View {
        LazyVStack(spacing: 10) {
            ForEach(list) { card in
                ZStack(alignment: .trailing) {
                    NavigationLink(
                        destination: SearchCardDetailView(portfolioCard: card, portfolioVM: vm)
                    ) {
                        PortfolioCardRow(card: card)
                    }
                    .buttonStyle(.plain)
                    .opacity(isEditMode ? 0.6 : 1.0)

                    if isEditMode {
                        Button {
                            withAnimation { vm.removeCard(card, context: context) }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.loss)
                                .padding(.trailing, 16)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Stat Item

    private func statItem(_ title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Color.dim)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Portfolio Card Row

struct PortfolioCardRow: View {
    let card: PortfolioCard
    private var displayedName: String { CardDisplay.format(card.displayName, context: .portfolio) }

    var body: some View {
        HStack(spacing: 10) {
            CardImageView(url: card.imageURL, width: 36, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                // Zeile 1: Name + Menge
                HStack(spacing: 5) {
                    Text(displayedName)
                        .font(CardDisplay.nameFont(for: displayedName))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if card.quantity > 1 {
                        Text("×\(card.quantity)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.accent)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                // Zeile 2: Set + Performance
                HStack(spacing: 6) {
                    Text(card.localizedSetName)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dim)
                        .lineLimit(1)
                    CompactProfitBadge(value: card.profitLoss, percent: card.profitLossPercent)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                if card.quantity > 1 {
                    Text(formatEUR(card.currentPrice))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dim)
                        .monospacedDigit()
                }
                Text(formatEUR(card.totalValue))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.accent)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .surfaceCard()
    }
}
