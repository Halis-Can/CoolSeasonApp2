//
//  SummaryPDFRenderer.swift
//  CoolNetEstimater
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

class SummaryPDFRenderer {
    
    func renderPDF(estimate: Estimate) -> URL? {
        #if os(iOS)
        return renderPDF_iOS(estimate: estimate)
        #elseif os(macOS)
        return renderPDF_macOS(estimate: estimate)
        #else
        return nil
        #endif
    }
    
    #if os(iOS)
    private func renderPDF_iOS(estimate: Estimate) -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "CoolSeason",
            kCGPDFContextAuthor: "CoolSeason HVAC"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var textOrigin = CGPoint(x: 40, y: 40)
            
            func drawLine(_ text: String, font: UIFont = .systemFont(ofSize: 12, weight: .regular)) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font
                ]
                let attributed = NSAttributedString(string: text, attributes: attrs)
                let size = attributed.size()
                if textOrigin.y + size.height > pageRect.height - 40 {
                    context.beginPage()
                    textOrigin = CGPoint(x: 40, y: 40)
                }
                attributed.draw(at: textOrigin)
                textOrigin.y += size.height + 4
            }
            
            drawLine("CoolSeason HVAC Estimate", font: .systemFont(ofSize: 18, weight: .bold))
            drawLine("------------------------------")
            
            drawLine("Customer: \(estimate.customerName)")
            drawLine("Address: \(estimate.address)")
            drawLine("Phone: \(estimate.phone)")
            drawLine("Email: \(estimate.email)")
            textOrigin.y += 8
            
            for system in estimate.systems.filter({ $0.enabled }) {
                drawLine("\(system.name) – \(system.tonnage) Ton \(system.equipmentType.rawValue)", font: .systemFont(ofSize: 14, weight: .bold))
                for option in system.options.filter({ $0.showToCustomer }) {
                    let selectedMark = option.isSelectedByCustomer ? " (SELECTED)" : ""
                    drawLine("  • \(option.tier.displayName) – SEER \(option.seer), \(option.stage) – $\(Int(option.price))\(selectedMark)")
                }
                textOrigin.y += 4
            }
            
            let enabledAddOns = estimate.addOns.filter { $0.enabled }
            if !enabledAddOns.isEmpty {
                textOrigin.y += 8
                drawLine("Additional Equipment:", font: .systemFont(ofSize: 14, weight: .bold))
                for addOn in enabledAddOns {
                    drawLine("  • \(addOn.name) – $\(Int(addOn.price))")
                }
            }
            
            textOrigin.y += 8
            drawLine("Systems Subtotal: $\(Int(estimate.systemsSubtotal))")
            drawLine("Add-ons Subtotal: $\(Int(estimate.addOnsSubtotal))")
            drawLine("TOTAL INVESTMENT: $\(Int(estimate.grandTotal))", font: .systemFont(ofSize: 14, weight: .bold))
            
            if let data = estimate.customerSignatureImageData,
               let image = UIImage(data: data) {
                textOrigin.y += 20
                drawLine("Customer Signature:", font: .systemFont(ofSize: 14, weight: .bold))
                let availableWidth = pageRect.width - 80
                let aspect = image.size.height / image.size.width
                let sigSize = CGSize(width: availableWidth, height: availableWidth * aspect)
                let sigRect = CGRect(origin: CGPoint(x: 40, y: textOrigin.y),
                                     size: sigSize)
                image.draw(in: sigRect)
            }
        }
        
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CoolSeasonEstimate-\(UUID().uuidString).pdf")
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("Error writing PDF: \(error)")
            return nil
        }
    }
    
    #elseif os(macOS)
    private func renderPDF_macOS(estimate: Estimate) -> URL? {
        // Use the cross-platform EstimatePDFRenderer for macOS
        let data = EstimatePDFRenderer.render(estimate: estimate)
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CoolSeasonEstimate-\(UUID().uuidString).pdf")
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("Error writing PDF: \(error)")
            return nil
        }
    }
    #endif
}


