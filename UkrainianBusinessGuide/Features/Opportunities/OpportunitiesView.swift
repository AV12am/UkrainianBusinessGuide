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
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    filters
                    ForEach(ranked, id: \.opportunity.id) { item in
                        Button {
                            selected = item.opportunity
                        } label: {
                            OpportunityCard(opportunity: item.opportunity, match: item.match)
                        }
                        .buttonStyle(.plain)
                    }
                    Label("Умови програм змінюються. Перед подачею перевіряйте актуальну інформацію на офіційному сайті.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle("Можливості")
            .sheet(item: $selected) { opportunity in
                OpportunityDetailView(opportunity: opportunity,
                                      match: store.profile.map { OpportunityCatalog.matchScore(opportunity, for: $0) } ?? 0)
            }
        }
    }

    private var ranked: [(opportunity: Opportunity, match: Double)] {
        guard let profile = store.profile else { return [] }
        return OpportunityCatalog.ranked(for: profile).filter { typeFilter == nil || $0.opportunity.type == typeFilter }
    }

    private var hero: some View {
        let strong = store.profile.map { profile in
            OpportunityCatalog.all.filter { OpportunityCatalog.matchScore($0, for: profile) >= 0.7 }.count
        } ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.title.weight(.bold))
            Text("\(strong) програм добре підходять вам")
                .font(.title2.weight(.heavy))
            Text("Підбір враховує галузь, статуси засновника та розмір команди.")
                .font(.subheadline)
                .opacity(0.85)
        }
        .foregroundStyle(Color(red: 0.12, green: 0.14, blue: 0.2))
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.sun, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "Усі", isSelected: typeFilter == nil) { typeFilter = nil }
                ForEach(OpportunityType.allCases) { type in
                    Chip(title: type.title, icon: type.icon, isSelected: typeFilter == type) { typeFilter = type }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct MatchBadge: View {
    let match: Double

    var body: some View {
        Text("\(Int((match * 100).rounded()))% збіг")
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(Theme.color(forScore: match))
            .background(Theme.color(forScore: match).opacity(0.15), in: Capsule())
    }
}

struct OpportunityCard: View {
    let opportunity: Opportunity
    let match: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                IconBadge(systemName: opportunity.type.icon, tint: Theme.blue, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(opportunity.title).font(.headline)
                    Text(opportunity.provider).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                MatchBadge(match: match)
            }
            Text(opportunity.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            HStack {
                Label(opportunity.amountDescription, systemImage: "banknote")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.blue)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
        }
        .glassCard()
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
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        IconBadge(systemName: opportunity.type.icon, tint: Theme.blue, size: 56)
                        Spacer()
                        MatchBadge(match: match)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(opportunity.title).font(.title.weight(.heavy))
                        Text(opportunity.provider).foregroundStyle(.secondary)
                    }
                    Text(opportunity.amountDescription)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.brand)
                    Text(opportunity.summary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Основні вимоги").font(.headline)
                        ForEach(opportunity.requirements, id: \.self) { requirement in
                            Label(requirement, systemImage: "checkmark.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Theme.mint)
                                .font(.subheadline)
                        }
                    }
                    .glassCard()

                    Button {
                        openURL(opportunity.url)
                    } label: {
                        Label("Офіційне джерело", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.primary)
                }
                .padding()
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Закрити") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    OpportunitiesView()
        .environment(AppStore.preview)
}
