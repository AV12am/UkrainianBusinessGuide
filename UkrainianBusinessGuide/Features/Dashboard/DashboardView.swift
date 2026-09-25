//
//  DashboardView.swift
//  UkrainianBusinessGuide
//
//  «Огляд»: зведення цифр, стан бізнесу, найближчі строки й нотатки.
//

import Charts
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
                VStack(alignment: .leading, spacing: 36) {
                    header
                    summary
                    actions
                    health(report)
                    deadlines
                    notes(report)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .tint(Theme.ink)
                    .accessibilityLabel("Профіль і налаштування")
                }
            }
            .sheet(isPresented: $showSimulator) { ScenarioSimulatorView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showAddTransaction) { AddTransactionView() }
        }
    }

    // MARK: - Шапка

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.ukrainian)))
            Text(store.profile?.businessName ?? "Мій бізнес")
                .font(.display(34, weight: .bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let profile = store.profile {
                Text([profile.ownerName, "ФОП \(profile.fopGroup.title)", profile.industry.title]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkMuted)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Зведення

    private var summary: some View {
        let month = store.monthlySummaries(months: 1).first
        let runway = HealthAnalyzer.runwayMonths(cash: store.cashBalance, monthlyIncome: store.averageMonthlyIncome, monthlyExpense: store.averageMonthlyExpense)
        let limitLeft = store.profile.map { store.taxEngine.annualIncomeLimit(for: $0.fopGroup) - store.yearIncome } ?? 0
        let monthName = month.map { $0.month.monthName } ?? "місяць"
        let profit = month?.profit ?? 0

        return VStack(alignment: .leading, spacing: 0) {
            Eyebrow("На рахунку")
            Text(store.cashBalance.uah)
                .font(.display(44, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.color(forAmount: store.cashBalance))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())
                .padding(.top, 4)
                .padding(.bottom, 16)

            Rule(color: Theme.ink.opacity(0.85))
            LedgerRow(label: "Прибуток, \(monthName)",
                      value: (profit >= 0 ? "+" : "−") + abs(profit).uah,
                      valueColor: profit >= 0 ? Theme.positive : Theme.negative)
            LedgerRow(label: "Дохід, \(monthName)", value: (month?.income ?? 0).uah)
            LedgerRow(label: "Запас міцності",
                      value: runway.map { String(format: "%.1f міс.", $0) } ?? "—",
                      detail: runway == nil ? "Доходи покривають витрати" : "Скільки місяців протримаєтесь без доходу")
            LedgerRow(label: "До ліміту групи", value: max(0, limitLeft).uahCompact,
                      detail: "Використано \(store.limitUsage.percent) річного ліміту")

            incomeSparkline
                .padding(.top, 16)
        }
    }

    private var incomeSparkline: some View {
        let summaries = store.monthlySummaries(months: 6)
        return VStack(alignment: .leading, spacing: 6) {
            Chart(summaries) { summary in
                BarMark(
                    x: .value("Місяць", summary.month, unit: .month),
                    y: .value("Дохід", summary.income),
                    width: .ratio(0.28)
                )
                .foregroundStyle(summary.id == summaries.last?.id ? Theme.accent : Theme.ink.opacity(0.18))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 56)
            Text("Дохід за останні 6 місяців")
                .font(.caption)
                .foregroundStyle(Theme.inkMuted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Графік доходу за останні 6 місяців")
    }

    // MARK: - Дії

    private var actions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("Нова операція") { showAddTransaction = true }
                Button("Що якщо?") { showSimulator = true }
                Button("Податки") { selectedTab = .taxes }
                Button("Запитати радника") { selectedTab = .advisor }
            }
            .buttonStyle(.outline)
        }
    }

    // MARK: - Стан бізнесу

    private func health(_ report: HealthReport) -> some View {
        LedgerSection(title: "Стан бізнесу") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(report.score)")
                    .font(.display(56, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text("зі 100 · \(report.verdict.lowercased())")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkMuted)
            }
            .padding(.top, 10)
            .padding(.bottom, 4)
            .accessibilityElement(children: .combine)

            ForEach(report.components) { component in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(component.title).font(.body).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(component.detail)
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(Theme.inkMuted)
                    }
                    Meter(value: component.value, tint: Theme.color(forScore: component.value), height: 3)
                }
                .padding(.vertical, 12)
                Rule()
            }
        }
    }

    // MARK: - Строки

    private var deadlines: some View {
        let upcoming = Array(store.upcomingDeadlines.prefix(3))
        return LedgerSection(title: "Найближчі строки", actionTitle: "Усі", action: { selectedTab = .taxes }) {
            if upcoming.isEmpty {
                EmptyNote(text: "Найближчим часом платежів немає.")
            } else {
                ForEach(upcoming) { DeadlineRow(deadline: $0) }
            }
        }
    }

    // MARK: - Нотатки

    private func notes(_ report: HealthReport) -> some View {
        LedgerSection(title: "Нотатки") {
            ForEach(report.insights) { insight in
                InsightRow(insight: insight)
                Rule()
            }
        }
    }
}

#Preview {
    DashboardView(selectedTab: .constant(.dashboard))
        .environment(AppStore.preview)
}
