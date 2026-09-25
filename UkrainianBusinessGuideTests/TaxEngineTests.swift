//
//  TaxEngineTests.swift
//  UkrainianBusinessGuideTests
//

import XCTest
@testable import UkrainianBusinessGuide

final class TaxEngineTests: XCTestCase {
    private let engine = TaxEngine()

    func testAnnualLimitsFollowMinimumWageMultipliers() {
        XCTAssertEqual(engine.annualIncomeLimit(for: .first), 8_647 * 167, accuracy: 0.01)
        XCTAssertEqual(engine.annualIncomeLimit(for: .second), 8_647 * 834, accuracy: 0.01)
        XCTAssertEqual(engine.annualIncomeLimit(for: .third), 8_647 * 1_167, accuracy: 0.01)
    }

    func testThirdGroupQuarterlyTaxes() {
        let taxes = engine.quarterlyTaxes(group: .third, isVATPayer: false, quarterIncome: 300_000)
        XCTAssertEqual(taxes.singleTax, 15_000, accuracy: 0.01)
        XCTAssertEqual(taxes.militaryLevy, 3_000, accuracy: 0.01)
        XCTAssertEqual(taxes.socialContribution, 1_902.34 * 3, accuracy: 0.01)
    }

    func testThirdGroupVATPayerRate() {
        let taxes = engine.quarterlyTaxes(group: .third, isVATPayer: true, quarterIncome: 100_000)
        XCTAssertEqual(taxes.singleTax, 3_000, accuracy: 0.01)
    }

    func testFixedGroupsIgnoreIncome() {
        let low = engine.quarterlyTaxes(group: .second, isVATPayer: false, quarterIncome: 10_000)
        let high = engine.quarterlyTaxes(group: .second, isVATPayer: false, quarterIncome: 1_000_000)
        XCTAssertEqual(low, high)
        XCTAssertEqual(low.singleTax, 1_729.40 * 3, accuracy: 0.01)
        XCTAssertEqual(low.militaryLevy, 864.70 * 3, accuracy: 0.01)
    }

    func testRecommendedGroupRespectsLimit() {
        XCTAssertEqual(engine.recommendedGroup(forAnnualIncome: 9_000_000, isVATPayer: false), .third)
        XCTAssertEqual(engine.recommendedGroup(forAnnualIncome: 50_000_000, isVATPayer: false), .third)
    }

    func testDeadlinesAreSortedAndWithinHorizon() {
        let start = Calendar.kyiv.date(from: DateComponents(year: 2026, month: 3, day: 25))!
        let deadlines = engine.deadlines(for: .third, isVATPayer: false, from: start, horizonDays: 90)
        XCTAssertFalse(deadlines.isEmpty)
        XCTAssertEqual(deadlines.map(\.date), deadlines.map(\.date).sorted())

        // ЄСВ за 1 квартал — 20 квітня.
        let esv = deadlines.first { $0.id == "esv-2026-q1" }
        XCTAssertNotNil(esv)
        XCTAssertEqual(Calendar.kyiv.dateComponents([.month, .day], from: esv!.date), DateComponents(month: 4, day: 20))

        // Декларація 3 групи за 1 квартал — 40 днів після 31 березня.
        let declaration = deadlines.first { $0.id == "decl-2026-q1" }
        XCTAssertEqual(Calendar.kyiv.dateComponents([.month, .day], from: declaration!.date), DateComponents(month: 5, day: 10))
    }

    func testMonthlyAdvancePaymentsForSecondGroup() {
        let start = Calendar.kyiv.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let deadlines = engine.deadlines(for: .second, isVATPayer: false, from: start, horizonDays: 60)
        XCTAssertEqual(deadlines.filter { $0.id.hasPrefix("ep12-2026") }.count, 2)
        XCTAssertTrue(deadlines.contains { $0.id == "decl-2025" })
    }
}

final class AnalyticsTests: XCTestCase {
    func testRunwayIsNilForProfitableBusiness() {
        XCTAssertNil(HealthAnalyzer.runwayMonths(cash: 10_000, monthlyIncome: 50_000, monthlyExpense: 40_000))
        XCTAssertEqual(HealthAnalyzer.runwayMonths(cash: 30_000, monthlyIncome: 10_000, monthlyExpense: 20_000)!, 3, accuracy: 0.001)
    }

    func testHealthScoreRewardsStrongBusiness() {
        let strong = HealthAnalyzer.analyze(HealthInputs(cashBalance: 500_000, averageMonthlyIncome: 200_000, averageMonthlyExpense: 100_000,
                                                         incomeLast30Days: 220_000, incomePrevious30Days: 180_000, limitUsage: 0.3, overdueDeadlines: 0))
        let weak = HealthAnalyzer.analyze(HealthInputs(cashBalance: 5_000, averageMonthlyIncome: 20_000, averageMonthlyExpense: 40_000,
                                                       incomeLast30Days: 10_000, incomePrevious30Days: 30_000, limitUsage: 0.95, overdueDeadlines: 1))
        XCTAssertGreaterThan(strong.score, 80)
        XCTAssertLessThan(weak.score, 40)
        XCTAssertEqual(weak.insights.first?.severity, .critical)
    }

    func testScenarioHiringReducesProfit() {
        let baseline = ScenarioBaseline(monthlyIncome: 100_000, monthlyExpense: 50_000, cash: 100_000, group: .third, isVATPayer: false)
        var input = ScenarioInput()
        input.newHires = 1
        input.salaryPerHire = 20_000
        let result = ScenarioSimulator.simulate(baseline, input)
        XCTAssertEqual(result.profitDelta, -24_400, accuracy: 0.01)
    }

    func testScenarioDetectsLimitOverflow() {
        let baseline = ScenarioBaseline(monthlyIncome: 800_000, monthlyExpense: 300_000, cash: 0, group: .third, isVATPayer: false)
        var input = ScenarioInput()
        input.volumeChange = 0.2
        XCTAssertTrue(ScenarioSimulator.simulate(baseline, input).exceedsGroupLimit)
    }

    func testIdeaValidatorExtremes() {
        let best = IdeaValidator.evaluate(Dictionary(uniqueKeysWithValues: IdeaCriterion.allCases.map { ($0, 5) }))
        let worst = IdeaValidator.evaluate(Dictionary(uniqueKeysWithValues: IdeaCriterion.allCases.map { ($0, 1) }))
        XCTAssertEqual(best.score, 100)
        XCTAssertEqual(worst.score, 0)
        XCTAssertEqual(worst.weakest.count, IdeaCriterion.allCases.count)
    }

    func testOpportunityMatchingUsesStatuses() {
        var profile = BusinessProfile.empty
        let veteranProgram = OpportunityCatalog.all.first { $0.id == "veterans" }!
        let without = OpportunityCatalog.matchScore(veteranProgram, for: profile)
        profile.statuses = [.veteran]
        let with = OpportunityCatalog.matchScore(veteranProgram, for: profile)
        XCTAssertGreaterThan(with, without)
    }

    func testStoreDerivedValues() {
        let store = AppStore(fileURL: nil)
        store.loadDemo()
        XCTAssertNotNil(store.profile)
        XCTAssertFalse(store.transactions.isEmpty)
        XCTAssertEqual(store.monthlySummaries(months: 6).count, 6)
        XCTAssertGreaterThan(store.averageMonthlyIncome, 0)
    }
}
