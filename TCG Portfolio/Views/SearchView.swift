import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WatchlistItem.dateAdded, order: .reverse) private var watchlistItems: [WatchlistItem]

    @State private var viewModel = SearchViewModel()
    @State private var portfolioVM: PortfolioViewModel
    @State private var watchlistVM: WatchlistViewModel
    @State private var selectedCard: CardSearchResult?

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(portfolioVM: PortfolioViewModel, watchlistVM: WatchlistViewModel) {
        _portfolioVM = State(initialValue: portfolioVM)
        _watchlistVM = State(initialValue: watchlistVM)
    }

    var sortedResults: [CardSearchResult] {
        viewModel.results.sorted { ($0.price ?? 0) > ($1.price ?? 0) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Header
                HStack {
                    Text("Suche")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Search field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.dim)
                    TextField("z.B. Glurak Stürmische Funken", text: $viewModel.searchText)
                        .autocorrectionDisabled()
                        .foregroundStyle(.white)
                        .onSubmit { Task { await viewModel.search() } }
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(Color.accent)
                            .scaleEffect(0.8)
                    } else if !viewModel.searchText.isEmpty {
                        Button(action: viewModel.clear) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.dim)
                        }
                        Text("↵")
                            .font(.caption)
                            .foregroundStyle(Color.dim)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.border)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    Button("Suchen") {
                        Task { await viewModel.search() }
                    }
                    .font(.caption.bold())
                    .foregroundStyle(Color.accent)
                    .disabled(viewModel.searchText.isEmpty || viewModel.isLoading)
                }
                .padding(14)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.border, lineWidth: 1))
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Results hint
                if !viewModel.results.isEmpty {
                    HStack {
                        Text("\(sortedResults.count) Ergebnisse · sortiert nach Preis ↓")
                            .font(.caption)
                            .foregroundStyle(Color.dim)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                // Content
                ScrollView {
                    if let error = viewModel.errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass.circle")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.dim)
                            Text(error)
                                .foregroundStyle(Color.dim)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(48)
                    } else if !viewModel.results.isEmpty {
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(sortedResults) { card in
                                let inWatchlist = watchlistVM.contains(card.id, in: watchlistItems)
                                ZStack {
                                    NavigationLink(
                                        destination: SearchCardDetailView(
                                            searchCard: card,
                                            portfolioVM: portfolioVM,
                                            watchlistVM: watchlistVM
                                        )
                                    ) {
                                        SearchResultCard(card: card)
                                    }
                                    .buttonStyle(.plain)

                                    // Herz (oben links) + Plus (oben rechts)
                                    VStack {
                                        HStack {
                                            Button {
                                                withAnimation(.spring(response: 0.25)) {
                                                    if inWatchlist {
                                                        watchlistVM.remove(id: card.id, context: context)
                                                    } else {
                                                        watchlistVM.add(card, context: context)
                                                    }
                                                }
                                            } label: {
                                                Image(systemName: inWatchlist ? "heart.fill" : "heart")
                                                    .font(.system(size: 16))
                                                    .foregroundStyle(inWatchlist ? Color.loss : Color.dim)
                                                    .padding(7)
                                                    .background(Color.surface.opacity(0.9).clipShape(Circle()))
                                                    .overlay(Circle().stroke(Color.border, lineWidth: 1))
                                            }
                                            Spacer()
                                            Button { selectedCard = card } label: {
                                                Image(systemName: "plus.circle.fill")
                                                    .font(.system(size: 22))
                                                    .foregroundStyle(Color.accent)
                                                    .background(Color.surface.clipShape(Circle()))
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else if viewModel.searchText.isEmpty {
                        searchTipsView
                    }
                    Spacer().frame(height: 80)
                }
            }
            .background(Color.appBG.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(item: $selectedCard) { card in
                AddCardSheet(card: card, portfolioVM: portfolioVM)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Search Tips

    private var searchTipsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Suchtipps")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                tipRow("sparkles", "Name + Set: \"Glurak Stürmische Funken\"")
                tipRow("globe",    "Englisch: \"Charizard Surging Sparks\"")
                tipRow("magnifyingglass", "Nur Name: \"Pikachu\"")
                tipRow("shippingbox", "Sealed: \"Phantomflammen Top Trainer Box\"")
            }
            .padding(16)
            .surfaceCard()

            Text("Sets")
                .font(.subheadline.bold())
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SetTranslator.allSets, id: \.id) { set in
                        Button(set.nameDE) {
                            viewModel.searchText = set.nameDE + " "
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.surface)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.border, lineWidth: 1))
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(16)
    }

    private func tipRow(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(Color.dim)
    }
}

// MARK: - Search Result Card (Grid-Kachel)

struct SearchResultCard: View {
    let card: CardSearchResult

    private var displayedName: String { CardDisplay.format(card.name) }

    /// Kursänderung vs. 7-Tage-Durchschnitt in Prozent.
    private var performance: Double? {
        guard let price = card.price, let avg7 = card.avg7, avg7 > 0 else { return nil }
        return ((price - avg7) / avg7) * 100
    }

    /// Kartennummer im Format "001 / 191", leer bei Sealed-Produkten.
    private var cardNumberText: String {
        guard !card.number.isEmpty else { return "" }
        if let total = card.totalCards { return "\(card.number) / \(total)" }
        return card.number
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Bild
            ZStack {
                Color.appBG
                CardImageView(url: card.imageURL, width: 100, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 155)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Info-Bereich
            VStack(alignment: .leading, spacing: 4) {

                // Name
                Text(displayedName)
                    .font(.system(size: displayedName.count > 20 ? 11 : 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Set
                Text(card.setName)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.dim)
                    .lineLimit(1)

                // Rarity + Nummer
                if !card.rarity.isEmpty {
                    RarityBadge(rarity: card.rarity)
                }
                if !cardNumberText.isEmpty {
                    Text(cardNumberText)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.dim)
                        .monospacedDigit()
                }

                Spacer(minLength: 6)

                // Preis + Performance
                VStack(alignment: .leading, spacing: 2) {
                    if let price = card.price {
                        Text(formatEUR(price))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.accent)
                            .monospacedDigit()
                    } else {
                        Text("–")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.dim)
                    }
                    if let perf = performance {
                        HStack(spacing: 2) {
                            Image(systemName: perf >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 9, weight: .bold))
                            Text(String(format: "%.1f%%", abs(perf)))
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
                        }
                        .foregroundStyle(perf >= 0 ? Color.profit : Color.loss)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Add Card Sheet

struct AddCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let card: CardSearchResult
    let portfolioVM: PortfolioViewModel

    @State private var quantity = 1
    @State private var useCustomPrice = false
    @State private var customPriceText = ""

    private var displayedName: String { CardDisplay.format(card.name) }
    private var suggestedPrice: Double { card.price ?? 0 }
    private var finalPrice: Double {
        useCustomPrice
            ? (Double(customPriceText.replacingOccurrences(of: ",", with: ".")) ?? suggestedPrice)
            : suggestedPrice
    }

    var body: some View {
        ZStack {
            Color(hex: "0e0e12").ignoresSafeArea()
            VStack(spacing: 20) {

                // Card info row
                HStack(spacing: 14) {
                    CardImageView(url: card.imageURL, width: 56, height: 78)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayedName)
                            .font(CardDisplay.nameFont(for: displayedName))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(card.setName)
                            .font(.subheadline)
                            .foregroundStyle(Color.dim)
                        if !card.rarity.isEmpty {
                            RarityBadge(rarity: card.rarity)
                        }
                    }
                    Spacer()
                    if let price = card.price {
                        Text(formatEUR(price))
                            .font(.title3.bold())
                            .foregroundStyle(Color.accent)
                            .monospacedDigit()
                    }
                }
                .padding(16)
                .surfaceCard()

                // Stepper
                HStack {
                    Text("Anzahl")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 20) {
                        Button {
                            if quantity > 1 { quantity -= 1 }
                        } label: {
                            Text("−")
                                .font(.title2.bold())
                                .foregroundStyle(quantity > 1 ? Color.accent : Color.dim)
                                .frame(width: 36, height: 36)
                                .background(Color.surface)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.border, lineWidth: 1))
                        }
                        Text("\(quantity)")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(minWidth: 32)
                            .monospacedDigit()
                        Button {
                            quantity += 1
                        } label: {
                            Text("+")
                                .font(.title2.bold())
                                .foregroundStyle(Color.accent)
                                .frame(width: 36, height: 36)
                                .background(Color.surface)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.border, lineWidth: 1))
                        }
                    }
                }
                .padding(16)
                .surfaceCard()

                // Total value
                HStack {
                    Text("Gesamtwert")
                        .font(.subheadline)
                        .foregroundStyle(Color.dim)
                    Spacer()
                    Text(formatEUR(finalPrice * Double(quantity)))
                        .font(.title3.bold())
                        .foregroundStyle(Color.accent)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: quantity)
                }
                .padding(16)
                .surfaceCard()

                // Add button
                Button {
                    portfolioVM.addCard(
                        card,
                        purchasePrice: finalPrice,
                        quantity: quantity,
                        context: context
                    )
                    dismiss()
                } label: {
                    Text("Zum Portfolio hinzufügen")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "0e0e12"))
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button("Abbrechen") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(Color.dim)
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }
}
