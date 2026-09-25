//
//  DeadlineReminders.swift
//  UkrainianBusinessGuide
//
//  Локальні сповіщення про податкові строки: за 3 дні та в день строку о 10:00 за Києвом.
//

import Foundation
import UserNotifications

enum DeadlineReminders {
    private static let prefix = "deadline-"
    private static let center = UNUserNotificationCenter.current()

    /// Запитує дозвіл на сповіщення. Повертає true, якщо дозволено.
    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Замінює всі заплановані нагадування актуальним списком строків.
    static func schedule(_ deadlines: [TaxDeadline], now: Date = .now) async {
        await cancelAll()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        for deadline in deadlines {
            for daysBefore in [3, 0] {
                guard let day = Calendar.kyiv.date(byAdding: .day, value: -daysBefore, to: deadline.date) else { continue }
                var components = Calendar.kyiv.dateComponents([.year, .month, .day], from: day)
                components.hour = 10
                components.timeZone = Calendar.kyiv.timeZone
                guard let fireDate = Calendar.kyiv.date(from: components), fireDate > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = daysBefore == 0 ? "Сьогодні строк: \(deadline.title)" : "Через 3 дні: \(deadline.title)"
                if let amount = deadline.estimatedAmount, amount > 0 {
                    content.body = "Орієнтовно \(amount.uah). Строк: \(deadline.date.shortUkrainian)."
                } else {
                    content.body = "Строк: \(deadline.date.shortUkrainian)."
                }
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(identifier: "\(prefix)\(deadline.id)-\(daysBefore)", content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }

    static func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
