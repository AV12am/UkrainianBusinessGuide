//
//  BusinessCompassWidget.swift
//  BusinessCompassWidget
//
//  Найближча сплата, податкова скарбничка й борги клієнтів — на головному екрані
//  та екрані блокування.
//

import SwiftUI
import WidgetKit

@main
struct BusinessCompassWidgets: WidgetBundle {
    var body: some Widget {
        NextPaymentWidget()
    }
}

struct NextPaymentWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextPayment", provider: CompassProvider()) { entry in
            CompassWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetPalette.paper }
        }
        .configurationDisplayName("Податки")
        .description("Найближча сплата і скільки відкласти на податки.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Дані

struct CompassEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct CompassProvider: TimelineProvider {
    func placeholder(in context: Context) -> CompassEntry {
        CompassEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (CompassEntry) -> Void) {
        completion(CompassEntry(date: .now, snapshot: context.isPreview ? .sample : (WidgetSnapshot.load() ?? .sample)))
    }

    /// Запис на кожну наступну північ, щоб «через N дн.» лишалося правильним без запуску застосунку.
    func getTimeline(in context: Context, completion: @escaping (Timeline<CompassEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let today = WidgetFormat.calendar.startOfDay(for: .now)
        let entries = (0..<7).compactMap { offset -> CompassEntry? in
            guard let day = WidgetFormat.calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return CompassEntry(date: offset == 0 ? .now : day, snapshot: snapshot)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Вигляд

struct CompassWidgetView: View {
    let entry: CompassEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemMedium: medium(snapshot)
            case .accessoryRectangular: rectangular(snapshot)
            case .accessoryInline: inline(snapshot)
            default: small(snapshot)
            }
        } else {
            empty
        }
    }

    private var empty: some View {
        Text("Відкрийте Бізнес Компас, щоб побачити строки сплати.")
            .font(.footnote)
            .foregroundStyle(WidgetPalette.inkMuted)
    }

    private func small(_ snapshot: WidgetSnapshot) -> some View {
        payment(snapshot)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func medium(_ snapshot: WidgetSnapshot) -> some View {
        HStack(alignment: .top, spacing: 16) {
            payment(snapshot)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Rectangle().fill(WidgetPalette.rule).frame(width: 1)
            VStack(alignment: .leading, spacing: 8) {
                figure("Відкласти на податки", WidgetFormat.uah(snapshot.taxReserve))
                if snapshot.receivables > 0 {
                    figure("Вам винні", WidgetFormat.uah(snapshot.receivables))
                }
                figure("Ліміт групи", WidgetFormat.percent(snapshot.limitUsage))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func payment(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Наступна сплата")
                .font(.caption)
                .foregroundStyle(WidgetPalette.inkMuted)
            if let next = snapshot.nextPayment {
                Text(WidgetFormat.dayMonth(next.date))
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(WidgetPalette.ink)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(next.title)
                    .font(.footnote)
                    .foregroundStyle(WidgetPalette.ink)
                    .lineLimit(2)
                Spacer(minLength: 4)
                Text(detail(next))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(urgency(next.date))
                    .lineLimit(2)
            } else {
                Text("Немає")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(WidgetPalette.ink)
                Text("Усі строки на найближчі місяці закриті.")
                    .font(.footnote)
                    .foregroundStyle(WidgetPalette.inkMuted)
            }
        }
    }

    private func figure(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption)
                .foregroundStyle(WidgetPalette.inkMuted)
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .monospacedDigit()
                .foregroundStyle(WidgetPalette.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }

    private func rectangular(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let next = snapshot.nextPayment {
                Text("Сплата \(WidgetFormat.dayMonth(next.date))")
                    .font(.headline)
                Text(next.title).lineLimit(1)
                Text(detail(next)).lineLimit(1)
            } else {
                Text("Податки").font(.headline)
                Text("Строків найближчим часом немає")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func inline(_ snapshot: WidgetSnapshot) -> some View {
        if let next = snapshot.nextPayment {
            Text("\(next.title), \(WidgetFormat.dayMonth(next.date))")
        } else {
            Text("Податкових строків немає")
        }
    }

    private func daysLeft(_ date: Date) -> Int {
        let calendar = WidgetFormat.calendar
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: entry.date), to: calendar.startOfDay(for: date)).day ?? 0
    }

    private func detail(_ payment: WidgetSnapshot.Payment) -> String {
        let days = daysLeft(payment.date)
        let due: String
        switch days {
        case ..<0: due = "прострочено"
        case 0: due = "сьогодні"
        case 1: due = "завтра"
        default: due = "через \(days) дн."
        }
        guard let amount = payment.amount, amount > 0 else { return due.prefix(1).uppercased() + String(due.dropFirst()) }
        return "≈ \(WidgetFormat.uah(amount)), \(due)"
    }

    private func urgency(_ date: Date) -> Color {
        switch daysLeft(date) {
        case ..<3: return WidgetPalette.negative
        case ..<10: return WidgetPalette.caution
        default: return WidgetPalette.inkMuted
        }
    }
}

// MARK: - Стиль

enum WidgetPalette {
    static let paper = dynamic(0xF6F2EA, 0x161512)
    static let ink = dynamic(0x1C1B19, 0xECE7DD)
    static let inkMuted = dynamic(0x6E685D, 0x9F988B)
    static let rule = dynamic(0xDCD5C7, 0x35322C)
    static let negative = dynamic(0xA3402F, 0xE38D7B)
    static let caution = dynamic(0x9A6310, 0xE2B25E)

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: 1)
        })
    }
}

enum WidgetFormat {
    static let locale = Locale(identifier: "uk_UA")

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Kyiv") ?? .current
        calendar.locale = locale
        return calendar
    }()

    static func uah(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: value.rounded())) ?? "0") + " ₴"
    }

    static func percent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "0%"
    }

    static func dayMonth(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).day().month(.abbreviated))
    }
}
