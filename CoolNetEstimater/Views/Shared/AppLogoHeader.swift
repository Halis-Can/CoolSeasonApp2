//
//  AppLogoHeader.swift
//  CoolNetEstimater
//

import SwiftUI

#if os(iOS)
import UIKit

extension UIImage {
    static var appIcon: UIImage? {
        if let iconsDict = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = iconsDict["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let last = files.last,
           let image = UIImage(named: last) {
            return image
        }
        return nil
    }
}
#elseif os(macOS)
import AppKit

extension NSImage {
    static var appIcon: NSImage? {
        if let iconsDict = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = iconsDict["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let last = files.last,
           let image = NSImage(named: last) {
            return image
        }
        return NSImage(named: "AppIcon")
    }
}
#endif

struct AppLogoHeader: View {
    var height: CGFloat = 100
    /// When true, always show the app's default logo (CompanyLogo asset); ignores Settings > Company Information logo.
    var useAppLogoOnly: Bool = false
    @AppStorage("company_logo_data") private var companyLogoData: Data?
    
    // Use logo data as id to force refresh when it changes (not used when useAppLogoOnly)
    private var logoId: String {
        useAppLogoOnly ? "app_logo_only" : (companyLogoData?.base64EncodedString().prefix(20).description ?? "no_logo")
    }
    
    var body: some View {
        HStack {
            Spacer()
            #if os(iOS)
            // When useAppLogoOnly, skip saved company logo and show app logo only
            if useAppLogoOnly {
                if let company = UIImage(named: "CompanyLogo") {
                    Image(uiImage: company)
                        .resizable()
                        .scaledToFit()
                        .frame(height: height)
                        .accessibilityHidden(true)
                } else if let uiImage = UIImage.appIcon {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "snow")
                        .resizable()
                        .scaledToFit()
                        .frame(height: height)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            } else if let logoData = companyLogoData, let savedLogo = UIImage(data: logoData) {
                Image(uiImage: savedLogo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
                    .accessibilityHidden(true)
            } else if let company = UIImage(named: "CompanyLogo") {
                Image(uiImage: company)
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
                    .accessibilityHidden(true)
            } else if let uiImage = UIImage.appIcon {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "snow")
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            #elseif os(macOS)
            if useAppLogoOnly {
                if let company = NSImage(named: "CompanyLogo") {
                    Image(nsImage: company)
                        .resizable()
                        .scaledToFit()
                        .frame(height: height)
                        .accessibilityHidden(true)
                } else if let nsImage = NSImage.appIcon {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "snow")
                        .resizable()
                        .scaledToFit()
                        .frame(height: height)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            } else if let logoData = companyLogoData, let savedLogo = NSImage(data: logoData) {
                Image(nsImage: savedLogo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
                    .accessibilityHidden(true)
            } else if let company = NSImage(named: "CompanyLogo") {
                Image(nsImage: company)
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
                    .accessibilityHidden(true)
            } else if let nsImage = NSImage.appIcon {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "snow")
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            #endif
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 8)
        .id(logoId) // Force refresh when logo changes
    }
}


