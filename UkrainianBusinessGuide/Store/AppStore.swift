//
//  AppStore.swift
//  UkrainianBusinessGuide
//
//  Єдине джерело правди: профіль, операції, закриті податкові строки.
//  Зберігається локально у JSON — дані не залишають пристрій.
//

import Foundation
import Observation

@Observable
final class AppStore {
    private(set) var profile: BusinessProfile?
    private(set) var transactions: [Transaction] = []
    private(set) var completedDeadlineIDs: Set<String> = []
    /// Виконані кроки гайду з відкриття бізнесу.
    private(set) var completedGuideSteps: Set<String> = []
    /// Чи увімкнені нагадування про податкові строки.
    private(set) var remindersEnabled = false

    var taxEngine = TaxEngine()

    @ObservationIgnored private let fileURL: URL?
    @ObservationIgnored private let calendar = Calendar.kyiv

    private struct Snapshot: Codable {
        var profile: BusinessProfile?
        var transactions: [Transaction]
        var completedDeadlineIDs: Set<String>
        // Необов'язкові поля: файли, збережені старішими версіями, читаються без помилок.
        var completedGuideSteps: Set<String>?
        var remindersEnabled: Bool?
    }

    /// `fileURL == nil` — стан лише в пам'яті (превью, тести).
    init(fileURL: URL? = AppStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    static var defaultFileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("business-compass.json")
    }

    // MARK: - Зміни стану

    func saveProfile(_ profile: BusinessProfile) {
        self.profile = profile
        persist()
        refreshReminders()
    }

    func add(_ transaction: Transaction) {
        transactions.append(transaction)
        transactions.sort { $0.date > $1.date }
        persist()
        refreshReminders()
    }

    func delete(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
        persist()
    }

    func toggleDeadline(_ deadline: TaxDeadline) {
        if completedDeadlineIDs.contains(deadline.id) {
            completedDeadlineIDs.remove(deadline.id)
        } else {
            completedDeadlineIDs.insert(deadline.id)
        }
        persist()
        refreshReminders()
    }

    func toggleGuideStep(_ id: String) {
        if completedGuideSteps.contains(id) {
            completedGuideSteps.remove(id)
        } else {
            completedGuideSteps.insert(id)
        }
        persist()
    }

    // MARK: - Нагадування

    /// Вмикає нагадування (з запитом дозволу) або вимикає їх. Повертає фактичний стан.
    @discardableResult
    func setRemindersEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            let granted = await DeadlineReminders.requestAuthorization()
            remindersEnabled = granted
        } else {
            remindersEnabled = false
        }
        persist()
        await rescheduleReminders()
        return remindersEnabled
    }

    func refreshReminders() {
        Task { await rescheduleReminders() }
    }

    private func rescheduleReminders() async {
        guard fileURL != nil else { return } // превью й тести
        if remindersEnabled {
            await DeadlineReminders.schedule(upcomingDeadlines)
        } else {
            await DeadlineReminders.cancelAll()
        }
    }

    func resetAll() {
        profile = nil
        transactions = []
        completedDeadlineIDs = []
        completedGuideSteps = []
        remindersEnabled = false
        persist()
        refreshReminders()
    }

    // MARK: - Похідні показники

    var cashBalance: Double {
        (profile?.startingCash ?? 0) + transactions.reduce(0) { $0 + $1.signedAmount }
    }

    func total(_ kind: TransactionKind, in interval: DateInterval) -> Double {
        transactions
            .filter { $0.kind == kind && interval.contains($0.date) && $0.date < interval.end }
            .reduce(0) { $0 + $1.amount }
    }

    func income(in interval: DateInterval) -> Double { total(.income, in: interval) }

    func lastDays(_ days: Int, offset: Int = 0, now: Date = .now) -> DateInterval {
        let end = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
        let start = calendar.date(byAdding: .day, value: -days, to: end) ?? end
        return DateInterval(start: start, end: end)
    }

    var yearIncome: Double {
        taxEngine.yearInterval(containing: .now).map(income(in:)) ?? 0
    }

    var quarterIncome: Double {
        taxEngine.quarterInterval(containing: .now).map(income(in:)) ?? 0
    }

    /// Підсумки по місяцях, від найстарішого до поточного.
    func monthlySummaries(months: Int = 6, now: Date = .now) -> [MonthSummary] {
        guard let currentMonth = calendar.dateInterval(of: .month, for: now)?.start else { return [] }
        return (0..<months).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .month, value: -offset, to: currentMonth),
                  let interval = calendar.dateInterval(of: .month, for: start) else { return nil }
            // Середина місяця: мітка не «перескакує» на сусідній місяць в іншому часовому поясі.
            let mid = calendar.date(byAdding: .day, value: 14, to: interval.start) ?? start
            return MonthSummary(month: mid, income: total(.income, in: interval), expense: total(.expense, in: interval))
        }
    }

    /// Середні показники за 3 повні попередні місяці + поточний; якщо даних немає — з профілю.
    var averageMonthlyIncome: Double {
        let summaries = monthlySummaries(months: 4).filter { $0.income > 0 || $0.expense > 0 }
        guard !summaries.isEmpty else { return 0 }
        return summaries.map(\.income).reduce(0, +) / Double(summaries.count)
    }

    var averageMonthlyExpense: Double {
        let summaries = monthlySummaries(months: 4).filter { $0.income > 0 || $0.expense > 0 }
        guard !summaries.isEmpty else { return profile?.monthlyFixedCosts ?? 0 }
        return max(profile?.monthlyFixedCosts ?? 0, summaries.map(\.expense).reduce(0, +) / Double(summaries.count))
    }

    var limitUsage: Double {
        guard let profile else { return 0 }
        return taxEngine.limitUsage(group: profile.fopGroup, yearIncome: yearIncome)
    }

    func deadlines(horizonDays: Int = 120) -> [TaxDeadline] {
        guard let profile else { return [] }
        return taxEngine.deadlines(for: profile.fopGroup, isVATPayer: profile.isVATPayer, from: .now, horizonDays: horizonDays) { [weak self] interval in
            self?.income(in: interval) ?? 0
        }
    }

    var upcomingDeadlines: [TaxDeadline] {
        deadlines().filter { !completedDeadlineIDs.contains($0.id) }
    }

    /// Строки за останні 30 днів, які не позначені як виконані.
    var overdueDeadlines: [TaxDeadline] {
        guard let profile,
              let monthAgo = calendar.date(byAdding: .day, value: -30, to: .now) else { return [] }
        let today = calendar.startOfDay(for: .now)
        return taxEngine.deadlines(for: profile.fopGroup, isVATPayer: profile.isVATPayer, from: monthAgo, horizonDays: 30)
            .filter { $0.date < today && !completedDeadlineIDs.contains($0.id) }
    }

    var healthReport: HealthReport {
        HealthAnalyzer.analyze(HealthInputs(
            cashBalance: cashBalance,
            averageMonthlyIncome: averageMonthlyIncome,
            averageMonthlyExpense: averageMonthlyExpense,
            incomeLast30Days: income(in: lastDays(30)),
            incomePrevious30Days: income(in: lastDays(30, offset: 30)),
            limitUsage: limitUsage,
            overdueDeadlines: overdueDeadlines.count
        ))
    }

    var advisorContext: AdvisorContext? {
        guard let profile else { return nil }
        return AdvisorContext(
            profile: profile,
            health: healthReport,
            yearIncome: yearIncome,
            averageMonthlyIncome: averageMonthlyIncome,
            nextDeadline: upcomingDeadlines.first,
            engine: taxEngine
        )
    }

    var scenarioBaseline: ScenarioBaseline? {
        guard let profile else { return nil }
        return ScenarioBaseline(
            monthlyIncome: averageMonthlyIncome,
            monthlyExpense: averageMonthlyExpense,
            cash: cashBalance,
            group: profile.fopGroup,
            isVATPayer: profile.isVATPayer
        )
    }

    // MARK: - Демо-дані

    func loadDemo(now: Date = .now) {
        var profile = BusinessProfile.empty
        profile.ownerName = "Олена"
        profile.businessName = "Кав'ярня «Зерно»"
        profile.fopGroup = .third
        profile.industry = .food
        profile.employees = 2
        profile.startingCash = 85_000
        profile.monthlyFixedCosts = 45_000
        profile.statuses = [.youth, .woman]
        self.profile = profile

        var generator = SeededGenerator(seed: 42)
        var demo: [Transaction] = []
        for monthOffset in 0..<6 {
            guard let monthStart = calendar.date(byAdding: .month, value: -monthOffset, to: now) else { continue }
            let growth = 1 + Double(5 - monthOffset) * 0.06
            for week in 0..<4 {
                guard let date = calendar.date(byAdding: .day, value: -week * 7, to: monthStart), date <= now else { continue }
                demo.append(Transaction(date: date, amount: (24_000 + Double(generator.next() % 9_000)) * growth, category: .sales, note: "Виручка за тиждень"))
            }
            demo.append(Transaction(date: monthStart, amount: 22_000, category: .rent, note: "Оренда приміщення"))
            demo.append(Transaction(date: monthStart, amount: 36_000, category: .salary, note: "Зарплата бариста"))
            demo.append(Transaction(date: monthStart, amount: 18_000 + Double(generator.next() % 6_000), category: .supplies, note: "Кава, молоко, випічка"))
            demo.append(Transaction(date: monthStart, amount: 4_500, category: .marketing, note: "Реклама в Instagram"))
        }
        transactions = demo.sorted { $0.date > $1.date }
        completedDeadlineIDs = []
        persist()
    }

    // MARK: - Збереження

    private func load() {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        profile = snapshot.profile
        transactions = snapshot.transactions.sorted { $0.date > $1.date }
        completedDeadlineIDs = snapshot.completedDeadlineIDs
        completedGuideSteps = snapshot.completedGuideSteps ?? []
        remindersEnabled = snapshot.remindersEnabled ?? false
    }

    private func persist() {
        guard let fileURL else { return }
        let snapshot = Snapshot(profile: profile, transactions: transactions, completedDeadlineIDs: completedDeadlineIDs,
                                completedGuideSteps: completedGuideSteps, remindersEnabled: remindersEnabled)
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            assertionFailure("Не вдалося зберегти дані: \(error)")
        }
    }
}

extension AppStore {
    /// Стор із демо-даними в пам'яті — для превью SwiftUI.
    static var preview: AppStore {
        let store = AppStore(fileURL: nil)
        store.loadDemo()
        return store
    }
}

/// Детермінований генератор, щоб демо-дані були однаковими при кожному запуску.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state >> 33
    }
}
