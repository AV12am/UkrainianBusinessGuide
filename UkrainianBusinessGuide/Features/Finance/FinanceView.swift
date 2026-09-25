//
//  FinanceView.swift
//  UkrainianBusinessGuide
//

import Charts
import SwiftUI

struct FinanceView: View {
    @Environment(AppStore.self) private var store
    @State private var filter: TransactionKind?
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
            List {
                Section {
                    chartCard
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    simulatorBanner
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                }
                .listRowSeparator(.hidden)

                Section {
                    filterBar
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    if filteredTransactions.isEmpty {
                        ContentUnavailableView("Операцій ще немає", systemImage: "tray",
                                               description: Text("Додайте перший дохід чи витрату кнопкою «+»."))
                            .listRowBackground(Color.clear)
                    }
                    ForEach(filteredTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .listRowBackground(Rectangle().fill(.ultraThinMaterial))
                            .swipeActions {
                                Button(role: .destructive) {
                                    withAnimation { store.delete(transaction) }
                                } label: {
                                    Label("Видалити", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text("Операції").font(.title3.weight(.bold)).foregroundStyle(.primary).textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .screenBackground()
            .navigationTitle("Фінанси")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                    .accessibilityLabel("Додати операцію")
                }
            }
            .sheet(isPresented: $showAdd) { AddTransactionView() }
            .sheet(isPresented: $showSimulator) { ScenarioSimulatorView() }
        }
    }

    private var filteredTransactions: [Transaction] {
        guard let filter else { return store.transactions }
        return store.transactions.filter { $0.kind == filter }
    }

    // MARK: - Графік

    private var chartCard: some View {
        let summaries = store.monthlySummaries(months: 6)
        let points = summaries.flatMap { summary in
            [ChartPoint(month: summary.month, kind: .income, amount: summary.income),
             ChartPoint(month: summary.month, kind: .expense, amount: summary.expense)]
        }
        let selected = selectedMonth.flatMap { month in
            summaries.first { Calendar.kyiv.isDate($0.month, equalTo: month, toGranularity: .month) }
        }
        let highlighted = selected ?? summaries.last

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(highlighted.map { $0.month.monthName.capitalized } ?? "Цей місяць")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                HStack(alignment: .firstTextBaseline) {
                    Text((highlighted?.profit ?? 0).uah)
                        .font(.system(.title, design: .rounded, weight: .heavy))
                        .foregroundStyle((highlighted?.profit ?? 0) >= 0 ? Theme.mint : Theme.coral)
                        .contentTransition(.numericText())
                    Text("прибуток").foregroundStyle(.secondary)
                }
            }

            Chart(points) { point in
                BarMark(
                    x: .value("Місяць", point.month, unit: .month),
                    y: .value("Сума", point.amount)
                )
                .foregroundStyle(by: .value("Тип", point.kind.title))
                .position(by: .value("Тип", point.kind.title))
                .cornerRadius(6)
                .opacity(isDimmed(point.month, selected: selected) ? 0.45 : 1)
            }
            .chartForegroundStyleScale([TransactionKind.income.title: Theme.mint, TransactionKind.expense.title: Theme.coral])
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount.uahCompact)
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedMonth)
            .frame(height: 200)
        }
        .glassCard(padding: 20)
    }

    private func isDimmed(_ month: Date, selected: MonthSummary?) -> Bool {
        guard let selected else { return false }
        return !Calendar.kyiv.isDate(selected.month, equalTo: month, toGranularity: .month)
    }

    private var simulatorBanner: some View {
        Button {
            showSimulator = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Симулятор «Що якщо»").font(.headline)
                    Text("Ціни, найм, витрати → прибуток і податки").font(.caption).opacity(0.85)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(
                LinearGradient(colors: [Theme.violet, Theme.blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            Chip(title: "Усі", isSelected: filter == nil) { filter = nil }
            Chip(title: "Доходи", icon: "arrow.down.left", isSelected: filter == .income) { filter = .income }
            Chip(title: "Витрати", icon: "arrow.up.right", isSelected: filter == .expense) { filter = .expense }
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(systemName: transaction.category.icon, tint: transaction.kind == .income ? Theme.mint : Theme.coral, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.note.isEmpty ? transaction.category.title : transaction.note)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(transaction.category.title) · \(transaction.date.shortUkrainian)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text((transaction.kind == .income ? "+" : "−") + transaction.amount.uah)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(transaction.kind == .income ? Theme.mint : .primary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    FinanceView()
        .environment(AppStore.preview)
}
