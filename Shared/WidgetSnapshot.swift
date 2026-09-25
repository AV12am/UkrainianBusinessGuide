//
//  WidgetSnapshot.swift
//  Спільний для застосунку й віджета.
//
//  Застосунок після кожної зміни записує короткий зріз у спільну теку App Group,
//  віджет лише читає його. Самі операції віджету недоступні.
//

import Foundation

struct WidgetSnapshot: Codable, Equatable {
    struct Payment: Codable, Equatable {
        var title: String
        var date: Date
        var amount: Double?
    }

    var businessName: String
    var nextPayment: Payment?
    var taxReserve: Double
    var limitUsage: Double
    var receivables: Double
    var updatedAt: Date

    static let appGroup = "group.ua.businesscompass.app"

    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("widget.json")
    }

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let url = Self.fileURL, let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Зразок для галереї віджетів і превью.
    static let sample = WidgetSnapshot(
        businessName: "Кав'ярня «Зерно»",
        nextPayment: Payment(title: "ЄСВ за 3 кв. 2026", date: Date(timeIntervalSinceNow: 25 * 86_400), amount: 5_707),
        taxReserve: 30_152,
        limitUsage: 0.078,
        receivables: 25_760,
        updatedAt: .now
    )
}
