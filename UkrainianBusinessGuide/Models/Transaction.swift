//
//  Transaction.swift
//  UkrainianBusinessGuide
//

import Foundation

enum TransactionKind: String, Codable, CaseIterable, Identifiable {
    case income, expense

    var id: String { rawValue }
    var title: String { self == .income ? "Дохід" : "Витрата" }
}

enum TransactionCategory: String, Codable, CaseIterable, Identifiable {
    // Доходи
    case sales, services, grant, otherIncome
    // Витрати
    case rent, salary, marketing, supplies, software, taxes, otherExpense

    var id: String { rawValue }

    var kind: TransactionKind {
        switch self {
        case .sales, .services, .grant, .otherIncome: return .income
        default: return .expense
        }
    }

    var title: String {
        switch self {
        case .sales: return "Продажі"
        case .services: return "Послуги"
        case .grant: return "Грант"
        case .otherIncome: return "Інший дохід"
        case .rent: return "Оренда"
        case .salary: return "Зарплата"
        case .marketing: return "Маркетинг"
        case .supplies: return "Закупівлі"
        case .software: return "Сервіси та ПЗ"
        case .taxes: return "Податки"
        case .otherExpense: return "Інше"
        }
    }

    var icon: String {
        switch self {
        case .sales: return "bag.fill"
        case .services: return "hands.sparkles.fill"
        case .grant: return "gift.fill"
        case .otherIncome: return "plus.circle.fill"
        case .rent: return "building.fill"
        case .salary: return "person.3.fill"
        case .marketing: return "megaphone.fill"
        case .supplies: return "shippingbox.fill"
        case .software: return "app.badge.fill"
        case .taxes: return "building.columns.fill"
        case .otherExpense: return "ellipsis.circle.fill"
        }
    }

    static func categories(for kind: TransactionKind) -> [TransactionCategory] {
        allCases.filter { $0.kind == kind }
    }
}

struct Transaction: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var amount: Double
    var category: TransactionCategory
    var note: String

    var kind: TransactionKind { category.kind }
    /// Сума зі знаком: дохід додатний, витрата від'ємна.
    var signedAmount: Double { kind == .income ? amount : -amount }
}

struct MonthSummary: Identifiable, Equatable {
    var month: Date
    var income: Double
    var expense: Double

    var id: Date { month }
    var profit: Double { income - expense }
}
