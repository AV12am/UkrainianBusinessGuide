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
                let result = ScenarioSimulator.simulate(baseline, input, engine: store.taxEngine)
                ScrollView {
                    VStack(spacing: 16) {
                        resultCard(result, baseline: baseline)
                        if result.exceedsGroupLimit || result.recommendedGroup != baseline.group {
                            groupWarning(result, baseline: baseline)
                        }
                        controls
                        Button("Скинути сценарій") {
                            withAnimation { input = ScenarioInput() }
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 4)
                    }
                    .padding()
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
    }

    private func resultCard(_ result: ScenarioResult, baseline: ScenarioBaseline) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Прибуток на місяць")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
                .textCase(.uppercase)
            Text(result.monthlyProfit.uah)
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .contentTransition(.numericText(value: result.monthlyProfit))
            HStack(spacing: 6) {
                Image(systemName: result.profitDelta >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text("\(result.profitDelta >= 0 ? "+" : "−")\(abs(result.profitDelta).uah) до поточного")
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.2), in: Capsule())

            Divider().overlay(.white.opacity(0.3))

            HStack {
                resultMetric("Дохід", result.monthlyIncome.uahCompact)
                resultMetric("Витрати", result.monthlyExpense.uahCompact)
                resultMetric("Податки", result.monthlyTaxes.uahCompact)
                resultMetric("Запас", result.runwayMonths.map { String(format: "%.1f міс", $0) } ?? "∞")
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: result.monthlyProfit >= 0 ? [Theme.blue, Theme.violet] : [Theme.coral, Theme.amber],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
        )
        .animation(.spring, value: result)
    }

    private func resultMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.subheadline.weight(.bold)).minimumScaleFactor(0.6).lineLimit(1)
            Text(title).font(.caption2).opacity(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func groupWarning(_ result: ScenarioResult, baseline: ScenarioBaseline) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(systemName: result.exceedsGroupLimit ? "exclamationmark.triangle.fill" : "lightbulb.fill",
                      tint: result.exceedsGroupLimit ? Theme.coral : Theme.amber)
            VStack(alignment: .leading, spacing: 4) {
                Text(result.exceedsGroupLimit ? "Перевищення ліміту \(baseline.group.title)" : "Можна платити менше")
                    .font(.subheadline.weight(.semibold))
                Text("Річний дохід за сценарієм — \(result.annualIncome.uahCompact). Оптимальна група: \(result.recommendedGroup.title). Перевірте, чи ваш вид діяльності їй відповідає.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .glassCard()
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 20) {
            percentSlider("Обсяг продажів", "cart.fill", value: $input.volumeChange, range: -0.5...1)
            percentSlider("Ціни", "tag.fill", value: $input.priceChange, range: -0.3...0.5)
            percentSlider("Інші витрати", "arrow.up.arrow.down", value: $input.expenseChange, range: -0.5...1)

            VStack(alignment: .leading, spacing: 8) {
                Stepper(value: $input.newHires, in: 0...20) {
                    Label("Нові працівники: \(input.newHires)", systemImage: "person.badge.plus")
                        .font(.subheadline.weight(.semibold))
                }
                if input.newHires > 0 {
                    HStack {
                        Text("Зарплата кожного")
                        Spacer()
                        Text(input.salaryPerHire.uah).fontWeight(.semibold)
                    }
                    .font(.footnote)
                    Slider(value: $input.salaryPerHire, in: 8_647...100_000, step: 1_000)
                    Text("+ ЄСВ 22% від роботодавця")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Додатковий маркетинг", systemImage: "megaphone.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(input.marketingBudget.uah).font(.footnote.weight(.semibold))
                }
                Slider(value: $input.marketingBudget, in: 0...100_000, step: 1_000)
            }
        }
        .glassCard(padding: 20)
    }

    private func percentSlider(_ title: String, _ icon: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon).font(.subheadline.weight(.semibold))
                Spacer()
                Text((value.wrappedValue >= 0 ? "+" : "") + value.wrappedValue.percent)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(value.wrappedValue == 0 ? Color.secondary : (value.wrappedValue > 0 ? Theme.mint : Theme.coral))
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: 0.05)
        }
    }
}

#Preview {
    ScenarioSimulatorView()
        .environment(AppStore.preview)
}
