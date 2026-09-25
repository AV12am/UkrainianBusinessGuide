//
//  SettingsView.swift
//  UkrainianBusinessGuide
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft = BusinessProfile.empty
    @State private var details = PaymentDetails()
    @State private var confirmReset = false
    @State private var backup: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var restoreData: Data?
    @State private var backupMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Профіль") {
                    TextField("Ім'я", text: $draft.ownerName)
                    TextField("Назва бізнесу", text: $draft.businessName)
                    Picker("Галузь", selection: $draft.industry) {
                        ForEach(Industry.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper("Працівників: \(draft.employees)", value: $draft.employees, in: 0...500)
                }
                Section("Оподаткування") {
                    Picker("Група ФОП", selection: $draft.fopGroup) {
                        ForEach(FOPGroup.allCases) { Text($0.title).tag($0) }
                    }
                    if draft.fopGroup == .third {
                        Toggle("Платник ПДВ", isOn: $draft.isVATPayer)
                    }
                }
                Section("Фінанси, ₴") {
                    LabeledContent("Початковий залишок") {
                        TextField("0", value: $draft.startingCash, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Постійні витрати / міс") {
                        TextField("0", value: $draft.monthlyFixedCosts, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                PaymentDetailsFields(details: $details)
                Section {
                    Toggle("Вхід через \(AppLock.methodName)", isOn: Binding(
                        get: { store.lockEnabled },
                        set: { newValue in Task { await setLock(newValue) } }
                    ))
                    .disabled(!AppLock.isAvailable && !store.lockEnabled)
                } header: {
                    Text("Безпека")
                } footer: {
                    Text(AppLock.isAvailable
                         ? "Застосунок блокується, коли ви з нього виходите, і приховує дані в перемикачі програм."
                         : "Увімкніть код-пароль на пристрої, щоб захистити дані.")
                }
                Section {
                    Button("Зберегти резервну копію") { exportBackup() }
                    Button("Відновити з копії") { showImporter = true }
                } header: {
                    Text("Резервна копія")
                } footer: {
                    Text(backupMessage ?? "Файл з усіма даними. Збережіть його в iCloud Drive через «Файли», щоб перенести дані на новий телефон.")
                }
                Section("Статуси засновника") {
                    ForEach(FounderStatus.allCases) { status in
                        Toggle(status.title, isOn: Binding(
                            get: { draft.statuses.contains(status) },
                            set: { if $0 { draft.statuses.insert(status) } else { draft.statuses.remove(status) } }
                        ))
                    }
                }
                Section {
                    Button("Видалити всі дані", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Бізнес Компас зберігає дані лише на цьому пристрої.")
                }
            }
            .screenBackground()
            .navigationTitle("Налаштування")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Зберегти") {
                        store.saveProfile(draft)
                        if details != store.paymentDetails { store.savePaymentDetails(details) }
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .confirmationDialog("Видалити всі дані?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Видалити", role: .destructive) {
                    dismiss()
                    store.resetAll()
                }
            } message: {
                Text("Профіль, операції, рахунки та позначки податкових строків буде видалено безповоротно.")
            }
            .onAppear {
                if let profile = store.profile { draft = profile }
                details = store.paymentDetails
            }
            .fileExporter(isPresented: $showExporter, document: backup, contentType: .json,
                          defaultFilename: "Бізнес Компас \(Date.now.numericUkrainian)") { result in
                if case .success = result { backupMessage = "Копію збережено." }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                guard let url = try? result.get() else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                restoreData = try? Data(contentsOf: url)
            }
            .confirmationDialog("Замінити поточні дані копією?", isPresented: Binding(
                get: { restoreData != nil },
                set: { if !$0 { restoreData = nil } }
            ), titleVisibility: .visible) {
                Button("Відновити", role: .destructive) { restore() }
            } message: {
                Text("Профіль, операції й рахунки на цьому пристрої буде замінено даними з файлу.")
            }
        }
        .tint(Theme.accent)
    }

    private func setLock(_ enabled: Bool) async {
        // Перед увімкненням перевіряємо, що людина справді може розблокувати пристрій.
        if enabled {
            guard await AppLock.authenticate(reason: "Увімкнути захист даних") else { return }
        }
        store.setLockEnabled(enabled)
    }

    private func exportBackup() {
        do {
            backup = BackupDocument(data: try store.backupData())
            showExporter = true
        } catch {
            backupMessage = "Не вдалося створити копію: \(error.localizedDescription)"
        }
    }

    private func restore() {
        guard let data = restoreData else { return }
        restoreData = nil
        do {
            try store.restoreBackup(from: data)
            if let profile = store.profile { draft = profile }
            details = store.paymentDetails
            backupMessage = "Дані відновлено з копії."
        } catch {
            backupMessage = "Файл не схожий на копію Бізнес Компаса."
        }
    }
}

/// JSON-файл резервної копії для системного діалогу збереження.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    SettingsView()
        .environment(AppStore.preview)
}
