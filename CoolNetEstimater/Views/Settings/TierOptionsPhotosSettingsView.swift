//
//  TierOptionsPhotosSettingsView.swift
//  CoolNetEstimater
//

import SwiftUI
import PhotosUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct TierOptionsPhotosSettingsView: View {
    @AppStorage("tier_good_photo_data") private var goodPhotoData: Data?
    @AppStorage("tier_better_photo_data") private var betterPhotoData: Data?
    @AppStorage("tier_best_photo_data") private var bestPhotoData: Data?
    
    @State private var goodImage: Image? = nil
    @State private var betterImage: Image? = nil
    @State private var bestImage: Image? = nil
    
    @State private var selectedGoodItem: PhotosPickerItem? = nil
    @State private var selectedBetterItem: PhotosPickerItem? = nil
    @State private var selectedBestItem: PhotosPickerItem? = nil
    
    #if os(macOS)
    @State private var showGoodPicker = false
    @State private var showBetterPicker = false
    @State private var showBestPicker = false
    #endif
    
    var body: some View {
        VStack(spacing: 16) {
            Form {
                Section {
                    Text("Set a photo for each option tier. These photos will appear on the estimate page for Good, Better, and Best options.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                tierPhotoSection(title: "Good", image: $goodImage, photoData: $goodPhotoData,
                                 selectedItem: $selectedGoodItem,
                                 loadFromData: loadGood, remove: removeGood,
                                 loadFromPicker: loadGoodFromPicker)
                
                tierPhotoSection(title: "Better", image: $betterImage, photoData: $betterPhotoData,
                                 selectedItem: $selectedBetterItem,
                                 loadFromData: loadBetter, remove: removeBetter,
                                 loadFromPicker: loadBetterFromPicker)
                
                tierPhotoSection(title: "Best", image: $bestImage, photoData: $bestPhotoData,
                                 selectedItem: $selectedBestItem,
                                 loadFromData: loadBest, remove: removeBest,
                                 loadFromPicker: loadBestFromPicker)
            }
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: 700)
        .padding()
        .background(CoolGradientBackground())
        .navigationTitle("Good, Better, Best Photos")
        .onAppear {
            loadGood()
            loadBetter()
            loadBest()
        }
        .onChange(of: selectedGoodItem) { newValue in
            Task { if let item = newValue { await loadGoodFromPicker(item: item) } }
        }
        .onChange(of: selectedBetterItem) { newValue in
            Task { if let item = newValue { await loadBetterFromPicker(item: item) } }
        }
        .onChange(of: selectedBestItem) { newValue in
            Task { if let item = newValue { await loadBestFromPicker(item: item) } }
        }
    }
    
    @ViewBuilder
    private func tierPhotoSection(
        title: String,
        image: Binding<Image?>,
        photoData: Binding<Data?>,
        selectedItem: Binding<PhotosPickerItem?>,
        loadFromData: () -> Void,
        remove: @escaping () -> Void,
        loadFromPicker: (PhotosPickerItem) async -> Void
    ) -> some View {
        Section(title) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.secondarySystemFill))
                        .frame(width: 120, height: 120)
                    if let img = image.wrappedValue {
                        img
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("No photo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                
                VStack(alignment: .leading, spacing: 8) {
                    #if os(iOS)
                    PhotosPicker(selection: selectedItem, matching: .images) {
                        Label("Change Photo", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.bordered)
                    #elseif os(macOS)
                    Button {
                        showTierPicker(photoData: photoData, image: image)
                    } label: {
                        Label("Change Photo", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.bordered)
                    #endif
                    if photoData.wrappedValue != nil {
                        Button(role: .destructive) {
                            remove()
                        } label: {
                            Label("Remove Photo", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    #if os(macOS)
    private func showTierPicker(photoData: Binding<Data?>, image: Binding<Image?>) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if let nsImage = NSImage(contentsOf: url) {
                let tiffData = nsImage.tiffRepresentation
                let bitmapRep = NSBitmapImageRep(data: tiffData ?? Data())
                let pngData = bitmapRep?.representation(using: .png, properties: [:])
                if let data = pngData {
                    photoData.wrappedValue = data
                    image.wrappedValue = Image(nsImage: nsImage)
                }
            }
        }
    }
    #endif
    
    private func loadGood() {
        loadTierImage(from: goodPhotoData, into: $goodImage)
    }
    private func loadBetter() {
        loadTierImage(from: betterPhotoData, into: $betterImage)
    }
    private func loadBest() {
        loadTierImage(from: bestPhotoData, into: $bestImage)
    }
    
    private func loadTierImage(from data: Data?, into binding: Binding<Image?>) {
        guard let data = data else {
            binding.wrappedValue = nil
            return
        }
        #if os(iOS)
        if let ui = UIImage(data: data) {
            binding.wrappedValue = Image(uiImage: ui)
        }
        #elseif os(macOS)
        if let ns = NSImage(data: data) {
            binding.wrappedValue = Image(nsImage: ns)
        }
        #endif
    }
    
    #if os(iOS)
    private func loadGoodFromPicker(item: PhotosPickerItem) async {
        await loadTierFromPicker(item: item, into: $goodPhotoData, image: $goodImage)
    }
    private func loadBetterFromPicker(item: PhotosPickerItem) async {
        await loadTierFromPicker(item: item, into: $betterPhotoData, image: $betterImage)
    }
    private func loadBestFromPicker(item: PhotosPickerItem) async {
        await loadTierFromPicker(item: item, into: $bestPhotoData, image: $bestImage)
    }
    
    private func loadTierFromPicker(item: PhotosPickerItem, into data: Binding<Data?>, image: Binding<Image?>) async {
        guard let raw = try? await item.loadTransferable(type: Data.self),
              let ui = UIImage(data: raw),
              let compressed = ui.jpegData(compressionQuality: 0.8) else { return }
        data.wrappedValue = compressed
        image.wrappedValue = Image(uiImage: ui)
    }
    #elseif os(macOS)
    private func loadGoodFromPicker(item: PhotosPickerItem) async {}
    private func loadBetterFromPicker(item: PhotosPickerItem) async {}
    private func loadBestFromPicker(item: PhotosPickerItem) async {}
    #endif
    
    private func removeGood() {
        goodPhotoData = nil
        goodImage = nil
        selectedGoodItem = nil
    }
    private func removeBetter() {
        betterPhotoData = nil
        betterImage = nil
        selectedBetterItem = nil
    }
    private func removeBest() {
        bestPhotoData = nil
        bestImage = nil
        selectedBestItem = nil
    }
}
