//
//  SystemTemplatesListView.swift
//  CoolSeasonApp
//

import SwiftUI

struct SystemTemplatesListView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var editingItem: SheetItem? = nil
    @State private var selectedType: EquipmentType = .acCondenserOnly
    
    private let categories: [EquipmentType] = [
        .coilOnly, .acCondenserOnly, .furnaceOnly, .heatPumpOnly, .airHandlerOnly
    ]
    
    struct SheetItem: Identifiable { let id: UUID }
    
    var body: some View {
        VStack(spacing: 16) {
            Picker("Category", selection: $selectedType) {
                ForEach(categories) { t in
                    Text(displayName(for: t)).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 700)
            
            List {
                ForEach(filteredTemplates) { tmpl in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tmpl.name)
                                .font(.headline)
                            Text("\(capacityLabel(for: tmpl)) • \(tmpl.equipmentType.rawValue) • \(tiersSummary(tmpl))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            settingsVM.systemTemplates.removeAll { $0.id == tmpl.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingItem = SheetItem(id: tmpl.id)
                    }
                }
                .onDelete { indexSet in
                    // Collect IDs safely first, then delete
                    let templatesArray = filteredTemplates
                    let idsToDelete: [UUID] = indexSet.compactMap { idx -> UUID? in
                        guard idx < templatesArray.count else { return nil }
                        return templatesArray[idx].id
                    }
                    settingsVM.systemTemplates.removeAll { idsToDelete.contains($0.id) }
                }
            }
            .frame(maxWidth: 900)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
        .background(CoolGradientBackground())
        .navigationTitle("System Templates")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    var new = makeDefaultTemplate()
                    new.equipmentType = selectedType
                    // Pick sensible default size for Furnace vs others
                    if selectedType == .furnaceOnly {
                        new.tonnage = 70000
                        new.name = "Furnace \(Int(new.tonnage)) BTU"
                    } else {
                        new.tonnage = 3.0
                        new.name = "\(displayName(for: selectedType)) \(formatTonnage(new.tonnage))"
                    }
                    settingsVM.systemTemplates.append(new)
                    editingItem = SheetItem(id: new.id)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editingItem) { item in
            if let binding = bindingForTemplate(item.id) {
                NavigationView {
                    SystemTemplateEditView(systemTemplate: binding)
                        .environmentObject(settingsVM)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            } else {
                VStack {
                    Text("Template not found")
                        .font(.headline)
                    Text("ID: \(item.id.uuidString)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }
    
    private var filteredTemplates: [EstimateSystem] {
        settingsVM.systemTemplates.filter { $0.equipmentType == selectedType }
    }
    
    private func tiersSummary(_ tmpl: EstimateSystem) -> String {
        let tiers = tmpl.options.map { $0.tier.displayName }.sorted()
        return tiers.joined(separator: "/")
    }
    
    private func capacityLabel(for tmpl: EstimateSystem) -> String {
        if tmpl.equipmentType == .furnaceOnly {
            let btus = Int(tmpl.tonnage)
            return "\(btus.formatted(.number.grouping(.automatic))) BTU"
        } else {
            return formatTonnage(tmpl.tonnage)
        }
    }
    
    private func displayName(for type: EquipmentType) -> String {
        switch type {
        case .acCondenserOnly: return "AC Condenser"
        case .coilOnly: return "AC Coil"
        case .furnaceOnly: return "Furnace"
        case .heatPumpOnly: return "Heat Pump"
        case .airHandlerOnly: return "Air Handler"
        default: return type.rawValue
        }
    }
    
    private func bindingForTemplate(_ id: UUID) -> Binding<EstimateSystem>? {
        guard let idx = settingsVM.systemTemplates.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { settingsVM.systemTemplates[idx] },
            set: { settingsVM.systemTemplates[idx] = $0 }
        )
    }
    
    private func makeDefaultTemplate() -> EstimateSystem {
        let ton: Double = 3.0
        let opts = [
            SystemOption(tier: .good, seer: 14, stage: "Single", tonnage: ton, price: 7000),
            SystemOption(tier: .better, seer: 16, stage: "Two-Stage", tonnage: ton, price: 8600),
            SystemOption(tier: .best, seer: 18, stage: "Variable Speed", tonnage: ton, price: 10600)
        ]
        return EstimateSystem(name: "3 Ton AC + Furnace", tonnage: ton, equipmentType: .acFurnace, options: opts)
    }
}


