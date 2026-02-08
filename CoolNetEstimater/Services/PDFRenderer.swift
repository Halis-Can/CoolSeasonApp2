//
//  PDFRenderer.swift
//  CoolNetEstimater
//
//  Renders a simple one-page PDF summary for the estimate
//

import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct EstimatePDFRenderer {
    static func render(estimate: Estimate, pageSize: CGSize = CGSize(width: 612, height: 792)) -> Data {
        #if os(iOS)
        return render_iOS(estimate: estimate, pageSize: pageSize)
        #elseif os(macOS)
        return render_macOS(estimate: estimate, pageSize: pageSize)
        #endif
    }
    
    #if os(iOS)
    private static func render_iOS(estimate: Estimate, pageSize: CGSize) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        let meta: [String: Any] = [
            kCGPDFContextTitle as String: "CoolSeason Estimate",
            kCGPDFContextCreator as String: "CoolSeason App"
        ]
        format.documentInfo = meta as [String : Any]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)
        
        return renderer.pdfData { ctx in
            ctx.beginPage()
            drawHeader_iOS(estimate: estimate)
            drawSystems_iOS(estimate: estimate)
            drawAddOns_iOS(estimate: estimate)
            drawTotals_iOS(estimate: estimate)
            drawSignature_iOS(estimate: estimate)
        }
    }
    
    private static func drawHeader_iOS(estimate: Estimate) {
        let title = "CoolSeason HVAC Estimate"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24)
        ]
        title.draw(at: CGPoint(x: 40, y: 32), withAttributes: attrs)
        
        let customer = """
        Customer: \(estimate.customerName)
        Address: \(estimate.address)
        Email: \(estimate.email)  Phone: \(estimate.phone)
        """
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        let smallAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .paragraphStyle: paragraph
        ]
        customer.draw(in: CGRect(x: 40, y: 72, width: 532, height: 60), withAttributes: smallAttrs)
    }
    
    private static func drawSystems_iOS(estimate: Estimate) {
        let heading = "Selected Systems"
        heading.draw(at: CGPoint(x: 40, y: 140), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18)])
        
        var y: CGFloat = 165
        for system in estimate.systems where system.enabled {
            var line = "- \(system.name) (\(system.equipmentType.rawValue), \(formatTonnage(system.tonnage)))"
            if let selected = system.options.first(where: { $0.isSelectedByCustomer }) {
                line += " | \(selected.tier.displayName), \(selected.seer) SEER, \(selected.stage) | \(formatCurrency(selected.price))"
            } else {
                line += " | No option selected"
            }
            line.draw(at: CGPoint(x: 48, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: 13)])
            y += 20
        }
    }
    
    private static func drawAddOns_iOS(estimate: Estimate) {
        let heading = "Add-Ons"
        heading.draw(at: CGPoint(x: 40, y: 260), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18)])
        
        var y: CGFloat = 285
        if estimate.addOns.isEmpty {
            "None".draw(at: CGPoint(x: 48, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: 13)])
            return
        }
        for addon in estimate.addOns where addon.enabled {
            let line = "- \(addon.name): \(formatCurrency(addon.price))"
            line.draw(at: CGPoint(x: 48, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: 13)])
            y += 20
        }
    }
    
    private static func drawTotals_iOS(estimate: Estimate) {
        let y: CGFloat = 420
        "Systems Subtotal: \(formatCurrency(estimate.systemsSubtotal))"
            .draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        "Add-Ons Subtotal: \(formatCurrency(estimate.addOnsSubtotal))"
            .draw(at: CGPoint(x: 40, y: y + 22), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        "Grand Total: \(formatCurrency(estimate.grandTotal))"
            .draw(at: CGPoint(x: 40, y: y + 44), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18)])
    }
    
    private static func drawSignature_iOS(estimate: Estimate) {
        let y: CGFloat = 520
        "Customer Signature:".draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        
        let frame = CGRect(x: 40, y: y + 20, width: 300, height: 120)
        UIColor.lightGray.setStroke()
        UIBezierPath(rect: frame).stroke()
        
        if let data = estimate.customerSignatureImageData, let image = UIImage(data: data) {
            image.draw(in: frame.insetBy(dx: 6, dy: 6))
        } else {
            let placeholder = "No signature captured"
            placeholder.draw(in: frame.insetBy(dx: 8, dy: 8), withAttributes: [.font: UIFont.italicSystemFont(ofSize: 12), .foregroundColor: UIColor.gray])
        }
    }
    
    #elseif os(macOS)
    private static func render_macOS(estimate: Estimate, pageSize: CGSize) -> Data {
        let pdfData = NSMutableData()
        let consumer = CGDataConsumer(data: pdfData)!
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)!
        
        context.beginPage(mediaBox: &mediaBox)
        drawHeader_macOS(estimate: estimate, context: context, pageSize: pageSize)
        drawSystems_macOS(estimate: estimate, context: context, pageSize: pageSize)
        drawAddOns_macOS(estimate: estimate, context: context, pageSize: pageSize)
        drawTotals_macOS(estimate: estimate, context: context, pageSize: pageSize)
        drawSignature_macOS(estimate: estimate, context: context, pageSize: pageSize)
        context.endPage()
        context.closePDF()
        
        return pdfData as Data
    }
    
    private static func drawHeader_macOS(estimate: Estimate, context: CGContext, pageSize: CGSize) {
        let title = "CoolSeason HVAC Estimate"
        let font = NSFont.boldSystemFont(ofSize: 24)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let titleString = NSAttributedString(string: title, attributes: attrs)
        titleString.draw(at: CGPoint(x: 40, y: pageSize.height - 32 - 24))
        
        let customer = """
        Customer: \(estimate.customerName)
        Address: \(estimate.address)
        Email: \(estimate.email)  Phone: \(estimate.phone)
        """
        let smallFont = NSFont.systemFont(ofSize: 12)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        let smallAttrs: [NSAttributedString.Key: Any] = [
            .font: smallFont,
            .paragraphStyle: paragraph
        ]
        let customerString = NSAttributedString(string: customer, attributes: smallAttrs)
        customerString.draw(in: CGRect(x: 40, y: pageSize.height - 72 - 60, width: 532, height: 60))
    }
    
    private static func drawSystems_macOS(estimate: Estimate, context: CGContext, pageSize: CGSize) {
        let heading = "Selected Systems"
        let font = NSFont.boldSystemFont(ofSize: 18)
        let headingString = NSAttributedString(string: heading, attributes: [.font: font])
        headingString.draw(at: CGPoint(x: 40, y: pageSize.height - 140 - 18))
        
        var y: CGFloat = pageSize.height - 165 - 13
        let systemFont = NSFont.systemFont(ofSize: 13)
        for system in estimate.systems where system.enabled {
            var line = "- \(system.name) (\(system.equipmentType.rawValue), \(formatTonnage(system.tonnage)))"
            if let selected = system.options.first(where: { $0.isSelectedByCustomer }) {
                line += " | \(selected.tier.displayName), \(selected.seer) SEER, \(selected.stage) | \(formatCurrency(selected.price))"
            } else {
                line += " | No option selected"
            }
            let lineString = NSAttributedString(string: line, attributes: [.font: systemFont])
            lineString.draw(at: CGPoint(x: 48, y: y))
            y -= 20
        }
    }
    
    private static func drawAddOns_macOS(estimate: Estimate, context: CGContext, pageSize: CGSize) {
        let heading = "Add-Ons"
        let font = NSFont.boldSystemFont(ofSize: 18)
        let headingString = NSAttributedString(string: heading, attributes: [.font: font])
        headingString.draw(at: CGPoint(x: 40, y: pageSize.height - 260 - 18))
        
        var y: CGFloat = pageSize.height - 285 - 13
        let systemFont = NSFont.systemFont(ofSize: 13)
        if estimate.addOns.isEmpty {
            let noneString = NSAttributedString(string: "None", attributes: [.font: systemFont])
            noneString.draw(at: CGPoint(x: 48, y: y))
            return
        }
        for addon in estimate.addOns where addon.enabled {
            let line = "- \(addon.name): \(formatCurrency(addon.price))"
            let lineString = NSAttributedString(string: line, attributes: [.font: systemFont])
            lineString.draw(at: CGPoint(x: 48, y: y))
            y -= 20
        }
    }
    
    private static func drawTotals_macOS(estimate: Estimate, context: CGContext, pageSize: CGSize) {
        let y: CGFloat = pageSize.height - 420 - 14
        let font = NSFont.systemFont(ofSize: 14)
        let boldFont = NSFont.boldSystemFont(ofSize: 18)
        
        let systemsString = NSAttributedString(string: "Systems Subtotal: \(formatCurrency(estimate.systemsSubtotal))", attributes: [.font: font])
        systemsString.draw(at: CGPoint(x: 40, y: y))
        
        let addOnsString = NSAttributedString(string: "Add-Ons Subtotal: \(formatCurrency(estimate.addOnsSubtotal))", attributes: [.font: font])
        addOnsString.draw(at: CGPoint(x: 40, y: y - 22))
        
        let totalString = NSAttributedString(string: "Grand Total: \(formatCurrency(estimate.grandTotal))", attributes: [.font: boldFont])
        totalString.draw(at: CGPoint(x: 40, y: y - 44))
    }
    
    private static func drawSignature_macOS(estimate: Estimate, context: CGContext, pageSize: CGSize) {
        let y: CGFloat = pageSize.height - 520 - 14
        let font = NSFont.systemFont(ofSize: 14)
        let signatureLabel = NSAttributedString(string: "Customer Signature:", attributes: [.font: font])
        signatureLabel.draw(at: CGPoint(x: 40, y: y))
        
        let frame = CGRect(x: 40, y: y - 20 - 120, width: 300, height: 120)
        context.setStrokeColor(NSColor.lightGray.cgColor)
        context.stroke(frame)
        
        if let data = estimate.customerSignatureImageData, let image = NSImage(data: data) {
            let imageRect = frame.insetBy(dx: 6, dy: 6)
            image.draw(in: imageRect)
        } else {
            let placeholder = "No signature captured"
            let italicFont = NSFontManager.shared.font(withFamily: NSFont.systemFont(ofSize: 12).familyName!, traits: .italicFontMask, weight: 5, size: 12) ?? NSFont.systemFont(ofSize: 12)
            let placeholderString = NSAttributedString(string: placeholder, attributes: [.font: italicFont, .foregroundColor: NSColor.gray])
            placeholderString.draw(in: frame.insetBy(dx: 8, dy: 8))
        }
    }
    
    #endif
    
    private static func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        return f.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    private static func formatTonnage(_ value: Double) -> String {
        if value == floor(value) {
            return "\(Int(value)) Ton"
        } else {
            return "\(value) Ton"
        }
    }
}


