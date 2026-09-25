//
//  Opportunity.swift
//  UkrainianBusinessGuide
//

import Foundation

enum OpportunityType: String, CaseIterable, Identifiable {
    case grant, credit, regime, education

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grant: return "Гранти"
        case .credit: return "Кредити"
        case .regime: return "Режими"
        case .education: return "Навчання"
        }
    }

    var icon: String {
        switch self {
        case .grant: return "gift.fill"
        case .credit: return "banknote.fill"
        case .regime: return "shield.lefthalf.filled"
        case .education: return "graduationcap.fill"
        }
    }
}

/// Програма підтримки бізнесу. Умови змінюються, тому в картці завжди є посилання на офіційне джерело.
struct Opportunity: Identifiable {
    let id: String
    let title: String
    let provider: String
    let type: OpportunityType
    let amountDescription: String
    let summary: String
    let requirements: [String]
    let industries: Set<Industry>   // порожньо = будь-яка галузь
    let statuses: Set<FounderStatus> // порожньо = для всіх
    let requiresEmployees: Bool
    let url: URL
    /// Кінцевий строк прийому заявок, якщо програма працює конкурсами.
    var applicationDeadline: Date? = nil

    func isOpen(on date: Date = .now) -> Bool {
        guard let applicationDeadline else { return true }
        return date <= applicationDeadline
    }
}
