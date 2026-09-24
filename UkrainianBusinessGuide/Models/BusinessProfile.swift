//
//  BusinessProfile.swift
//  UkrainianBusinessGuide
//

import Foundation

/// Група платника єдиного податку (ФОП).
enum FOPGroup: Int, Codable, CaseIterable, Identifiable {
    case first = 1
    case second = 2
    case third = 3

    var id: Int { rawValue }

    var title: String { "\(rawValue) група" }

    var subtitle: String {
        switch self {
        case .first: return "Роздрібна торгівля на ринках, побутові послуги населенню"
        case .second: return "Послуги та продаж для населення і платників ЄП, до 10 найманих"
        case .third: return "Будь-які дозволені види діяльності, без обмежень щодо клієнтів"
        }
    }
}

/// Галузь бізнесу.
enum Industry: String, Codable, CaseIterable, Identifiable {
    case it, trade, services, manufacturing, agro, food, creative

    var id: String { rawValue }

    var title: String {
        switch self {
        case .it: return "IT та digital"
        case .trade: return "Торгівля"
        case .services: return "Послуги"
        case .manufacturing: return "Виробництво"
        case .agro: return "Агро"
        case .food: return "Кафе та їжа"
        case .creative: return "Креативні індустрії"
        }
    }

    var icon: String {
        switch self {
        case .it: return "laptopcomputer"
        case .trade: return "cart.fill"
        case .services: return "person.2.fill"
        case .manufacturing: return "gearshape.2.fill"
        case .agro: return "leaf.fill"
        case .food: return "cup.and.saucer.fill"
        case .creative: return "paintpalette.fill"
        }
    }
}

/// Особливі статуси підприємця, що відкривають доступ до окремих програм підтримки.
enum FounderStatus: String, Codable, CaseIterable, Identifiable {
    case veteran, veteranFamily, idp, youth, woman

    var id: String { rawValue }

    var title: String {
        switch self {
        case .veteran: return "Ветеран / ветеранка"
        case .veteranFamily: return "Член родини ветерана"
        case .idp: return "ВПО"
        case .youth: return "До 35 років"
        case .woman: return "Жінка-підприємиця"
        }
    }
}

struct BusinessProfile: Codable, Equatable {
    var ownerName: String
    var businessName: String
    var fopGroup: FOPGroup
    var isVATPayer: Bool
    var industry: Industry
    var employees: Int
    var startingCash: Double
    var monthlyFixedCosts: Double
    var statuses: Set<FounderStatus>
    var createdAt: Date

    static let empty = BusinessProfile(
        ownerName: "",
        businessName: "",
        fopGroup: .third,
        isVATPayer: false,
        industry: .services,
        employees: 0,
        startingCash: 0,
        monthlyFixedCosts: 0,
        statuses: [],
        createdAt: .now
    )
}
