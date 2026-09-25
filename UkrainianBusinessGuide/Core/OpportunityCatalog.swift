//
//  OpportunityCatalog.swift
//  UkrainianBusinessGuide
//
//  Каталог програм підтримки та алгоритм персонального підбору.
//  Умови звірено з публікаціями Мінекономіки, Дії, Українського ветеранського фонду
//  та банків-учасників програми 5-7-9% станом на `verifiedOn`. Перед подачею
//  завжди перевіряйте умови на офіційному сайті.
//

import Foundation

enum OpportunityCatalog {
    /// Дата останньої звірки умов з офіційними джерелами.
    static let verifiedOn = Calendar.kyiv.date(from: DateComponents(year: 2026, month: 9, day: 25))!

    static let all: [Opportunity] = [
        Opportunity(
            id: "vlasna-sprava-start",
            title: "«Власна справа»: старт бізнесу",
            provider: "Мінекономіки, Дія, єРобота",
            type: .grant,
            amountDescription: "100–300 тис ₴, з надбавками до 500 тис ₴",
            summary: "Безповоротний грант на відкриття або розвиток малого бізнесу. З 1 вересня 2026 року сума залежить від кількості нових робочих місць, регіону (для прифронтових є надбавка), галузі та категорії заявника.",
            requirements: [
                "Громадянство України, вік від 18 років",
                "Немає боргів перед бюджетом і прострочених кредитів",
                "Створення робочих місць відповідно до обраної суми",
                "Вести діяльність і сплачувати податки щонайменше 3 роки",
                "Не можна: зброя, алкоголь, тютюн, обмін валют, ломбарди"
            ],
            industries: [],
            statuses: [],
            requiresEmployees: false,
            url: URL(string: "https://erobota.diia.gov.ua/")!
        ),
        Opportunity(
            id: "vlasna-sprava-scale",
            title: "«Власна справа»: масштабування",
            provider: "Мінекономіки, Дія, єРобота",
            type: .grant,
            amountDescription: "0,5–1,5 млн ₴, з надбавками до 2,5 млн ₴",
            summary: "Другий напрям оновленої програми для чинного бізнесу: обладнання, оренда й ремонт приміщення, цифровізація, маркетинг, розширення команди та виробництва. Сюди увійшли й колишні окремі гранти, зокрема на сади та теплиці.",
            requirements: [
                "Діючий бізнес (ФОП або юридична особа)",
                "Нові робочі місця: від їх кількості залежить сума",
                "Немає боргів перед бюджетом",
                "Вести діяльність і сплачувати податки щонайменше 3 роки"
            ],
            industries: [],
            statuses: [],
            requiresEmployees: true,
            url: URL(string: "https://erobota.diia.gov.ua/")!
        ),
        Opportunity(
            id: "processing",
            title: "Грант на переробне підприємство",
            provider: "Мінекономіки, Дія",
            type: .grant,
            amountDescription: "до 8 млн ₴",
            summary: "Кошти на обладнання для переробки та виробництва. Держава покриває до половини вартості проєкту, решту вкладає підприємство.",
            requirements: [
                "Переробна або виробнича діяльність",
                "Співфінансування 50% вартості проєкту (для окремих галузей і прифронтових територій менше)",
                "Створення нових робочих місць",
                "Сплатити податків не менше за суму гранту протягом 3 років"
            ],
            industries: [.manufacturing, .agro, .food],
            statuses: [],
            requiresEmployees: true,
            url: URL(string: "https://diia.gov.ua/services/grant-na-pererobne-pidpriyemstvo")!
        ),
        Opportunity(
            id: "veterans",
            title: "Гранти для ветеранів і їхніх родин",
            provider: "Мінекономіки, Дія",
            type: .grant,
            amountDescription: "до 1 млн ₴",
            summary: "Окремий напрям «Власної справи». З 2026 року, крім ветеранів, людей з інвалідністю внаслідок війни та їхніх подружжів, подати можуть батьки учасників бойових дій, їхні повнолітні діти й опікуни. Для родин загиблих і зниклих безвісти захисників теж до 1 млн ₴.",
            requirements: [
                "Статус ветерана або члена родини",
                "Співфінансування: 70% держава, 30% отримувач",
                "Створення робочих місць",
                "Бізнес-план"
            ],
            industries: [],
            statuses: [.veteran, .veteranFamily],
            requiresEmployees: false,
            url: URL(string: "https://erobota.diia.gov.ua/")!
        ),
        Opportunity(
            id: "uvf-varto",
            title: "«ВАРТО: крок вперед»",
            provider: "Український ветеранський фонд",
            type: .grant,
            amountDescription: "0,5–1,5 млн ₴",
            summary: "Конкурс бюджетних грантів для ветеранського бізнесу будь-якої галузі. Сума залежить від кошторису проєкту. Переможців оголосять 30 листопада 2026 року.",
            requirements: [
                "Суб'єкт ветеранського підприємництва",
                "Кошторис і опис бізнес-проєкту",
                "Заявка до 18:00 29 вересня 2026 року"
            ],
            industries: [],
            statuses: [.veteran, .veteranFamily],
            requiresEmployees: false,
            url: URL(string: "https://veteranfund.com.ua")!,
            applicationDeadline: Calendar.kyiv.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 18))
        ),
        Opportunity(
            id: "579",
            title: "Доступні кредити 5-7-9%",
            provider: "Фонд розвитку підприємництва, банки-партнери",
            type: .credit,
            amountDescription: "до 50 млн ₴ під 5–9%",
            summary: "Кредити на інвестиції та оборотні кошти на 3–5 років з компенсацією відсотків державою. Кожне нове робоче місце знижує ставку на 0,5%. Для деокупованих територій і аграріїв діють пільгові умови.",
            requirements: [
                "Мікро-, малий або середній бізнес (річний дохід до 50 млн €)",
                "Заява в банк-учасник програми",
                "Без простроченої заборгованості",
                "З 1 вересня 2026 року: дотримання екологічних і соціальних стандартів Світового банку"
            ],
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
            summary: "Податковий режим для IT-компаній з альтернативними ставками для компанії та гіг-спеціалістів.",
            requirements: [
                "Юридична особа (ТОВ)",
                "Основна діяльність у сфері IT",
                "Мінімальна кількість спеціалістів і рівень оплати праці"
            ],
            industries: [.it],
            statuses: [],
            requiresEmployees: true,
            url: URL(string: "https://city.diia.gov.ua")!
        ),
        Opportunity(
            id: "osvita",
            title: "Безкоштовні курси з підприємництва",
            provider: "Дія.Освіта",
            type: .education,
            amountDescription: "безкоштовно",
            summary: "Короткі курси про старт бізнесу, фінанси, маркетинг і податки для ФОП.",
            requirements: ["Реєстрація на платформі"],
            industries: [],
            statuses: [],
            requiresEmployees: false,
            url: URL(string: "https://osvita.diia.gov.ua")!
        )
    ]

    /// Персональний відсоток відповідності програми профілю (0…1).
    static func matchScore(_ opportunity: Opportunity, for profile: BusinessProfile, on date: Date = .now) -> Double {
        guard opportunity.isOpen(on: date) else { return 0 }
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
            score += 0.1 // молодий бізнес: навчання особливо корисне
        }

        return min(1, max(0, score))
    }

    /// Відкриті програми за відповідністю, закриті в кінці списку.
    static func ranked(for profile: BusinessProfile, on date: Date = .now) -> [(opportunity: Opportunity, match: Double)] {
        all.map { ($0, matchScore($0, for: profile, on: date)) }
            .sorted { lhs, rhs in
                let lhsOpen = lhs.0.isOpen(on: date), rhsOpen = rhs.0.isOpen(on: date)
                if lhsOpen != rhsOpen { return lhsOpen }
                return lhs.1 > rhs.1
            }
    }
}
