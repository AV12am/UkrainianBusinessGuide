//
//  MonobankClient.swift
//  UkrainianBusinessGuide
//
//  Відкритий API monobank для фізосіб і ФОП: https://api.monobank.ua/docs/
//  Токен створюється на api.monobank.ua і дає доступ лише на читання.
//  Виписку можна отримати не частіше одного разу на 60 секунд і максимум за 31 добу.
//

import Foundation

struct MonobankClient {
    struct Account: Decodable, Identifiable, Equatable {
        let id: String
        let type: String
        let currencyCode: Int
        let iban: String?
        let balance: Int

        var title: String {
            let kind = type == "fop" ? "Рахунок ФОП" : "Картка \(type)"
            let tail = iban.map { " …" + String($0.suffix(4)) } ?? ""
            return kind + tail
        }
    }

    private struct ClientInfo: Decodable {
        let name: String
        let accounts: [Account]
    }

    private struct StatementItem: Decodable {
        let id: String
        let time: Int
        let description: String
        let mcc: Int
        let amount: Int
        let comment: String?
        let counterName: String?
    }

    enum ClientError: LocalizedError {
        case unauthorized, rateLimited, noAccounts, server(Int)

        var errorDescription: String? {
            switch self {
            case .unauthorized: return "monobank не прийняв токен. Перевірте, що скопіювали його повністю."
            case .rateLimited: return "monobank дозволяє запит раз на хвилину. Спробуйте трохи пізніше."
            case .noAccounts: return "У цьому профілі monobank немає гривневих рахунків."
            case .server(let code): return "monobank повернув помилку \(code). Спробуйте пізніше."
            }
        }
    }

    static let tokenKey = "monobank-token"

    let token: String
    var session: URLSession = .shared
    private let base = URL(string: "https://api.monobank.ua")!

    /// Гривневі рахунки; рахунок ФОП першим.
    func accounts() async throws -> [Account] {
        let info: ClientInfo = try await get("/personal/client-info")
        let accounts = info.accounts
            .filter { $0.currencyCode == 980 }
            .sorted { ($0.type == "fop" ? 0 : 1) < ($1.type == "fop" ? 0 : 1) }
        guard !accounts.isEmpty else { throw ClientError.noAccounts }
        return accounts
    }

    /// Операції за останні `days` днів (не більше 31).
    func statement(account: String, days: Int = 31, now: Date = .now) async throws -> [ImportedOperation] {
        let to = Int(now.timeIntervalSince1970)
        let from = to - min(days, 31) * 86_400
        let items: [StatementItem] = try await get("/personal/statement/\(account)/\(from)/\(to)")
        return items.map { item in
            let text = [item.description, item.comment].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ". ")
            return ImportedOperation(externalID: "mono:" + item.id,
                                     date: Date(timeIntervalSince1970: TimeInterval(item.time)),
                                     amount: Double(item.amount) / 100,
                                     description: text,
                                     mcc: item.mcc)
        }
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.setValue(token, forHTTPHeaderField: "X-Token")
        request.timeoutInterval = 30
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200: return try JSONDecoder().decode(T.self, from: data)
        case 401, 403: throw ClientError.unauthorized
        case 429: throw ClientError.rateLimited
        default: throw ClientError.server(status)
        }
    }
}
