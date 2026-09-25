//
//  Formatting.swift
//  UkrainianBusinessGuide
//

import Foundation

extension Locale {
    static let ukrainian = Locale(identifier: "uk_UA")
}

extension Calendar {
    /// Григоріанський календар у часовому поясі Києва — усі податкові дати рахуються за ним.
    static let kyiv: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .ukrainian
        calendar.timeZone = TimeZone(identifier: "Europe/Kyiv") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }()
}

extension Double {
    var roundedToKopiyky: Double { (self * 100).rounded() / 100 }

    /// «12 345 ₴»
    var uah: String {
        let formatter = NumberFormatter()
        formatter.locale = .ukrainian
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = abs(self) < 1_000 ? 2 : 0
        formatter.minimumFractionDigits = 0
        return "\(formatter.string(from: NSNumber(value: self)) ?? "0") ₴"
    }

    /// «12 345,00 ₴» — з копійками, для рахунків.
    var uahExact: String {
        let formatter = NumberFormatter()
        formatter.locale = .ukrainian
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return "\(formatter.string(from: NSNumber(value: self)) ?? "0,00") ₴"
    }

    /// «1,5» або «12» — кількість без зайвих нулів.
    var quantityText: String {
        let formatter = NumberFormatter()
        formatter.locale = .ukrainian
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 3
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    /// «1,2 млн ₴» — для компактних плиток.
    var uahCompact: String {
        let value = abs(self)
        let sign = self < 0 ? "−" : ""
        switch value {
        case 1_000_000...:
            return sign + String(format: "%.1f млн ₴", value / 1_000_000).replacingOccurrences(of: ".", with: ",")
        case 10_000...:
            return sign + String(format: "%.0f тис ₴", value / 1_000)
        default:
            return sign + value.uah
        }
    }

    var percent: String {
        let formatter = NumberFormatter()
        formatter.locale = .ukrainian
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: self)) ?? "0%"
    }
}

extension Date.FormatStyle {
    /// Українська локаль і київський час незалежно від часового поясу пристрою:
    /// усі строки й дати програм задані за Києвом.
    static var kyiv: Date.FormatStyle {
        Date.FormatStyle(locale: .ukrainian, calendar: .kyiv, timeZone: Calendar.kyiv.timeZone)
    }
}

extension Date {
    var shortUkrainian: String {
        formatted(Date.FormatStyle.kyiv.day().month(.wide))
    }

    /// «25.09.2026»
    var numericUkrainian: String {
        formatted(Date.FormatStyle.kyiv.day(.twoDigits).month(.twoDigits).year())
    }

    var monthName: String {
        formatted(Date.FormatStyle.kyiv.month(.wide))
    }
}

extension String {
    /// «пʼятниця, 25 вересня» → «Пʼятниця, 25 вересня» (на відміну від `capitalized`, решту не чіпає).
    var capitalizedFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }
}
