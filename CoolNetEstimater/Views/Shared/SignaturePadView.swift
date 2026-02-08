//
//  SignaturePadView.swift
//  CoolNetEstimater
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct SignaturePadView: View {
    @State private var currentPath: [CGPoint] = []
    @State private var paths: [[CGPoint]] = []
    @Binding var imageData: Data?
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                Canvas { context, size in
                    let strokeStyle = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    let pathColor = Color.primary
                    for pts in paths {
                        if pts.count > 1 {
                            var path = Path()
                            path.addLines(pts)
                            context.stroke(path, with: .color(pathColor), style: strokeStyle)
                        }
                    }
                    if currentPath.count > 1 {
                        var path = Path()
                        path.addLines(currentPath)
                        context.stroke(path, with: .color(pathColor), style: strokeStyle)
                    }
                }
                .background(Color.white)
                .gesture(DragGesture(minimumDistance: 0.1)
                    .onChanged { value in
                        currentPath.append(value.location)
                    }
                    .onEnded { _ in
                        if !currentPath.isEmpty {
                            paths.append(currentPath)
                            currentPath = []
                            imageData = snapshotImage(in: proxy)
                        }
                    }
                )
                
                HStack {
                    Button {
                        paths = []
                        currentPath = []
                        imageData = nil
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .padding(8)
                }
            }
        }
    }
    
    private func snapshotImage(in proxy: GeometryProxy) -> Data? {
        #if os(iOS)
        let renderer = UIGraphicsImageRenderer(size: proxy.size)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: proxy.size))
            UIColor.black.setStroke()
            for pts in paths {
                if pts.count > 1 {
                    let path = UIBezierPath()
                    path.move(to: pts.first!)
                    for p in pts.dropFirst() {
                        path.addLine(to: p)
                    }
                    path.lineWidth = 2
                    path.lineCapStyle = .round
                    path.lineJoinStyle = .round
                    path.stroke()
                }
            }
        }
        return image.pngData()
        #elseif os(macOS)
        let image = NSImage(size: proxy.size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: proxy.size).fill()
        NSColor.black.setStroke()
        
        if let context = NSGraphicsContext.current?.cgContext {
            context.setLineWidth(2)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            for pts in paths {
                if pts.count > 1 {
                    context.beginPath()
                    context.move(to: pts.first!)
                    for p in pts.dropFirst() {
                        context.addLine(to: p)
                    }
                    context.strokePath()
                }
            }
        }
        
        image.unlockFocus()
        return image.tiffRepresentation(using: .png, factor: 1.0)
        #endif
    }
}



