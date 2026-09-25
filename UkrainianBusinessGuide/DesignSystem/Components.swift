//
//  Components.swift
//  UkrainianBusinessGuide
//

import SwiftUI

/// Дрібний підпис над значенням.
struct Eyebrow: View {
    let text: String
    var color: Color = Theme.inkMuted

    init(_ text: String, color: Color = Theme.inkMuted) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.eyebrow)
            .foregroundStyle(color)
    }
}

/// Тонка горизонтальна лінія.
struct Rule: View {
    var color: Color = Theme.rule

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
    }
}

/// Розділ сторінки: підпис, лінія, вміст.
struct LedgerSection<Content: View>: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?
    let content: () -> Content

    init(title: String, actionTitle: String? = nil, action: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.display(21))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.bottom, 8)
            Rule(color: Theme.ink.opacity(0.85))
            content()
        }
    }
}

/// Рядок «назва — значення» з лінією знизу.
struct LedgerRow: View {
    let label: String
    let value: String
    var detail: String? = nil
    var valueColor: Color = Theme.ink
    var emphasized = false
    var showsRule = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(emphasized ? .body.weight(.semibold) : .body)
                        .foregroundStyle(Theme.ink)
                    if let detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
                Spacer(minLength: 8)
                Text(value)
                    .font(emphasized ? .display(20) : .body)
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 12)
            if showsRule { Rule() }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Тонка шкала заповнення з необов'язковими позначками порогів.
struct Meter: View {
    var value: Double
    var tint: Color = Theme.ink
    var marks: [Double] = []
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.rule)
                Rectangle()
                    .fill(tint)
                    .frame(width: proxy.size.width * min(1, max(0, value)))
                ForEach(marks, id: \.self) { mark in
                    Rectangle()
                        .fill(Theme.inkMuted)
                        .frame(width: 1, height: height + 6)
                        .offset(x: proxy.size.width * mark)
                }
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.6), value: value)
    }
}

/// Вкладки-фільтри: текст із підкресленням у вибраної.
struct FilterTabs<Value: Hashable>: View {
    let options: [(title: String, value: Value)]
    @Binding var selection: Value

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(options, id: \.value) { option in
                    let isSelected = option.value == selection
                    Button {
                        selection = option.value
                    } label: {
                        VStack(spacing: 6) {
                            Text(option.title)
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Theme.ink : Theme.inkMuted)
                            Rectangle()
                                .fill(isSelected ? Theme.accent : .clear)
                                .frame(height: 2)
                        }
                        .fixedSize()
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Нотатка-інсайт: кольорова вертикальна риска замість іконки.
struct InsightRow: View {
    let insight: Insight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Theme.color(for: insight.severity))
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(insight.message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 12)
    }
}

/// Рядок податкового строку: дата, що сплатити, позначка «виконано».
struct DeadlineRow: View {
    let deadline: TaxDeadline
    var isDone: Bool = false
    var onToggle: (() -> Void)? = nil

    private var daysLeft: Int {
        Calendar.kyiv.dateComponents([.day], from: Calendar.kyiv.startOfDay(for: .now), to: deadline.date).day ?? 0
    }

    private var urgencyColor: Color {
        if isDone { return Theme.inkMuted }
        switch daysLeft {
        case ..<3: return Theme.negative
        case ..<10: return Theme.caution
        default: return Theme.inkMuted
        }
    }

    private var dueText: String {
        switch daysLeft {
        case 0: return "сьогодні"
        case 1: return "завтра"
        default: return "через \(daysLeft) дн."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(deadline.date.formatted(Date.FormatStyle.kyiv.day()))
                        .font(.display(24))
                        .monospacedDigit()
                    Text(deadline.date.formatted(Date.FormatStyle.kyiv.month(.abbreviated)))
                        .font(.caption)
                        .foregroundStyle(Theme.inkMuted)
                }
                .frame(width: 44, alignment: .leading)
                .foregroundStyle(isDone ? Theme.inkMuted : Theme.ink)

                VStack(alignment: .leading, spacing: 3) {
                    Text(deadline.title)
                        .font(.body)
                        .foregroundStyle(isDone ? Theme.inkMuted : Theme.ink)
                        .strikethrough(isDone, color: Theme.inkMuted)
                    HStack(spacing: 0) {
                        Text(deadline.kind == .payment ? "Сплата" : "Звіт")
                        if let amount = deadline.estimatedAmount, amount > 0 {
                            Text(", ≈ \(amount.uah)")
                        }
                        Text(", ")
                        Text(dueText).foregroundStyle(urgencyColor)
                    }
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.inkMuted)
                }

                Spacer(minLength: 0)

                if let onToggle {
                    Button(action: onToggle) {
                        Image(systemName: isDone ? "checkmark.square.fill" : "square")
                            .font(.title3)
                            .foregroundStyle(isDone ? Theme.positive : Theme.inkMuted)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.success, trigger: isDone)
                    .accessibilityLabel(isDone ? "Позначити як невиконане" : "Позначити як виконане")
                }
            }
            .padding(.vertical, 12)
            Rule()
        }
    }
}

/// Рядок-перехід між лініями: заголовок, пояснення, стрілка. Для Button і NavigationLink.
struct LinkRowLabel: View {
    let title: String
    let text: String
    var showsTopRule = true

    var body: some View {
        VStack(spacing: 0) {
            if showsTopRule { Rule(color: Theme.ink.opacity(0.85)) }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.display(20))
                        .foregroundStyle(Theme.ink)
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(Theme.accent)
            }
            .padding(.vertical, 14)
            Rule()
        }
        .contentShape(Rectangle())
    }
}

/// Порожній стан розділу.
struct EmptyNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.inkMuted)
            .padding(.vertical, 16)
    }
}
