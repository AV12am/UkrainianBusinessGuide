//
//  StartupGuideView.swift
//  UkrainianBusinessGuide
//
//  «Плануєте відкрити свою справу? Ми вам допоможемо»: покроковий план з прогресом.
//

import SwiftUI

struct StartupGuideView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var expanded: Set<String> = []

    private var doneCount: Int {
        StartupGuide.steps.filter { store.completedGuideSteps.contains($0.id) }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Плануєте відкрити свою справу?")
                        .font(.display(30, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Ми вам допоможемо. Ось усі кроки від ідеї до першої сплати податків. Позначайте виконані, щоб бачити, що лишилося.")
                        .font(.body)
                        .foregroundStyle(Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Виконано \(doneCount) з \(StartupGuide.steps.count)")
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Meter(value: Double(doneCount) / Double(StartupGuide.steps.count), tint: Theme.accent, height: 4)
                }

                VStack(spacing: 0) {
                    Rule(color: Theme.ink.opacity(0.85))
                    ForEach(Array(StartupGuide.steps.enumerated()), id: \.element.id) { index, step in
                        stepRow(step, number: index + 1)
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 12)
        }
    }

    private func stepRow(_ step: GuideStep, number: Int) -> some View {
        let isDone = store.completedGuideSteps.contains(step.id)
        let isExpanded = expanded.contains(step.id)

        return VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text("\(number)")
                    .font(.display(17))
                    .monospacedDigit()
                    .foregroundStyle(isDone ? Theme.inkMuted : Theme.accent)
                    .frame(width: 22, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            if isExpanded { expanded.remove(step.id) } else { expanded.insert(step.id) }
                        }
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            Text(step.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(isDone ? Theme.inkMuted : Theme.ink)
                                .strikethrough(isDone, color: Theme.inkMuted)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.footnote)
                                .foregroundStyle(Theme.inkMuted)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if isExpanded || !isDone {
                        Text(step.summary)
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if isExpanded {
                        ForEach(step.tips, id: \.self) { tip in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Rectangle().fill(Theme.accent).frame(width: 2, height: 12)
                                Text(tip)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if let link = step.link {
                            Button(link.title) { openURL(link.url) }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }

                Button {
                    withAnimation { store.toggleGuideStep(step.id) }
                } label: {
                    Image(systemName: isDone ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(isDone ? Theme.positive : Theme.inkMuted)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: isDone)
                .accessibilityLabel(isDone ? "Позначити як невиконаний" : "Позначити як виконаний")
            }
            .padding(.vertical, 14)
            Rule()
        }
    }
}

/// Гайд в окремому аркуші (з онбордингу).
struct StartupGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            StartupGuideView()
                .screenBackground()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Готово") { dismiss() }
                    }
                }
        }
        .tint(Theme.accent)
    }
}

#Preview {
    StartupGuideView()
        .environment(AppStore.preview)
}
