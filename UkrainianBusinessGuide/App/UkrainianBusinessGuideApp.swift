//
//  UkrainianBusinessGuideApp.swift
//  UkrainianBusinessGuide
//
//  Created by Developer on 2026-04-30
//

import SwiftUI

@main
struct UkrainianBusinessGuideApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, Locale(identifier: "uk_UA"))
        }
    }
}
