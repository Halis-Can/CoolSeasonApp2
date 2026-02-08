//
//  DocumentPicker.swift
//  CoolNetEstimater
//

import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit

struct JSONDocumentPicker: UIViewControllerRepresentable {
    var onPick: (Data) -> Void
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: JSONDocumentPicker
        init(_ parent: JSONDocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    parent.onPick(data)
                }
            } else if let data = try? Data(contentsOf: url) {
                parent.onPick(data)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.json, .data, .plainText]
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        vc.allowsMultipleSelection = false
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

#elseif os(macOS)
import AppKit

struct JSONDocumentPicker: NSViewRepresentable {
    var onPick: (Data) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            showOpenPanel()
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    private func showOpenPanel() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json, .data, .plainText]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                if let data = try? Data(contentsOf: url) {
                    onPick(data)
                }
            }
        }
    }
}
#endif


