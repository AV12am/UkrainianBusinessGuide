//
//  InvoicesView.swift
//  UkrainianBusinessGuide
//
//  Рахунки клієнтам: хто скільки винен, що прострочено, PDF із QR-кодом оплати.
//

import SwiftUI

struct InvoicesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Invoice?
    @State private var showDetails = false

    private var open: [Invoice] { store.invoices.filter { $0.paidDate == nil } }
    private var paid: [Invoice] { store.invoices.filter { $0.paidDate != nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    summary
                    if !store.paymentDetails.isComplete {
                        detailsNote
                    }
                    section("Очікують оплати", invoices: open,
                            empty: "Неоплачених рахунків немає. Новий рахунок створюється кнопкою «+» угорі.")
                    if !paid.isEmpty {
                        section("Оплачені", invoices: paid, empty: "")
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .navigationTitle("Рахунки")
            .navigationDestination(for: UUID.self) { InvoiceDetailView(invoiceID: $0) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрити") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = newInvoice()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Новий рахунок")
                }
            }
            .sheet(item: $editing) { InvoiceEditorView(invoice: $0) }
            .sheet(isPresented: $showDetails) { PaymentDetailsView() }
        }
        .tint(Theme.accent)
    }

    private var summary: some View {
        let overdue = store.overdueInvoices
        return VStack(alignment: .leading, spacing: 4) {
            Eyebrow("Вам винні клієнти")
            Text(store.receivables.uah)
                .font(.display(44, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if !overdue.isEmpty {
                Text("Прострочені рахунки: \(overdue.count), на суму \(overdue.reduce(0) { $0 + $1.total }.uah)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.negative)
            }
        }
    }

    private var detailsNote: some View {
        Button {
            showDetails = true
        } label: {
            LinkRowLabel(title: "Заповніть реквізити",
                         text: "ПІБ, РНОКПП та IBAN потрібні, щоб у рахунку з'явився QR-код для оплати.")
        }
        .buttonStyle(.plain)
    }

    private func section(_ title: String, invoices: [Invoice], empty: String) -> some View {
        LedgerSection(title: title) {
            if invoices.isEmpty {
                EmptyNote(text: empty)
            }
            ForEach(invoices) { invoice in
                NavigationLink(value: invoice.id) {
                    InvoiceRow(invoice: invoice)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func newInvoice() -> Invoice {
        let today = Calendar.kyiv.startOfDay(for: .now)
        return Invoice(number: store.nextInvoiceNumber, clientName: "", clientCode: "",
                       items: [InvoiceItem(title: "", quantity: 1, price: 0)],
                       issueDate: today,
                       dueDate: Calendar.kyiv.date(byAdding: .day, value: 7, to: today) ?? today)
    }
}

extension Invoice {
    var statusText: String {
        switch status() {
        case .paid:
            return "оплачено " + (paidDate?.numericUkrainian ?? "")
        case .overdue:
            let days = Calendar.kyiv.dateComponents([.day], from: dueDate, to: Calendar.kyiv.startOfDay(for: .now)).day ?? 0
            return "прострочено на \(days) дн."
        case .unpaid:
            return "сплатити до \(dueDate.shortUkrainian)"
        case .draft:
            return "чернетка"
        }
    }

    var statusColor: Color {
        switch status() {
        case .overdue: return Theme.negative
        case .paid: return Theme.positive
        default: return Theme.inkMuted
        }
    }
}

struct InvoiceRow: View {
    let invoice: Invoice

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(invoice.clientName.isEmpty ? "Клієнта не вказано" : invoice.clientName)
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text("№ \(invoice.number), \(invoice.statusText)")
                        .font(.footnote)
                        .foregroundStyle(invoice.statusColor)
                }
                Spacer(minLength: 8)
                Text(invoice.total.uah)
                    .font(.body)
                    .monospacedDigit()
                    .foregroundStyle(invoice.paidDate == nil ? Theme.ink : Theme.inkMuted)
            }
            .padding(.vertical, 12)
            Rule()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Картка рахунку

struct InvoiceDetailView: View {
    let invoiceID: UUID

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL: URL?
    @State private var editing: Invoice?
    @State private var showDetails = false
    @State private var confirmDelete = false

    private struct RenderKey: Equatable {
        let invoice: Invoice
        let details: PaymentDetails
    }

    private var invoice: Invoice? { store.invoices.first { $0.id == invoiceID } }

    var body: some View {
        ScrollView {
            if let invoice {
                content(invoice)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 32)
            }
        }
        .screenBackground()
        .navigationTitle(invoice.map { "№ \($0.number)" } ?? "Рахунок")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Редагувати", systemImage: "pencil") { editing = invoice }
                    Button("Реквізити", systemImage: "building.columns") { showDetails = true }
                    Button("Видалити", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $editing) { InvoiceEditorView(invoice: $0) }
        .sheet(isPresented: $showDetails) { PaymentDetailsView() }
        .confirmationDialog("Видалити рахунок?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Видалити", role: .destructive) {
                if let invoice { store.delete(invoice) }
                dismiss()
            }
        } message: {
            Text("Якщо рахунок позначено оплаченим, запис про дохід теж буде видалено.")
        }
        .task(id: invoice.map { RenderKey(invoice: $0, details: store.paymentDetails) }) {
            guard let invoice else { return }
            pdfURL = InvoicePDF.render(invoice, details: store.paymentDetails, isVATPayer: store.profile?.isVATPayer ?? false)
        }
    }

    private func content(_ invoice: Invoice) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(invoice.statusText.capitalizedFirstLetter, color: invoice.statusColor)
                Text(invoice.total.uahExact)
                    .font(.display(40, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(invoice.clientName.isEmpty ? "Клієнта не вказано" : invoice.clientName)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkMuted)
            }
            .padding(.top, 8)

            LedgerSection(title: "Позиції") {
                ForEach(invoice.items) { item in
                    LedgerRow(label: item.title.isEmpty ? "Без назви" : item.title,
                              value: item.total.uahExact,
                              detail: "\(item.quantity.quantityText) × \(item.price.uahExact)")
                }
                LedgerRow(label: "Разом", value: invoice.total.uahExact, emphasized: true, showsRule: false)
            }

            LedgerSection(title: "Строки") {
                LedgerRow(label: "Виставлено", value: invoice.issueDate.numericUkrainian)
                LedgerRow(label: "Сплатити до", value: invoice.dueDate.numericUkrainian,
                          showsRule: invoice.paidDate != nil)
                if let paidDate = invoice.paidDate {
                    LedgerRow(label: "Оплачено", value: paidDate.numericUkrainian, showsRule: false)
                }
            }

            qrBlock(invoice)

            VStack(spacing: 10) {
                if let pdfURL {
                    ShareLink(item: pdfURL) {
                        Text("Надіслати PDF")
                    }
                    .buttonStyle(.primary)
                }
                Button(invoice.paidDate == nil ? "Позначити оплаченим" : "Скасувати оплату") {
                    withAnimation { store.togglePaid(invoice) }
                }
                .buttonStyle(.outline)
                .frame(maxWidth: .infinity)
                Text(invoice.paidDate == nil
                     ? "Після оплати сума автоматично з'явиться в доходах."
                     : "Дохід за цим рахунком уже записано в журнал операцій.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func qrBlock(_ invoice: Invoice) -> some View {
        let details = store.paymentDetails
        if details.isComplete, invoice.paidDate == nil,
           let image = PaymentQR.image(for: PaymentQR.link(recipient: details.fullName, iban: details.iban,
                                                          amount: invoice.total, code: details.taxID,
                                                          purpose: invoice.purpose)) {
            LedgerSection(title: "QR-код для оплати") {
                HStack(alignment: .top, spacing: 16) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 132, height: 132)
                        .padding(8)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Клієнт наводить камеру телефона на код, і банк відкриває платіж із вже заповненими реквізитами й сумою.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                        Text("Формат НБУ, працює з monobank, Приват24, Ощад 24/7 та іншими банками.")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
                .padding(.vertical, 14)
            }
        } else if !details.isComplete {
            Button {
                showDetails = true
            } label: {
                LinkRowLabel(title: "Додати QR-код для оплати",
                             text: "Заповніть реквізити: ПІБ, РНОКПП та IBAN.")
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Редактор

struct InvoiceEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Invoice

    init(invoice: Invoice) {
        _draft = State(initialValue: invoice)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Клієнт") {
                    TextField("Назва або ПІБ", text: $draft.clientName)
                        .textContentType(.organizationName)
                    TextField("ЄДРПОУ або РНОКПП, необов'язково", text: $draft.clientCode)
                        .keyboardType(.numberPad)
                }
                Section {
                    ForEach($draft.items) { $item in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Товар або послуга", text: $item.title)
                            HStack {
                                TextField("К-сть", value: $item.quantity, format: .number)
                                    .keyboardType(.decimalPad)
                                    .frame(maxWidth: 70)
                                Text("×").foregroundStyle(Theme.inkMuted)
                                TextField("Ціна", value: $item.price, format: .number)
                                    .keyboardType(.decimalPad)
                                Spacer()
                                Text(item.total.uah)
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.inkMuted)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { draft.items.remove(atOffsets: $0) }
                    Button("Додати позицію") {
                        draft.items.append(InvoiceItem(title: "", quantity: 1, price: 0))
                    }
                } header: {
                    Text("Позиції")
                } footer: {
                    Text("Разом: \(draft.total.uahExact)")
                }
                Section("Рахунок") {
                    TextField("Номер", text: $draft.number)
                    DatePicker("Дата", selection: $draft.issueDate, displayedComponents: .date)
                    DatePicker("Сплатити до", selection: $draft.dueDate, in: draft.issueDate..., displayedComponents: .date)
                }
            }
            .screenBackground()
            .navigationTitle(store.invoices.contains { $0.id == draft.id } ? "Рахунок № \(draft.number)" : "Новий рахунок")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Зберегти") {
                        draft.items.removeAll { $0.title.trimmingCharacters(in: .whitespaces).isEmpty && $0.total == 0 }
                        store.save(draft)
                        dismiss()
                    }
                    .disabled(draft.clientName.trimmingCharacters(in: .whitespaces).isEmpty || draft.total <= 0)
                    .fontWeight(.semibold)
                }
            }
        }
        .tint(Theme.accent)
    }
}

// MARK: - Реквізити

struct PaymentDetailsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft = PaymentDetails()

    var body: some View {
        NavigationStack {
            Form {
                PaymentDetailsFields(details: $draft)
            }
            .screenBackground()
            .navigationTitle("Реквізити")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Зберегти") {
                        store.savePaymentDetails(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { draft = store.paymentDetails }
        }
        .tint(Theme.accent)
    }
}

/// Поля реквізитів — спільні для налаштувань і рахунків.
struct PaymentDetailsFields: View {
    @Binding var details: PaymentDetails

    var body: some View {
        Section {
            TextField("ФОП Прізвище Ім'я По батькові", text: $details.fullName)
                .textContentType(.name)
            TextField("РНОКПП", text: $details.taxID)
                .keyboardType(.numberPad)
            TextField("IBAN, UA…", text: $details.iban)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            TextField("Банк", text: $details.bankName)
        } header: {
            Text("Реквізити для рахунків")
        } footer: {
            if !details.iban.isEmpty && PaymentQR.normalizedIBAN(details.iban).count != 29 {
                Text("Український IBAN містить 29 символів: UA і 27 цифр.")
                    .foregroundStyle(Theme.negative)
            } else {
                Text("Потрапляють у PDF рахунку та QR-код для оплати. Зберігаються лише на пристрої.")
            }
        }
    }
}
