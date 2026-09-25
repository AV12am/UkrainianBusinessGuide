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
                    VStack(alignment: .leading, spacing: 20) {
                        limitCard(profile)
                        quarterCard(profile)
                        calendar
                        calculator(profile)
                        disclaimer
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
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

    private func limitCard(_ profile: BusinessProfile) -> some View {
        let limit = store.taxEngine.annualIncomeLimit(for: profile.fopGroup)
        let usage = store.limitUsage
        return HStack(spacing: 18) {
            RingGauge(progress: usage, lineWidth: 12, colors: [Theme.mint, Theme.amber, Theme.coral]) {
                VStack(spacing: 0) {
                    Text(usage.percent).font(.headline.weight(.heavy))
                    Text("ліміту").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(profile.fopGroup.title) · \(String(store.taxEngine.parameters.year))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(store.yearIncome.uah)
                    .font(.title2.weight(.heavy))
                Text("з \(limit.uah) річного ліміту")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if usage >= 0.8 {
                    Label("Сплануйте зміну групи", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.amber)
                }
            }
        }
        .glassCard(padding: 20)
    }

    // MARK: - Поточний квартал

    private func quarterCard(_ profile: BusinessProfile) -> some View {
        let breakdown = store.taxEngine.quarterlyTaxes(group: profile.fopGroup, isVATPayer: profile.isVATPayer, quarterIncome: store.quarterIncome)
        return VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Поточний квартал")
            VStack(spacing: 12) {
                HStack {
                    Text("Дохід за квартал").foregroundStyle(.secondary)
                    Spacer()
                    Text(store.quarterIncome.uah).fontWeight(.semibold)
                }
                Divider()
                taxLine("Єдиний податок", breakdown.singleTax, Theme.skyBlue)
                taxLine("Військовий збір", breakdown.militaryLevy, Theme.violet)
                taxLine("ЄСВ", breakdown.socialContribution, Theme.amber)
                Divider()
                HStack {
                    Text("Разом").font(.headline)
                    Spacer()
                    Text(breakdown.total.uah).font(.title3.weight(.heavy)).foregroundStyle(Theme.brand)
                }
                stackedBar(breakdown)
            }
            .glassCard()
        }
    }

    private func taxLine(_ title: String, _ amount: Double, _ color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(title)
            Spacer()
            Text(amount.uah).fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    private func stackedBar(_ breakdown: TaxBreakdown) -> some View {
        GeometryReader { proxy in
            let total = max(breakdown.total, 1)
            HStack(spacing: 2) {
                Theme.skyBlue.frame(width: proxy.size.width * breakdown.singleTax / total)
                Theme.violet.frame(width: proxy.size.width * breakdown.militaryLevy / total)
                Theme.amber.frame(width: proxy.size.width * breakdown.socialContribution / total)
            }
            .clipShape(Capsule())
        }
        .frame(height: 10)
    }

    // MARK: - Календар

    private var calendar: some View {
        let all = store.deadlines()
        let visible = showCompleted ? all : all.filter { !store.completedDeadlineIDs.contains($0.id) }
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Календар строків",
                         action: (title: showCompleted ? "Сховати сплачені" : "Показати всі",
                                  handler: { withAnimation { showCompleted.toggle() } }))
            if visible.isEmpty {
                Text("Усі строки на найближчі 4 місяці закриті ✅")
                    .foregroundStyle(.secondary)
                    .glassCard()
            } else {
                VStack(spacing: 14) {
                    ForEach(visible) { deadline in
                        DeadlineRow(deadline: deadline,
                                    isDone: store.completedDeadlineIDs.contains(deadline.id),
                                    onToggle: { withAnimation { store.toggleDeadline(deadline) } })
                        if deadline.id != visible.last?.id { Divider() }
                    }
                }
                .glassCard()
            }
        }
    }

    // MARK: - Калькулятор

    private func calculator(_ profile: BusinessProfile) -> some View {
        let income = calculatorIncome ?? 0
        let breakdown = store.taxEngine.quarterlyTaxes(group: calculatorGroup, isVATPayer: profile.isVATPayer, quarterIncome: income)
        let rate = store.taxEngine.effectiveRate(group: calculatorGroup, isVATPayer: profile.isVATPayer, quarterIncome: income)
        let limitExceeded = income * 4 > store.taxEngine.annualIncomeLimit(for: calculatorGroup)

        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Калькулятор ФОП")
            VStack(alignment: .leading, spacing: 14) {
                Picker("Група", selection: $calculatorGroup) {
                    ForEach(FOPGroup.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Дохід за квартал")
                    Spacer()
                    TextField("0", value: $calculatorIncome, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.headline)
                        .frame(maxWidth: 160)
                    Text("₴")
                }
                .padding(12)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading) {
                        Text("До сплати").font(.caption).foregroundStyle(.secondary)
                        Text(breakdown.total.uah).font(.title2.weight(.heavy))
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Ефективна ставка").font(.caption).foregroundStyle(.secondary)
                        Text(rate.percent).font(.title3.weight(.bold)).foregroundStyle(Theme.violet)
                    }
                }
                if limitExceeded {
                    Label("Річний дохід понад ліміт \(calculatorGroup.title)", systemImage: "exclamationmark.octagon.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.coral)
                }
                Text(explanation(for: calculatorGroup, isVATPayer: profile.isVATPayer))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .glassCard()
        }
    }

    private func explanation(for group: FOPGroup, isVATPayer: Bool) -> String {
        let engine = store.taxEngine
        let esv = engine.monthlySocialContribution.uah
        switch group {
        case .first, .second:
            let single = (engine.monthlyFixedSingleTax(for: group) ?? 0).uah
            return "Щомісяця: єдиний податок \(single) (макс. ставка), військовий збір \(engine.monthlyFixedMilitaryLevy.uah), ЄСВ \(esv)."
        case .third:
            return "\(isVATPayer ? "3%" : "5%") єдиного податку + 1% військового збору від доходу, ЄСВ \(esv) на місяць."
        }
    }

    private var disclaimer: some View {
        Label("Розрахунки орієнтовні й базуються на мінімальній зарплаті \(store.taxEngine.parameters.minimumWage.uah) та прожитковому мінімумі \(store.taxEngine.parameters.subsistenceMinimum.uah) станом на \(String(store.taxEngine.parameters.year)) рік. Місцеві ставки 1–2 груп можуть бути нижчими. Звіряйтеся з податковою або бухгалтером.",
              systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }
}

#Preview {
    TaxesView()
        .environment(AppStore.preview)
}
