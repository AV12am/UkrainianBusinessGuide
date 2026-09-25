//
//  TaxesView.swift
//  UkrainianBusinessGuide
//

import SwiftUI

struct TaxesView: View {
    @Environment(AppStore.self) private var store
    @State private var calculatorIncome: Double?
    @State private var calculatorGroup: FOPGroup = .third
    @State private var showCompleted = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile = store.profile {
                    VStack(alignment: .leading, spacing: 36) {
                        limit(profile)
                        quarter(profile)
                        calendar
                        calculator(profile)
                        disclaimer
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 32)
                }
            }
            .screenBackground()
            .navigationTitle("Податки")
            .onAppear {
                if let group = store.profile?.fopGroup { calculatorGroup = group }
            }
        }
    }

    // MARK: - Ліміт

    private func limit(_ profile: BusinessProfile) -> some View {
        let engine = store.taxEngine
        let limit = engine.annualIncomeLimit(for: profile.fopGroup)
        let usage = store.limitUsage
        let tint = usage >= 0.9 ? Theme.negative : (usage >= 0.7 ? Theme.caution : Theme.ink)

        return VStack(alignment: .leading, spacing: 0) {
            Eyebrow("\(profile.fopGroup.title) · дохід за \(String(engine.parameters.year)) рік")
            Text(store.yearIncome.uah)
                .font(.display(44, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.top, 4)
            Text("\(usage.percent) з річного ліміту \(limit.uah)")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(Theme.inkMuted)
                .padding(.top, 4)
                .padding(.bottom, 14)
            Meter(value: usage, tint: tint, marks: [0.7, 0.9], height: 6)
            Text("Позначки на шкалі — 70% і 90% ліміту")
                .font(.caption2)
                .foregroundStyle(Theme.inkMuted)
                .padding(.top, 8)
            if usage >= 0.8 {
                Text("Ліміт близько: сплануйте перехід на іншу групу або систему оподаткування.")
                    .font(.footnote)
                    .foregroundStyle(Theme.caution)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Поточний квартал

    private func quarter(_ profile: BusinessProfile) -> some View {
        let breakdown = store.taxEngine.quarterlyTaxes(group: profile.fopGroup, isVATPayer: profile.isVATPayer, quarterIncome: store.quarterIncome)
        return LedgerSection(title: "Поточний квартал") {
            LedgerRow(label: "Дохід за квартал", value: store.quarterIncome.uah)
            LedgerRow(label: "Єдиний податок", value: breakdown.singleTax.uah,
                      detail: profile.fopGroup == .third ? (profile.isVATPayer ? "3% доходу" : "5% доходу") : "Фіксована ставка")
            LedgerRow(label: "Військовий збір", value: breakdown.militaryLevy.uah,
                      detail: profile.fopGroup == .third ? "1% доходу" : "10% мінімальної зарплати")
            LedgerRow(label: "ЄСВ", value: breakdown.socialContribution.uah, detail: "22% мінімальної зарплати")
            LedgerRow(label: "Разом до сплати", value: breakdown.total.uah, emphasized: true, showsRule: false)
        }
    }

    // MARK: - Календар

    private var calendar: some View {
        let all = store.deadlines()
        let visible = showCompleted ? all : all.filter { !store.completedDeadlineIDs.contains($0.id) }
        return LedgerSection(title: "Календар строків",
                             actionTitle: showCompleted ? "Сховати сплачені" : "Показати всі",
                             action: { withAnimation { showCompleted.toggle() } }) {
            if visible.isEmpty {
                EmptyNote(text: "Усі строки на найближчі чотири місяці закриті.")
            } else {
                ForEach(visible) { deadline in
                    DeadlineRow(deadline: deadline,
                                isDone: store.completedDeadlineIDs.contains(deadline.id),
                                onToggle: { withAnimation { store.toggleDeadline(deadline) } })
                }
            }
        }
    }

    // MARK: - Калькулятор

    private func calculator(_ profile: BusinessProfile) -> some View {
        let engine = store.taxEngine
        let income = calculatorIncome ?? 0
        let breakdown = engine.quarterlyTaxes(group: calculatorGroup, isVATPayer: profile.isVATPayer, quarterIncome: income)
        let rate = engine.effectiveRate(group: calculatorGroup, isVATPayer: profile.isVATPayer, quarterIncome: income)
        let limitExceeded = income * 4 > engine.annualIncomeLimit(for: calculatorGroup)

        return LedgerSection(title: "Калькулятор") {
            Picker("Група", selection: $calculatorGroup) {
                ForEach(FOPGroup.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 14)

            HStack(alignment: .firstTextBaseline) {
                Text("Дохід за квартал")
                Spacer()
                TextField("0", value: $calculatorIncome, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(maxWidth: 160)
                Text("₴").foregroundStyle(Theme.inkMuted)
            }
            .padding(12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.rule))
            .padding(.bottom, 4)

            LedgerRow(label: "До сплати за квартал", value: breakdown.total.uah)
            LedgerRow(label: "Ефективна ставка", value: rate.percent, showsRule: false)

            if limitExceeded {
                Text("Річний дохід понад ліміт \(calculatorGroup.title).")
                    .font(.footnote)
                    .foregroundStyle(Theme.negative)
                    .padding(.top, 4)
            }
            Text(explanation(for: calculatorGroup, isVATPayer: profile.isVATPayer))
                .font(.footnote)
                .foregroundStyle(Theme.inkMuted)
                .padding(.top, 8)
        }
    }

    private func explanation(for group: FOPGroup, isVATPayer: Bool) -> String {
        let engine = store.taxEngine
        let esv = engine.monthlySocialContribution.uah
        switch group {
        case .first, .second:
            let single = (engine.monthlyFixedSingleTax(for: group) ?? 0).uah
            return "Щомісяця: єдиний податок \(single) (максимальна ставка), військовий збір \(engine.monthlyFixedMilitaryLevy.uah), ЄСВ \(esv)."
        case .third:
            return "\(isVATPayer ? "3" : "5")% єдиного податку й 1% військового збору від доходу, плюс ЄСВ \(esv) на місяць."
        }
    }

    private var disclaimer: some View {
        let parameters = store.taxEngine.parameters
        return Text("Розрахунки орієнтовні: мінімальна зарплата \(parameters.minimumWage.uah), прожитковий мінімум \(parameters.subsistenceMinimum.uah) станом на \(String(parameters.year)) рік. Місцеві ставки для 1–2 груп можуть бути нижчими. Звіряйтеся з податковою або бухгалтером.")
            .font(.footnote)
            .foregroundStyle(Theme.inkMuted)
    }
}

#Preview {
    TaxesView()
        .environment(AppStore.preview)
}
