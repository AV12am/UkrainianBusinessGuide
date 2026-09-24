//
//  ScenarioSimulator.swift
//  UkrainianBusinessGuide
//
//  Симулятор «Що якщо»: як зміна цін, продажів, витрат або найм людей вплине на
//  прибуток, податки, запас міцності та відповідність ліміту групи ФОП.
//

import Foundation

struct ScenarioBaseline: Equatable {
    var monthlyIncome: Double
    var monthlyExpense: Double
    var cash: Double
    var group: FOPGroup
    var isVATPayer: Bool
}

struct ScenarioInput: Equatable {
    /// Зміна кількості продажів, -0.5…+1
    var volumeChange: Double = 0
    /// Зміна цін, -0.3…+0.5
    var priceChange: Double = 0
    /// Зміна витрат, -0.5…+1
    var expenseChange: Double = 0
    var newHires: Int = 0
    var salaryPerHire: Double = 20_000
    var marketingBudget: Double = 0
}

struct ScenarioResult: Equatable {
    var monthlyIncome: Double
    var monthlyExpense: Double
    var monthlyTaxes: Double
    var monthlyProfit: Double
    var runwayMonths: Double?
    var annualIncome: Double
    var exceedsGroupLimit: Bool
    var recommendedGroup: FOPGroup
    var profitDelta: Double
}

enum ScenarioSimulator {
    /// Роботодавець сплачує ЄСВ 22% понад зарплату.
    static let employerContributionRate = 0.22

    static func simulate(_ baseline: ScenarioBaseline, _ input: ScenarioInput, engine: TaxEngine = TaxEngine()) -> ScenarioResult {
        let baseTaxes = engine.monthlyTaxes(group: baseline.group, isVATPayer: baseline.isVATPayer, monthlyIncome: baseline.monthlyIncome)
        let baseProfit = baseline.monthlyIncome - baseline.monthlyExpense - baseTaxes

        let income = max(0, baseline.monthlyIncome * (1 + input.volumeChange) * (1 + input.priceChange))
        // Змінна частина витрат (закупівлі) зростає разом з обсягом; приймаємо 40% витрат як змінні.
        let variableShare = 0.4
        let scaledExpense = baseline.monthlyExpense * ((1 - variableShare) + variableShare * (1 + input.volumeChange))
        let payroll = Double(input.newHires) * input.salaryPerHire * (1 + employerContributionRate)
        let expense = max(0, scaledExpense * (1 + input.expenseChange) + payroll + input.marketingBudget)

        let taxes = engine.monthlyTaxes(group: baseline.group, isVATPayer: baseline.isVATPayer, monthlyIncome: income)
        let profit = income - expense - taxes
        let annual = income * 12
        let limit = engine.annualIncomeLimit(for: baseline.group)

        return ScenarioResult(
            monthlyIncome: income,
            monthlyExpense: expense,
            monthlyTaxes: taxes,
            monthlyProfit: profit,
            runwayMonths: HealthAnalyzer.runwayMonths(cash: baseline.cash, monthlyIncome: income, monthlyExpense: expense + taxes),
            annualIncome: annual,
            exceedsGroupLimit: annual > limit,
            recommendedGroup: engine.recommendedGroup(forAnnualIncome: annual, isVATPayer: baseline.isVATPayer),
            profitDelta: profit - baseProfit
        )
    }
}
