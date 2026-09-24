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
        case .dashboard: return "Пульс"
        case .finance: return "Фінанси"
        case .taxes: return "Податки"
        case .opportunities: return "Можливості"
        case .advisor: return "Радник"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "waveform.path.ecg"
        case .finance: return "chart.bar.xaxis"
        case .taxes: return "building.columns"
        case .opportunities: return "sparkles"
        case .advisor: return "bubble.left.and.text.bubble.right"
        }
    }
}

struct ContentView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        Group {
            if store.profile == nil {
                OnboardingView()
                    .transition(.opacity)
            } else {
                mainInterface
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: store.profile == nil)
    }

    private var mainInterface: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView(selectedTab: $selectedTab)
                    .tabPage(.dashboard)
                FinanceView()
                    .tabPage(.finance)
                TaxesView()
                    .tabPage(.taxes)
                OpportunitiesView()
                    .tabPage(.opportunities)
                AdvisorView()
                    .tabPage(.advisor)
            }

            FloatingTabBar(selection: $selectedTab)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                .ignoresSafeArea(.keyboard)
        }
    }
}

private extension View {
    /// Ховає системну панель вкладок і резервує місце під плаваючу.
    func tabPage(_ tab: AppTab) -> some View {
        self
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 64) }
            .toolbar(.hidden, for: .tabBar)
            .tag(tab)
    }
}

/// Плаваюча скляна панель вкладок з анімованим індикатором.
struct FloatingTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .symbolEffect(.bounce, value: selection == tab)
                        Text(tab.title)
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selection == tab ? Color.white : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.brand)
                                .matchedGeometryEffect(id: "indicator", in: indicator)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.2)))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview {
    ContentView()
        .environment(AppStore.preview)
}
