//
//  InvoicePDF.swift
//  UkrainianBusinessGuide
//
//  Рахунок на оплату у форматі A4: реквізити сторін, позиції, сума, QR-код НБУ.
//

import SwiftUI

enum InvoicePDF {
    static let pageSize = CGSize(width: 595, height: 842) // A4 у пунктах

    @MainActor
    static func render(_ invoice: Invoice, details: PaymentDetails, isVATPayer: Bool) -> URL? {
        let document = InvoiceDocument(invoice: invoice, details: details, isVATPayer: isVATPayer)
            .frame(width: pageSize.width, height: pageSize.height)
        let renderer = ImageRenderer(content: document)
        let safeNumber = String(invoice.number.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "_" })
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Рахунок \(safeNumber).pdf")
        var rendered = false
        renderer.render { _, draw in
            var box = CGRect(origin: .zero, size: pageSize)
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            rendered = true
        }
        return rendered ? url : nil
    }
}

/// Сторінка рахунку. Кольори фіксовані чорні: документ друкують і пересилають.
struct InvoiceDocument: View {
    let invoice: Invoice
    let details: PaymentDetails
    let isVATPayer: Bool

    private let ink = Color.black
    private let muted = Color(white: 0.4)
    private let line = Color(white: 0.75)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Рахунок на оплату")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                    Text("№ \(invoice.number) від \(invoice.issueDate.numericUkrainian)")
                        .font(.system(size: 12))
                        .foregroundStyle(muted)
                }
                Spacer()
                if let qr {
                    VStack(spacing: 4) {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 92, height: 92)
                        Text("Скануйте для оплати")
                            .font(.system(size: 7))
                            .foregroundStyle(muted)
                    }
                }
            }

            HStack(alignment: .top, spacing: 24) {
                party("Постачальник", [
                    details.fullName,
                    details.taxID.isEmpty ? "" : "РНОКПП \(details.taxID)",
                    details.iban.isEmpty ? "" : "IBAN \(PaymentQR.normalizedIBAN(details.iban))",
                    details.bankName
                ])
                party("Платник", [
                    invoice.clientName,
                    invoice.clientCode.isEmpty ? "" : "Код \(invoice.clientCode)"
                ])
            }

            table

            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Разом до сплати: \(invoice.total.uahExact)")
                        .font(.system(size: 14, weight: .bold))
                    Text(isVATPayer ? "у тому числі ПДВ 20%: \((invoice.total / 6).uahExact)" : "Без ПДВ")
                        .font(.system(size: 10))
                        .foregroundStyle(muted)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Сплатити до \(invoice.dueDate.numericUkrainian).")
                Text("Призначення платежу: \(invoice.purpose)" + (isVATPayer ? "" : ", без ПДВ") + ".")
            }
            .font(.system(size: 10))

            Spacer()

            HStack(alignment: .bottom, spacing: 12) {
                Text("Постачальник")
                    .font(.system(size: 10))
                    .foregroundStyle(muted)
                Rectangle().fill(ink).frame(width: 160, height: 0.5)
                Text(details.fullName)
                    .font(.system(size: 10))
            }
        }
        .padding(48)
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private var qr: UIImage? {
        guard details.isComplete, invoice.paidDate == nil else { return nil }
        return PaymentQR.image(for: PaymentQR.link(recipient: details.fullName, iban: details.iban,
                                                   amount: invoice.total, code: details.taxID,
                                                   purpose: invoice.purpose), side: 368)
    }

    private func party(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(muted)
            ForEach(Array(lines.filter { !$0.isEmpty }.enumerated()), id: \.offset) { _, line in
                Text(line).font(.system(size: 10))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var table: some View {
        VStack(spacing: 0) {
            row(["№", "Товар або послуга", "К-сть", "Ціна", "Сума"], header: true)
            Rectangle().fill(ink).frame(height: 0.8)
            ForEach(Array(invoice.items.enumerated()), id: \.element.id) { index, item in
                row(["\(index + 1)", item.title, item.quantity.quantityText, item.price.uahExact, item.total.uahExact], header: false)
                Rectangle().fill(line).frame(height: 0.5)
            }
        }
    }

    private func row(_ cells: [String], header: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(cells[0]).frame(width: 18, alignment: .leading)
            Text(cells[1]).frame(maxWidth: .infinity, alignment: .leading)
            Text(cells[2]).frame(width: 40, alignment: .trailing)
            Text(cells[3]).frame(width: 80, alignment: .trailing)
            Text(cells[4]).frame(width: 86, alignment: .trailing)
        }
        .font(.system(size: 10, weight: header ? .semibold : .regular))
        .monospacedDigit()
        .padding(.vertical, 6)
    }
}
