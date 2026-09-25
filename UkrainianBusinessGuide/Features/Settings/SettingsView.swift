//
//  SettingsView.swift
//  UkrainianBusinessGuide
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft = BusinessProfile.empty
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Профіль") {
                    TextField("Ім'я", text: $draft.ownerName)
                    TextField("Назва бізнесу", text: $draft.businessName)
                    Picker("Галузь", selection: $draft.industry) {
                        ForEach(Industry.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
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
            .navigationTitle("Налаштування")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Зберегти") {
                        store.saveProfile(draft)
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
                Text("Профіль, операції та позначки податкових строків буде видалено безповоротно.")
            }
            .onAppear {
                if let profile = store.profile { draft = profile }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppStore.preview)
}
