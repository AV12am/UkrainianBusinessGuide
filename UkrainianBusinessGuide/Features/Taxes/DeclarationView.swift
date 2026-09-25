//
//  DeclarationView.swift
//  UkrainianBusinessGuide
//
//  Суми для декларації платника єдиного податку — у тому вигляді, як їх вносять
//  в Електронному кабінеті.
//

import SwiftUI

struct DeclarationView: View {
    @Environment(AppStore.self) private var store
    @State private var year = Calendar.kyiv.component(.year, from: .now)

    private struct QuarterRow: Identifiable {
        let quarter: Int
        let income: Double
        let cumulative: Double
        let taxes: TaxBreakdown
        var id: Int { quarter }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Picker("Рік", selection: $year) {
                    ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                }
                .pickerStyle(.segmented)

                if let profile = store.profile {
                    if profile.fopGroup == .third {
                        thirdGroup(profile)
                    } else {
                        fixedGroup(profile)
                    }
                }

                Text("Цифри взято з журналу операцій. Перед поданням переконайтеся, що внесено всі доходи, зокрема готівкові й отримані на картку.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkMuted)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .screenBackground()
        .navigationTitle("Для декларації")
    }

    private var years: [Int] {
        let current = Calendar.kyiv.component(.year, from: .now)
        return [current - 1, current]
    }

    private func rows(_ profile: BusinessProfile) -> [QuarterRow] {
        var cumulative = 0.0
        var result: [QuarterRow] = []
        for quarter in 1...4 {
            guard let interval = store.taxEngine.quarterInterval(year: year, quarter: quarter),
                  interval.start <= .now else { break }
            let income = store.income(in: interval)
            cumulative += income
            let taxes = store.taxEngine.quarterlyTaxes(group: profile.fopGroup, isVATPayer: profile.isVATPayer, quarterIncome: income)
            result.append(QuarterRow(quarter: quarter, income: income, cumulative: cumulative, taxes: taxes))
        }
        return result
    }

    // MARK: - 3 група

    private func thirdGroup(_ profile: BusinessProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            LedgerSection(title: "Декларація 3 групи") {
                let items = rows(profile)
                if items.isEmpty {
                    EmptyNote(text: "За цей рік ще немає звітних кварталів.")
                }
                ForEach(items) { row in
                    LedgerRow(label: "\(row.quarter) квартал, з початку року",
                              value: row.cumulative.uah,
                              detail: "За квартал \(row.income.uah). Єдиний податок \(row.taxes.singleTax.uah), військовий збір \(row.taxes.militaryLevy.uah).",
                              showsRule: row.id != items.last?.id)
                }
            }
            Text("У декларації 3 групи дохід вказують наростаючим підсумком з початку року, а податки вказують лише за звітний квартал. Декларацію подають в Електронному кабінеті протягом 40 днів після кінця кварталу, податки сплачують протягом 50 днів.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 1–2 групи

    private func fixedGroup(_ profile: BusinessProfile) -> some View {
        let items = rows(profile)
        let total = items.last?.cumulative ?? 0
        let limit = store.taxEngine.annualIncomeLimit(for: profile.fopGroup)
        return VStack(alignment: .leading, spacing: 14) {
            LedgerSection(title: "Річна декларація, \(profile.fopGroup.title)") {
                LedgerRow(label: "Дохід за \(String(year)) рік", value: total.uah, emphasized: true)
                LedgerRow(label: "Ліміт групи", value: limit.uah,
                          detail: "Використано \(store.taxEngine.limitUsage(group: profile.fopGroup, yearIncome: total).percent)")
                ForEach(items) { row in
                    LedgerRow(label: "\(row.quarter) квартал", value: row.income.uah, showsRule: row.id != items.last?.id)
                }
            }
            Text("Декларацію 1–2 груп подають раз на рік, протягом 60 днів після його завершення. Єдиний податок і військовий збір сплачують щомісяця фіксованою сумою, тому в декларації головне вказати суму доходу.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
