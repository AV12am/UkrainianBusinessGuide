//
//  ContentView.swift
//  UkrainianBusinessGuide
//
//  Created by Developer on 2026-04-30
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Вкладка: Компанії
            CompaniesView()
                .tabItem {
                    Label("Компанії", systemImage: "building.2.fill")
                }
                .tag(0)
            
            // Вкладка: Новини
            NewsView()
                .tabItem {
                    Label("Новини", systemImage: "newspaper.fill")
                }
                .tag(1)
            
            // Вкладка: Поради
            TipsView()
                .tabItem {
                    Label("Поради", systemImage: "lightbulb.fill")
                }
                .tag(2)
            
            // Вкладка: Аналітика
            AnalyticsView()
                .tabItem {
                    Label("Аналітика", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
}
