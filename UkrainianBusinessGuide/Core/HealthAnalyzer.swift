//
//  HealthAnalyzer.swift
//  UkrainianBusinessGuide
//
//  «Стан бізнесу» — інтегральний індекс 0–100 з пояснюваними складовими та порадами.
//

import Foundation

struct HealthInputs: Equatable {
    var cashBalance: Double
    var averageMonthlyIncome: Double
    var averageMonthlyExpense: Double
    var incomeLast30Days: Double
    var incomePrevious30Days: Double
    var limitUsage: Double
    var overdueDeadlines: Int
}

struct HealthComponent: Identifiable, Equatable {
    let title: String
    let icon: String
    /// 0…1
    let value: Double
    let detail: String

    var id: String { title }
}

struct Insight: Identifiable, Equatable {
    enum Severity: Int, Comparable {
        case good = 0, info, warning, critical
        static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let id: String
    let icon: String
    let title: String
    let message: String
    let severity: Severity
}

struct HealthReport: Equatable {
    let score: Int
    let components: [HealthComponent]
    let insights: [Insight]

    var verdict: String {
        switch score {
        case 80...: return "Відмінна форма"
        case 60..<80: return "Стабільно"
        case 40..<60: return "Потребує уваги"
        default: return "Зона ризику"
        }
    }
}

enum HealthAnalyzer {
    /// Скільки місяців бізнес проживе на поточному залишку за середнього «спалювання» грошей.
    static func runwayMonths(cash: Double, monthlyIncome: Double, monthlyExpense: Double) -> Double? {
        let burn = monthlyExpense - monthlyIncome
        guard burn > 0 else { return nil } // прибутковий бізнес — runway необмежений
        return max(0, cash) / burn
    }

    static func analyze(_ input: HealthInputs) -> HealthReport {
        var components: [HealthComponent] = []
        var insights: [Insight] = []

        // 1. Запас міцності (runway)
        let runway = runwayMonths(cash: input.cashBalance, monthlyIncome: input.averageMonthlyIncome, monthlyExpense: input.averageMonthlyExpense)
        let runwayScore: Double
        if let runway {
            runwayScore = min(1, runway / 6)
            components.append(HealthComponent(title: "Запас міцності", icon: "hourglass", value: runwayScore, detail: String(format: "%.1f міс. грошей", runway)))
            if runway < 3 {
                insights.append(Insight(id: "runway", icon: "exclamationmark.triangle.fill", title: "Грошей менше ніж на 3 місяці",
                                        message: "Скоротіть змінні витрати або прискорте надходження: передоплата, знижка за швидку оплату, продаж залишків.",
                                        severity: .critical))
            }
        } else {
            runwayScore = input.averageMonthlyIncome > 0 ? 1 : 0.5
            components.append(HealthComponent(title: "Запас міцності", icon: "hourglass", value: runwayScore, detail: input.averageMonthlyIncome > 0 ? "Бізнес сам себе фінансує" : "Недостатньо даних"))
        }

        // 2. Маржинальність
        let margin = input.averageMonthlyIncome > 0 ? (input.averageMonthlyIncome - input.averageMonthlyExpense) / input.averageMonthlyIncome : 0
        let marginScore = min(1, max(0, margin / 0.3))
        components.append(HealthComponent(title: "Маржа", icon: "percent", value: marginScore, detail: margin.percent))
        if input.averageMonthlyIncome > 0 && margin < 0.1 {
            insights.append(Insight(id: "margin", icon: "chart.line.downtrend.xyaxis", title: "Низька маржа",
                                    message: "Перевірте ціни: підвищення на 5–10% часто дає більше прибутку, ніж ріст продажів. Спробуйте симулятор «Що якщо».",
                                    severity: .warning))
        }

        // 3. Динаміка виручки
        let growth: Double
        if input.incomePrevious30Days > 0 {
            growth = (input.incomeLast30Days - input.incomePrevious30Days) / input.incomePrevious30Days
        } else {
            growth = input.incomeLast30Days > 0 ? 1 : 0
        }
        let growthScore = min(1, max(0, 0.5 + growth))
        components.append(HealthComponent(title: "Динаміка", icon: "arrow.up.right", value: growthScore, detail: (growth >= 0 ? "+" : "") + growth.percent))
        if growth > 0.15 {
            insights.append(Insight(id: "growth", icon: "flame.fill", title: "Виручка зростає",
                                    message: "Дохід за 30 днів вищий на \(growth.percent). Час інвестувати в канал, що дає цей ріст.",
                                    severity: .good))
        } else if growth < -0.2 {
            insights.append(Insight(id: "decline", icon: "arrow.down.right.circle.fill", title: "Виручка падає",
                                    message: "Мінус \(abs(growth).percent) до попереднього місяця. Зв'яжіться з постійними клієнтами та перевірте сезонність.",
                                    severity: .warning))
        }

        // 4. Податкова безпека
        var complianceScore: Double = 1
        if input.limitUsage >= 0.9 { complianceScore -= 0.6 } else if input.limitUsage >= 0.7 { complianceScore -= 0.3 }
        complianceScore -= Double(input.overdueDeadlines) * 0.2
        complianceScore = max(0, complianceScore)
        components.append(HealthComponent(title: "Податки", icon: "checkmark.shield.fill", value: complianceScore,
                                          detail: "Ліміт: \(input.limitUsage.percent)"))
        if input.limitUsage >= 0.8 {
            insights.append(Insight(id: "limit", icon: "gauge.with.dots.needle.67percent", title: "Наближаєтесь до ліміту групи",
                                    message: "Використано \(input.limitUsage.percent) річного ліміту. Заздалегідь сплануйте перехід на іншу групу чи систему оподаткування.",
                                    severity: input.limitUsage >= 1 ? .critical : .warning))
        }
        if input.overdueDeadlines > 0 {
            insights.append(Insight(id: "overdue", icon: "calendar.badge.exclamationmark", title: "Є незакриті податкові строки",
                                    message: "Позначте сплачені платежі у вкладці «Податки», щоб індекс був точним.",
                                    severity: .critical))
        }

        let weights: [Double] = [0.3, 0.3, 0.15, 0.25]
        let values = components.map(\.value)
        let weighted = zip(weights, values).map { $0 * $1 }.reduce(0, +)
        let score = Int((weighted * 100).rounded())

        if insights.isEmpty {
            insights.append(Insight(id: "ok", icon: "sparkles", title: "Все під контролем",
                                    message: "Додайте ще кілька операцій — і аналітика стане точнішою.", severity: .info))
        }

        return HealthReport(score: score, components: components, insights: insights.sorted { $0.severity > $1.severity })
    }
}
