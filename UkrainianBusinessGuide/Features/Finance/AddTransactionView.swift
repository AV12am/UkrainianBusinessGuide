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

                    TextField("0 ₴", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(kind == .income ? Theme.mint : Theme.coral)
                        .focused($amountFocused)
                        .listRowBackground(Color.clear)
                }

                Section("Категорія") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                        ForEach(TransactionCategory.categories(for: kind)) { item in
                            Button {
                                category = item
                            } label: {
                                VStack(spacing: 6) {
                                    IconBadge(systemName: item.icon, tint: category == item ? .white : Theme.skyBlue, size: 44)
                                        .background(category == item ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Color.clear), in: Circle())
                                    Text(item.title)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
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
                }
            }
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
                    .fontWeight(.bold)
                }
            }
            .onChange(of: kind) { _, newKind in
                category = TransactionCategory.categories(for: newKind).first ?? .otherIncome
            }
            .onAppear { amountFocused = true }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    AddTransactionView()
        .environment(AppStore.preview)
}
