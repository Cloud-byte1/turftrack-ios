import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: FairLieStore

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.cream.ignoresSafeArea()
            Group {
                switch store.tab {
                case .lab:
                    LabView()
                case .sessions:
                    SessionsView()
                case .progress:
                    ProgressViewTab()
                }
            }
            .padding(.bottom, 72)

            mobileNav
        }
    }

    private var mobileNav: some View {
        HStack {
            ForEach(FairLieStore.Tab.allCases, id: \.self) { item in
                Button {
                    store.tab = item
                } label: {
                    VStack(spacing: 4) {
                        Text(item == .lab ? "⌂" : item == .sessions ? "◫" : "↗")
                        Text(item.rawValue)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(store.tab == item ? Theme.greenDark : Theme.muted)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}

#Preview {
    ContentView().environmentObject(FairLieStore())
}
