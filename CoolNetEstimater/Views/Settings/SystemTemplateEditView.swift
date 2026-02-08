//
//  SystemTemplateEditView.swift
//  CoolNetEstimater
//

import SwiftUI

struct SystemTemplateEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsVM: SettingsViewModel
    @Binding var systemTemplate: EstimateSystem
    
    private let templateAllowedTonnages: [Double] = [1.5,2,2.5,3,3.5,4,4.5,5,5.5]
    private let furnaceBTUOptions: [Int] = [40000, 45000, 60000, 70000, 80000, 90000, 100000, 110000]
    private let allowedEquipmentTypes: [EquipmentType] = [
        .acCondenserOnly, .coilOnly, .acCondenserCoil, .acCondenserCoilFurnace, .furnaceOnly, .heatPumpOnly, .airHandlerOnly
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // Context header: show selected equipment type and size
            VStack(spacing: 2) {
                Text(displayName(for: systemTemplate.equipmentType))
                    .font(.title2).bold()
                Text(currentCapacityLabel(systemTemplate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            Form {
                Section("System") {
                    TextField("Name", text: $systemTemplate.name)
                    Picker("Equipment Type", selection: $systemTemplate.equipmentType) {
                        ForEach(allowedEquipmentTypes) { t in
                            Text(displayName(for: t)).tag(t)
                        }
                    }
                    if systemTemplate.equipmentType == .acCondenserCoil {
                        Button {
                            if let composite = settingsVM.buildCondenserCoilComposite(for: systemTemplate.tonnage) {
                                systemTemplate.options = composite.options
                                if !systemTemplate.name.contains("AC Condenser + Coil") {
                                    systemTemplate.name = composite.name
                                }
                            }
                        } label: {
                            Label("Build from AC Condenser + AC Coil Templates", systemImage: "wand.and.stars")
                        }
                    }
                    if systemTemplate.equipmentType == .acCondenserCoilFurnace {
                        Button {
                            let btus = systemTemplate.furnaceBTU ?? 70000
                            if let composite = settingsVM.buildCondenserCoilFurnaceComposite(tonnage: systemTemplate.tonnage, furnaceBTU: btus) {
                                systemTemplate.options = composite.options
                                systemTemplate.name = composite.name
                            }
                        } label: {
                            Label("Build from AC Condenser + AC Coil + Furnace", systemImage: "wand.and.stars")
                        }
                    }
                    if systemTemplate.equipmentType == .furnaceOnly {
                        Picker("Capacity", selection: Binding<Double>(
                            get: { systemTemplate.tonnage },
                            set: { systemTemplate.tonnage = $0 }
                        )) {
                            ForEach(furnaceBTUOptions, id: \.self) { btus in
                                Text("\(btus.formatted(.number.grouping(.automatic))) BTU")
                                    .tag(Double(btus))
                            }
                        }
                    } else if systemTemplate.equipmentType == .acCondenserCoilFurnace {
                        Picker("Tonnage", selection: $systemTemplate.tonnage) {
                            ForEach(templateAllowedTonnages, id: \.self) { t in
                                Text(formatTonnage(t)).tag(t)
                            }
                        }
                        Picker("Furnace BTU", selection: Binding<Double>(
                            get: { systemTemplate.furnaceBTU ?? 70000 },
                            set: { systemTemplate.furnaceBTU = $0 }
                        )) {
                            ForEach(furnaceBTUOptions, id: \.self) { btus in
                                Text("\(btus.formatted(.number.grouping(.automatic))) BTU")
                                    .tag(Double(btus))
                            }
                        }
                    } else {
                        Picker("Tonnage", selection: $systemTemplate.tonnage) {
                            ForEach(templateAllowedTonnages, id: \.self) { t in
                                Text(formatTonnage(t)).tag(t)
                            }
                        }
                    }
                }
                Section {
                    ForEach(Tier.allCases) { tier in
                        if let idx = systemTemplate.options.firstIndex(where: { $0.tier == tier }) {
                            OptionEditorView(option: $systemTemplate.options[idx], equipmentType: systemTemplate.equipmentType, tonnage: systemTemplate.tonnage)
                        } else {
                            Button("Add \(tier.rawValue)") {
                                systemTemplate.options.append(
                                    SystemOption(tier: tier, seer: 14, stage: "Single", tonnage: systemTemplate.tonnage, price: 0)
                                )
                            }
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Options (Good / Better / Best)")
                        Text("\(displayName(for: systemTemplate.equipmentType)) • \(currentCapacityLabel(systemTemplate))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Button {
                        autoFillModelsAndWarranty()
                    } label: {
                        Label("Auto-Fill Model Codes & Warranty", systemImage: "sparkles")
                    }
                }
            }
            .frame(maxWidth: 900)
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
        .background(Color(.systemBackground))
        .navigationTitle("Edit System Template")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { dismiss() }
            }
        }
    }
    
    // Auto-fill missing model numbers (5 letters + numeric tag) and warranty text
    private func autoFillModelsAndWarranty() {
        let warranty = "WARRANTY: 10 years manufacturer warranty, 1 year labor warranty"
        func fiveLetters(_ seed: String) -> String {
            let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
            var hash = abs(seed.hashValue)
            var s = ""
            for _ in 0..<5 {
                s.append(letters[hash % letters.count])
                hash = hash &* 1103515245 &+ 12345
            }
            return String(s.prefix(5))
        }
        func numericTag() -> String {
            if systemTemplate.equipmentType == .furnaceOnly {
                return String(Int((systemTemplate.tonnage / 1000.0).rounded()))
            } else {
                let steps = Int(round((systemTemplate.tonnage - 1.5) / 0.5))
                let value = 18 + (steps * 6)
                return String(value)
            }
        }
        let tag = numericTag()
        for idx in systemTemplate.options.indices {
            let tier = systemTemplate.options[idx].tier
            let seed = "\(systemTemplate.equipmentType.rawValue)-\(systemTemplate.tonnage)-\(tier)"
            let letters = fiveLetters(seed)
            let model = "\(letters)-\(tag)"
            switch systemTemplate.equipmentType {
            case .acCondenserOnly:
                if (systemTemplate.options[idx].outdoorModel ?? "").isEmpty {
                    systemTemplate.options[idx].outdoorModel = model
                }
            case .coilOnly, .airHandlerOnly:
                if (systemTemplate.options[idx].indoorModel ?? "").isEmpty {
                    systemTemplate.options[idx].indoorModel = model
                }
            case .heatPumpOnly:
                if (systemTemplate.options[idx].outdoorModel ?? "").isEmpty {
                    systemTemplate.options[idx].outdoorModel = model
                }
                if (systemTemplate.options[idx].indoorModel ?? "").isEmpty {
                    systemTemplate.options[idx].indoorModel = model
                }
            case .furnaceOnly:
                if (systemTemplate.options[idx].furnaceModel ?? "").isEmpty {
                    systemTemplate.options[idx].furnaceModel = model
                }
            default:
                break
            }
            if (systemTemplate.options[idx].warrantyText ?? "").isEmpty {
                systemTemplate.options[idx].warrantyText = warranty
            }
        }
    }
}

private struct OptionEditorView: View {
    @Binding var option: SystemOption
    var equipmentType: EquipmentType
    var tonnage: Double
    
    private let stages = ["Single", "Two-Stage", "Variable Speed"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(option.tier.displayName).font(.headline)
                Spacer()
                Toggle("Show", isOn: $option.showToCustomer).labelsHidden()
            }
            HStack {
                Stepper("SEER: \(option.seer, specifier: "%.0f")", value: $option.seer, in: 13...24, step: 1)
                Spacer()
                Picker("Stage", selection: $option.stage) {
                    ForEach(stages, id: \.self) { s in
                        Text(s).tag(s)
                    }
                }
                .pickerStyle(.menu)
            }
            HStack {
                Text("Price")
                Spacer()
                TextField("0", value: $option.price, formatter: decimalFormatter)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 180)
                    .textFieldStyle(.roundedBorder)
            }
            // Reference caption under price: e.g., "2 Ton AC Condenser" or "80,000 BTU Furnace"
            Text("\(referenceCapacityLabel()) \(displayName(for: equipmentType))")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Outdoor Model", text: Binding(get: { option.outdoorModel ?? "" }, set: { option.outdoorModel = $0.isEmpty ? nil : $0 }))
            TextField("Indoor Model", text: Binding(get: { option.indoorModel ?? "" }, set: { option.indoorModel = $0.isEmpty ? nil : $0 }))
            TextField("Furnace Model", text: Binding(get: { option.furnaceModel ?? "" }, set: { option.furnaceModel = $0.isEmpty ? nil : $0 }))
            TextField("Warranty", text: Binding(get: { option.warrantyText ?? "" }, set: { option.warrantyText = $0.isEmpty ? nil : $0 }))
            TextField("Advantages (comma-separated)", text: Binding(
                get: { option.advantages.joined(separator: ", ") },
                set: { option.advantages = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
            ))
        }
        .padding(.vertical, 6)
    }
    
    private func referenceCapacityLabel() -> String {
        if equipmentType == .furnaceOnly {
            return "\(Int(tonnage).formatted(.number.grouping(.automatic))) BTU"
        } else {
            return formatTonnage(tonnage)
        }
    }
}

private let currencyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    return f
}()

private let decimalFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 2
    return f
}()

private func displayName(for type: EquipmentType) -> String {
    switch type {
    case .acCondenserOnly: return "AC Condenser"
    case .coilOnly: return "AC Coil"
    case .acCondenserCoil: return "AC Condenser + Coil"
    case .furnaceOnly: return "Furnace"
    case .heatPumpOnly: return "Heat Pump"
    case .airHandlerOnly: return "Air Handler"
    default: return type.rawValue
    }
}

private func currentCapacityLabel(_ sys: EstimateSystem) -> String {
    if sys.equipmentType == .furnaceOnly {
        return "\(Int(sys.tonnage).formatted(.number.grouping(.automatic))) BTU"
    } else {
        return formatTonnage(sys.tonnage)
    }
}


