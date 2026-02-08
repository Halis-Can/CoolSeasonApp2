//
//  CoolNetEstimaterApp.swift
//  CoolNetEstimater
//
//  Created by Halis Can on 11/26/25.
//

import SwiftUI

@main
struct CoolNetEstimaterApp: App {
    @StateObject private var settingsVM = SettingsViewModel()
    @StateObject private var estimateVM = EstimateViewModel()
    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .environmentObject(settingsVM)
                .environmentObject(estimateVM)
                .onAppear {
                    estimateVM.attachTemplates(settingsVM.addOnTemplates)
                    if estimateVM.currentEstimate.systems.isEmpty {
                        // initialize a fresh estimate from the templates on first launch
                        estimateVM.startNewEstimate(using: settingsVM.systemTemplates, addOns: settingsVM.enabledAddOnTemplates())
                    }
                }
                .onReceive(settingsVM.$systemTemplates) { templates in
                    estimateVM.syncSystemsWithTemplates(templates)
                }
                .onReceive(settingsVM.$addOnTemplates) { addOns in
                    estimateVM.attachTemplates(addOns)
                }
        }
    }
}
