//
//  DashboardView.swift
//  UkrainianBusinessGuide
//
//  «Пульс бізнесу»: індекс здоров'я, ключові метрики, найближчі строки та інсайти.
//

import SwiftUI

struct DashboardView: View {
    @Environment(AppStore.self) private var store
    @Binding var selectedTab: AppTab

    @State private var showSimulator = false
    @State private var showSettings = false
    @State private var showAddTransaction = false

    var body: some View {
        NavigationStack {
            let report = store.healthReport
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    healthCard(report)
                    metrics
                    quickActions
                    deadlines
                    insights(report)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title3)
                    }
                    .accessibilityLabel("Профіль і налаштування")
                }
            }
            .sheet(isPresented: $showSimulator) { ScenarioSimulatorView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showAddTransaction) { AddTransactionView() }
        }
    }

    // MARK: - Секції

    private var greeting: String {
        switch Calendar.kyiv.component(.hour, from: .now) {
        case 5..<12: return "Доброго ранку"
        case 12..<18: return "Добрий день"
        default: return "Добрий вечір"
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.ukrainian)).capitalized)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(store.profile.map { "\(greeting), \($0.ownerName.isEmpty ? "підприємцю" : $0.ownerName)" } ?? greeting)
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
            if let name = store.profile?.businessName {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(Theme.brand)
            }
        }
        .padding(.top, 8)
    }

    private func healthCard(_ report: HealthReport) -> some View {
        HStack(spacing: 20) {
            RingGauge(progress: Double(report.score) / 100, lineWidth: 16) {
                VStack(spacing: 0) {
                    Text("\(report.score)")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText())
                    Text("зі 100")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 124, height: 124)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Пульс бізнесу")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(report.verdict)
                        .font(.title3.weight(.bold))
                }
                ForEach(report.components) { component in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(component.title)
                            Spacer()
                            Text(component.detail).foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        ProgressBar(value: component.value, height: 5)
                    }
                }
            }
        }
        .glassCard(padding: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Пульс бізнесу \(report.score) зі 100, \(report.verdict)")
    }

    private var metrics: some View {
        let month = store.monthlySummaries(months: 1).first
        let runway = HealthAnalyzer.runwayMonths(cash: store.cashBalance, monthlyIncome: store.averageMonthlyIncome, monthlyExpense: store.averageMonthlyExpense)
        let limitLeft = store.profile.map { store.taxEngine.annualIncomeLimit(for: $0.fopGroup) - store.yearIncome } ?? 0

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            MetricTile(title: "Гроші на рахунку", value: store.cashBalance.uahCompact, icon: "creditcard.fill",
                       tint: store.cashBalance >= 0 ? Theme.skyBlue : Theme.coral)
            MetricTile(title: "Прибуток цього місяця", value: (month?.profit ?? 0).uahCompact, icon: "chart.line.uptrend.xyaxis",
                       tint: (month?.profit ?? 0) >= 0 ? Theme.mint : Theme.coral,
                       footnote: month.map { "Дохід \($0.income.uahCompact)" })
            MetricTile(title: "Запас міцності", value: runway.map { String(format: "%.1f міс", $0) } ?? "∞", icon: "hourglass",
                       tint: Theme.violet, footnote: runway == nil ? "Бізнес прибутковий" : nil)
            MetricTile(title: "До ліміту групи", value: max(0, limitLeft).uahCompact, icon: "gauge.with.dots.needle.33percent",
                       tint: store.limitUsage > 0.8 ? Theme.amber : Theme.blue, footnote: "Використано \(store.limitUsage.percent)")
        }
    }

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                quickAction("Операція", "plus.circle.fill", Theme.brand) { showAddTransaction = true }
                quickAction("Що якщо?", "slider.horizontal.3", LinearGradient(colors: [Theme.violet, Theme.skyBlue], startPoint: .topLeading, endPoint: .bottomTrailing)) { showSimulator = true }
                quickAction("Гранти", "gift.fill", Theme.sun) { selectedTab = .opportunities }
                quickAction("Спитати", "bubble.left.fill", LinearGradient(colors: [Theme.mint, Theme.skyBlue], startPoint: .topLeading, endPoint: .bottomTrailing)) { selectedTab = .advisor }
            }
            .padding(.vertical, 4)
        }
    }

    private func quickAction(_ title: String, _ icon: String, _ gradient: LinearGradient, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 76)
        }
        .buttonStyle(.plain)
    }

    private var deadlines: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Найближчі строки", action: (title: "Усі", handler: { selectedTab = .taxes }))
            let upcoming = Array(store.upcomingDeadlines.prefix(3))
            if upcoming.isEmpty {
                Text("Найближчим часом платежів немає 🎉")
                    .foregroundStyle(.secondary)
                    .glassCard()
            } else {
                VStack(spacing: 14) {
                    ForEach(upcoming) { deadline in
                        DeadlineRow(deadline: deadline)
                        if deadline.id != upcoming.last?.id { Divider() }
                    }
                }
                .glassCard()
            }
        }
    }

    private func insights(_ report: HealthReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Інсайти")
            VStack(alignment: .leading, spacing: 16) {
                ForEach(report.insights) { InsightRow(insight: $0) }
            }
            .glassCard()
        }
    }
}

#Preview {
    DashboardView(selectedTab: .constant(.dashboard))
        .environment(AppStore.preview)
}
