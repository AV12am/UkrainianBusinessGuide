//
//  LockView.swift
//  UkrainianBusinessGuide
//

import SwiftUI

struct LockView: View {
    @Environment(AppLock.self) private var lock

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer()
            Text("Бізнес Компас")
                .font(.display(34, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Дані захищено. Розблокуйте, щоб продовжити.")
                .font(.body)
                .foregroundStyle(Theme.inkMuted)
            Spacer()
            Button("Розблокувати") {
                Task { await lock.unlock() }
            }
            .buttonStyle(.primary)
            .disabled(lock.isAuthenticating)
        }
        .padding(Theme.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.paper.ignoresSafeArea())
        .task { await lock.unlock() }
    }
}
