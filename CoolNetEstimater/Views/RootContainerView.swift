//
//  RootContainerView.swift
//  CoolNetEstimater
//

import SwiftUI

struct RootContainerView: View {
    @State private var showWelcome: Bool = true
    
    var body: some View {
        MainTabView()
            .fullScreenCover(isPresented: $showWelcome) {
                WelcomeView { showWelcome = false }
            }
            .onAppear { 
                // Check if this is first launch
                if !UserDefaults.standard.bool(forKey: "has_completed_onboarding") {
                    showWelcome = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SignOutRequested"))) { _ in
                showWelcome = true
                UserDefaults.standard.set(false, forKey: "has_completed_onboarding")
            }
    }
}

#Preview {
    RootContainerView()
        .environmentObject(SettingsViewModel())
        .environmentObject(EstimateViewModel())
}


