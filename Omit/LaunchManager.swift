//
//  LaunchManager.swift
//  Omit
//
//  Created by heisyoudan on 2026/1/17.
//

import Foundation
import ServiceManagement
import Combine

class LaunchManager: ObservableObject {
    @Published var isLaunchAtLoginEnabled: Bool = false
    
    init() {
        checkStatus()
    }
    
    func checkStatus() {
        if SMAppService.mainApp.status == .enabled {
            isLaunchAtLoginEnabled = true
        } else {
            isLaunchAtLoginEnabled = false
        }
    }
    
    func toggleLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled { return }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status == .notFound { return }
                try SMAppService.mainApp.unregister()
            }
            isLaunchAtLoginEnabled = enabled
        } catch {
            print("Failed to toggle launch at login: \(error)")
        }
    }
}
