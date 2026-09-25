//
//  FormsCatalog.swift
//  UkrainianBusinessGuide
//
//  Довідник документів ФОП: що подавати, коли та де. Підбирається під профіль.
//  Правила звірено станом на `OpportunityCatalog.verifiedOn`.
//

import Foundation

struct BusinessForm: Identifiable {
    enum Stage: String, CaseIterable, Identifiable {
        case registration, regular, employees, cash, changes

        var id: String { rawValue }

        var title: String {
            switch self {
            case .registration: return "Реєстрація"
            case .regular: return "Регулярна звітність"
            case .employees: return "Працівники"
            case .cash: return "Оплата від клієнтів"
            case .changes: return "Зміни та закриття"
            }
        }
    }

    let id: String
    let title: String
    let stage: Stage
    /// Коли подавати.
    let when: String
    /// Куди подавати.
    let whereToFile: String
    let note: String?
    let url: URL
    /// Для яких груп актуально (порожньо = для всіх).
    var groups: Set<FOPGroup> = []
}

enum FormsCatalog {
    private static let taxCabinet = URL(string: "https://cabinet.tax.gov.ua")!
    private static let diia = URL(string: "https://diia.gov.ua")!
    private static let pfuPortal = URL(string: "https://portal.pfu.gov.ua")!

    static let all: [BusinessForm] = [
        BusinessForm(
            id: "registration",
            title: "Заява про державну реєстрацію ФОП",
            stage: .registration,
            when: "До початку діяльності. Запис у реєстрі з'являється протягом 2 робочих днів.",
            whereToFile: "Дія (онлайн, безкоштовно), ЦНАП або нотаріус",
            note: "У тій самій заяві в Дії можна одразу обрати групу єдиного податку.",
            url: diia
        ),
        BusinessForm(
            id: "simplified",
            title: "Заява про застосування спрощеної системи",
            stage: .registration,
            when: "Разом із реєстрацією. Для 3 групи можна окремо протягом 10 днів після реєстрації. Перехід або зміна групи: не пізніше ніж за 15 днів до початку кварталу.",
            whereToFile: "Дія під час реєстрації або електронний кабінет платника",
            note: "Якщо заяву не подати, ФОП працюватиме на загальній системі оподаткування.",
            url: taxCabinet
        ),
        BusinessForm(
            id: "declaration-12",
            title: "Декларація платника єдиного податку, 1–2 група",
            stage: .regular,
            when: "Раз на рік, протягом 60 днів після закінчення року (за 2026 рік до 1 березня 2027).",
            whereToFile: "Електронний кабінет платника",
            note: "У декларації відображаєте доходи, сплачений військовий збір і додаток про ЄСВ за себе.",
            url: taxCabinet,
            groups: [.first, .second]
        ),
        BusinessForm(
            id: "declaration-3",
            title: "Декларація платника єдиного податку, 3 група",
            stage: .regular,
            when: "Щокварталу, протягом 40 днів після кварталу: 10 травня, 9 серпня, 9 листопада, 9 лютого.",
            whereToFile: "Електронний кабінет платника",
            note: "Єдиний податок і військовий збір сплачуються протягом 10 днів після строку подання декларації.",
            url: taxCabinet,
            groups: [.third]
        ),
        BusinessForm(
            id: "esv",
            title: "Сплата ЄСВ за себе",
            stage: .regular,
            when: "Щокварталу до 20 числа місяця після кварталу, навіть якщо доходу не було. Мінімум 1 902,34 ₴ на місяць.",
            whereToFile: "Банк або Дія, реквізити в електронному кабінеті",
            note: nil,
            url: taxCabinet
        ),
        BusinessForm(
            id: "hire-notice",
            title: "Повідомлення про прийняття працівника",
            stage: .employees,
            when: "До ДПС до початку роботи працівника. До ПФУ оперативні відомості не пізніше наступного дня після наказу.",
            whereToFile: "Електронний кабінет платника та портал ПФУ",
            note: "ФОП 1 групи не може мати найманих працівників.",
            url: pfuPortal,
            groups: [.second, .third]
        ),
        BusinessForm(
            id: "payroll-report",
            title: "Податковий розрахунок (ПДФО, військовий збір, ЄСВ)",
            stage: .employees,
            when: "З 2026 року щокварталу з розбивкою по місяцях, протягом 40 днів після кварталу.",
            whereToFile: "Електронний кабінет платника",
            note: "Подають лише ті, хто має працівників або платив фізособам за договорами.",
            url: taxCabinet,
            groups: [.second, .third]
        ),
        BusinessForm(
            id: "prro",
            title: "Реєстрація ПРРО (форма № 1-ПРРО) і ключа касира (№ 5-ПРРО)",
            stage: .cash,
            when: "До першого розрахунку з клієнтом готівкою чи карткою.",
            whereToFile: "Електронний кабінет: там є безкоштовний програмний касовий апарат ДПС",
            note: "Обов'язок залежить від способу оплати, а не лише від групи. 1 група працює без касового апарата.",
            url: taxCabinet,
            groups: [.second, .third]
        ),
        BusinessForm(
            id: "20-opp",
            title: "Повідомлення про об'єкти оподаткування (№ 20-ОПП)",
            stage: .cash,
            when: "Коли з'являється місце ведення діяльності: магазин, кафе, склад, транспорт.",
            whereToFile: "Електронний кабінет платника",
            note: nil,
            url: taxCabinet
        ),
        BusinessForm(
            id: "vat",
            title: "Заява про реєстрацію платником ПДВ (№ 1-ПДВ)",
            stage: .changes,
            when: "За бажанням, якщо обираєте ставку 3% на 3 групі.",
            whereToFile: "Електронний кабінет платника",
            note: "Законопроєкт про обов'язковий ПДВ для ФОП з 2027 року станом на вересень 2026 не ухвалено.",
            url: taxCabinet,
            groups: [.third]
        ),
        BusinessForm(
            id: "closing",
            title: "Заява про припинення підприємницької діяльності",
            stage: .changes,
            when: "Коли вирішили закрити ФОП. Після цього подається декларація за період до закриття.",
            whereToFile: "Дія, ЦНАП або нотаріус",
            note: nil,
            url: diia
        )
    ]

    /// Документи, актуальні для профілю.
    static func forms(for profile: BusinessProfile?) -> [BusinessForm] {
        guard let profile else { return all }
        return all.filter { $0.groups.isEmpty || $0.groups.contains(profile.fopGroup) }
    }
}
