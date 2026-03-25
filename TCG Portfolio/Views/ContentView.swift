import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var portfolioVM  = PortfolioViewModel()
    @State private var watchlistVM  = WatchlistViewModel()
    @State private var selectedTab  = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBG.ignoresSafeArea()

            Group {
                PortfolioView()
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 0)
                SearchView(portfolioVM: portfolioVM, watchlistVM: watchlistVM)
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 1)
                WatchlistView(portfolioVM: portfolioVM, watchlistVM: watchlistVM)
                    .opacity(selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            customTabBar
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(icon: "chart.pie.fill",   label: "Portfolio", tag: 0)
            tabButton(icon: "magnifyingglass",   label: "Suche",     tag: 1)
            tabButton(icon: "heart.fill",        label: "Watchlist", tag: 2)
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color.border),
            alignment: .top
        )
    }

    private func tabButton(icon: String, label: String, tag: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.25)) { selectedTab = tag }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selectedTab == tag ? Color.accent : Color.dim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: selectedTab)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [PortfolioCard.self, PriceEntry.self, AppSettings.self, WatchlistItem.self], inMemory: true)
}
