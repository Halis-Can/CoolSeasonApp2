//
//  SystemSettingsView.swift
//  CoolNetEstimater
//

import SwiftUI

struct SystemSettingsView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var showingExport = false
    @State private var showingImport = false
    @State private var exportMode: ExportMode = .all
    @State private var exportItem: ExportItem?
    @State private var showingSignOutConfirmation = false
    
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
                            CompanyInfoSettingsView()
                        } label: {
                            Label("Company Information", systemImage: "building.2")
                        }
                    }
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
                            Label("Payment Settings", systemImage: "creditcard")
                        }
                        NavigationLink {
                            TierOptionsPhotosSettingsView()
                        } label: {
                            Label("Good, Better, Best Options Photos", systemImage: "photo.on.rectangle.angled")
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
                    
                    Section {
                        NavigationLink {
                            AppInformationView()
                        } label: {
                            Label("App Information", systemImage: "info.circle")
                        }
                    }
                    
                    Section {
                        Button(role: .destructive) {
                            showingSignOutConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                Spacer()
                            }
                        }
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
        .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to sign out? This will clear all app data and return to the welcome screen.")
        }
    }
    
    // MARK: - Sign Out
    
    private func signOut() {
        // Clear all user data
        clearAllUserData()
        
        // Reset to welcome screen
        // This will be handled by the app's root view
        NotificationCenter.default.post(name: NSNotification.Name("SignOutRequested"), object: nil)
    }
    
    private func clearAllUserData() {
        // Clear AppStorage values
        UserDefaults.standard.removeObject(forKey: "company_name")
        UserDefaults.standard.removeObject(forKey: "company_phone")
        UserDefaults.standard.removeObject(forKey: "company_email")
        UserDefaults.standard.removeObject(forKey: "company_address")
        UserDefaults.standard.removeObject(forKey: "company_license")
        UserDefaults.standard.removeObject(forKey: "company_website")
        UserDefaults.standard.removeObject(forKey: "company_logo_data")
        UserDefaults.standard.removeObject(forKey: "finance_rate_percent")
        UserDefaults.standard.removeObject(forKey: "finance_term_months")
        UserDefaults.standard.removeObject(forKey: "finance_markup_percent")
        
        // Clear saved estimates
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let estimateURL = documents.appendingPathComponent("current_estimate.json")
        let estimatesListURL = documents.appendingPathComponent("estimates.json")
        
        try? FileManager.default.removeItem(at: estimateURL)
        try? FileManager.default.removeItem(at: estimatesListURL)
        
        // Clear templates (optional - you might want to keep these)
        // let templatesURL = documents.appendingPathComponent("system_templates.json")
        // let addOnTemplatesURL = documents.appendingPathComponent("addon_templates.json")
        // try? FileManager.default.removeItem(at: templatesURL)
        // try? FileManager.default.removeItem(at: addOnTemplatesURL)
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


