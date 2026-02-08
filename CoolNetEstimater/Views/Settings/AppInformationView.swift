//
//  AppInformationView.swift
//  CoolNetEstimater
//

import SwiftUI

struct AppInformationView: View {
    var body: some View {
        VStack(spacing: 16) {
            Form {
                Section("App Information") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(buildNumber)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Bundle ID")
                        Spacer()
                        Text(bundleIdentifier)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    #if os(iOS)
                    HStack {
                        Text("Platform")
                        Spacer()
                        Text("iOS")
                            .foregroundStyle(.secondary)
                    }
                    #elseif os(macOS)
                    HStack {
                        Text("Platform")
                        Spacer()
                        Text("macOS")
                            .foregroundStyle(.secondary)
                    }
                    #endif
                }
            }
            .frame(maxWidth: 700)
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
        .background(CoolGradientBackground())
        .navigationTitle("App Information")
    }
    
    // MARK: - App Information
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "Unknown"
    }
}
