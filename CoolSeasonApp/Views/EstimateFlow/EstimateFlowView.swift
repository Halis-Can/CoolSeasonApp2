//
//  EstimateFlowView.swift
//  CoolSeasonApp
//

import SwiftUI
#if canImport(MessageUI)
import MessageUI
#endif

struct EstimateFlowView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var estimateVM: EstimateViewModel
    
    enum Step: Int, CaseIterable {
        case customer, systems, options, addons, summary
        
        var title: String {
            switch self {
            case .customer: return "Customer Info"
            case .systems: return "System Setup"
            case .options: return "System Options"
            case .addons: return "Additional Equipment"
            case .summary: return "Final Summary"
            }
        }
    }
    
    @State private var step: Step
    
    init(startStep: Step = .customer) {
        _step = State(initialValue: startStep)
    }
    @State private var customerSaved: Bool = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar: Customer info lives here consistently
            SidebarCustomerForm(saved: $customerSaved)
        } detail: {
            // Detail: Wizard steps
            Group {
                switch step {
                case .customer:
                    CenteredScreen {
                        AppLogoHeader()
                        VStack(alignment: .center, spacing: 12) {
                            Text("Please enter customer information on the left, then tap Save.")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                            Button("Next") { goNext() }
                                .disabled(!customerSaved)
                                .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                case .systems:
                    CenteredScreen {
                        AppLogoHeader()
                        SystemsSetupScreen(onChange: handleSystemMetaChange, next: goNext, back: goBack)
                    }
                case .options:
                    CenteredScreen {
                        AppLogoHeader()
                        SystemOptionsScreen(next: goNext, back: goBack)
                    }
                case .addons:
                    CenteredScreen {
                        AppLogoHeader()
                        AdditionalEquipmentScreen(next: goNext, back: goBack)
                    }
                case .summary:
                    CenteredScreen {
                        AppLogoHeader()
                        FinalSummaryView(back: goBack)
                    }
                }
            }
            .navigationTitle(step.title)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if step != .customer {
                        Button("Back") { goBack() }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if step != .summary {
                        Button("Next") { goNext() }
                            .disabled(step == .customer && !customerSaved)
                    }
                }
            }
        }
        .background(CoolGradientBackground())
        .onAppear {
            if estimateVM.currentEstimate.systems.isEmpty {
                estimateVM.ensureSystemCount(1, settingsVM: settingsVM)
                estimateVM.attachTemplates(settingsVM.addOnTemplates)
            }
        }
    }
    
    private func goNext() {
        if let next = Step(rawValue: step.rawValue + 1) {
            step = next
        }
    }
    private func goBack() {
        if let prev = Step(rawValue: step.rawValue - 1) {
            step = prev
        }
    }
    
    private func handleSystemMetaChange(_ systemId: UUID) {
        estimateVM.replaceOptionsForSystem(systemId, using: settingsVM)
    }
}

// Sidebar with customer information always visible on the left
private struct SidebarCustomerForm: View {
    @EnvironmentObject var estimateVM: EstimateViewModel
    @Binding var saved: Bool
    @State private var isEditing: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppLogoHeader()
            Form {
                Section("Customer") {
                    LabeledContent("Name:") {
                        TextField("New Customer Name", text: binding(\.customerName))
                            .textInputAutocapitalization(.words)
                    }
                    LabeledContent("Address:") {
                        TextField("Street, City, ST ZIP", text: binding(\.address))
                            .textInputAutocapitalization(.words)
                    }
                    LabeledContent("Phone:") {
                        TextField("(555) 555-5555", text: binding(\.phone))
                            .keyboardType(.phonePad)
                    }
                    LabeledContent("Email:") {
                        TextField("name@example.com", text: binding(\.email))
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled(true)
                    }
                }
                .disabled(!isEditing)
                
                Section {
                    HStack {
                        Button {
                            saved = true
                            isEditing = false
                        } label: {
                            Label("Save", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isEditing || estimateVM.currentEstimate.customerName.trimmingCharacters(in: .whitespaces).isEmpty)
                        
                        Button {
                            isEditing = true
                            saved = false
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .padding([.horizontal, .top], 12)
        .background(CoolGradientBackground())
        .onAppear {
            isEditing = !saved
        }
    }
    
    private func binding<T>(_ keyPath: WritableKeyPath<Estimate, T>) -> Binding<T> {
        Binding(get: { estimateVM.currentEstimate[keyPath: keyPath] },
                set: { estimateVM.currentEstimate[keyPath: keyPath] = $0 })
    }
}

// Centers content on iPad screens with a comfortable max width
private struct CenteredScreen<Content: View>: View {
    private let contentView: Content
    init(@ViewBuilder content: () -> Content) {
        self.contentView = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            contentView
        }
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal)
        .padding(.top, 16)
    }
}

// MARK: - Customer Info

private struct CustomerInfoScreen: View {
    @EnvironmentObject var estimateVM: EstimateViewModel
    let next: () -> Void
    
    var body: some View {
        Form {
            Section("Customer") {
                TextField("Customer Name", text: binding(\.customerName))
                TextField("Address", text: binding(\.address))
                TextField("Phone", text: binding(\.phone))
                    .keyboardType(.phonePad)
                TextField("Email", text: binding(\.email))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            }
            Section {
                Button {
                    next()
                } label: {
                    Text("Start System Selection")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .scrollContentBackground(.hidden)
    }
    
    private func binding<T>(_ keyPath: WritableKeyPath<Estimate, T>) -> Binding<T> {
        Binding(get: { estimateVM.currentEstimate[keyPath: keyPath] },
                set: { estimateVM.currentEstimate[keyPath: keyPath] = $0 })
    }
}

// MARK: - Systems Setup

private let allowedTonnages: [Double] = [1.5,2,2.5,3,3.5,4,4.5,5,5.5]
private let furnaceBTUOptions: [Int] = [40000, 45000, 60000, 70000, 80000, 90000, 100000, 110000]
private let flowAllowedEquipmentTypes: [EquipmentType] = [
    .acCondenserOnly,
    .coilOnly,
    .furnaceOnly,
    .acCondenserCoil,
    .acCondenserCoilFurnace,
    .acFurnace,
    .heatPumpOnly,
    .airHandlerOnly,
    .heatPumpAirHandler
]

private struct SystemsSetupScreen: View {
    @EnvironmentObject var estimateVM: EstimateViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    let onChange: (UUID) -> Void
    let next: () -> Void
    let back: () -> Void
    @State private var systemCount: Int = 1
    @State private var editingIds: Set<UUID> = []
    @State private var savedIds: Set<UUID> = []
    
    var body: some View {
        Form {
            Section("How many systems?") {
                Picker("Systems", selection: $systemCount) {
                    ForEach(1..<4) { c in
                        Text("\(c)").tag(c)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: systemCount) { newValue in
                    estimateVM.ensureSystemCount(newValue, settingsVM: settingsVM)
                    // Reset editing/saved state on count change
                    editingIds = Set(estimateVM.currentEstimate.systems.map { $0.id })
                    savedIds = []
                }
            }
            
            ForEach(Array(estimateVM.currentEstimate.systems.enumerated()), id: \.element.id) { idx, system in
                Section("\(idx + 1). System") {
                    TextField("System name", text: Binding(
                        get: { system.name },
                        set: { estimateVM.updateSystemMeta(system.id, name: $0) }
                    ))
                    .disabled(!editingIds.contains(system.id))
                    
                    Picker("Equipment Type", selection: Binding(
                        get: { system.equipmentType },
                        set: { newVal in
                            estimateVM.updateSystemMeta(system.id, equipmentType: newVal)
                            onChange(system.id)
                            // Auto-name if using default placeholder
                            if system.name.hasPrefix("System #") {
                                let newName: String
                                if newVal == .furnaceOnly {
                                    newName = "\(displayName(for: newVal)) \(Int(system.tonnage)) BTU"
                                } else if newVal == .acCondenserCoilFurnace {
                                    let btus = Int(system.furnaceBTU ?? 70000)
                                    newName = "\(displayName(for: newVal)) \(formatTonnage(system.tonnage)) • \(btus.formatted(.number.grouping(.automatic))) BTU"
                                } else {
                                    newName = "\(displayName(for: newVal)) \(formatTonnage(system.tonnage))"
                                }
                                estimateVM.updateSystemMeta(system.id, name: newName)
                            }
                        }
                    )) {
                        ForEach(flowAllowedEquipmentTypes) { e in
                            Text(displayName(for: e)).tag(e)
                        }
                    }
                    .disabled(!editingIds.contains(system.id))
                    
                    if system.equipmentType == .furnaceOnly {
                        Picker("Heating BTU", selection: Binding(
                            get: { system.tonnage },
                            set: { newVal in
                                estimateVM.updateSystemMeta(system.id, tonnage: newVal)
                                onChange(system.id)
                                if system.name.hasPrefix("System #") || system.name.contains("BTU") {
                                    let newName = "\(displayName(for: system.equipmentType)) \(Int(newVal)) BTU"
                                    estimateVM.updateSystemMeta(system.id, name: newName)
                                }
                            }
                        )) {
                            ForEach(furnaceBTUOptions, id: \.self) { btus in
                                Text("\(btus.formatted(.number.grouping(.automatic))) BTU")
                                    .tag(Double(btus))
                            }
                        }
                        .disabled(!editingIds.contains(system.id))
                    } else if system.equipmentType == .acCondenserCoilFurnace {
                        // Show both tonnage and explicit furnace BTU
                        Picker("Tonnage", selection: Binding(
                            get: { system.tonnage },
                            set: { newVal in
                                estimateVM.updateSystemMeta(system.id, tonnage: newVal)
                                onChange(system.id)
                                // Update auto name if placeholder-style
                                if system.name.hasPrefix("System #") || system.name.contains("Ton") || system.name.contains("BTU") {
                                    let btusVal = Int(system.furnaceBTU ?? 70000)
                                    let newName = "\(displayName(for: system.equipmentType)) \(formatTonnage(newVal)) • \(btusVal.formatted(.number.grouping(.automatic))) BTU"
                                    estimateVM.updateSystemMeta(system.id, name: newName)
                                }
                            }
                        )) {
                            ForEach(allowedTonnages, id: \.self) { t in
                                Text(formatTonnage(t)).tag(t)
                            }
                        }
                        .disabled(!editingIds.contains(system.id))
                        Picker("Furnace BTU", selection: Binding(
                            get: { system.furnaceBTU ?? 70000 },
                            set: { newVal in
                                if let idx = estimateVM.currentEstimate.systems.firstIndex(where: { $0.id == system.id }) {
                                    estimateVM.currentEstimate.systems[idx].furnaceBTU = newVal
                                    onChange(system.id)
                                    // Update auto name if placeholder-style
                                    if system.name.hasPrefix("System #") || system.name.contains("Ton") || system.name.contains("BTU") {
                                        let newName = "\(displayName(for: system.equipmentType)) \(formatTonnage(system.tonnage)) • \(Int(newVal).formatted(.number.grouping(.automatic))) BTU"
                                        estimateVM.updateSystemMeta(system.id, name: newName)
                                    }
                                }
                            }
                        )) {
                            ForEach(furnaceBTUOptions, id: \.self) { btus in
                                Text("\(btus.formatted(.number.grouping(.automatic))) BTU")
                                    .tag(Double(btus))
                            }
                        }
                        .disabled(!editingIds.contains(system.id))
                    } else {
                        Picker("Tonnage", selection: Binding(
                            get: { system.tonnage },
                            set: { newVal in
                                estimateVM.updateSystemMeta(system.id, tonnage: newVal)
                                onChange(system.id)
                                if system.name.hasPrefix("System #") || system.name.contains("Ton") {
                                    let newName = "\(displayName(for: system.equipmentType)) \(formatTonnage(newVal))"
                                    estimateVM.updateSystemMeta(system.id, name: newName)
                                }
                            }
                        )) {
                            ForEach(allowedTonnages, id: \.self) { t in
                                Text(formatTonnage(t)).tag(t)
                            }
                        }
                        .disabled(!editingIds.contains(system.id))
                    }
                    
                    HStack {
                        let isEditing = editingIds.contains(system.id)
                        let isSaved = savedIds.contains(system.id)
                        Button {
                            savedIds.insert(system.id)
                            editingIds.remove(system.id)
                        } label: {
                            Label("Save", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSaved || !isEditing)
                        
                        Button {
                            editingIds.insert(system.id)
                            savedIds.remove(system.id)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isEditing)
                    }
                }
            }
            
            Section {
                HStack {
                    Button("Back") { back() }
                    Spacer()
                    Button("Next") { next() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!allSystemsSaved)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .onAppear {
            systemCount = max(1, min(3, estimateVM.currentEstimate.systems.count))
            editingIds = Set(estimateVM.currentEstimate.systems.map { $0.id })
            savedIds = []
        }
    }
    
    private var allSystemsSaved: Bool {
        let ids = Set(estimateVM.currentEstimate.systems.map { $0.id })
        return !ids.isEmpty && savedIds.isSuperset(of: ids)
    }
}

// Shared display mapping for equipment type labels in flow
private func displayName(for type: EquipmentType) -> String {
    switch type {
    case .acCondenserOnly: return "AC Condenser"
    case .coilOnly: return "AC Coil"
    case .acCondenserCoil: return "AC Condenser + Coil"
    case .acCondenserCoilFurnace: return "AC Condenser + Coil + Furnace"
    case .acFurnace: return "AC + Furnace"
    case .furnaceOnly: return "Furnace"
    case .heatPumpOnly: return "Heat Pump"
    case .heatPumpAirHandler: return "Heat Pump + Air Handler"
    case .airHandlerOnly: return "Air Handler"
    default: return type.rawValue
    }
}

// MARK: - Options

private struct SystemOptionsScreen: View {
    @EnvironmentObject var estimateVM: EstimateViewModel
    let next: () -> Void
    let back: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(estimateVM.currentEstimate.systems) { system in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(system.name).font(.headline)
                        VStack(spacing: 12) {
                            ForEach(filteredOptions(for: system)) { opt in
                                OptionEditableRow(option: opt, systemId: system.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .padding(.horizontal)
                }
                HStack {
                    Button("Back") { back() }
                    Spacer()
                    Button("Next") { next() }.buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
    }
    
    private func filteredOptions(for system: EstimateSystem) -> [SystemOption] {
        // Always show all tiers for every system/tonnage as requested
        return system.options
    }
}

private struct OptionEditableRow: View {
    @EnvironmentObject var estimateVM: EstimateViewModel
    let option: SystemOption
    let systemId: UUID
    @State private var showToCustomer: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(option.tier.displayName).font(.headline)
                Spacer()
                Toggle("Show", isOn: Binding(
                    get: { option.showToCustomer },
                    set: { estimateVM.setOptionVisibility(systemId: systemId, optionId: option.id, showToCustomer: $0) }
                ))
                .labelsHidden()
            }
            // Price prominently on the left
            Text(formatCurrency(option.price)).bold()
            Text("\(option.seer, specifier: "%.0f") SEER • \(option.stage) • \(formatTonnage(option.tonnage))")
                .foregroundStyle(.secondary)
            if let ref = systemReferenceLabel(systemId: systemId) {
                Text(ref)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if option.outdoorModel != nil || option.indoorModel != nil || option.furnaceModel != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let m = option.outdoorModel, !m.isEmpty {
                        Text("Outdoor: \(m)").font(.caption)
                    }
                    if let m = option.indoorModel, !m.isEmpty {
                        Text("Indoor: \(m)").font(.caption)
                    }
                    if let m = option.furnaceModel, !m.isEmpty {
                        Text("Furnace: \(m)").font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }
            Text(formatCurrency(option.price)).bold()
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
            if let w = option.warrantyText, !w.isEmpty {
                Text("Warranty: \(w)").font(.caption).foregroundStyle(.secondary)
            }
            Button(action: { estimateVM.toggleOptionSelection(systemId: systemId, optionId: option.id) }) {
                Text(option.isSelectedByCustomer ? "Unselect" : "Select")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(option.isSelectedByCustomer ? Color.green : Color(UIColor.separator), lineWidth: option.isSelectedByCustomer ? 2 : 1)
        )
    }
    
    private func systemReferenceLabel(systemId: UUID) -> String? {
        guard let sys = estimateVM.currentEstimate.systems.first(where: { $0.id == systemId }) else { return nil }
        let cap: String
        if sys.equipmentType == .furnaceOnly {
            cap = "\(Int(sys.tonnage).formatted(.number.grouping(.automatic))) BTU"
        } else {
            cap = formatTonnage(sys.tonnage)
        }
        return "\(cap) \(displayName(for: sys.equipmentType))"
    }
}

// MARK: - Add-Ons

private struct AdditionalEquipmentScreen: View {
    @EnvironmentObject var estimateVM: EstimateViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    let next: () -> Void
    let back: () -> Void
    private let priceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }()
    
    var body: some View {
        Form {
            ForEach(Array(estimateVM.currentEstimate.systems.enumerated()), id: \.element.id) { sidx, system in
                Section("\(sidx + 1). System – \(system.name)") {
                    let items = estimateVM.currentEstimate.addOns.filter { $0.systemId == system.id }
                    ForEach(items, id: \.id) { addon in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { addon.enabled },
                                set: { estimateVM.setAddOnEnabled(addon.id, enabled: $0) }
                            )) {
                                VStack(alignment: .leading) {
                                    Text(addon.name)
                                    Text(addon.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(formatCurrency(addon.price))
                                .frame(width: 120, alignment: .trailing)
                        }
                    }
                }
            }
            Section {
                HStack {
                    Button("Back") { back() }
                    Spacer()
                    Button("Next") { next() }.buttonStyle(.borderedProminent)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .onAppear {
            // Ensure per-system add-ons exist and mirror settings templates
            estimateVM.attachTemplates(settingsVM.addOnTemplates)
        }
    }
}


