//
//  IdeaValidatorView.swift
//  UkrainianBusinessGuide
//

import SwiftUI

struct IdeaValidatorView: View {
    @State private var idea = ""
    @State private var ratings: [IdeaCriterion: Int] = Dictionary(uniqueKeysWithValues: IdeaCriterion.allCases.map { ($0, 3) })

    var body: some View {
        let evaluation = IdeaValidator.evaluate(ratings)
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                TextField("Ідея одним реченням", text: $idea, axis: .vertical)
                    .font(.display(22))
                    .lineLimit(1...4)
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) { Rule(color: Theme.ink.opacity(0.85)) }

                score(evaluation)

                LedgerSection(title: "Оцініть від 1 до 5") {
                    ForEach(IdeaCriterion.allCases) { criterion in
                        criterionRow(criterion)
                    }
                }

                if !evaluation.weakest.isEmpty {
                    LedgerSection(title: "Що посилити") {
                        ForEach(evaluation.weakest) { criterion in
                            InsightRow(insight: Insight(id: criterion.id, icon: "", title: criterion.title,
                                                        message: criterion.advice, severity: .warning))
                            Rule()
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func score(_ evaluation: IdeaEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(evaluation.score)")
                    .font(.display(56, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("зі 100")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkMuted)
            }
            Text(evaluation.verdict)
                .font(.body)
                .foregroundStyle(Theme.ink)
            Meter(value: Double(evaluation.score) / 100, tint: Theme.color(forScore: Double(evaluation.score) / 100), height: 3)
                .padding(.top, 6)
        }
        .animation(.easeOut(duration: 0.25), value: evaluation)
    }

    private func criterionRow(_ criterion: IdeaCriterion) -> some View {
        let value = ratings[criterion] ?? 3
        return VStack(alignment: .leading, spacing: 10) {
            Text(criterion.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(criterion.question)
                .font(.subheadline)
                .foregroundStyle(Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { rating in
                    let isFilled = rating <= value
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { ratings[criterion] = rating }
                    } label: {
                        Text("\(rating)")
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(isFilled ? Theme.paper : Theme.inkMuted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background {
                                if isFilled {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.ink)
                                } else {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.rule)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(criterion.title): \(rating) з 5")
                }
            }
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Rule() }
        .sensoryFeedback(.selection, trigger: value)
    }
}

#Preview {
    IdeaValidatorView()
}
