//
//  CompassMark.swift
//  UkrainianBusinessGuide
//
//  Знак застосунку: тонке кільце з рисками сторін світу й стрілка
//  (північ синя, південь чорнильна). Пропорції ті самі, що на іконці.
//

import SwiftUI

struct CompassMark: View {
    /// Кут стрілки від півночі за годинниковою стрілкою. На іконці 35°.
    var needleAngle: Angle = .degrees(35)
    var ringColor: Color = Theme.ink

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let line = side / 2 * 0.035
            ZStack {
                CompassDial()
                    .stroke(ringColor, style: StrokeStyle(lineWidth: line, lineCap: .butt))
                    .padding(line / 2)
                CompassNeedle()
                    .rotationEffect(needleAngle)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Кільце й чотири риски всередину.
private struct CompassDial: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        for index in 0..<4 {
            let angle = CGFloat(index) * .pi / 2
            let inner = radius * 0.868
            path.move(to: CGPoint(x: center.x + inner * cos(angle), y: center.y + inner * sin(angle)))
            path.addLine(to: CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle)))
        }
        return path
    }
}

/// Стрілка-ромб: північна половина акцентна, південна чорнильна, у центрі паперова крапка.
private struct CompassNeedle: View {
    var body: some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) / 2
            ZStack {
                NeedleHalf(north: true).fill(Theme.accent)
                NeedleHalf(north: false).fill(Theme.ink)
                Circle()
                    .fill(Theme.paper)
                    .frame(width: radius * 0.13, height: radius * 0.13)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct NeedleHalf: Shape {
    let north: Bool

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let tip = radius * 0.853 * (north ? -1 : 1)
        let half = radius * 0.22
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y + tip))
        path.addLine(to: CGPoint(x: center.x + half, y: center.y))
        path.addLine(to: CGPoint(x: center.x - half, y: center.y))
        path.closeSubpath()
        return path
    }
}

#Preview {
    CompassMark()
        .frame(width: 160)
        .padding()
        .background(Theme.paper)
}
