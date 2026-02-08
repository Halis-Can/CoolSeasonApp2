//
//  WelcomeView.swift
//  CoolNetEstimater
//

import SwiftUI

struct WelcomeView: View {
    var onContinue: () -> Void
    
    var body: some View {
        ZStack {
            CoolGradientBackground()
            
            VStack(spacing: 28) {
                AppLogoHeader(height: 640, useAppLogoOnly: true)
                
                Text("Welcome")
                    .font(.title.bold())
                    .foregroundStyle(.secondary)
                
                Text("Cool Net Estimater")
                    .font(.custom("Snell Roundhand", size: 44))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)
                
                Text("To create a new estimate, please tap the Continue button.")
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .italic()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .lineSpacing(6)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                
                Button(action: {
                    UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
                    onContinue()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: 260)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.top, 8)
            }
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
}


