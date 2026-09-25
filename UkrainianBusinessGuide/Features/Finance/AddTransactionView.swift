//
//  AddTransactionView.swift
//  UkrainianBusinessGuide
//

import SwiftUI

struct AddTransactionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var kind: TransactionKind = .income
    @State private var amount: Double?
    @State private var category: TransactionCategory = .sales
    @State private var date = Date.now
    @State private var note = ""
    @FocusState private var amountFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Тип", selection: $kind) {
                        ForEach(TransactionKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TextField("0", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.display(44, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                            .focused($amountFocused)
                        Text("₴")
                            .font(.display(28))
                            .foregroundStyle(Theme.inkMuted)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 0, trailing: 0))
                }

                Section("Категорія") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(TransactionCategory.categories(for: kind)) { item in
                            let isSelected = category == item
                            Button {
                                category = item
                            } label: {
                                Text(item.title)
                                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                    .foregroundStyle(isSelected ? Theme.paper : Theme.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background {
                                        if isSelected {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.ink)
                                        } else {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.rule)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                    TextField("Коментар", text: $note)
                } footer: {
                    if kind == .income, let rate = store.reserveRate, let amount, amount > 0 {
                        Text("Відкладіть ≈ \((amount * rate).uah) на податки: \(rate.percent) від доходу.")
                    }
                }
            }
            .screenBackground()
            .navigationTitle("Нова операція")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Зберегти") {
                        guard let amount, amount > 0 else { return }
                        store.add(Transaction(date: date, amount: amount, category: category, note: note))
                        dismiss()
                    }
                    .disabled((amount ?? 0) <= 0)
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: kind) { _, newKind in
                category = TransactionCategory.categories(for: newKind).first ?? .otherIncome
            }
            .onAppear { amountFocused = true }
        }
        .tint(Theme.accent)
    }
}

#Preview {
    AddTransactionView()
        .environment(AppStore.preview)
}
