//
//  OnboardingView.swift
//  UkrainianBusinessGuide
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var step = 0
    @State private var draft = BusinessProfile.empty

    private let stepsCount = 3

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 12)

            TabView(selection: $step) {
                welcome.tag(0)
                businessStep.tag(1)
                financeStep.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: step)

            controls
                .padding(Theme.gutter)
        }
        .background(Theme.paper.ignoresSafeArea())
    }

    // MARK: - Кроки

    private var header: some View {
        HStack {
            Eyebrow("Бізнес Компас", color: Theme.ink)
            Spacer()
            Text("\(step + 1) / \(stepsCount)")
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(Theme.inkMuted)
        }
    }

    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Облік, податки й рішення для ФОП.")
                        .font(.display(38, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Додаєте доходи й витрати — застосунок рахує податки, нагадує про строки та показує, як рішення вплинуть на прибуток.")
                        .font(.body)
                        .foregroundStyle(Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 36)

                VStack(alignment: .leading, spacing: 0) {
                    Rule(color: Theme.ink.opacity(0.85))
                    feature("01", "Стан бізнесу", "Запас грошей, маржа, динаміка й податкові ризики в одному місці.")
                    feature("02", "Податки ФОП", "Єдиний податок, військовий збір, ЄСВ, ліміт групи та календар строків.")
                    feature("03", "Що якщо", "Порахуйте наслідки підвищення цін, найму чи нових витрат до рішення.")
                    feature("04", "Програми підтримки", "Гранти й пільгові кредити, що підходять саме вашому профілю.")
                }
            }
            .padding(.horizontal, Theme.gutter)
        }
    }

    private func feature(_ number: String, _ title: String, _ text: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(number)
                    .font(.display(15))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text(text).font(.subheadline).foregroundStyle(Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            Rule()
        }
    }

    private var businessStep: some View {
        Form {
            Section {
                TextField("Ваше ім'я", text: $draft.ownerName)
                    .textContentType(.givenName)
                TextField("Назва бізнесу", text: $draft.businessName)
            } header: {
                stepTitle("Про вас")
            }
            Section("Галузь") {
                Picker("Галузь", selection: $draft.industry) {
                    ForEach(Industry.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
            }
            Section {
                Picker("Група ФОП", selection: $draft.fopGroup) {
                    ForEach(FOPGroup.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if draft.fopGroup == .third {
                    Toggle("Платник ПДВ (ставка 3%)", isOn: $draft.isVATPayer)
                }
            } header: {
                Text("Оподаткування")
            } footer: {
                Text(draft.fopGroup.subtitle)
            }
            Section("Особливі статуси — для підбору програм") {
                ForEach(FounderStatus.allCases) { status in
                    Toggle(status.title, isOn: Binding(
                        get: { draft.statuses.contains(status) },
                        set: { isOn in
                            if isOn { draft.statuses.insert(status) } else { draft.statuses.remove(status) }
                        }
                    ))
                }
            }
        }
        .screenBackground()
    }

    private var financeStep: some View {
        Form {
            Section {
                LabeledContent("Гроші на рахунку") {
                    TextField("0", value: $draft.startingCash, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Постійні витрати на місяць") {
                    TextField("0", value: $draft.monthlyFixedCosts, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                Stepper("Працівників: \(draft.employees)", value: $draft.employees, in: 0...500)
            } header: {
                stepTitle("Стартові цифри, ₴")
            } footer: {
                Text("Дані зберігаються лише на цьому пристрої. Змінити їх можна в налаштуваннях.")
            }

            Section {
                Button("Відкрити з прикладом — кав'ярня «Зерно»") {
                    store.loadDemo()
                }
            } footer: {
                Text("Шість місяців вигаданих операцій, щоб побачити всі розділи з даними.")
            }
        }
        .screenBackground()
    }

    private func stepTitle(_ text: String) -> some View {
        Text(text)
            .font(.display(26, weight: .bold))
            .foregroundStyle(Theme.ink)
            .textCase(nil)
            .padding(.bottom, 6)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Назад") { step -= 1 }
                    .buttonStyle(.outline)
            }
            Button(step == stepsCount - 1 ? "Почати" : "Далі") {
                if step < stepsCount - 1 {
                    step += 1
                } else {
                    var profile = draft
                    if profile.businessName.trimmingCharacters(in: .whitespaces).isEmpty {
                        profile.businessName = "Мій бізнес"
                    }
                    profile.createdAt = .now
                    store.saveProfile(profile)
                }
            }
            .buttonStyle(.primary)
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppStore(fileURL: nil))
}
