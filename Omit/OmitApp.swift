//
//  OmitApp.swift
//  Omit
//
//  Created by heisyoudan on 2026/1/16.
//

import SwiftUI

@main
struct OmitApp: App {
    var body: some Scene {
        MenuBarExtra("Omit", systemImage: "circle") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
