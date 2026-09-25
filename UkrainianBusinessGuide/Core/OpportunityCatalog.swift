//
//  OpportunityCatalog.swift
//  UkrainianBusinessGuide
//
//  Каталог програм підтримки та алгоритм персонального підбору.
//  Суми та умови — орієнтовні; у кожній картці є посилання на офіційне джерело.
//

import Foundation

enum OpportunityCatalog {
    static let all: [Opportunity] = [
        Opportunity(
            id: "vlasna-sprava",
            title: "Грант «Власна справа»",
            provider: "єРобота / Дія",
            type: .grant,
            amountDescription: "до 250 000 ₴",
            summary: "Безповоротний грант на створення або розвиток мікробізнесу з обов'язковим створенням робочих місць.",
            requirements: ["ФОП або ТОВ", "Бізнес-план", "Створення щонайменше 1–2 робочих місць", "Співфінансування частини проєкту"],
            industries: [],
            statuses: [],
            requiresEmployees: false,
            url: URL(string: "https://diia.gov.ua")!
        ),
        Opportunity(
            id: "processing",
            title: "Грант на переробне підприємство",
            provider: "єРобота / Дія",
            type: .grant,
            amountDescription: "до 8 млн ₴",
            summary: "Фінансування обладнання для переробки та виробництва з умовою створення робочих місць.",
            requirements: ["Переробна або виробнича діяльність", "Співфінансування 30%", "Нові робочі місця"],
            industries: [.manufacturing, .agro, .food],
            statuses: [],
            requiresEmployees: true,
            url: URL(string: "https://diia.gov.ua")!
        ),
        Opportunity(
            id: "gardens",
            title: "Грант на сади та теплиці",
            provider: "єРобота / Дія",
            type: .grant,
            amountDescription: "за площею насаджень",
            summary: "Підтримка створення садів, ягідників, виноградників і тепличних господарств.",
            requirements: ["Земля у власності чи оренді", "Агро-діяльність", "Співфінансування"],
            industries: [.agro],
            statuses: [],
            requiresEmployees: false,
            url: URL(string: "https://diia.gov.ua")!
        ),
        Opportunity(
            id: "veterans",
            title: "Гранти для ветеранів і їхніх родин",
            provider: "Український ветеранський фонд / єРобота",
            type: .grant,
            amountDescription: "за умовами конкурсу",
            summary: "Окремі грантові програми для ветеранів, ветеранок та членів їхніх родин на старт і розвиток бізнесу.",
            requirements: ["Статус ветерана або члена родини", "Бізнес-план", "Звітність про використання коштів"],
            industries: [],
            statuses: [.veteran, .veteranFamily],
            requiresEmployees: false,
            url: URL(string: "https://veteranfund.com.ua")!
        ),
        Opportunity(
            id: "579",
            title: "Доступні кредити 5-7-9%",
            provider: "Фонд розвитку підприємництва",
            type: .credit,
            amountDescription: "пільгова ставка 5–9%",
            summary: "Кредити на інвестиції, рефінансування та оборотні кошти з компенсацією відсотків державою.",
            requirements: ["Суб'єкт мікро- або малого бізнесу", "Звернення в банк-партнер", "Відсутність простроченої заборгованості"],
            industries: [],
            statuses: [],
            requiresEmployees: false,
            url: URL(string: "https://5-7-9.gov.ua")!
        ),
        Opportunity(
            id: "diia-city",
            title: "Резидентство Diia.City",
            provider: "Мінцифри",
            type: .regime,
            amountDescription: "спецрежим оподаткування",
            summary: "Податковий режим для IT-компаній: альтернативні ставки для компанії та гіг-спеціалістів.",
            requirements: ["Юридична особа (ТОВ)", "IT-діяльність — основна", "Мінімальна кількість спеціалістів та рівень оплати"],
            industries: [.it],
            statuses: [],
            requiresEmployees: true,
            url: URL(string: "https://city.diia.gov.ua")!
        ),
        Opportunity(
            id: "osvita",
            title: "Безкоштовні курси підприємництва",
            provider: "Дія.Освіта",
            type: .education,
            amountDescription: "безкоштовно",
            summary: "Серіали та курси про старт бізнесу, фінанси, маркетинг і податки для ФОП.",
            requirements: ["Реєстрація на платформі"],
            industries: [],
            statuses: [],
            requiresEmployees: false,
            url: URL(string: "https://osvita.diia.gov.ua")!
        )
    ]

    /// Персональний відсоток відповідності програми профілю (0…1).
    static func matchScore(_ opportunity: Opportunity, for profile: BusinessProfile) -> Double {
        var score = 0.55

        if opportunity.industries.isEmpty {
            score += 0.1
        } else if opportunity.industries.contains(profile.industry) {
            score += 0.3
        } else {
            score -= 0.35
        }

        if !opportunity.statuses.isEmpty {
            score += opportunity.statuses.isDisjoint(with: profile.statuses) ? -0.4 : 0.35
        }

        if opportunity.requiresEmployees && profile.employees == 0 {
            score -= 0.1
        }

        if opportunity.type == .education && profile.createdAt.timeIntervalSinceNow > -60 * 60 * 24 * 365 {
            score += 0.1 // молодий бізнес — навчання особливо корисне
        }

        return min(1, max(0, score))
    }

    static func ranked(for profile: BusinessProfile) -> [(opportunity: Opportunity, match: Double)] {
        all.map { ($0, matchScore($0, for: profile)) }
            .sorted { $0.1 > $1.1 }
    }
}
