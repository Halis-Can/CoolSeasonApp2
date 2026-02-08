//
//  TierOptionPhotoView.swift
//  CoolNetEstimater
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Displays the custom tier photo (from Settings) or a fallback symbol when no custom photo is set.
struct TierOptionPhotoView: View {
    let tier: Tier
    let height: CGFloat
    var fallbackSymbol: String = "shippingbox"
    
    @AppStorage("tier_good_photo_data") private var goodPhotoData: Data?
    @AppStorage("tier_better_photo_data") private var betterPhotoData: Data?
    @AppStorage("tier_best_photo_data") private var bestPhotoData: Data?
    
    private var photoData: Data? {
        switch tier {
        case .good: return goodPhotoData
        case .better: return betterPhotoData
        case .best: return bestPhotoData
        }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.tertiarySystemFill))
                .frame(height: height)
            if let data = photoData {
                tierImage(from: data)
                    .resizable()
                    .scaledToFit()
                    .frame(height: height - 20)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: fallbackSymbol)
                    .resizable()
                    .scaledToFit()
                    .frame(height: height - 40)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
    
    private func tierImage(from data: Data) -> Image {
        #if os(iOS)
        if let ui = UIImage(data: data) {
            return Image(uiImage: ui)
        }
        return Image(systemName: fallbackSymbol)
        #elseif os(macOS)
        if let ns = NSImage(data: data) {
            return Image(nsImage: ns)
        }
        return Image(systemName: fallbackSymbol)
        #endif
    }
}
