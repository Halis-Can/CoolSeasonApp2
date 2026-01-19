//
//  SystemSettingsView.swift
//  CoolSeasonApp
//

import SwiftUI

struct SystemSettingsView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var showingExport = false
    @State private var showingImport = false
    @State private var exportMode: ExportMode = .all
    @State private var exportItem: ExportItem?
    
    enum ExportMode {
        case all, systemsOnly, addOnsOnly, fileExporterAll, fileExporterSystems, fileExporterAddOns
    }
    
    struct ExportItem: Identifiable {
        let url: URL
        var id: URL { url }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                AppLogoHeader()
                List {
                    Section {
                        NavigationLink {
                            SystemTemplatesListView()
                        } label: {
                            Label("System Templates", systemImage: "square.stack.3d.up")
                        }
                    }
                    Section {
                        NavigationLink {
                            AddOnTemplatesView()
                        } label: {
                            Label("Additional Equipment Templates", systemImage: "wrench.and.screwdriver")
                        }
                    }
                    Section {
                        NavigationLink {
                            FinanceSettingsView()
                        } label: {
                            Label("Finance", systemImage: "creditcard")
                        }
                    }
                    Section("Appearance") {
                        Picker("Theme", selection: $settingsVM.themeMode) {
                            ForEach(SettingsViewModel.ThemeMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .frame(maxWidth: 900)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
            .navigationTitle("System Settings")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            exportMode = .all
                            showingExport = true
                        } label: { Label("Export All (Share)", systemImage: "square.and.arrow.up") }
                        Button {
                            exportMode = .systemsOnly
                            showingExport = true
                        } label: { Label("Export System Templates (Share)", systemImage: "square.and.arrow.up") }
                        Button {
                            exportMode = .addOnsOnly
                            showingExport = true
                        } label: { Label("Export Add-On Templates (Share)", systemImage: "square.and.arrow.up") }
                        Divider()
                        Button {
                            prepareFileExport(mode: .fileExporterAll)
                        } label: { Label("Save All to Files", systemImage: "folder") }
                        Button {
                            prepareFileExport(mode: .fileExporterSystems)
                        } label: { Label("Save System Templates to Files", systemImage: "folder") }
                        Button {
                            prepareFileExport(mode: .fileExporterAddOns)
                        } label: { Label("Save Add-On Templates to Files", systemImage: "folder") }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showingImport = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                }
            }
        }
        .background(CoolGradientBackground())
        .sheet(isPresented: $showingExport) {
            let data: Data? = {
                switch exportMode {
                case .all: return settingsVM.exportTemplatesJSON()
                case .systemsOnly: return settingsVM.exportSystemTemplatesJSON()
                case .addOnsOnly: return settingsVM.exportAddOnTemplatesJSON()
                default: return settingsVM.exportTemplatesJSON()
                }
            }()
            if let data = data {
                ActivityView(activityItems: [data, exportFileName(for: exportMode)])
            }
        }
        .sheet(item: $exportItem) { item in
            ExportDocumentPicker(urls: [item.url]) {
                // Cleanup temp file after export UI finishes
                try? FileManager.default.removeItem(at: item.url)
                exportItem = nil
            }
        }
        .sheet(isPresented: $showingImport) {
            JSONDocumentPicker { data in
                do {
                    try settingsVM.importTemplates(from: data)
                } catch {
                    print("Import failed: \(error)")
                }
                showingImport = false
            }
        }
    }
    
    private func exportFileName(for mode: ExportMode) -> String {
        switch mode {
        case .systemsOnly: return "system_templates.json"
        case .addOnsOnly: return "addon_templates.json"
        default: return "templates_seed.json"
        }
    }
    
    private func prepareFileExport(mode: ExportMode) {
        let data: Data?
        switch mode {
        case .fileExporterAll:
            data = settingsVM.exportTemplatesJSON()
        case .fileExporterSystems:
            data = settingsVM.exportSystemTemplatesJSON()
        case .fileExporterAddOns:
            data = settingsVM.exportAddOnTemplatesJSON()
        default:
            data = settingsVM.exportTemplatesJSON()
        }
        guard let d = data else { return }
        let tmp = FileManager.default.temporaryDirectory
        let url = tmp.appendingPathComponent(exportFileName(for: mode))
        do {
            try d.write(to: url, options: [.atomic])
            exportItem = ExportItem(url: url)
        } catch {
            print("Failed to write temp export: \(error)")
        }
    }
}


