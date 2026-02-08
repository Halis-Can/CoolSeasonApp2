//
//  ZoneSelectionView.swift
//  CoolNetEstimater
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ZoneSelectionView: View {
    @EnvironmentObject var viewModel: AppStateViewModel
    var onNext: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            // Header centered
            AppLogoHeader(height: 80)
            
            // Visual: Climate zone map header (drop an asset named "ClimateZonesMap")
            Card {
                ZStack {
                    Group {
                        #if os(iOS)
                        if UIImage(named: "ClimateZonesMap") != nil {
                            Image("ClimateZonesMap")
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            // Fallback placeholder until the image asset is added
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: [.blue.opacity(0.35), .orange.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 180)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "map")
                                            .font(.system(size: 42, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Text("Climate Zone Map")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                )
                        }
                        #elseif os(macOS)
                        if NSImage(named: "ClimateZonesMap") != nil {
                            Image("ClimateZonesMap")
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            // Fallback placeholder until the image asset is added
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: [.blue.opacity(0.35), .orange.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 180)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "map")
                                            .font(.system(size: 42, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Text("Climate Zone Map")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                )
                        }
                        #endif
                    }
                }
            }
            
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Climate Zone").font(.headline)
                    HStack {
                        Picker("Zone", selection: Binding(get: {
                            viewModel.selectedClimateZone ?? .zone1
                        }, set: { newVal in
                            viewModel.selectedClimateZone = newVal
                        })) {
                            ForEach(ClimateZone.allCases) { z in
                                Text(z.title).tag(z)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ZIP Code (optional)").font(.subheadline).foregroundStyle(.secondary)
                        TextField("e.g. 30040", text: $viewModel.zipCode)
                            .textFieldStyle(.roundedBorder)
                    }
                    Text("Pick the ASHRAE/DOE climate zone for the job location. ZIP is just for your own reference.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Show "Next" for Zone 1, "Save" for Zone 2-5
            if viewModel.selectedClimateZone == .zone1 {
                Button {
                    if let onNext {
                        onNext()
                    }
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else if let zone = viewModel.selectedClimateZone, [.zone2, .zone3, .zone4, .zone5].contains(zone) {
                Button {
                    if let onNext {
                        onNext()
                    }
                } label: {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Ensure default is Zone 1 if not set
            if viewModel.selectedClimateZone == nil {
                viewModel.selectedClimateZone = .zone1
            }
        }
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(Color(.separator), lineWidth: 1)
        )
    }
}

#Preview {
    ZoneSelectionView().environmentObject(AppStateViewModel())
}


