//
//  ExportDocumentPicker.swift
//  CoolNetEstimater
//

import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit

struct ExportDocumentPicker: UIViewControllerRepresentable {
    let urls: [URL]
    var onFinish: (() -> Void)?
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: ExportDocumentPicker
        init(_ parent: ExportDocumentPicker) { self.parent = parent }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onFinish?()
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onFinish?()
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let vc = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

#elseif os(macOS)
import AppKit

struct ExportDocumentPicker: NSViewRepresentable {
    let urls: [URL]
    var onFinish: (() -> Void)?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            showSavePanel()
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    private func showSavePanel() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = urls.first?.lastPathComponent ?? "export.pdf"
        
        savePanel.begin { response in
            if response == .OK, let destinationURL = savePanel.url {
                for sourceURL in urls {
                    try? FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                }
            }
            onFinish?()
        }
    }
}
#endif



