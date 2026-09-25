//
//  UkrainianBusinessGuideApp.swift
//  UkrainianBusinessGuide
//
//  Бізнес Компас — операційна система для українського підприємця.
//

import SwiftUI

@main
struct UkrainianBusinessGuideApp: App {
    @State private var store: AppStore
    @State private var lock: AppLock
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Appearance.configure()
        // `-uiDemo YES` у аргументах запуску — демо-дані лише в пам'яті (для скриншотів у CI).
        let initial: AppStore
        if UserDefaults.standard.bool(forKey: "uiDemo") {
            initial = AppStore(fileURL: nil)
            initial.loadDemo()
        } else {
            initial = AppStore()
        }
        _store = State(initialValue: initial)
        _lock = State(initialValue: AppLock(locked: initial.lockEnabled))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .overlay {
                    if lock.isLocked {
                        LockView()
                    }
                }
                .environment(store)
                .environment(lock)
                .environment(\.locale, .ukrainian)
                .tint(Theme.accent)
        }
        .onChange(of: scenePhase) { _, phase in
            // Блокуємо при виході у фон: дані не видно й у перемикачі програм.
            if phase == .background, store.lockEnabled {
                lock.lock()
            } else if phase == .active, lock.isLocked {
                Task { await lock.unlock() }
            }
        }
    }
}
