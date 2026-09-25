//
//  IdeaValidator.swift
//  UkrainianBusinessGuide
//
//  Швидка оцінка бізнес-ідеї за шістьма критеріями з вагами та рекомендаціями.
//

import Foundation

enum IdeaCriterion: String, CaseIterable, Identifiable {
    case demand, competition, margin, skills, capital, speed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .demand: return "Попит"
        case .competition: return "Конкуренція"
        case .margin: return "Маржинальність"
        case .skills: return "Ваша експертиза"
        case .capital: return "Стартовий капітал"
        case .speed: return "Швидкість до першої виручки"
        }
    }

    var question: String {
        switch self {
        case .demand: return "Наскільки гостро клієнти потребують цього вже зараз?"
        case .competition: return "Наскільки вільна ніша? (5: конкурентів майже немає)"
        case .margin: return "Яка очікувана націнка? (5: понад 50%)"
        case .skills: return "Наскільки добре ви знаєте цю сферу?"
        case .capital: return "Наскільки мало грошей потрібно на старт? (5: майже нуль)"
        case .speed: return "Як швидко можна отримати перші гроші? (5: за тиждень)"
        }
    }

    var icon: String {
        switch self {
        case .demand: return "person.crop.circle.badge.checkmark"
        case .competition: return "flag.2.crossed.fill"
        case .margin: return "chart.pie.fill"
        case .skills: return "brain.head.profile"
        case .capital: return "banknote"
        case .speed: return "bolt.fill"
        }
    }

    var weight: Double {
        switch self {
        case .demand: return 0.25
        case .competition: return 0.15
        case .margin: return 0.2
        case .skills: return 0.15
        case .capital: return 0.1
        case .speed: return 0.15
        }
    }

    var advice: String {
        switch self {
        case .demand: return "Проведіть 10 інтерв'ю з потенційними клієнтами й запропонуйте передзамовлення до запуску."
        case .competition: return "Знайдіть вузький сегмент, який конкуренти обслуговують погано, і станьте там №1."
        case .margin: return "Перегляньте ціноутворення або постачальників. З низькою маржею бізнес важко розширювати."
        case .skills: return "Знайдіть партнера чи ментора з галузі або пройдіть коротке навчання."
        case .capital: return "Почніть з мінімальної версії продукту, розгляньте гранти «Власна справа» чи кредити 5-7-9%."
        case .speed: return "Спростіть першу пропозицію до послуги, яку можна продати вже цього тижня."
        }
    }
}

struct IdeaEvaluation: Equatable {
    let score: Int
    let verdict: String
    let weakest: [IdeaCriterion]
}

enum IdeaValidator {
    /// `ratings` — оцінки 1…5 за кожним критерієм.
    static func evaluate(_ ratings: [IdeaCriterion: Int]) -> IdeaEvaluation {
        let weighted = IdeaCriterion.allCases.reduce(0.0) { sum, criterion in
            let rating = Double(min(5, max(1, ratings[criterion] ?? 3)))
            return sum + (rating - 1) / 4 * criterion.weight
        }
        let score = Int((weighted * 100).rounded())
        let verdict: String
        switch score {
        case 75...: verdict = "Сильна ідея. Перевірте її на реальних клієнтах уже цього тижня"
        case 55..<75: verdict = "Перспективно, але є слабкі місця"
        case 35..<55: verdict = "Ризиковано. Спершу перевірте припущення"
        default: verdict = "Варто переосмислити концепцію"
        }
        let weakest = IdeaCriterion.allCases
            .filter { (ratings[$0] ?? 3) <= 2 }
            .sorted { $0.weight > $1.weight }
        return IdeaEvaluation(score: score, verdict: verdict, weakest: weakest)
    }
}
