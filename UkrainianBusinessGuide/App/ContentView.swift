//
//  ContentView.swift
//  UkrainianBusinessGuide
//

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard, finance, taxes, opportunities, advisor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Огляд"
        case .finance: return "Фінанси"
        case .taxes: return "Податки"
        case .opportunities: return "Підтримка"
        case .advisor: return "Радник"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "square.text.square"
        case .finance: return "chart.bar"
        case .taxes: return "building.columns"
        case .opportunities: return "doc.text.magnifyingglass"
        case .advisor: return "text.bubble"
        }
    }
}

struct ContentView: View {
    @Environment(AppStore.self) private var store
    /// `-uiTab finance` у аргументах запуску відкриває потрібну вкладку (для скриншотів у CI).
    @State private var selectedTab: AppTab = AppTab(rawValue: UserDefaults.standard.string(forKey: "uiTab") ?? "") ?? .dashboard

    var body: some View {
        Group {
            if store.profile == nil {
                OnboardingView()
                    .transition(.opacity)
            } else {
                mainInterface
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.profile == nil)
    }

    private var mainInterface: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab)
                .tabItem { Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.icon) }
                .tag(AppTab.dashboard)
            FinanceView()
                .tabItem { Label(AppTab.finance.title, systemImage: AppTab.finance.icon) }
                .tag(AppTab.finance)
            TaxesView()
                .tabItem { Label(AppTab.taxes.title, systemImage: AppTab.taxes.icon) }
                .tag(AppTab.taxes)
            OpportunitiesView()
                .tabItem { Label(AppTab.opportunities.title, systemImage: AppTab.opportunities.icon) }
                .tag(AppTab.opportunities)
            AdvisorView()
                .tabItem { Label(AppTab.advisor.title, systemImage: AppTab.advisor.icon) }
                .tag(AppTab.advisor)
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}

#Preview {
    ContentView()
        .environment(AppStore.preview)
}
