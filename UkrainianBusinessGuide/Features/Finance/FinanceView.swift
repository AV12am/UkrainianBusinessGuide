//
//  FinanceView.swift
//  UkrainianBusinessGuide
//

import Charts
import SwiftUI

struct FinanceView: View {
    enum Filter: Hashable { case all, income, expense }

    @Environment(AppStore.self) private var store
    @State private var filter: Filter = .all
    @State private var showAdd = false
    @State private var showSimulator = false
    @State private var selectedMonth: Date?

    private struct ChartPoint: Identifiable {
        let month: Date
        let kind: TransactionKind
        let amount: Double
        var id: String { "\(month.timeIntervalSince1970)-\(kind.rawValue)" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    overview
                    scenarioLink
                    ledger
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .navigationTitle("Фінанси")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .tint(Theme.ink)
                    .accessibilityLabel("Додати операцію")
                }
            }
            .sheet(isPresented: $showAdd) { AddTransactionView() }
            .sheet(isPresented: $showSimulator) { ScenarioSimulatorView() }
        }
    }

    // MARK: - Огляд місяця та графік

    private var overview: some View {
        let summaries = store.monthlySummaries(months: 6)
        let points = summaries.flatMap { summary in
            [ChartPoint(month: summary.month, kind: .income, amount: summary.income),
             ChartPoint(month: summary.month, kind: .expense, amount: summary.expense)]
        }
        let selected = selectedMonth.flatMap { month in
            summaries.first { Calendar.kyiv.isDate($0.month, equalTo: month, toGranularity: .month) }
        }
        let shown = selected ?? summaries.last
        let profit = shown?.profit ?? 0

        return VStack(alignment: .leading, spacing: 0) {
            Eyebrow("Прибуток, \(shown.map { $0.month.monthName } ?? "місяць")")
            Text((profit >= 0 ? "+" : "−") + abs(profit).uah)
                .font(.display(44, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(profit >= 0 ? Theme.ink : Theme.negative)
                .contentTransition(.numericText())
                .padding(.top, 4)
            HStack(spacing: 16) {
                Text("Дохід \((shown?.income ?? 0).uah)")
                Text("Витрати \((shown?.expense ?? 0).uah)")
            }
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(Theme.inkMuted)
            .padding(.top, 4)
            .padding(.bottom, 20)

            Chart(points) { point in
                BarMark(
                    x: .value("Місяць", point.month, unit: .month),
                    y: .value("Сума", point.amount)
                )
                .foregroundStyle(by: .value("Тип", point.kind.title))
                .position(by: .value("Тип", point.kind.title))
                .opacity(isDimmed(point.month, selected: selected) ? 0.35 : 1)
            }
            .chartForegroundStyleScale([TransactionKind.income.title: Theme.accent,
                                        TransactionKind.expense.title: Theme.ink.opacity(0.25)])
            .chartLegend(position: .bottom, alignment: .leading)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                        .foregroundStyle(Theme.inkMuted)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Theme.rule)
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount.uahCompact).foregroundStyle(Theme.inkMuted)
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedMonth)
            .frame(height: 200)
        }
    }

    private func isDimmed(_ month: Date, selected: MonthSummary?) -> Bool {
        guard let selected else { return false }
        return !Calendar.kyiv.isDate(selected.month, equalTo: month, toGranularity: .month)
    }

    // MARK: - Сценарії

    private var scenarioLink: some View {
        Button {
            showSimulator = true
        } label: {
            VStack(spacing: 0) {
                Rule(color: Theme.ink.opacity(0.85))
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Що якщо?")
                            .font(.display(20))
                            .foregroundStyle(Theme.ink)
                        Text("Порахуйте, як зміна цін, найм чи нові витрати вплинуть на прибуток і податки.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkMuted)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(Theme.accent)
                }
                .padding(.vertical, 14)
                Rule()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Журнал операцій

    private var filteredTransactions: [Transaction] {
        switch filter {
        case .all: return store.transactions
        case .income: return store.transactions.filter { $0.kind == .income }
        case .expense: return store.transactions.filter { $0.kind == .expense }
        }
    }

    private var ledger: some View {
        VStack(alignment: .leading, spacing: 14) {
            FilterTabs(options: [(title: "Усі операції", value: Filter.all), (title: "Доходи", value: Filter.income), (title: "Витрати", value: Filter.expense)], selection: $filter)
            VStack(spacing: 0) {
                Rule(color: Theme.ink.opacity(0.85))
                if filteredTransactions.isEmpty {
                    EmptyNote(text: "Операцій ще немає. Додайте першу кнопкою «+» угорі.")
                }
                LazyVStack(spacing: 0) {
                    ForEach(filteredTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .contextMenu {
                                Button("Видалити", systemImage: "trash", role: .destructive) {
                                    withAnimation { store.delete(transaction) }
                                }
                            }
                    }
                }
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(transaction.date.formatted(Date.FormatStyle.kyiv.day(.twoDigits).month(.twoDigits)))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.inkMuted)
                    .frame(width: 40, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.note.isEmpty ? transaction.category.title : transaction.note)
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(transaction.category.title)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkMuted)
                }
                Spacer(minLength: 8)
                Text((transaction.kind == .income ? "+" : "−") + transaction.amount.uah)
                    .font(.body)
                    .monospacedDigit()
                    .foregroundStyle(transaction.kind == .income ? Theme.positive : Theme.ink)
            }
            .padding(.vertical, 12)
            Rule()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    FinanceView()
        .environment(AppStore.preview)
}
