//
//  Theme.swift
//  UkrainianBusinessGuide
//
//  Редакційна дизайн-система «гросбух»: теплий папір, чорнило, один акцент.
//  Ієрархію будують шрифт і тонкі лінії, а не картки, тіні та градієнти.
//

import SwiftUI
import UIKit

enum Theme {
    // MARK: Кольори

    /// Фон сторінки — теплий папір.
    static let paper = Color(light: 0xF6F2EA, dark: 0x161512)
    /// Трохи світліша поверхня для полів вводу та повідомлень.
    static let surface = Color(light: 0xFCFAF5, dark: 0x201E1A)
    /// Основний текст.
    static let ink = Color(light: 0x1C1B19, dark: 0xECE7DD)
    /// Другорядний текст і підписи.
    static let inkMuted = Color(light: 0x6E685D, dark: 0x9F988B)
    /// Тонкі лінії-розділювачі.
    static let rule = Color(light: 0xDCD5C7, dark: 0x35322C)
    /// Єдиний акцент — глибокий синій.
    static let accent = Color(light: 0x1F3A93, dark: 0x9DB1EE)

    // Семантичні кольори — приглушені, лише для значень.
    static let positive = Color(light: 0x2E6B45, dark: 0x86C49A)
    static let negative = Color(light: 0xA3402F, dark: 0xE38D7B)
    static let caution = Color(light: 0x9A6310, dark: 0xE2B25E)

    static func color(for severity: Insight.Severity) -> Color {
        switch severity {
        case .good: return positive
        case .info: return accent
        case .warning: return caution
        case .critical: return negative
        }
    }

    /// 0…1: чим більше, тим краще.
    static func color(forScore value: Double) -> Color {
        switch value {
        case ..<0.4: return negative
        case ..<0.7: return caution
        default: return positive
        }
    }

    /// Колір для суми зі знаком.
    static func color(forAmount value: Double) -> Color {
        value < 0 ? negative : ink
    }

    // MARK: Розміри

    static let gutter: CGFloat = 20
    static let radius: CGFloat = 10
}

// MARK: - Шрифти

extension Font {
    /// Заголовки й великі цифри — New York (засічки).
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Дрібні підписи над значеннями.
    static let eyebrow = Font.footnote
}

// MARK: - Кольори зі світлою/темною версією

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Фон екрана

extension View {
    /// Паперовий фон під усім екраном.
    func screenBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.paper.ignoresSafeArea())
    }
}

// MARK: - Кнопки

/// Суцільна кнопка кольору чорнила.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.paper)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.ink, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Контурна кнопка з тонкою рамкою.
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .strokeBorder(Theme.rule, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == OutlineButtonStyle {
    static var outline: OutlineButtonStyle { OutlineButtonStyle() }
}

// MARK: - Навігація

enum Appearance {
    /// Заголовки навігації — тим самим шрифтом із засічками, що й заголовки розділів.
    static func configure() {
        // Колір не задаємо: системний колір тексту сам підлаштовується під світлу й темну тему.
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: serifFont(size: 34, weight: .bold)]
        UINavigationBar.appearance().titleTextAttributes = [.font: serifFont(size: 17, weight: .semibold)]
    }

    private static func serifFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}
