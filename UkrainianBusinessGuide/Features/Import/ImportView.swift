//
//  ImportView.swift
//  UkrainianBusinessGuide
//
//  Імпорт операцій: автоматично з monobank за особистим токеном або з файлу CSV будь-якого банку.
//  Перед додаванням показуємо, що саме буде записано; дублікати пропускаються.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var token = ""
    @State private var hasToken = Keychain.get(MonobankClient.tokenKey) != nil
    @State private var accounts: [MonobankClient.Account] = []
    @State private var isLoading = false
    @State private var showFilePicker = false
    @State private var pending: [ImportedOperation] = []
    /// Операції, які користувач вирішив не додавати (і перекази між своїми рахунками за замовчуванням).
    @State private var excluded: Set<String> = []
    @State private var source = ""
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Text("Операції з банку потрапляють у журнал разом із категоріями. Податки, ліміт і прогнози одразу рахуються з нових даних.")
                        .font(.body)
                        .foregroundStyle(Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    if let message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(isError ? Theme.negative : Theme.positive)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if pending.isEmpty {
                        monobank
                        csv
                    } else {
                        preview
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .navigationTitle("Імпорт з банку")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрити") { dismiss() }
                }
            }
            .fileImporter(isPresented: $showFilePicker,
                          allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .text]) { result in
                handleFile(result)
            }
        }
        .tint(Theme.accent)
    }

    // MARK: - monobank

    private var monobank: some View {
        LedgerSection(title: "monobank") {
            VStack(alignment: .leading, spacing: 14) {
                if hasToken {
                    if accounts.count > 1 {
                        Picker("Рахунок", selection: Binding(
                            get: { store.monobankAccountID ?? accounts.first?.id ?? "" },
                            set: { store.setMonobankAccount($0) }
                        )) {
                            ForEach(accounts) { Text($0.title).tag($0.id) }
                        }
                    }
                    Text(syncStatus)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkMuted)
                    Button(isLoading ? "Завантажуємо…" : "Отримати операції за 31 день") {
                        Task { await syncMonobank() }
                    }
                    .buttonStyle(.primary)
                    .disabled(isLoading)
                    Button("Від'єднати monobank") {
                        Keychain.set(nil, for: MonobankClient.tokenKey)
                        store.setMonobankAccount(nil)
                        hasToken = false
                        accounts = []
                    }
                    .buttonStyle(.outline)
                } else {
                    Text("Застосунок отримує виписку напряму з monobank. Токен дає доступ лише на читання, зберігається в Keychain і нікуди не передається.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 6) {
                        step(1, "Відкрийте api.monobank.ua і підтвердьте вхід у застосунку monobank.")
                        step(2, "Скопіюйте токен і вставте його нижче.")
                    }
                    Button("Відкрити api.monobank.ua") {
                        if let url = URL(string: "https://api.monobank.ua/") { openURL(url) }
                    }
                    .buttonStyle(.outline)
                    SecureField("Токен", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.rule))
                    Button(isLoading ? "Підключаємо…" : "Підключити") {
                        Task { await connectMonobank() }
                    }
                    .buttonStyle(.primary)
                    .disabled(isLoading || token.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.vertical, 14)
        }
    }

    private var syncStatus: String {
        guard let last = store.lastBankSync else { return "Підключено. Виписку ще не завантажували." }
        return "Підключено. Останнє оновлення \(last.shortUkrainian), \(last.formatted(Date.FormatStyle.kyiv.hour().minute()))."
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.display(15))
                .foregroundStyle(Theme.accent)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func connectMonobank() async {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        isLoading = true
        defer { isLoading = false }
        do {
            let found = try await MonobankClient(token: value).accounts()
            Keychain.set(value, for: MonobankClient.tokenKey)
            accounts = found
            store.setMonobankAccount(found.first?.id)
            hasToken = true
            token = ""
            show("Підключено: \(found.first?.title ?? "рахунок"). Виписку можна отримати через хвилину, так monobank обмежує частоту запитів.", error: false)
        } catch {
            show(error.localizedDescription, error: true)
        }
    }

    private func syncMonobank() async {
        guard let saved = Keychain.get(MonobankClient.tokenKey) else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let client = MonobankClient(token: saved)
            var accountID = store.monobankAccountID
            if accountID == nil {
                let found = try await client.accounts()
                accounts = found
                accountID = found.first?.id
                store.setMonobankAccount(accountID)
            }
            guard let accountID else { return }
            let operations = try await client.statement(account: accountID)
            store.markBankSynced()
            present(operations, from: "monobank")
        } catch {
            show(error.localizedDescription, error: true)
        }
    }

    // MARK: - CSV

    private var csv: some View {
        LedgerSection(title: "Файл виписки") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Виписка у форматі CSV з будь-якого банку: Приват24, ПУМБ, Ощадбанк, Райффайзен, monobank. Дату, суму й призначення платежу застосунок знайде сам.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Обрати файл") { showFilePicker = true }
                    .buttonStyle(.outline)
            }
            .padding(.vertical, 14)
        }
    }

    private func handleFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let operations = try BankStatementParser.parse(try Data(contentsOf: url))
            present(operations, from: url.lastPathComponent)
        } catch {
            show(error.localizedDescription, error: true)
        }
    }

    // MARK: - Перегляд перед додаванням

    private func present(_ operations: [ImportedOperation], from origin: String) {
        let fresh = store.newOperations(operations)
        if fresh.isEmpty {
            show("Нових операцій немає: усі \(operations.count) вже є в журналі.", error: false)
        } else {
            message = nil
            source = origin
            excluded = Set(fresh.filter(\.isLikelyOwnTransfer).map(\.externalID))
            withAnimation { pending = fresh }
        }
    }

    private var included: [ImportedOperation] {
        pending.filter { !excluded.contains($0.externalID) }
    }

    private var preview: some View {
        let chosen = included
        let income = chosen.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let expense = chosen.filter { $0.amount < 0 }.reduce(0) { $0 - $1.amount }
        return VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow("Нові операції з \(source)")
                Text("\(chosen.count) з \(pending.count)")
                    .font(.display(44, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("Надходження \(income.uah), списання \(expense.uah)")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(Theme.inkMuted)
                Text("Натисніть на операцію, щоб не додавати її. Перекази між власними рахунками вже вимкнено: це не дохід.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            HStack(spacing: 10) {
                Button("Скасувати") { withAnimation { pending = []; excluded = [] } }
                    .buttonStyle(.outline)
                Button("Додати в журнал") {
                    let added = store.importOperations(included)
                    withAnimation { pending = []; excluded = [] }
                    show("Додано операцій: \(added). Категорії підібрано автоматично, змінити категорію можна довгим натисканням на операцію у «Фінансах».", error: false)
                }
                .buttonStyle(.primary)
                .disabled(chosen.isEmpty)
            }
            VStack(spacing: 0) {
                Rule(color: Theme.ink.opacity(0.85))
                ForEach(pending.prefix(100)) { operation in
                    let isOn = !excluded.contains(operation.externalID)
                    Button {
                        if isOn { excluded.insert(operation.externalID) } else { excluded.remove(operation.externalID) }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                                .foregroundStyle(isOn ? Theme.accent : Theme.inkMuted)
                            TransactionRow(transaction: operation.transaction)
                                .opacity(isOn ? 1 : 0.45)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel((isOn ? "Буде додано: " : "Не додавати: ") + operation.description)
                }
                if pending.count > 100 {
                    EmptyNote(text: "Ще \(pending.count - 100) операцій буде додано разом з показаними.")
                }
            }
        }
    }

    private func show(_ text: String, error: Bool) {
        withAnimation {
            message = text
            isError = error
        }
    }
}
