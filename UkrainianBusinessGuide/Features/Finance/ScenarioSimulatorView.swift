//
//  ScenarioSimulatorView.swift
//  UkrainianBusinessGuide
//

import SwiftUI

struct ScenarioSimulatorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var input = ScenarioInput()

    var body: some View {
        NavigationStack {
            if let baseline = store.scenarioBaseline {
                let current = ScenarioSimulator.simulate(baseline, ScenarioInput(), engine: store.taxEngine)
                let result = ScenarioSimulator.simulate(baseline, input, engine: store.taxEngine)
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        headline(result)
                        comparison(current: current, result: result)
                        if result.exceedsGroupLimit || result.recommendedGroup != baseline.group {
                            groupNote(result, baseline: baseline)
                        }
                        controls
                        Button("Скинути сценарій") {
                            withAnimation { input = ScenarioInput() }
                        }
                        .buttonStyle(.outline)
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 32)
                }
                .screenBackground()
                .navigationTitle("Що якщо?")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Готово") { dismiss() }
                    }
                }
            }
        }
        .tint(Theme.accent)
    }

    private func headline(_ result: ScenarioResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow("Прибуток на місяць за сценарієм")
            Text(result.monthlyProfit.uah)
                .font(.display(44, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.color(forAmount: result.monthlyProfit))
                .contentTransition(.numericText(value: result.monthlyProfit))
            Text("\(result.profitDelta >= 0 ? "+" : "−")\(abs(result.profitDelta).uah) до поточного")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(result.profitDelta >= 0 ? Theme.positive : Theme.negative)
        }
        .padding(.top, 8)
        .animation(.easeOut(duration: 0.25), value: result)
    }

    private func comparison(current: ScenarioResult, result: ScenarioResult) -> some View {
        VStack(spacing: 0) {
            HStack {
                Eyebrow("На місяць")
                Spacer()
                Eyebrow("Зараз").frame(width: 96, alignment: .trailing)
                Eyebrow("Сценарій", color: Theme.ink).frame(width: 96, alignment: .trailing)
            }
            .padding(.bottom, 8)
            Rule(color: Theme.ink.opacity(0.85))
            comparisonRow("Дохід", current.monthlyIncome.uahCompact, result.monthlyIncome.uahCompact)
            comparisonRow("Витрати", current.monthlyExpense.uahCompact, result.monthlyExpense.uahCompact)
            comparisonRow("Податки", current.monthlyTaxes.uahCompact, result.monthlyTaxes.uahCompact)
            comparisonRow("Прибуток", current.monthlyProfit.uahCompact, result.monthlyProfit.uahCompact, emphasized: true)
            comparisonRow("Запас міцності", runway(current), runway(result))
        }
    }

    private func runway(_ result: ScenarioResult) -> String {
        result.runwayMonths.map { String(format: "%.1f міс.", $0) } ?? "—"
    }

    private func comparisonRow(_ title: String, _ now: String, _ then: String, emphasized: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(emphasized ? .body.weight(.semibold) : .body)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(now)
                    .foregroundStyle(Theme.inkMuted)
                    .frame(width: 96, alignment: .trailing)
                Text(then)
                    .fontWeight(emphasized ? .semibold : .regular)
                    .foregroundStyle(Theme.ink)
                    .frame(width: 96, alignment: .trailing)
            }
            .font(.body)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.vertical, 11)
            Rule()
        }
    }

    private func groupNote(_ result: ScenarioResult, baseline: ScenarioBaseline) -> some View {
        InsightRow(insight: Insight(
            id: "group",
            icon: "",
            title: result.exceedsGroupLimit ? "Дохід перевищить ліміт \(baseline.group.title)" : "Можна платити менше податків",
            message: "Річний дохід за сценарієм: \(result.annualIncome.uahCompact). Вигідніша група: \(result.recommendedGroup.title). Перевірте, чи ваш вид діяльності їй відповідає.",
            severity: result.exceedsGroupLimit ? .critical : .warning
        ))
    }

    private var controls: some View {
        LedgerSection(title: "Параметри") {
            percentSlider("Обсяг продажів", value: $input.volumeChange, range: -0.5...1)
            percentSlider("Ціни", value: $input.priceChange, range: -0.3...0.5)
            percentSlider("Інші витрати", value: $input.expenseChange, range: -0.5...1)

            VStack(alignment: .leading, spacing: 10) {
                Stepper(value: $input.newHires, in: 0...20) {
                    HStack {
                        Text("Нові працівники")
                        Spacer()
                        Text("\(input.newHires)").monospacedDigit().foregroundStyle(Theme.inkMuted)
                    }
                }
                if input.newHires > 0 {
                    HStack {
                        Text("Зарплата кожного").font(.subheadline)
                        Spacer()
                        Text(input.salaryPerHire.uah).font(.subheadline).monospacedDigit()
                    }
                    Slider(value: $input.salaryPerHire, in: 8_647...100_000, step: 1_000)
                    Text("Плюс ЄСВ 22% від роботодавця")
                        .font(.caption)
                        .foregroundStyle(Theme.inkMuted)
                }
            }
            .padding(.vertical, 14)
            Rule()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Додатковий маркетинг")
                    Spacer()
                    Text(input.marketingBudget.uah).monospacedDigit().foregroundStyle(Theme.inkMuted)
                }
                Slider(value: $input.marketingBudget, in: 0...100_000, step: 1_000)
            }
            .padding(.vertical, 14)
            Rule()
        }
    }

    private func percentSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                Spacer()
                Text((value.wrappedValue > 0 ? "+" : "") + value.wrappedValue.percent)
                    .monospacedDigit()
                    .foregroundStyle(value.wrappedValue == 0 ? Theme.inkMuted : (value.wrappedValue > 0 ? Theme.positive : Theme.negative))
            }
            Slider(value: value, in: range, step: 0.05)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Rule() }
    }
}

#Preview {
    ScenarioSimulatorView()
        .environment(AppStore.preview)
}
