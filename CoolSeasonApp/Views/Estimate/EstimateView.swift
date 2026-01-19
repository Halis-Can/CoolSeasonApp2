//
//  EstimateView.swift
//  CoolSeasonApp
//

import SwiftUI
#if canImport(MessageUI)
import MessageUI
#endif

struct EstimateView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var estimateVM: EstimateViewModel
    @AppStorage("finance_markup_percent") private var financeMarkupPercent: Double = 0.0
    @State private var showingAddOnSheet: Bool = false
    @State private var showingActivity: Bool = false
    @State private var showingMail: Bool = false
    @State private var showingMessage: Bool = false
    @State private var pdfData: Data?
    
    var body: some View {
        NavigationSplitView {
            systemsList
        } detail: {
            detailPane
        }
        .navigationTitle("Estimate")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    // Try to add from a matching template, fallback to default template if none
                    let tonnage = 3.0
                    let equip: EquipmentType = .acFurnace
                    if let tmpl = settingsVM.systemTemplate(for: tonnage, equipment: equip) {
                        estimateVM.addSystem(from: tmpl)
                    } else {
                        let options: [SystemOption] = [
                            SystemOption(tier: .good, seer: 14, stage: "Single", tonnage: tonnage, price: 6800, imageName: "snow"),
                            SystemOption(tier: .better, seer: 16, stage: "Two-Stage", tonnage: tonnage, price: 8400, imageName: "wind"),
                            SystemOption(tier: .best, seer: 18, stage: "Variable Speed", tonnage: tonnage, price: 10400, imageName: "sun.max")
                        ]
                        let sys = EstimateSystem(name: "System #\(estimateVM.currentEstimate.systems.count + 1)", tonnage: tonnage, equipmentType: equip, options: options)
                        estimateVM.addSystem(from: sys)
                    }
                } label: {
                    Label("Add System", systemImage: "plus")
                }
                
                Menu {
                    Button {
                        generatePDF()
                        showingActivity = true
                    } label: { Label("Share PDF", systemImage: "square.and.arrow.up") }
                    
                    Button {
                        generatePDF()
                        showingMail = true
                    } label: { Label("Email PDF", systemImage: "envelope") }
                        .disabled(!canSendMail())
                    
                    Button {
                        generatePDF()
                        showingMessage = true
                    } label: { Label("SMS PDF", systemImage: "message") }
                        .disabled(!canSendText())
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingAddOnSheet) {
            AddOnTemplatePicker { template in
                estimateVM.addAddOn(from: template)
            }
            .environmentObject(settingsVM)
        }
        .sheet(isPresented: $showingActivity) {
            if let data = pdfData {
                ActivityView(activityItems: [data, "CoolSeason Estimate.pdf"])
            }
        }
        #if canImport(MessageUI)
        .sheet(isPresented: $showingMail) {
            if let data = pdfData {
                MailComposerView(
                    subject: "CoolSeason Estimate",
                    recipients: estimateVM.currentEstimate.email.isEmpty ? [] : [estimateVM.currentEstimate.email],
                    body: "Please find your HVAC estimate attached.",
                    attachments: [(data, "application/pdf", "CoolSeasonEstimate.pdf")]
                )
            }
        }
        .sheet(isPresented: $showingMessage) {
            if let data = pdfData {
                MessageComposerView(
                    recipients: estimateVM.currentEstimate.phone.isEmpty ? [] : [estimateVM.currentEstimate.phone],
                    body: "Your CoolSeason estimate is attached.",
                    attachments: [(data, "com.adobe.pdf", "CoolSeasonEstimate.pdf")]
                )
            }
        }
        #endif
    }
    
    private var systemsList: some View {
        List {
            Section("Customer") {
                TextField("Name", text: binding(\.customerName))
                TextField("Address", text: binding(\.address))
                TextField("Email", text: binding(\.email))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                TextField("Phone", text: binding(\.phone))
                    .keyboardType(.phonePad)
            }
            
            Section("Systems") {
                ForEach(estimateVM.currentEstimate.systems) { system in
                    NavigationLink(value: system.id) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(system.name)
                                    .font(.headline)
                                Text("\(system.equipmentType.rawValue) • \(formatTonnage(system.tonnage))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let selected = system.options.first(where: { $0.isSelectedByCustomer }) {
                                Text(formatCurrency(selected.price))
                                    .bold()
                            } else {
                                Text("Select option")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tag(system.id)
                }
                .onDelete { indexSet in
                    // Collect IDs safely first, then delete
                    let systemsArray = estimateVM.currentEstimate.systems
                    let idsToDelete: [UUID] = indexSet.compactMap { idx -> UUID? in
                        guard idx < systemsArray.count else { return nil }
                        return systemsArray[idx].id
                    }
                    idsToDelete.forEach(estimateVM.removeSystem)
                }
            }
            
            Section("Add-Ons") {
                ForEach(estimateVM.currentEstimate.addOns) { addon in
                    HStack {
                        Toggle(isOn: bindingForAddOnEnabled(addon.id)) {
                            VStack(alignment: .leading) {
                                Text(addon.name)
                                Text(addon.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(formatCurrency(addon.price))
                            .bold()
                    }
                }
                .onDelete { indexSet in
                    // Collect IDs safely first, then delete
                    let addOnsArray = estimateVM.currentEstimate.addOns
                    let idsToDelete: [UUID] = indexSet.compactMap { idx -> UUID? in
                        guard idx < addOnsArray.count else { return nil }
                        return addOnsArray[idx].id
                    }
                    idsToDelete.forEach(estimateVM.removeAddOn)
                }
                
                Button {
                    showingAddOnSheet = true
                } label: {
                    Label("Add from Templates", systemImage: "plus.circle")
                }
            }
            
            Section("Totals") {
                HStack {
                    Text("Systems Subtotal")
                    Spacer()
                    Text(formatCurrency(estimateVM.currentEstimate.systemsSubtotal))
                }
                HStack {
                    Text("Add-Ons Subtotal")
                    Spacer()
                    Text(formatCurrency(estimateVM.currentEstimate.addOnsSubtotal))
                }
                HStack {
                    Text("Grand Total")
                        .bold()
                    Spacer()
                    let factor = 1 + (financeMarkupPercent / 100.0)
                    let totalWithMarkup = estimateVM.currentEstimate.grandTotal * factor
                    Text(formatCurrency(totalWithMarkup))
                        .bold()
                }
            }
        }
        .navigationDestination(for: UUID.self) { systemId in
            if let system = estimateVM.currentEstimate.systems.first(where: { $0.id == systemId }) {
                SystemDetailView(system: system)
            }
        }
    }
    
    private var detailPane: some View {
        VStack(spacing: 16) {
            Text("Capture Signature")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            SignatureView(signatureData: Binding(
                get: { estimateVM.currentEstimate.customerSignatureImageData },
                set: { newData in
                    estimateVM.currentEstimate.customerSignatureImageData = newData
                    estimateVM.recalculateTotals()
                }
            ))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()
        }
    }
    
    private func binding<T>(_ keyPath: WritableKeyPath<Estimate, T>) -> Binding<T> {
        Binding(get: { estimateVM.currentEstimate[keyPath: keyPath] },
                set: { estimateVM.currentEstimate[keyPath: keyPath] = $0 })
    }
    
    private func bindingForAddOnEnabled(_ id: UUID) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                estimateVM.currentEstimate.addOns.first(where: { $0.id == id })?.enabled ?? true
            },
            set: { newValue in
                estimateVM.setAddOnEnabled(id, enabled: newValue)
            }
        )
    }
    
    private func generatePDF() {
        pdfData = EstimatePDFRenderer.render(estimate: estimateVM.currentEstimate)
    }
}

// MARK: - Subviews

private struct SystemDetailView: View {
    @EnvironmentObject var estimateVM: EstimateViewModel
    let system: EstimateSystem
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                systemHeader
                optionsRow
                existingSystemForm
            }
            .padding()
        }
        .navigationTitle(system.name)
    }
    
    private var systemHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(system.name)
                    .font(.title2).bold()
                Spacer()
                Toggle("Enabled", isOn: bindingForSystem(\.enabled))
                    .labelsHidden()
            }
            HStack {
                Picker("Type", selection: bindingForSystem(\.equipmentType)) {
                    ForEach(EquipmentType.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.menu)
                Stepper("Tonnage: \(formatTonnage(bindingForSystem(\.tonnage).wrappedValue))",
                        value: bindingForSystem(\.tonnage), in: 1...6, step: 0.5)
            }
        }
    }
    
    private var optionsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Options").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(system.options) { option in
                        SystemOptionCard(option: option, isSelected: option.isSelectedByCustomer) {
                            estimateVM.selectOption(systemId: system.id, optionId: option.id)
                        }
                        .frame(width: 320)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var existingSystemForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Existing System (Optional)").font(.headline)
            Grid(alignment: .leading) {
                GridRow {
                    TextField("Brand", text: bindingForSystemOptional(\.existingBrand))
                    TextField("Model", text: bindingForSystemOptional(\.existingModel))
                }
                GridRow {
                    TextField("Location", text: bindingForSystemOptional(\.existingLocation))
                    TextField("Age (years)", text: bindingForSystemIntOptional(\.existingAgeYears))
                        .keyboardType(.numberPad)
                }
                GridRow {
                    TextField("Notes", text: bindingForSystemOptional(\.existingNotes))
                }
            }
        }
    }
    
    private func bindingForSystem<T>(_ keyPath: WritableKeyPath<EstimateSystem, T>) -> Binding<T> {
        Binding(
            get: {
                estimateVM.currentEstimate.systems.first(where: { $0.id == system.id })?[keyPath: keyPath] ?? system[keyPath: keyPath]
            },
            set: { newValue in
                guard let idx = estimateVM.currentEstimate.systems.firstIndex(where: { $0.id == system.id }) else { return }
                estimateVM.currentEstimate.systems[idx][keyPath: keyPath] = newValue
                estimateVM.recalculateTotals()
            }
        )
    }
    
    private func bindingForSystemOptional(_ keyPath: WritableKeyPath<EstimateSystem, String?>) -> Binding<String> {
        Binding<String>(
            get: {
                estimateVM.currentEstimate.systems.first(where: { $0.id == system.id })?[keyPath: keyPath] ?? ""
            },
            set: { newValue in
                guard let idx = estimateVM.currentEstimate.systems.firstIndex(where: { $0.id == system.id }) else { return }
                estimateVM.currentEstimate.systems[idx][keyPath: keyPath] = newValue.isEmpty ? nil : newValue
                estimateVM.recalculateTotals()
            }
        )
    }
    
    private func bindingForSystemIntOptional(_ keyPath: WritableKeyPath<EstimateSystem, Int?>) -> Binding<String> {
        Binding<String>(
            get: {
                if let v = estimateVM.currentEstimate.systems.first(where: { $0.id == system.id })?[keyPath: keyPath] {
                    return String(v)
                }
                return ""
            },
            set: { newValue in
                guard let idx = estimateVM.currentEstimate.systems.firstIndex(where: { $0.id == system.id }) else { return }
                estimateVM.currentEstimate.systems[idx][keyPath: keyPath] = Int(newValue)
                estimateVM.recalculateTotals()
            }
        )
    }
}

private struct SystemOptionCard: View {
    let option: SystemOption
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(option.tier.displayName)
                    .font(.headline)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .padding(.bottom, 4)
            
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.tertiarySystemFill))
                    .frame(height: 140)
                if let imageName = option.imageName, UIImage(systemName: imageName) != nil {
                    Image(systemName: imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .foregroundStyle(Color.accentColor)
                } else {
                    Image(systemName: "shippingbox")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .foregroundStyle(Color.accentColor)
                }
            }
            
            Text("\(option.seer, specifier: "%.0f") SEER • \(option.stage)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if !option.advantages.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(option.advantages.prefix(3), id: \.self) { adv in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal")
                            Text(adv)
                        }
                        .font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }
            
            HStack {
                Text(formatCurrency(option.price))
                    .font(.title3).bold()
                Spacer()
                Button(action: onSelect) {
                    Text(isSelected ? "Selected" : "Select")
                        .frame(maxWidth: 120)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.green : Color(UIColor.separator), lineWidth: isSelected ? 2 : 1)
        )
    }
}

private struct AddOnTemplatePicker: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsVM: SettingsViewModel
    let onPick: (AddOnTemplate) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(settingsVM.addOnTemplates.filter { $0.enabled }) { tmpl in
                    Button {
                        onPick(tmpl)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(tmpl.name)
                                Text(tmpl.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if tmpl.freeWhenTierIsBest {
                                Text("Free w/ Best").font(.caption2).padding(4).background(Color.green.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            Text(formatCurrency(tmpl.defaultPrice))
                                .bold()
                        }
                    }
                }
            }
            .navigationTitle("Add-On Templates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Helpers

func formatCurrency(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.locale = .current
    return f.string(from: NSNumber(value: value)) ?? "$0.00"
}

func formatTonnage(_ value: Double) -> String {
    if value == floor(value) {
        return "\(Int(value)) Ton"
    } else {
        return "\(value) Ton"
    }
}

#if canImport(MessageUI)
private func canSendMail() -> Bool { MFMailComposeViewController.canSendMail() }
private func canSendText() -> Bool { MFMessageComposeViewController.canSendText() }
#else
private func canSendMail() -> Bool { false }
private func canSendText() -> Bool { false }
#endif


