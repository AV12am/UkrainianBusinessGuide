//
//  Invoice.swift
//  UkrainianBusinessGuide
//

import Foundation

/// Реквізити підприємця для рахунків і QR-коду оплати.
struct PaymentDetails: Codable, Equatable {
    /// Повне ім'я як у реєстрі: «ФОП Петренко Олена Іванівна».
    var fullName = ""
    /// РНОКПП (ідентифікаційний код).
    var taxID = ""
    var iban = ""
    var bankName = ""

    var isComplete: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && PaymentQR.normalizedIBAN(iban).count == 29
            && !taxID.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

struct InvoiceItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var quantity: Double
    var price: Double

    var total: Double { quantity * price }
}

struct Invoice: Codable, Identifiable, Equatable {
    enum Status { case draft, unpaid, overdue, paid }

    var id = UUID()
    var number: String
    var clientName: String
    /// ЄДРПОУ або РНОКПП клієнта, необов'язково.
    var clientCode: String
    var items: [InvoiceItem]
    var issueDate: Date
    var dueDate: Date
    var paidDate: Date?

    var total: Double { items.reduce(0) { $0 + $1.total } }

    var purpose: String { "Оплата за рахунком № \(number) від \(issueDate.numericUkrainian)" }

    func status(on date: Date = .now) -> Status {
        if paidDate != nil { return .paid }
        if total <= 0 { return .draft }
        return Calendar.kyiv.startOfDay(for: date) > dueDate ? .overdue : .unpaid
    }
}
