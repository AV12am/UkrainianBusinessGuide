//
//  Advisor.swift
//  UkrainianBusinessGuide
//
//  Бізнес-радник: відповідає на поширені питання ФОП з урахуванням даних користувача.
//  Працює офлайн; точка розширення для LLM — протокол `AdvisorEngine`.
//

import Foundation

struct AdvisorMessage: Identifiable, Equatable {
    enum Role: Equatable { case user, advisor }

    let id = UUID()
    let role: Role
    let text: String
    let date = Date()
}

/// Контекст, який радник враховує у відповідях.
struct AdvisorContext {
    var profile: BusinessProfile
    var health: HealthReport
    var yearIncome: Double
    var averageMonthlyIncome: Double
    var nextDeadline: TaxDeadline?
    var engine: TaxEngine
}

protocol AdvisorEngine {
    func reply(to question: String, context: AdvisorContext) async -> String
}

/// Офлайн-радник на базі правил і бази знань.
struct LocalAdvisor: AdvisorEngine {
    static let suggestions = [
        "Як справи в моєму бізнесі?",
        "Які документи мені подавати?",
        "Як відкрити ФОП?",
        "Скільки податків я сплачу?",
        "Коли наступний платіж?",
        "Чи варто змінити групу?",
        "Як найняти працівника?",
        "Де взяти гроші на розвиток?"
    ]

    func reply(to question: String, context: AdvisorContext) async -> String {
        let q = question.lowercased()
        let engine = context.engine
        let profile = context.profile

        func has(_ words: String...) -> Bool { words.contains { q.contains($0) } }

        if has("документ", "форм", "заяв", "звіт", "декларац") {
            let forms = FormsCatalog.forms(for: profile).prefix(4).map { "• \($0.title): \($0.when)" }.joined(separator: "\n")
            return "Основні документи для вашої групи:\n\(forms)\n\nПовний перелік із посиланнями у розділі «Документи» вгорі цього екрана."
        }

        if has("відкрити", "зареєструв", "реєстрац", "почати бізнес", "старт") {
            return "Покроковий план відкриття ФОП, від вибору КВЕД до першої сплати податків, є в розділі «Відкриття» вгорі цього екрана. Реєстрація в Дії займає близько 10 хвилин і безкоштовна."
        }

        if has("справи", "бізнес", "стан", "пульс", "здоров") {
            let top = context.health.insights.first.map { "\n\nГоловне зараз: \($0.title.lowercased()). \($0.message)" } ?? ""
            return "Стан бізнесу: \(context.health.score) зі 100, \(context.health.verdict.lowercased()).\n"
                + context.health.components.map { "• \($0.title): \($0.detail)" }.joined(separator: "\n")
                + top
        }

        if has("наступн", "коли", "строк", "дедлайн", "календар") {
            guard let deadline = context.nextDeadline else {
                return "Найближчих податкових строків не знайдено. Перевірте вкладку «Податки»."
            }
            let amount = deadline.estimatedAmount.map { " Орієнтовно: \($0.uah)." } ?? ""
            return "Найближчий строк: \(deadline.date.shortUkrainian), \(deadline.title).\(amount)\n\n\(deadline.detail)"
        }

        if has("групу", "група", "груп", "перейти") {
            let projected = max(context.yearIncome, context.averageMonthlyIncome * 12)
            let recommended = engine.recommendedGroup(forAnnualIncome: projected, isVATPayer: profile.isVATPayer)
            let usage = engine.limitUsage(group: profile.fopGroup, yearIncome: context.yearIncome)
            var text = "Ви на \(profile.fopGroup.title). Використано \(usage.percent) річного ліміту (\(engine.annualIncomeLimit(for: profile.fopGroup).uah)).\n"
            text += "За прогнозу доходу \(projected.uah) на рік найдешевшою за податками є \(recommended.title)."
            if recommended != profile.fopGroup {
                text += "\n\nВажливо: групи 1–2 мають обмеження за видами діяльності та клієнтами. Заяву про зміну групи подають не пізніше ніж за 15 днів до початку кварталу. Якщо дохід перевищить ліміт, із суми перевищення сплачується 15%."
            }
            return text
        }

        if has("податк", "єсв", "сплач", "військов") {
            let quarterIncome = context.averageMonthlyIncome * 3
            let taxes = engine.quarterlyTaxes(group: profile.fopGroup, isVATPayer: profile.isVATPayer, quarterIncome: quarterIncome)
            return "За середнього доходу \(context.averageMonthlyIncome.uah)/міс за квартал ви сплатите приблизно \(taxes.total.uah):\n"
                + "• Єдиний податок: \(taxes.singleTax.uah)\n"
                + "• Військовий збір: \(taxes.militaryLevy.uah)\n"
                + "• ЄСВ: \(taxes.socialContribution.uah)\n\n"
                + "Порада: відкладайте \(engine.effectiveRate(group: profile.fopGroup, isVATPayer: profile.isVATPayer, quarterIncome: quarterIncome).percent) кожного надходження на окремий рахунок, тоді сплата в строк не стане проблемою."
        }

        if has("найм", "працівник", "співробітник", "штат") {
            let salary = 20_000.0
            let employerCost = salary * (1 + ScenarioSimulator.employerContributionRate)
            return "Щоб найняти працівника як ФОП:\n1. Укладіть трудовий договір і подайте повідомлення до податкової до початку роботи.\n2. Щомісяця сплачуйте ПДФО 18% та військовий збір (утримуються з зарплати) і ЄСВ 22% зверху.\n3. Подавайте звіт з ПДФО та ЄСВ щоквартально.\n\nПриклад: зарплата \(salary.uah) коштуватиме вам ≈ \(employerCost.uah) на місяць. Перевірте вплив у симуляторі «Що якщо»."
                + (profile.fopGroup == .first ? "\n\nЗверніть увагу: ФОП 1 групи не може мати найманих працівників." : "")
        }

        if has("грант", "гроші", "фінансув", "кредит", "інвест") {
            let top = OpportunityCatalog.ranked(for: profile).prefix(3)
                .map { "• \($0.opportunity.title): \($0.opportunity.amountDescription) (збіг \(Int($0.match * 100))%)" }
                .joined(separator: "\n")
            return "Найрелевантніші для вас програми:\n\(top)\n\nДеталі й посилання у вкладці «Підтримка»."
        }

        if has("ціна", "ціни", "прибут", "марж") {
            return "Три швидкі способи підняти прибуток:\n1. Підвищте ціну на 5–10% для нових клієнтів і подивіться на реакцію.\n2. Додайте преміум-пакет: 10–20% клієнтів обирають дорожчий варіант.\n3. Перегляньте 3 найбільші статті витрат.\n\nЗмоделюйте ефект у симуляторі «Що якщо» на вкладці «Фінанси»."
        }

        if has("пдв") {
            return "ФОП 1–2 груп не можуть бути платниками ПДВ. На 3 групі є вибір: 5% єдиного податку без ПДВ або 3% з реєстрацією платником ПДВ. Другий варіант вигідний, якщо ваші клієнти самі платять ПДВ і хочуть податковий кредит. Обов'язкова реєстрація при обсязі операцій понад 1 млн ₴ за 12 місяців стосується загальної системи. Уряд пропонує з 2027 року поширити обов'язковий ПДВ і на «єдинників», але станом на вересень 2026 такий закон не ухвалено. Рішення варто обговорити з бухгалтером."
        }

        return "Я можу допомогти з податками ФОП, строками сплати, вибором групи, наймом, фінансуванням та аналізом вашого бізнесу. Спробуйте одне з питань нижче."
    }
}
