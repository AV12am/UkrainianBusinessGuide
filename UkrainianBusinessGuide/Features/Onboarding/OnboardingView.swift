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
            progress
                .padding(.horizontal, 24)
                .padding(.top, 12)

            TabView(selection: $step) {
                welcome.tag(0)
                businessStep.tag(1)
                financeStep.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: step)

            controls
                .padding(24)
        }
        .background(AppBackground())
    }

    // MARK: - Кроки

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0..<stepsCount, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Color.primary.opacity(0.1)))
                    .frame(height: 5)
            }
        }
    }

    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ZStack {
                    Circle().fill(Theme.flag).frame(width: 120, height: 120)
                        .blur(radius: 30).opacity(0.7)
                    Image(systemName: "safari.fill")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundStyle(Theme.flag)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)

                Text("Бізнес Компас")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                Text("Персональний фінансовий директор, бухгалтер-нагадувач і бізнес-радник для ФОП — у кишені.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 16) {
                    feature("waveform.path.ecg", Theme.mint, "Пульс бізнесу", "Індекс здоров'я 0–100 з поясненнями")
                    feature("building.columns.fill", Theme.skyBlue, "Податки без стресу", "Калькулятор ФОП, ліміти та календар строків")
                    feature("slider.horizontal.3", Theme.violet, "Симулятор «Що якщо»", "Змоделюйте ціни, найм і витрати до рішення")
                    feature("sparkles", Theme.amber, "Гранти під вас", "Підбір програм з відсотком збігу")
                }
                .glassCard()
            }
            .padding(24)
        }
    }

    private var businessStep: some View {
        Form {
            Section("Про вас") {
                TextField("Ваше ім'я", text: $draft.ownerName)
                    .textContentType(.givenName)
                TextField("Назва бізнесу", text: $draft.businessName)
            }
            Section("Галузь") {
                Picker("Галузь", selection: $draft.industry) {
                    ForEach(Industry.allCases) { industry in
                        Label(industry.title, systemImage: industry.icon).tag(industry)
                    }
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
            Section("Особливі статуси (для підбору грантів)") {
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
        .scrollContentBackground(.hidden)
    }

    private var financeStep: some View {
        Form {
            Section {
                LabeledContent("Гроші на рахунку") {
                    TextField("0", value: $draft.startingCash, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Постійні витрати / міс") {
                    TextField("0", value: $draft.monthlyFixedCosts, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                Stepper("Працівників: \(draft.employees)", value: $draft.employees, in: 0...500)
            } header: {
                Text("Стартові цифри, ₴")
            } footer: {
                Text("Дані зберігаються лише на вашому пристрої. Їх можна змінити будь-коли в налаштуваннях.")
            }

            Section {
                Button {
                    store.loadDemo()
                } label: {
                    Label("Переглянути з демо-даними кав'ярні", systemImage: "cup.and.saucer.fill")
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button {
                    step -= 1
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 54, height: 54)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Назад")
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

    private func feature(_ icon: String, _ tint: Color, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            IconBadge(systemName: icon, tint: tint, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppStore(fileURL: nil))
}
