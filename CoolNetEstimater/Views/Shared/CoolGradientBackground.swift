//
//  CoolGradientBackground.swift
//  CoolNetEstimater
//

import SwiftUI

struct CoolGradientBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.blue.opacity(0.4),
                Color.purple.opacity(0.4),
                Color.red.opacity(0.4)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}


