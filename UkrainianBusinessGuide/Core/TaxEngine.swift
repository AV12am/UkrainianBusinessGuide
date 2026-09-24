//
//  TaxEngine.swift
//  UkrainianBusinessGuide
//
//  Розрахунок податків ФОП на спрощеній системі: єдиний податок, військовий збір, ЄСВ,
//  ліміти доходу та податковий календар. Параметри винесені в `TaxParameters`,
//  щоб оновлювати їх щороку без зміни логіки.
//

import Foundation

struct TaxParameters: Codable, Equatable {
    var year: Int
    /// Мінімальна заробітна плата на 1 січня.
    var minimumWage: Double
    /// Прожитковий мінімум для працездатних осіб на 1 січня.
    var subsistenceMinimum: Double

    static let y2026 = TaxParameters(year: 2026, minimumWage: 8_647, subsistenceMinimum: 3_328)
}

struct TaxBreakdown: Equatable {
    var singleTax: Double
    var militaryLevy: Double
    var socialContribution: Double

    var total: Double { singleTax + militaryLevy + socialContribution }
}

struct TaxDeadline: Identifiable, Equatable {
    enum Kind: Equatable {
        case payment, declaration
    }

    let id: String
    let title: String
    let detail: String
    let date: Date
    let kind: Kind
    var estimatedAmount: Double?
}

struct TaxEngine {
    var parameters: TaxParameters = .y2026
    var calendar: Calendar = .kyiv

    // MARK: - Ставки

    /// Мінімальний ЄСВ за місяць: 22% від мінімальної зарплати.
    var monthlySocialContribution: Double {
        (parameters.minimumWage * 0.22).roundedToKopiyky
    }

    /// Річний ліміт доходу для групи (у мінімальних зарплатах).
    func annualIncomeLimit(for group: FOPGroup) -> Double {
        let multiplier: Double
        switch group {
        case .first: multiplier = 167
        case .second: multiplier = 834
        case .third: multiplier = 1_167
        }
        return parameters.minimumWage * multiplier
    }

    /// Фіксований єдиний податок за місяць для 1–2 груп (за максимальною ставкою).
    func monthlyFixedSingleTax(for group: FOPGroup) -> Double? {
        switch group {
        case .first: return (parameters.subsistenceMinimum * 0.10).roundedToKopiyky
        case .second: return (parameters.minimumWage * 0.20).roundedToKopiyky
        case .third: return nil
        }
    }

    /// Відсоткова ставка єдиного податку для 3 групи.
    func singleTaxRate(for group: FOPGroup, isVATPayer: Bool) -> Double? {
        guard group == .third else { return nil }
        return isVATPayer ? 0.03 : 0.05
    }

    /// Військовий збір за місяць для 1–2 груп: 10% мінімальної зарплати.
    var monthlyFixedMilitaryLevy: Double {
        (parameters.minimumWage * 0.10).roundedToKopiyky
    }

    // MARK: - Розрахунки

    /// Податкове навантаження за квартал.
    func quarterlyTaxes(group: FOPGroup, isVATPayer: Bool, quarterIncome: Double) -> TaxBreakdown {
        let income = max(0, quarterIncome)
        let social = monthlySocialContribution * 3
        switch group {
        case .first, .second:
            return TaxBreakdown(
                singleTax: (monthlyFixedSingleTax(for: group) ?? 0) * 3,
                militaryLevy: monthlyFixedMilitaryLevy * 3,
                socialContribution: social
            )
        case .third:
            let rate = singleTaxRate(for: group, isVATPayer: isVATPayer) ?? 0.05
            return TaxBreakdown(
                singleTax: (income * rate).roundedToKopiyky,
                militaryLevy: (income * 0.01).roundedToKopiyky,
                socialContribution: social
            )
        }
    }

    /// Податки за місяць за середнього місячного доходу — для симулятора та дашборду.
    func monthlyTaxes(group: FOPGroup, isVATPayer: Bool, monthlyIncome: Double) -> Double {
        quarterlyTaxes(group: group, isVATPayer: isVATPayer, quarterIncome: monthlyIncome * 3).total / 3
    }

    /// Ефективна ставка: усі податки / дохід.
    func effectiveRate(group: FOPGroup, isVATPayer: Bool, quarterIncome: Double) -> Double {
        guard quarterIncome > 0 else { return 0 }
        return quarterlyTaxes(group: group, isVATPayer: isVATPayer, quarterIncome: quarterIncome).total / quarterIncome
    }

    /// Частка використаного річного ліміту (0…∞).
    func limitUsage(group: FOPGroup, yearIncome: Double) -> Double {
        yearIncome / annualIncomeLimit(for: group)
    }

    /// Найвигідніша група для прогнозованого річного доходу (без урахування обмежень на види діяльності).
    func recommendedGroup(forAnnualIncome income: Double, isVATPayer: Bool) -> FOPGroup {
        let candidates = FOPGroup.allCases.filter { annualIncomeLimit(for: $0) >= income }
        let cheapest = candidates.min { lhs, rhs in
            quarterlyTaxes(group: lhs, isVATPayer: isVATPayer, quarterIncome: income / 4).total <
                quarterlyTaxes(group: rhs, isVATPayer: isVATPayer, quarterIncome: income / 4).total
        }
        return cheapest ?? .third
    }

    // MARK: - Податковий календар

    /// Строки сплати та звітності на горизонті `horizonDays` від дати `from`.
    /// `quarterIncome` повертає дохід за квартал — щоб показати орієнтовну суму до сплати.
    func deadlines(
        for group: FOPGroup,
        isVATPayer: Bool,
        from start: Date,
        horizonDays: Int = 120,
        quarterIncome: (DateInterval) -> Double = { _ in 0 }
    ) -> [TaxDeadline] {
        let today = calendar.startOfDay(for: start)
        guard let end = calendar.date(byAdding: .day, value: horizonDays, to: today) else { return [] }
        let currentYear = calendar.component(.year, from: today)
        var result: [TaxDeadline] = []

        for year in (currentYear - 1)...(currentYear + 1) {
            for quarter in 1...4 {
                guard let interval = quarterInterval(year: year, quarter: quarter),
                      let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) else { continue }
                let label = "\(quarter) кв. \(year)"

                // ЄСВ — до 20 числа місяця, що настає за кварталом.
                if let esvDate = day(20, ofMonthOf: interval.end) {
                    result.append(TaxDeadline(
                        id: "esv-\(year)-q\(quarter)",
                        title: "ЄСВ за \(label)",
                        detail: "Мінімальний внесок: 22% × мінімальна зарплата × 3 місяці",
                        date: esvDate,
                        kind: .payment,
                        estimatedAmount: monthlySocialContribution * 3
                    ))
                }

                if group == .third {
                    let income = quarterIncome(interval)
                    let taxes = quarterlyTaxes(group: group, isVATPayer: isVATPayer, quarterIncome: income)
                    if let declaration = calendar.date(byAdding: .day, value: 40, to: lastDay) {
                        result.append(TaxDeadline(
                            id: "decl-\(year)-q\(quarter)",
                            title: "Декларація за \(label)",
                            detail: "Податкова декларація платника єдиного податку (40 днів після кварталу)",
                            date: declaration,
                            kind: .declaration,
                            estimatedAmount: nil
                        ))
                    }
                    if let payment = calendar.date(byAdding: .day, value: 50, to: lastDay) {
                        result.append(TaxDeadline(
                            id: "ep3-\(year)-q\(quarter)",
                            title: "Єдиний податок + ВЗ за \(label)",
                            detail: "\(Int((singleTaxRate(for: group, isVATPayer: isVATPayer) ?? 0.05) * 100))% єдиного податку та 1% військового збору від доходу",
                            date: payment,
                            kind: .payment,
                            estimatedAmount: taxes.singleTax + taxes.militaryLevy
                        ))
                    }
                }
            }

            if group != .third {
                // Авансові платежі — до 20 числа поточного місяця.
                for month in 1...12 {
                    guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 20)) else { continue }
                    result.append(TaxDeadline(
                        id: "ep12-\(year)-\(month)",
                        title: "Єдиний податок + ВЗ за \(date.monthName)",
                        detail: "Авансовий платіж за поточний місяць",
                        date: date,
                        kind: .payment,
                        estimatedAmount: (monthlyFixedSingleTax(for: group) ?? 0) + monthlyFixedMilitaryLevy
                    ))
                }
                // Річна декларація — 60 днів після закінчення року.
                if let yearEnd = calendar.date(from: DateComponents(year: year, month: 12, day: 31)),
                   let declaration = calendar.date(byAdding: .day, value: 60, to: yearEnd) {
                    result.append(TaxDeadline(
                        id: "decl-\(year)",
                        title: "Річна декларація за \(year)",
                        detail: "Декларація платника єдиного податку 1–2 групи",
                        date: declaration,
                        kind: .declaration,
                        estimatedAmount: nil
                    ))
                }
            }
        }

        return result
            .filter { $0.date >= today && $0.date <= end }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Календарні допоміжні

    func quarterInterval(year: Int, quarter: Int) -> DateInterval? {
        let startMonth = (quarter - 1) * 3 + 1
        guard let start = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1)),
              let end = calendar.date(byAdding: .month, value: 3, to: start) else { return nil }
        return DateInterval(start: start, end: end)
    }

    func quarterInterval(containing date: Date) -> DateInterval? {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return quarterInterval(year: year, quarter: (month - 1) / 3 + 1)
    }

    func yearInterval(containing date: Date) -> DateInterval? {
        calendar.dateInterval(of: .year, for: date)
    }

    private func day(_ day: Int, ofMonthOf date: Date) -> Date? {
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = day
        return calendar.date(from: components)
    }
}
