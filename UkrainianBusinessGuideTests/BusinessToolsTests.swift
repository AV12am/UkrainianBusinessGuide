//
//  BusinessToolsTests.swift
//  UkrainianBusinessGuideTests
//
//  Імпорт виписок, рахунки з QR-кодом, скарбничка, резервна копія.
//

import XCTest
@testable import UkrainianBusinessGuide

final class BusinessToolsTests: XCTestCase {
    // MARK: - Виписка CSV

    func testParsesMonobankStyleStatement() throws {
        let csv = """
        "Дата i час операції","Деталі операції","MCC","Сума в валюті картки (UAH)","Сума в валюті операції","Валюта","Курс","Сума комісій (UAH)","Сума кешбеку (UAH)","Залишок після операції"
        "25.09.2026 10:15:00","Оплата від ТОВ Ромашка за послуги","4829","15000.00","15000.00","UAH","—","—","—","20000.00"
        "24.09.2026 18:02:11","Google Workspace","5818","-300.50","-300.50","UAH","—","—","—","5000.00"
        """
        let operations = try BankStatementParser.parse(Data(csv.utf8))
        XCTAssertEqual(operations.count, 2)
        XCTAssertEqual(operations[0].amount, 15_000, accuracy: 0.001)
        XCTAssertEqual(operations[0].transaction.category, .services)
        XCTAssertEqual(operations[1].amount, -300.5, accuracy: 0.001)
        XCTAssertEqual(operations[1].mcc, 5818)
        XCTAssertEqual(operations[1].transaction.category, .software)
        XCTAssertEqual(operations[1].transaction.kind, .expense)
    }

    func testParsesDebitCreditColumnsWithDecimalComma() throws {
        let csv = """
        Виписка по рахунку ФОП
        Дата операції;Дебет;Кредит;Призначення платежу
        01.09.2026;;"12 500,00";Оплата за рахунком 7
        02.09.2026;"1 000,00";;Сплата єдиного податку
        """
        let operations = try BankStatementParser.parse(Data(csv.utf8))
        XCTAssertEqual(operations.count, 2)
        let income = try XCTUnwrap(operations.first { $0.amount > 0 })
        let expense = try XCTUnwrap(operations.first { $0.amount < 0 })
        XCTAssertEqual(income.amount, 12_500, accuracy: 0.001)
        XCTAssertEqual(expense.amount, -1_000, accuracy: 0.001)
        XCTAssertEqual(expense.transaction.category, .taxes)
    }

    func testIdenticalOperationsOnSameDayStayDistinct() throws {
        let csv = """
        Дата;Сума;Опис
        01.09.2026;60;Кава
        01.09.2026;60;Кава
        """
        let operations = try BankStatementParser.parse(Data(csv.utf8))
        XCTAssertEqual(Set(operations.map(\.externalID)).count, 2)
    }

    func testRejectsFileWithoutAmountColumn() {
        XCTAssertThrowsError(try BankStatementParser.parse(Data("Ім'я;Місто\nОлена;Київ".utf8)))
    }

    func testAmountParsing() {
        XCTAssertEqual(BankStatementParser.parseAmount("1.234,56"), 1_234.56)
        XCTAssertEqual(BankStatementParser.parseAmount("1,234.56"), 1_234.56)
        XCTAssertEqual(BankStatementParser.parseAmount("-300,5"), -300.5)
        XCTAssertEqual(BankStatementParser.parseAmount("12 500,00 ₴"), 12_500)
        XCTAssertNil(BankStatementParser.parseAmount("—"))
    }

    func testImportSkipsDuplicates() {
        let store = AppStore(fileURL: nil)
        store.saveProfile(.empty)
        let operation = ImportedOperation(externalID: "mono:1", date: .now, amount: 1_000, description: "Оплата")
        XCTAssertEqual(store.importOperations([operation]), 1)
        XCTAssertEqual(store.importOperations([operation]), 0)
        XCTAssertEqual(store.transactions.count, 1)
    }

    // MARK: - QR-код НБУ

    func testPaymentQRPayloadFollowsNBUFormat() throws {
        let payload = PaymentQR.payload(recipient: "ФОП Коваленко Олена", iban: "ua21 3223 1300 0002 6007 2335 6600 1",
                                        amount: 1_234.5, code: "3456789012", purpose: "Оплата за рахунком № 1")
        let lines = payload.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 13)
        XCTAssertEqual(Array(lines.prefix(4)), ["BCD", "002", "1", "UCT"])
        XCTAssertEqual(lines[6], "UA213223130000026007233566001")
        XCTAssertEqual(lines[7], "UAH1234.50")
        XCTAssertEqual(lines[8], "3456789012")

        let link = PaymentQR.link(recipient: "ФОП Коваленко Олена", iban: "UA213223130000026007233566001",
                                  amount: 1_234.5, code: "3456789012", purpose: "Оплата за рахунком № 1")
        XCTAssertTrue(link.hasPrefix("https://bank.gov.ua/qr/"))
        var base64 = String(link.dropFirst("https://bank.gov.ua/qr/".count))
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        let decoded = try XCTUnwrap(Data(base64Encoded: base64).flatMap { String(data: $0, encoding: .utf8) })
        XCTAssertTrue(decoded.contains("ФОП Коваленко Олена"))
        XCTAssertNotNil(PaymentQR.image(for: link))
    }

    // MARK: - Рахунки

    func testInvoiceStatusesAndPayment() throws {
        let store = AppStore(fileURL: nil)
        store.loadDemo()
        XCTAssertEqual(store.invoices.count, 3)
        XCTAssertEqual(store.overdueInvoices.count, 1)
        XCTAssertEqual(store.receivables, 12 * 780 + 250 + 16_400, accuracy: 0.01)
        XCTAssertTrue(store.paymentDetails.isComplete)

        let unpaid = try XCTUnwrap(store.invoices.first { $0.status() == .unpaid })
        let before = store.transactions.count
        store.togglePaid(unpaid)
        XCTAssertEqual(store.transactions.count, before + 1)
        XCTAssertEqual(store.invoices.first { $0.id == unpaid.id }?.status(), .paid)
        store.togglePaid(unpaid)
        XCTAssertEqual(store.transactions.count, before)
    }

    func testNextInvoiceNumberCountsThisYear() {
        let store = AppStore(fileURL: nil)
        let year = Calendar.kyiv.component(.year, from: .now)
        XCTAssertEqual(store.nextInvoiceNumber, "\(year)-001")
    }

    // MARK: - Скарбничка й резервна копія

    func testTaxReserveForThirdGroup() throws {
        let store = AppStore(fileURL: nil)
        store.loadDemo()
        XCTAssertEqual(try XCTUnwrap(store.reserveRate), 0.06, accuracy: 0.0001)
        XCTAssertGreaterThan(store.taxReserve, 0)
    }

    func testBackupRoundTrip() throws {
        let source = AppStore(fileURL: nil)
        source.loadDemo()
        let data = try source.backupData()

        let target = AppStore(fileURL: nil)
        try target.restoreBackup(from: data)
        XCTAssertEqual(target.profile?.businessName, source.profile?.businessName)
        XCTAssertEqual(target.transactions.count, source.transactions.count)
        XCTAssertEqual(target.invoices.count, source.invoices.count)
        XCTAssertEqual(target.paymentDetails, source.paymentDetails)
        XCTAssertThrowsError(try target.restoreBackup(from: Data("{}".utf8)))
    }

    // MARK: - Регресії з повного перегляду

    func testRecommendedGroupRespectsEmployees() {
        let engine = TaxEngine()
        XCTAssertEqual(engine.recommendedGroup(forAnnualIncome: 500_000, isVATPayer: false), .first)
        XCTAssertNotEqual(engine.recommendedGroup(forAnnualIncome: 500_000, isVATPayer: false, employees: 2), .first)
        XCTAssertEqual(engine.recommendedGroup(forAnnualIncome: 500_000, isVATPayer: false, employees: 12), .third)
        XCTAssertEqual(engine.recommendedGroup(forAnnualIncome: 500_000, isVATPayer: true), .third)
    }

    func testEmployerContributionHasMinimumBase() {
        let baseline = ScenarioBaseline(monthlyIncome: 100_000, monthlyExpense: 50_000, cash: 100_000, group: .third, isVATPayer: false)
        var input = ScenarioInput()
        input.newHires = 1
        input.salaryPerHire = 5_000 // нижче мінімальної зарплати
        let result = ScenarioSimulator.simulate(baseline, input)
        XCTAssertEqual(result.profitDelta, -(5_000 + 8_647 * 0.22), accuracy: 0.01)
    }

    func testGrowthWithoutPreviousIncomeIsNotHundredPercent() {
        let report = HealthAnalyzer.analyze(HealthInputs(cashBalance: 10_000, averageMonthlyIncome: 5_000, averageMonthlyExpense: 1_000,
                                                         incomeLast30Days: 5_000, incomePrevious30Days: 0, limitUsage: 0, overdueDeadlines: 0))
        let growth = try? XCTUnwrap(report.components.first { $0.title == "Динаміка" })
        XCTAssertEqual(growth?.detail, "Мало даних для порівняння")
        XCTAssertFalse(report.insights.contains { $0.id == "growth" })
    }

    func testInvoiceNumbersNeverRepeatAfterDeletion() throws {
        let store = AppStore(fileURL: nil)
        store.loadDemo()
        let year = Calendar.kyiv.component(.year, from: .now)
        let middle = try XCTUnwrap(store.invoices.first { $0.number == "2026-002" })
        store.delete(middle)
        if year == 2026 {
            XCTAssertEqual(store.nextInvoiceNumber, "2026-004")
        }
    }

    func testEditingPaidInvoiceUpdatesIncome() throws {
        let store = AppStore(fileURL: nil)
        store.loadDemo()
        var invoice = try XCTUnwrap(store.invoices.first { $0.paidDate == nil })
        store.togglePaid(invoice)
        invoice = try XCTUnwrap(store.invoices.first { $0.id == invoice.id })
        invoice.items.append(InvoiceItem(title: "Додатково", quantity: 1, price: 1_000))
        store.save(invoice)
        let income = try XCTUnwrap(store.transactions.first { $0.externalID == "invoice:" + invoice.id.uuidString })
        XCTAssertEqual(income.amount, invoice.total, accuracy: 0.01)
    }

    func testOwnTransfersAreDetected() {
        XCTAssertTrue(OperationCategorizer.isLikelyOwnTransfer("З білої картки"))
        XCTAssertTrue(OperationCategorizer.isLikelyOwnTransfer("Переказ між власними рахунками"))
        XCTAssertFalse(OperationCategorizer.isLikelyOwnTransfer("Оплата від ТОВ Ромашка"))
    }

    func testAdvisorAnswersFundingQuestionAboutBusiness() async throws {
        let store = AppStore(fileURL: nil)
        store.loadDemo()
        let context = try XCTUnwrap(store.advisorContext)
        let answer = await LocalAdvisor().reply(to: "Де взяти гроші на розвиток бізнесу?", context: context)
        XCTAssertTrue(answer.contains("програми"), answer)
        let health = await LocalAdvisor().reply(to: "Як справи в моєму бізнесі?", context: context)
        XCTAssertTrue(health.hasPrefix("Стан бізнесу"), health)
    }
}
