import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WatchlistItem.dateAdded, order: .reverse) private var items: [WatchlistItem]

    let portfolioVM: PortfolioViewModel
    let watchlistVM: WatchlistViewModel

    @State private var sortOrder: SortOrder = .dateAdded

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    enum SortOrder: String, CaseIterable {
        case dateAdded = "Zuletzt"
        case name      = "Name"
        case value     = "Wert"
    }

    private var sortedItems: [WatchlistItem] {
        switch sortOrder {
        case .dateAdded: return items
        case .name:      return items.sorted { $0.displayName < $1.displayName }
        case .value:     return items.sorted { ($0.price ?? 0) > ($1.price ?? 0) }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Header
                HStack {
                    Text("Watchlist")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    if !items.isEmpty {
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
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.border, lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(sortedItems) { item in
                                ZStack(alignment: .topTrailing) {
                                    NavigationLink(
                                        destination: SearchCardDetailView(
                                            searchCard: CardSearchResult(from: item),
                                            portfolioVM: portfolioVM,
                                            watchlistVM: watchlistVM
                                        )
                                    ) {
                                        SearchResultCard(card: CardSearchResult(from: item))
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        withAnimation(.spring(response: 0.25)) {
                                            watchlistVM.remove(id: item.id, context: context)
                                        }
                                    } label: {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(Color.loss)
                                            .padding(7)
                                            .background(Color.surface.opacity(0.9).clipShape(Circle()))
                                            .overlay(Circle().stroke(Color.border, lineWidth: 1))
                                            .padding(8)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        Spacer().frame(height: 80)
                    }
                }
            }
            .background(Color.appBG.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "heart.slash")
                .font(.system(size: 48))
                .foregroundStyle(Color.dim)
            Text("Keine Einträge")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Tippe in der Suche auf das Herz-Icon,\num Karten zur Watchlist hinzuzufügen.")
                .font(.subheadline)
                .foregroundStyle(Color.dim)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}
