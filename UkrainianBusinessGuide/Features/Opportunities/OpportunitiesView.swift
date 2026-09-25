//
//  OpportunitiesView.swift
//  UkrainianBusinessGuide
//

import SwiftUI

struct OpportunitiesView: View {
    @Environment(AppStore.self) private var store
    @State private var typeFilter: OpportunityType?
    @State private var selected: Opportunity?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    intro
                    FilterTabs(options: filterOptions, selection: $typeFilter)
                    VStack(spacing: 0) {
                        Rule(color: Theme.ink.opacity(0.85))
                        ForEach(ranked, id: \.opportunity.id) { item in
                            Button {
                                selected = item.opportunity
                            } label: {
                                OpportunityRow(opportunity: item.opportunity, match: item.match)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Умови програм змінюються. Перед подачею перевірте актуальну інформацію на офіційному сайті.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkMuted)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .navigationTitle("Підтримка")
            .sheet(item: $selected) { opportunity in
                OpportunityDetailView(opportunity: opportunity,
                                      match: store.profile.map { OpportunityCatalog.matchScore(opportunity, for: $0) } ?? 0)
            }
        }
    }

    private var filterOptions: [(title: String, value: OpportunityType?)] {
        var options: [(title: String, value: OpportunityType?)] = [(title: "Усі", value: nil)]
        options += OpportunityType.allCases.map { (title: $0.title, value: Optional($0)) }
        return options
    }

    private var ranked: [(opportunity: Opportunity, match: Double)] {
        guard let profile = store.profile else { return [] }
        return OpportunityCatalog.ranked(for: profile).filter { typeFilter == nil || $0.opportunity.type == typeFilter }
    }

    private var intro: some View {
        let strong = store.profile.map { profile in
            OpportunityCatalog.all.filter { OpportunityCatalog.matchScore($0, for: profile) >= 0.7 }.count
        } ?? 0
        return Text("Програми відсортовані за тим, наскільки підходять вашому бізнесу. Добре підходять — \(strong).")
            .font(.body)
            .foregroundStyle(Theme.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Відсоток відповідності — текстом, колір лише для числа.
struct MatchLabel: View {
    let match: Double

    var body: some View {
        Text("збіг \(Int((match * 100).rounded())) %")
            .font(.footnote.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(match >= 0.7 ? Theme.positive : (match >= 0.4 ? Theme.caution : Theme.inkMuted))
    }
}

struct OpportunityRow: View {
    let opportunity: Opportunity
    let match: Double

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Eyebrow(opportunity.type.title)
                    Spacer()
                    MatchLabel(match: match)
                }
                Text(opportunity.title)
                    .font(.display(21))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Text(opportunity.summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkMuted)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                HStack {
                    Text(opportunity.amountDescription)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("· \(opportunity.provider)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkMuted)
                        .lineLimit(1)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            Rule()
        }
        .contentShape(Rectangle())
    }
}

struct OpportunityDetailView: View {
    let opportunity: Opportunity
    let match: Double
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Eyebrow(opportunity.type.title)
                            Spacer()
                            MatchLabel(match: match)
                        }
                        Text(opportunity.title)
                            .font(.display(30, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text(opportunity.provider)
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkMuted)
                    }

                    VStack(spacing: 0) {
                        Rule(color: Theme.ink.opacity(0.85))
                        LedgerRow(label: "Сума", value: opportunity.amountDescription, showsRule: false)
                        Rule()
                    }

                    Text(opportunity.summary)
                        .font(.body)
                        .foregroundStyle(Theme.ink)

                    LedgerSection(title: "Основні вимоги") {
                        ForEach(Array(opportunity.requirements.enumerated()), id: \.offset) { index, requirement in
                            VStack(spacing: 0) {
                                HStack(alignment: .firstTextBaseline, spacing: 14) {
                                    Text(String(format: "%02d", index + 1))
                                        .font(.display(15))
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.accent)
                                    Text(requirement)
                                        .font(.body)
                                        .foregroundStyle(Theme.ink)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 11)
                                Rule()
                            }
                        }
                    }

                    Button("Відкрити офіційний сайт") {
                        openURL(opportunity.url)
                    }
                    .buttonStyle(.primary)
                }
                .padding(Theme.gutter)
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Закрити") { dismiss() }
                }
            }
        }
        .tint(Theme.accent)
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    OpportunitiesView()
        .environment(AppStore.preview)
}
