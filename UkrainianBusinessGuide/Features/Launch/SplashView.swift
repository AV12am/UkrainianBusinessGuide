//
//  SplashView.swift
//  UkrainianBusinessGuide
//
//  Заставка при запуску: стрілка компаса робить оберт і, похитавшись, зупиняється
//  на тому ж куті, що й на іконці. Із «Зменшенням руху» стрілка не обертається.
//

import SwiftUI

struct SplashView: View {
    /// `-uiSplashHold YES` тримає заставку на екрані (для скриншота в CI).
    var hold = UserDefaults.standard.bool(forKey: "uiSplashHold")
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = -325
    @State private var showTitle = false

    var body: some View {
        VStack(spacing: 28) {
            CompassMark(needleAngle: .degrees(angle))
                .frame(width: 132, height: 132)
            Text("Бізнес Компас")
                .font(.display(28, weight: .bold))
                .foregroundStyle(Theme.ink)
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper.ignoresSafeArea())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Бізнес Компас")
        .task {
            if reduceMotion {
                angle = 35
            } else {
                // Повний оберт і згасаюче похитування, як у справжнього компаса.
                withAnimation(.spring(response: 1.0, dampingFraction: 0.42)) { angle = 35 }
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) { showTitle = true }
            guard !hold else { return }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 700 : 1_600))
            onFinish()
        }
    }
}

/// Покриває дані, коли застосунок іде у фон із увімкненим захистом:
/// у перемикачі програм видно лише знак, а не суми.
struct PrivacyCover: View {
    var body: some View {
        CompassMark()
            .frame(width: 96, height: 96)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.paper.ignoresSafeArea())
    }
}

#Preview {
    SplashView(hold: true) {}
}
