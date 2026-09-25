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
            VStack(alignment: .leading, spacing: 16) {
                TextField("Опишіть ідею одним реченням", text: $idea, axis: .vertical)
                    .lineLimit(2...4)
                    .glassCard()

                scoreCard(evaluation)

                ForEach(IdeaCriterion.allCases) { criterion in
                    criterionRow(criterion)
                }

                if !evaluation.weakest.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Що посилити").font(.headline)
                        ForEach(evaluation.weakest) { criterion in
                            HStack(alignment: .top, spacing: 12) {
                                IconBadge(systemName: criterion.icon, tint: Theme.amber, size: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(criterion.title).font(.subheadline.weight(.semibold))
                                    Text(criterion.advice).font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .glassCard()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func scoreCard(_ evaluation: IdeaEvaluation) -> some View {
        HStack(spacing: 18) {
            RingGauge(progress: Double(evaluation.score) / 100, lineWidth: 10) {
                Text("\(evaluation.score)")
                    .font(.title2.weight(.heavy))
                    .contentTransition(.numericText())
            }
            .frame(width: 80, height: 80)
            VStack(alignment: .leading, spacing: 4) {
                Text(idea.isEmpty ? "Потенціал ідеї" : idea)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(evaluation.verdict)
                    .font(.headline)
            }
        }
        .glassCard()
        .animation(.spring, value: evaluation)
    }

    private func criterionRow(_ criterion: IdeaCriterion) -> some View {
        let value = ratings[criterion] ?? 3
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(criterion.title, systemImage: criterion.icon)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(value)/5")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.color(forScore: Double(value - 1) / 4))
            }
            Text(criterion.question)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        withAnimation(.spring(response: 0.3)) { ratings[criterion] = rating }
                    } label: {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(rating <= value ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Color.primary.opacity(0.08)))
                            .frame(height: 30)
                            .overlay(Text("\(rating)").font(.caption.weight(.bold))
                                .foregroundStyle(rating <= value ? Color.white : Color.secondary))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(criterion.title): \(rating) з 5")
                }
            }
        }
        .glassCard()
        .sensoryFeedback(.selection, trigger: value)
    }
}

#Preview {
    IdeaValidatorView()
}
