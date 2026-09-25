//
//  UkrainianBusinessGuideApp.swift
//  UkrainianBusinessGuide
//
//  Бізнес Компас — операційна система для українського підприємця.
//

import SwiftUI

@main
struct UkrainianBusinessGuideApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(\.locale, .ukrainian)
                .tint(Theme.blue)
        }
    }
}
