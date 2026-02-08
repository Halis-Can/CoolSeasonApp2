//
//  SwiftUIViewPDFRenderer.swift
//  CoolNetEstimater
//

import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct SwiftUIViewPDFRenderer {
    static func render<V: View>(view: V,
                                pageSize: CGSize = CGSize(width: 612, height: 792),
                                margins: UIEdgeInsets = UIEdgeInsets(top: 32, left: 32, bottom: 32, right: 32)) -> URL? {
        #if os(iOS)
        return render_iOS(view: view, pageSize: pageSize, margins: margins)
        #elseif os(macOS)
        // macOS doesn't have UIHostingController, return nil or use alternative
        return nil
        #else
        return nil
        #endif
    }
    
    #if os(iOS)
    private static func render_iOS<V: View>(view: V,
                                pageSize: CGSize,
                                margins: UIEdgeInsets) -> URL? {
        let hosting = UIHostingController(rootView: view)
        hosting.view.backgroundColor = .white
        
        // Measure content with a fixed width (page width - horizontal margins)
        let targetWidth = pageSize.width - margins.left - margins.right
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        let container = UIView(frame: CGRect(x: 0, y: 0, width: targetWidth, height: 10))
        container.backgroundColor = .white
        container.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: container.topAnchor)
        ])
        // Allow the height to grow
        let heightConstraint = hosting.view.heightAnchor.constraint(equalToConstant: 10)
        heightConstraint.priority = .defaultLow
        heightConstraint.isActive = true
        
        container.setNeedsLayout()
        container.layoutIfNeeded()
        // Ask for best fitting size
        let size = hosting.view.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingExpandedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let contentHeight = max(size.height, 1)
        hosting.view.frame = CGRect(x: 0, y: 0, width: targetWidth, height: contentHeight)
        container.frame = hosting.view.frame
        container.setNeedsLayout()
        container.layoutIfNeeded()
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "CoolSeason",
            kCGPDFContextAuthor as String: "CoolSeason iPad App"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)
        let data = renderer.pdfData { ctx in
            let availableHeight = pageSize.height - margins.top - margins.bottom
            var yOffset: CGFloat = 0
            while yOffset < contentHeight {
                ctx.beginPage()
                let ctxRef = UIGraphicsGetCurrentContext()!
                ctxRef.saveGState()
                ctxRef.translateBy(x: margins.left, y: margins.top - yOffset)
                // Render the SwiftUI hierarchy into PDF context
                hosting.view.layer.render(in: ctxRef)
                ctxRef.restoreGState()
                yOffset += availableHeight
            }
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoolSeasonSummary-\(UUID().uuidString).pdf")
        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            print("SwiftUIViewPDFRenderer failed: \(error)")
            return nil
        }
    }
    #endif
    
    // Render multiple SwiftUI pages as separate PDF pages, preserving colors/layout
    static func renderPages(pages: [AnyView],
                            pageSize: CGSize = CGSize(width: 612, height: 792),
                            margins: UIEdgeInsets = UIEdgeInsets(top: 32, left: 32, bottom: 32, right: 32)) -> URL? {
        #if os(iOS)
        return renderPages_iOS(pages: pages, pageSize: pageSize, margins: margins)
        #elseif os(macOS)
        // macOS doesn't have UIHostingController, return nil or use alternative
        return nil
        #else
        return nil
        #endif
    }
    
    #if os(iOS)
    private static func renderPages_iOS(pages: [AnyView],
                            pageSize: CGSize,
                            margins: UIEdgeInsets) -> URL? {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "CoolSeason",
            kCGPDFContextAuthor as String: "CoolSeason iPad App"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)
        let data = renderer.pdfData { ctx in
            for page in pages {
                let hosting = UIHostingController(rootView: page)
                hosting.view.backgroundColor = .white
                
                // Measure to target width, auto height
                let targetWidth = pageSize.width - margins.left - margins.right
                hosting.view.translatesAutoresizingMaskIntoConstraints = false
                let container = UIView(frame: CGRect(x: 0, y: 0, width: targetWidth, height: 10))
                container.backgroundColor = .white
                container.addSubview(hosting.view)
                NSLayoutConstraint.activate([
                    hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    hosting.view.topAnchor.constraint(equalTo: container.topAnchor)
                ])
                let heightConstraint = hosting.view.heightAnchor.constraint(equalToConstant: 10)
                heightConstraint.priority = .defaultLow
                heightConstraint.isActive = true
                container.setNeedsLayout()
                container.layoutIfNeeded()
                let fit = hosting.view.systemLayoutSizeFitting(
                    CGSize(width: targetWidth, height: UIView.layoutFittingExpandedSize.height),
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                )
                hosting.view.frame = CGRect(x: 0, y: 0, width: targetWidth, height: max(fit.height, 1))
                container.frame = hosting.view.frame
                container.setNeedsLayout()
                container.layoutIfNeeded()
                
                ctx.beginPage()
                if let cg = UIGraphicsGetCurrentContext() {
                    cg.saveGState()
                    cg.translateBy(x: margins.left, y: margins.top)
                    hosting.view.layer.render(in: cg)
                    cg.restoreGState()
                }
            }
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoolSeasonSummary-\(UUID().uuidString).pdf")
        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            print("SwiftUIViewMultiPDFRenderer failed: \(error)")
            return nil
        }
    }
    #endif
}


