//
//  Components.swift
//  UkrainianBusinessGuide
//

import SwiftUI

/// Кільцевий індикатор з градієнтом і анімацією заповнення.
struct RingGauge<Label: View>: View {
    var progress: Double
    var lineWidth: CGFloat = 14
    var tint: Color = Theme.mint
    @ViewBuilder var label: () -> Label

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            label()
        }
        .onAppear { animate(to: progress) }
        .onChange(of: progress) { _, newValue in animate(to: newValue) }
    }

    private func animate(to value: Double) {
        withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
            animatedProgress = min(1, max(0, value))
        }
    }
}

/// Горизонтальна шкала прогресу з кольором за рівнем заповнення.
struct ProgressBar: View {
    var value: Double
    var tint: Color? = nil
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(tint ?? Theme.color(forScore: value))
                    .frame(width: proxy.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: height)
        .animation(.spring, value: value)
    }
}

/// Плитка ключового показника.
struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    var tint: Color = Theme.skyBlue
    var footnote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            Text(value)
                .font(.title3.weight(.bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let footnote {
                Text(footnote)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
            }
        }
        .glassCard()
        .accessibilityElement(children: .combine)
    }
}

struct SectionTitle: View {
    let title: String
    var action: (title: String, handler: () -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.weight(.bold))
            Spacer()
            if let action {
                Button(action.title, action: action.handler)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 4)
    }
}

/// Кругла іконка з кольоровою підкладкою.
struct IconBadge: View {
    let systemName: String
    var tint: Color = Theme.skyBlue
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.15), in: Circle())
    }
}

/// Чип-фільтр.
struct Chip: View {
    let title: String
    var icon: String? = nil
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? .white : .primary)
            .background {
                if isSelected {
                    Capsule().fill(Theme.brand)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

struct InsightRow: View {
    let insight: Insight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(systemName: insight.icon, tint: Theme.color(for: insight.severity), size: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title).font(.subheadline.weight(.semibold))
                Text(insight.message).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct DeadlineRow: View {
    let deadline: TaxDeadline
    var isDone: Bool = false
    var onToggle: (() -> Void)? = nil

    private var daysLeft: Int {
        Calendar.kyiv.dateComponents([.day], from: Calendar.kyiv.startOfDay(for: .now), to: deadline.date).day ?? 0
    }

    private var urgency: Color {
        switch daysLeft {
        case ..<3: return Theme.coral
        case ..<10: return Theme.amber
        default: return Theme.mint
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(deadline.date.formatted(.dateTime.day()))
                    .font(.title3.weight(.bold))
                Text(deadline.date.formatted(.dateTime.month(.abbreviated).locale(.ukrainian)))
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
            }
            .foregroundStyle(isDone ? Color.secondary : urgency)
            .frame(width: 52, height: 52)
            .background((isDone ? Color.secondary : urgency).opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(deadline.title)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(isDone)
                HStack(spacing: 6) {
                    Label(deadline.kind == .payment ? "Сплата" : "Звіт",
                          systemImage: deadline.kind == .payment ? "creditcard" : "doc.text")
                    if let amount = deadline.estimatedAmount, amount > 0 {
                        Text("≈ \(amount.uah)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text(daysLeft == 0 ? "Сьогодні" : "Через \(daysLeft) дн.")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isDone ? Color.secondary : urgency)
            }
            Spacer(minLength: 0)
            if let onToggle {
                Button(action: onToggle) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isDone ? Theme.mint : .secondary)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: isDone)
                .accessibilityLabel(isDone ? "Позначити як невиконане" : "Позначити як виконане")
            }
        }
    }
}
