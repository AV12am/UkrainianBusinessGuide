//
//  PaymentQR.swift
//  UkrainianBusinessGuide
//
//  QR-код для кредитового переказу за правилами НБУ (постанова № 97 від 19.08.2022).
//  Камера телефона або застосунок банку відкриває платіж з уже заповненими реквізитами.
//

import CoreImage.CIFilterBuiltins
import UIKit

enum PaymentQR {
    /// Вміст QR-коду: рядки формату НБУ версії 002 у кодуванні UTF-8.
    static func payload(recipient: String, iban: String, amount: Double, code: String, purpose: String) -> String {
        let lines = [
            "BCD",                                   // службова мітка
            "002",                                   // версія формату
            "1",                                     // кодування: UTF-8
            "UCT",                                   // функція: кредитовий переказ
            "",                                      // BIC, не використовується
            String(recipient.prefix(70)),
            normalizedIBAN(iban),
            "UAH" + String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), max(0, amount)),
            code.filter(\.isNumber),
            "",                                      // код цілі, резерв
            "",                                      // посилання, резерв
            String(purpose.prefix(140)),
            ""                                       // відображення, резерв
        ]
        return lines.joined(separator: "\n")
    }

    /// Посилання, яке кодується в QR: https://bank.gov.ua/qr/ + Base64URL без доповнення.
    static func link(recipient: String, iban: String, amount: Double, code: String, purpose: String) -> String {
        let data = Data(payload(recipient: recipient, iban: iban, amount: amount, code: code, purpose: purpose).utf8)
        let base64URL = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "https://bank.gov.ua/qr/" + base64URL
    }

    static func normalizedIBAN(_ iban: String) -> String {
        iban.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Чорно-білий QR без згладжування, масштабований до `side` точок.
    static func image(for string: String, side: CGFloat = 480) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = side / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
