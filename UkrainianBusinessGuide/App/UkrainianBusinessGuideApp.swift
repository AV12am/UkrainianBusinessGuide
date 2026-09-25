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

    init() {
        // `-uiDemo YES` у аргументах запуску — демо-дані лише в пам'яті (для скриншотів у CI).
        if UserDefaults.standard.bool(forKey: "uiDemo") {
            let demo = AppStore(fileURL: nil)
            demo.loadDemo()
            _store = State(initialValue: demo)
        } else {
            _store = State(initialValue: AppStore())
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(\.locale, .ukrainian)
                .tint(Theme.blue)
        }
    }
}
