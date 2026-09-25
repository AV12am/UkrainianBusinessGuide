//
//  Theme.swift
//  UkrainianBusinessGuide
//
//  Дизайн-система «Бізнес Компас»: синьо-жовта палітра, скляні картки, м'які тіні.
//

import SwiftUI

enum Theme {
    static let blue = Color(red: 0.0, green: 0.34, blue: 0.72)
    static let skyBlue = Color(red: 0.25, green: 0.52, blue: 0.98)
    static let yellow = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let amber = Color(red: 1.0, green: 0.62, blue: 0.1)
    static let mint = Color(red: 0.16, green: 0.78, blue: 0.58)
    static let coral = Color(red: 0.95, green: 0.33, blue: 0.36)
    static let violet = Color(red: 0.49, green: 0.36, blue: 0.96)

    static let brand = LinearGradient(colors: [blue, skyBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let sun = LinearGradient(colors: [yellow, amber], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let flag = LinearGradient(colors: [skyBlue, blue, yellow], startPoint: .topLeading, endPoint: .bottomTrailing)

    static let cornerRadius: CGFloat = 24
    static let spacing: CGFloat = 16

    static func color(for severity: Insight.Severity) -> Color {
        switch severity {
        case .good: return mint
        case .info: return skyBlue
        case .warning: return amber
        case .critical: return coral
        }
    }

    /// Колір для значення 0…1: від червоного через жовтий до зеленого.
    static func color(forScore value: Double) -> Color {
        switch value {
        case ..<0.4: return coral
        case ..<0.7: return amber
        default: return mint
        }
    }
}

/// Живий фон: розмиті кольорові плями у фірмових кольорах поверх системного фону.
struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
            Circle()
                .fill(Theme.skyBlue.opacity(colorScheme == .dark ? 0.35 : 0.22))
                .frame(width: 380)
                .blur(radius: 90)
                .offset(x: -140, y: -320)
            Circle()
                .fill(Theme.yellow.opacity(colorScheme == .dark ? 0.18 : 0.25))
                .frame(width: 320)
                .blur(radius: 90)
                .offset(x: 160, y: -120)
            Circle()
                .fill(Theme.violet.opacity(colorScheme == .dark ? 0.2 : 0.1))
                .frame(width: 300)
                .blur(radius: 100)
                .offset(x: 120, y: 380)
        }
        .ignoresSafeArea()
    }
}

struct GlassCard: ViewModifier {
    var padding: CGFloat = Theme.spacing

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
    }
}

extension View {
    func glassCard(padding: CGFloat = Theme.spacing) -> some View {
        modifier(GlassCard(padding: padding))
    }

    /// Стандартне оформлення екрана вкладки.
    func screenBackground() -> some View {
        background(AppBackground())
            .scrollContentBackground(.hidden)
    }
}

/// Кнопка з фірмовим градієнтом.
struct PrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = Theme.brand

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Theme.blue.opacity(0.3), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
