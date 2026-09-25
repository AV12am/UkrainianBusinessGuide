//
//  AppStore.swift
//  UkrainianBusinessGuide
//
//  Єдине джерело правди: профіль, операції, закриті податкові строки.
//  Зберігається локально у JSON — дані не залишають пристрій.
//

import Foundation
import Observation
import WidgetKit

@Observable
final class AppStore {
    private(set) var profile: BusinessProfile?
    private(set) var transactions: [Transaction] = []
    private(set) var completedDeadlineIDs: Set<String> = []
    /// Виконані кроки гайду з відкриття бізнесу.
    private(set) var completedGuideSteps: Set<String> = []
    /// Чи увімкнені нагадування про податкові строки.
    private(set) var remindersEnabled = false
    private(set) var invoices: [Invoice] = []
    private(set) var paymentDetails = PaymentDetails()
    /// Вхід за Face ID / кодом пристрою.
    private(set) var lockEnabled = false
    /// Рахунок monobank, з якого підтягується виписка. Сам токен — у Keychain.
    private(set) var monobankAccountID: String?
    private(set) var lastBankSync: Date?

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
        var invoices: [Invoice]?
        var paymentDetails: PaymentDetails?
        var lockEnabled: Bool?
        var monobankAccountID: String?
        var lastBankSync: Date?
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

    func setCategory(_ category: TransactionCategory, for transaction: Transaction) {
        guard category.kind == transaction.kind,
              let index = transactions.firstIndex(where: { $0.id == transaction.id }) else { return }
        transactions[index].category = category
        persist()
    }

    // MARK: - Імпорт виписки

    /// Операції з виписки, яких ще немає в журналі.
    func newOperations(_ operations: [ImportedOperation]) -> [ImportedOperation] {
        let knownIDs = Set(transactions.compactMap(\.externalID))
        let knownFingerprints = Set(transactions.map(fingerprint))
        return operations.filter { operation in
            !knownIDs.contains(operation.externalID) && !knownFingerprints.contains(fingerprint(operation.transaction))
        }
    }

    /// Додає нові операції з виписки. Повертає, скільки додано.
    @discardableResult
    func importOperations(_ operations: [ImportedOperation]) -> Int {
        let fresh = newOperations(operations)
        guard !fresh.isEmpty else { return 0 }
        transactions.append(contentsOf: fresh.map(\.transaction))
        transactions.sort { $0.date > $1.date }
        persist()
        refreshReminders()
        return fresh.count
    }

    func setMonobankAccount(_ id: String?) {
        monobankAccountID = id
        persist()
    }

    func markBankSynced(at date: Date = .now) {
        lastBankSync = date
        persist()
    }

    private func fingerprint(_ transaction: Transaction) -> String {
        let day = calendar.startOfDay(for: transaction.date).timeIntervalSince1970
        return "\(Int(day))|\(String(format: "%.2f", transaction.signedAmount))|\(transaction.note.lowercased())"
    }

    // MARK: - Рахунки клієнтам

    func save(_ invoice: Invoice) {
        if let index = invoices.firstIndex(where: { $0.id == invoice.id }) {
            invoices[index] = invoice
        } else {
            invoices.append(invoice)
        }
        invoices.sort { $0.issueDate > $1.issueDate }
        persist()
    }

    func delete(_ invoice: Invoice) {
        invoices.removeAll { $0.id == invoice.id }
        transactions.removeAll { $0.externalID == Self.invoiceTransactionID(invoice) }
        persist()
    }

    /// Позначає рахунок оплаченим і записує дохід; повторний виклик скасовує оплату.
    func togglePaid(_ invoice: Invoice, on date: Date = .now) {
        guard let index = invoices.firstIndex(where: { $0.id == invoice.id }) else { return }
        let transactionID = Self.invoiceTransactionID(invoice)
        if invoices[index].paidDate == nil {
            invoices[index].paidDate = date
            let note = "Оплата рахунку № \(invoice.number), \(invoice.clientName)"
            transactions.append(Transaction(date: date, amount: invoice.total, category: .services, note: note, externalID: transactionID))
            transactions.sort { $0.date > $1.date }
        } else {
            invoices[index].paidDate = nil
            transactions.removeAll { $0.externalID == transactionID }
        }
        persist()
        refreshReminders()
    }

    var nextInvoiceNumber: String {
        let year = calendar.component(.year, from: .now)
        let thisYear = invoices.filter { $0.number.hasPrefix("\(year)-") }.count
        return "\(year)-" + String(format: "%03d", thisYear + 1)
    }

    /// Сума неоплачених рахунків.
    var receivables: Double {
        invoices.filter { $0.paidDate == nil }.reduce(0) { $0 + $1.total }
    }

    var overdueInvoices: [Invoice] {
        invoices.filter { $0.status() == .overdue }
    }

    func savePaymentDetails(_ details: PaymentDetails) {
        paymentDetails = details
        persist()
    }

    private static func invoiceTransactionID(_ invoice: Invoice) -> String { "invoice:" + invoice.id.uuidString }

    // MARK: - Безпека й резервна копія

    func setLockEnabled(_ enabled: Bool) {
        lockEnabled = enabled
        persist()
    }

    /// Усі дані одним JSON-файлом. Токен monobank у копію не потрапляє.
    func backupData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    func restoreBackup(from data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        apply(try decoder.decode(Snapshot.self, from: data))
        persist()
        refreshReminders()
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
        invoices = []
        paymentDetails = PaymentDetails()
        lockEnabled = false
        monobankAccountID = nil
        lastBankSync = nil
        Keychain.set(nil, for: MonobankClient.tokenKey)
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

    /// Податкова скарбничка: скільки мати відкладеним на несплачені податки найближчих 60 днів
    /// (включно з простроченими).
    var taxReserve: Double {
        guard let horizon = calendar.date(byAdding: .day, value: 60, to: .now) else { return 0 }
        return (overdueDeadlines + upcomingDeadlines)
            .filter { $0.kind == .payment && $0.date <= horizon }
            .compactMap(\.estimatedAmount)
            .reduce(0, +)
    }

    /// Частка кожного доходу, яку варто відкладати: для 3 групи — ставка єдиного податку й військовий збір.
    /// Для 1–2 груп податки фіксовані й не залежать від доходу.
    var reserveRate: Double? {
        guard let profile, profile.fopGroup == .third,
              let rate = taxEngine.singleTaxRate(for: .third, isVATPayer: profile.isVATPayer) else { return nil }
        return rate + 0.01
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

        paymentDetails = PaymentDetails(fullName: "ФОП Коваленко Олена Петрівна", taxID: "3456789012",
                                        iban: "UA213223130000026007233566001", bankName: "АТ «Універсал Банк»")
        let day = { (offset: Int) in self.calendar.date(byAdding: .day, value: offset, to: now) ?? now }
        invoices = [
            Invoice(number: "2026-003", clientName: "ТОВ «Смачна справа»", clientCode: "43210987",
                    items: [InvoiceItem(title: "Кава в зернах, 1 кг", quantity: 12, price: 780),
                            InvoiceItem(title: "Доставка", quantity: 1, price: 250)],
                    issueDate: day(-3), dueDate: day(7)),
            Invoice(number: "2026-002", clientName: "Коворкінг «Простір»", clientCode: "",
                    items: [InvoiceItem(title: "Кейтеринг на захід, 40 осіб", quantity: 1, price: 16_400)],
                    issueDate: day(-20), dueDate: day(-6)),
            Invoice(number: "2026-001", clientName: "ФОП Мельник І. В.", clientCode: "2987654321",
                    items: [InvoiceItem(title: "Кава для офісу, місячний абонемент", quantity: 1, price: 5_600)],
                    issueDate: day(-34), dueDate: day(-24), paidDate: day(-26))
        ]
        persist()
    }

    // MARK: - Збереження

    private var snapshot: Snapshot {
        Snapshot(profile: profile, transactions: transactions, completedDeadlineIDs: completedDeadlineIDs,
                 completedGuideSteps: completedGuideSteps, remindersEnabled: remindersEnabled,
                 invoices: invoices, paymentDetails: paymentDetails, lockEnabled: lockEnabled,
                 monobankAccountID: monobankAccountID, lastBankSync: lastBankSync)
    }

    private func apply(_ snapshot: Snapshot) {
        profile = snapshot.profile
        transactions = snapshot.transactions.sorted { $0.date > $1.date }
        completedDeadlineIDs = snapshot.completedDeadlineIDs
        completedGuideSteps = snapshot.completedGuideSteps ?? []
        remindersEnabled = snapshot.remindersEnabled ?? false
        invoices = (snapshot.invoices ?? []).sorted { $0.issueDate > $1.issueDate }
        paymentDetails = snapshot.paymentDetails ?? PaymentDetails()
        lockEnabled = snapshot.lockEnabled ?? false
        monobankAccountID = snapshot.monobankAccountID
        lastBankSync = snapshot.lastBankSync
    }

    private func load() {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        apply(snapshot)
    }

    private func persist() {
        guard let fileURL else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            assertionFailure("Не вдалося зберегти дані: \(error)")
        }
        publishWidgetSnapshot()
    }

    /// Дані для віджета на головному екрані й екрані блокування.
    private func publishWidgetSnapshot() {
        let next = upcomingDeadlines.first { $0.kind == .payment }
        let widget = WidgetSnapshot(
            businessName: profile?.businessName ?? "",
            nextPayment: next.map { WidgetSnapshot.Payment(title: $0.title, date: $0.date, amount: $0.estimatedAmount) },
            taxReserve: taxReserve,
            limitUsage: limitUsage,
            receivables: receivables,
            updatedAt: .now
        )
        widget.save()
        WidgetCenter.shared.reloadAllTimelines()
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
