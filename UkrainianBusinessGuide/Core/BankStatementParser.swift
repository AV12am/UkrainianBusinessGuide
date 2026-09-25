//
//  BankStatementParser.swift
//  UkrainianBusinessGuide
//
//  Розбирає виписку у форматі CSV з будь-якого банку: сам знаходить рядок заголовків,
//  роздільник, колонки дати, суми й призначення платежу.
//

import Foundation

struct ImportedOperation: Identifiable, Equatable {
    var id: String { externalID }
    let externalID: String
    let date: Date
    /// Зі знаком: надходження додатні, списання від'ємні.
    let amount: Double
    let description: String
    var mcc: Int? = nil

    var isLikelyOwnTransfer: Bool { OperationCategorizer.isLikelyOwnTransfer(description) }

    var transaction: Transaction {
        Transaction(date: date, amount: abs(amount),
                    category: OperationCategorizer.category(for: description, mcc: mcc, isIncome: amount > 0),
                    note: description, externalID: externalID)
    }
}

enum BankStatementParser {
    enum ParseError: LocalizedError {
        case empty, noHeader, noRows

        var errorDescription: String? {
            switch self {
            case .empty: return "Файл порожній або не є текстовим CSV."
            case .noHeader: return "Не знайшли колонки з датою та сумою. Збережіть виписку у форматі CSV і спробуйте ще раз."
            case .noRows: return "У виписці немає операцій, які вдалося прочитати."
            }
        }
    }

    static func parse(_ data: Data) throws -> [ImportedOperation] {
        guard let text = decode(data), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ParseError.empty }
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let delimiter = detectDelimiter(lines)
        let rows = lines.map { split($0, delimiter: delimiter) }

        guard let (headerIndex, columns) = findHeader(rows) else { throw ParseError.noHeader }

        var result: [ImportedOperation] = []
        // Однакові операції в один день (дві кави по 60 ₴) розрізняються порядковим номером.
        var occurrences: [String: Int] = [:]
        for row in rows.dropFirst(headerIndex + 1) {
            guard let date = column(columns.date, in: row).flatMap(parseDate) else { continue }
            let amount: Double
            if let credit = columns.credit, let debit = columns.debit {
                let plus = column(credit, in: row).flatMap(parseAmount) ?? 0
                let minus = column(debit, in: row).flatMap(parseAmount) ?? 0
                amount = abs(plus) - abs(minus)
            } else if let value = column(columns.amount, in: row).flatMap(parseAmount) {
                amount = value
            } else {
                continue
            }
            guard amount != 0 else { continue }
            let description = column(columns.description, in: row)?.trimmingCharacters(in: .whitespaces) ?? ""
            let mcc = column(columns.mcc, in: row).flatMap { Int($0) }
            let id: String
            if let reference = column(columns.reference, in: row), !reference.isEmpty {
                id = "ref:" + reference
            } else {
                let key = "csv:\(Int(date.timeIntervalSince1970)):\(String(format: "%.2f", amount)):\(description.prefix(40))"
                let count = occurrences[key, default: 0]
                occurrences[key] = count + 1
                id = count == 0 ? key : "\(key)#\(count)"
            }
            result.append(ImportedOperation(externalID: id, date: date, amount: amount, description: description, mcc: mcc))
        }
        guard !result.isEmpty else { throw ParseError.noRows }
        return result.sorted { $0.date > $1.date }
    }

    // MARK: - Колонки

    private struct Columns {
        var date: Int?
        var amount: Int?
        var credit: Int?
        var debit: Int?
        var description: Int?
        var reference: Int?
        var mcc: Int?
    }

    private static func findHeader(_ rows: [[String]]) -> (Int, Columns)? {
        for (index, row) in rows.prefix(30).enumerated() {
            var columns = Columns()
            for (i, rawCell) in row.enumerated() {
                let cell = rawCell.lowercased()
                if columns.date == nil, cell.contains("дата") || cell.contains("date") || cell.contains("час операц") {
                    columns.date = i
                } else if columns.credit == nil, cell.contains("кредит") || cell.contains("надходж") || cell == "credit" {
                    columns.credit = i
                } else if columns.debit == nil, cell.contains("дебет") || cell.contains("списан") || cell == "debit" {
                    columns.debit = i
                } else if columns.amount == nil,
                          cell.contains("сума") || cell.contains("сумма") || cell.contains("amount"),
                          !cell.contains("комісі"), !cell.contains("кешбек"), !cell.contains("залиш") {
                    columns.amount = i
                } else if columns.description == nil,
                          cell.contains("призначен") || cell.contains("опис") || cell.contains("деталі") || cell.contains("description") || cell.contains("коментар") {
                    columns.description = i
                } else if columns.mcc == nil, cell == "mcc" {
                    columns.mcc = i
                } else if columns.reference == nil, cell.contains("референс") || cell.contains("номер документ") || cell == "id" {
                    columns.reference = i
                }
            }
            let hasAmount = columns.amount != nil || (columns.credit != nil && columns.debit != nil)
            if columns.date != nil, hasAmount { return (index, columns) }
        }
        return nil
    }

    private static func column(_ index: Int?, in row: [String]) -> String? {
        guard let index, row.indices.contains(index) else { return nil }
        return row[index]
    }

    // MARK: - Текст

    private static func decode(_ data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8) {
            return text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        }
        return String(data: data, encoding: .windowsCP1251)
    }

    private static func detectDelimiter(_ lines: [String]) -> Character {
        let sample = lines.prefix(10).joined()
        let candidates: [Character] = [";", "\t", ","]
        return candidates.max { lhs, rhs in
            sample.filter { $0 == lhs }.count < sample.filter { $0 == rhs }.count
        } ?? ";"
    }

    /// Розбиває рядок CSV з урахуванням лапок.
    static func split(_ line: String, delimiter: Character) -> [String] {
        var cells: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()
        var pending: Character? = nil
        while let char = pending ?? iterator.next() {
            pending = nil
            if char == "\"" {
                if inQuotes, let next = iterator.next() {
                    if next == "\"" { current.append("\""); continue }
                    inQuotes = false
                    pending = next
                    continue
                }
                inQuotes.toggle()
            } else if char == delimiter && !inQuotes {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }

    // MARK: - Значення

    static func parseAmount(_ raw: String) -> Double? {
        var text = raw.replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "₴", with: "")
            .replacingOccurrences(of: "UAH", with: "")
            .replacingOccurrences(of: "−", with: "-")
        guard !text.isEmpty else { return nil }
        // «1.234,56» або «1,234.56»: останній роздільник — десятковий.
        if let lastComma = text.lastIndex(of: ","), let lastDot = text.lastIndex(of: ".") {
            if lastComma > lastDot {
                text = text.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                text = text.replacingOccurrences(of: ",", with: "")
            }
        } else {
            text = text.replacingOccurrences(of: ",", with: ".")
        }
        return Double(text)
    }

    private static let dateFormats = [
        "dd.MM.yyyy HH:mm:ss", "dd.MM.yyyy HH:mm", "dd.MM.yyyy",
        "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd",
        "dd/MM/yyyy HH:mm", "dd/MM/yyyy", "dd.MM.yy"
    ]

    private static let formatters: [DateFormatter] = dateFormats.map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.kyiv.timeZone
        formatter.dateFormat = format
        return formatter
    }

    static func parseDate(_ raw: String) -> Date? {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        for formatter in formatters {
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}

/// Підбирає категорію операції за описом і кодом MCC.
enum OperationCategorizer {
    /// Схоже на переказ між власними рахунками: це не дохід і не витрата бізнесу,
    /// тому під час імпорту такі операції за замовчуванням не додаються.
    static func isLikelyOwnTransfer(_ description: String) -> Bool {
        let text = description.lowercased()
        let markers = ["між власними", "між своїми", "власних коштів", "власний рахунок", "власного рахунку",
                       "з білої картки", "з чорної картки", "на білу картку", "на чорну картку",
                       "з картки фоп", "на картку фоп", "з рахунку фоп", "на рахунок фоп", "зі своєї картки", "на свою картку"]
        return markers.contains { text.contains($0) }
    }

    static func category(for description: String, mcc: Int?, isIncome: Bool) -> TransactionCategory {
        let text = description.lowercased()
        func has(_ words: String...) -> Bool { words.contains { text.contains($0) } }

        if isIncome {
            if has("грант", "власна справа", "єробота") { return .grant }
            if has("послуг", "консультац", "розробк", "договор", "рахунк", "акт ") { return .services }
            return .sales
        }
        if has("єдиний податок", "єсв", "єдиний внесок", "військовий збір", "гу дпс", "дпс у", "казначейств", "податк") { return .taxes }
        if has("оренд", "rent") { return .rent }
        if has("зарплат", "заробітн", "аванс") { return .salary }
        if has("facebook", "meta ", "google ads", "instagram", "реклам", "tiktok") { return .marketing }
        if let mcc, [4816, 5734, 5817, 5818, 7372].contains(mcc) { return .software }
        if has("apple.com", "google", "adobe", "notion", "figma", "github", "openai", "anthropic", "microsoft", "zoom", "хостинг") { return .software }
        if let mcc, (5411...5499).contains(mcc) || [5200, 5251, 5311, 5331, 5399, 5999, 5045].contains(mcc) { return .supplies }
        return .otherExpense
    }
}
