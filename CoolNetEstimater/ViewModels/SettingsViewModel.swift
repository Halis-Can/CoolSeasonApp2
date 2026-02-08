//
//  SettingsViewModel.swift
//  CoolNetEstimater
//

import Foundation
import SwiftUI
import Combine
 
struct TemplatesBundle: Codable {
    var systemTemplates: [EstimateSystem]
    var addOnTemplates: [AddOnTemplate]
}

final class SettingsViewModel: ObservableObject {
    enum ThemeMode: String, CaseIterable, Identifiable, Codable {
        case system, light, dark
        var id: String { rawValue }
        var title: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
    }
    
    @Published var systemTemplates: [EstimateSystem] {
        didSet { persistSystemTemplates() }
    }
    @Published var addOnTemplates: [AddOnTemplate] {
        didSet { persistAddOnTemplates() }
    }
    @Published var themeMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: "cs_theme_mode")
        }
    }
    
    private let systemTemplatesURL: URL
    private let addOnTemplatesURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        systemTemplatesURL = documents.appendingPathComponent("system_templates.json")
        addOnTemplatesURL = documents.appendingPathComponent("addon_templates.json")
        if let savedTheme = UserDefaults.standard.string(forKey: "cs_theme_mode"),
           let mode = ThemeMode(rawValue: savedTheme) {
            themeMode = mode
        } else {
            themeMode = .system
        }
        
        if let loadedSystems: [EstimateSystem] = try? Self.load([EstimateSystem].self, from: systemTemplatesURL),
           let loadedAddOns: [AddOnTemplate] = try? Self.load([AddOnTemplate].self, from: addOnTemplatesURL) {
            systemTemplates = loadedSystems
            addOnTemplates = loadedAddOns
        } else if let bundle = Self.loadFromBundleSeed() {
            systemTemplates = bundle.systemTemplates
            addOnTemplates = bundle.addOnTemplates
        } else {
            systemTemplates = Self.defaultSystemTemplates()
            addOnTemplates = Self.defaultAddOnTemplates()
        }
        // If loaded files exist but are empty, reseed with bundle/defaults
        if systemTemplates.isEmpty {
            if let bundle = Self.loadFromBundleSeed() {
                systemTemplates = bundle.systemTemplates
            } else {
                systemTemplates = Self.defaultSystemTemplates()
            }
        }
        if addOnTemplates.isEmpty {
            if let bundle = Self.loadFromBundleSeed() {
                addOnTemplates = bundle.addOnTemplates
            } else {
                addOnTemplates = Self.defaultAddOnTemplates()
            }
        }
        // Migration: ensure baseline templates exist for all categories/tonnages
        seedMissingTemplatesIfNeeded()
        
        persistSystemTemplates()
        persistAddOnTemplates()
    }
    
    // MARK: - Persistence
    
    private static func load<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func persistSystemTemplates() {
        do {
            let data = try encoder.encode(systemTemplates)
            try data.write(to: systemTemplatesURL, options: [.atomic])
        } catch {
            print("Persist system templates failed: \(error)")
        }
    }
    
    private func persistAddOnTemplates() {
        do {
            let data = try encoder.encode(addOnTemplates)
            try data.write(to: addOnTemplatesURL, options: [.atomic])
        } catch {
            print("Persist add-on templates failed: \(error)")
        }
    }
    
    private static func loadFromBundleSeed() -> TemplatesBundle? {
        guard let url = Bundle.main.url(forResource: "templates_seed", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TemplatesBundle.self, from: data)
    }
    
    // MARK: - Defaults
    
    private static func defaultSystemTemplates() -> [EstimateSystem] {
        // Build full template matrix based on provided table
        let tonnages: [Double] = [1.5, 2, 2.5, 3, 3.5, 4, 5]
        let furnaceBTUs: [Double] = [40000, 45000, 60000, 70000, 80000, 90000, 100000, 110000]
        
        var result: [EstimateSystem] = []
        
        // AC Coil
        for t in tonnages {
            result.append(EstimateSystem(
                name: "\(formatTonnage(t)) AC Coil",
                tonnage: t,
                equipmentType: .coilOnly,
                options: makeOptions(for: .coilOnly, capacity: t)
            ))
        }
        // AC Condenser
        for t in tonnages {
            result.append(EstimateSystem(
                name: "\(formatTonnage(t)) AC Condenser",
                tonnage: t,
                equipmentType: .acCondenserOnly,
                options: makeOptions(for: .acCondenserOnly, capacity: t)
            ))
        }
        // Heat Pump
        for t in tonnages {
            result.append(EstimateSystem(
                name: "\(formatTonnage(t)) Heat Pump",
                tonnage: t,
                equipmentType: .heatPumpOnly,
                options: makeOptions(for: .heatPumpOnly, capacity: t)
            ))
        }
        // Air Handler
        for t in tonnages {
            result.append(EstimateSystem(
                name: "\(formatTonnage(t)) Air Handler",
                tonnage: t,
                equipmentType: .airHandlerOnly,
                options: makeOptions(for: .airHandlerOnly, capacity: t)
            ))
        }
        // Furnace (capacity in BTU, stored in 'tonnage' for lookup convenience)
        for btu in furnaceBTUs {
            result.append(EstimateSystem(
                name: "\(Int(btu).formatted(.number.grouping(.automatic))) BTU Furnace",
                tonnage: btu,
                equipmentType: .furnaceOnly,
                options: makeOptions(for: .furnaceOnly, capacity: btu)
            ))
        }
        return result
    }
    
    // MARK: - Template option factory
    private static func makeOptions(for type: EquipmentType, capacity: Double) -> [SystemOption] {
        let caps: (good: Double, better: Double, best: Double, seerGood: Double, seerBetter: Double, seerBest: Double, stageGood: String, stageBetter: String, stageBest: String)
        switch type {
        case .acCondenserOnly:
            // Price scale ~ per ton
            let scale = capacity / 2.5
            caps = (
                good: roundTo50(4200 * scale),
                better: roundTo50(5200 * scale),
                best: roundTo50(6400 * scale),
                seerGood: 14, seerBetter: 16, seerBest: 18,
                stageGood: "Single", stageBetter: "Two-Stage", stageBest: "Variable Speed"
            )
        case .coilOnly:
            let scale = capacity / 2.5
            caps = (
                good: roundTo50(900 * scale),
                better: roundTo50(1100 * scale),
                best: roundTo50(1400 * scale),
                seerGood: 14, seerBetter: 16, seerBest: 18,
                stageGood: "Single", stageBetter: "Two-Stage", stageBest: "Variable Speed"
            )
        case .heatPumpOnly:
            let scale = capacity / 2.5
            caps = (
                good: roundTo50(5200 * scale),
                better: roundTo50(6800 * scale),
                best: roundTo50(8200 * scale),
                seerGood: 15, seerBetter: 17, seerBest: 19,
                stageGood: "Single", stageBetter: "Two-Stage", stageBest: "Variable Speed"
            )
        case .airHandlerOnly:
            let scale = capacity / 2.5
            caps = (
                good: roundTo50(1200 * scale),
                better: roundTo50(1500 * scale),
                best: roundTo50(1900 * scale),
                seerGood: 0, seerBetter: 0, seerBest: 0,
                stageGood: "Single", stageBetter: "Two-Stage", stageBest: "Variable Speed"
            )
        case .furnaceOnly:
            let scale = capacity / 80000.0
            caps = (
                good: roundTo50(1900 * scale),
                better: roundTo50(2400 * scale),
                best: roundTo50(2900 * scale),
                seerGood: 0, seerBetter: 0, seerBest: 0,
                stageGood: "Single", stageBetter: "Two-Stage", stageBest: "Variable Speed"
            )
        default:
            // Generic fallback
            let scale = capacity / 2.5
            caps = (
                good: roundTo50(4000 * scale),
                better: roundTo50(5200 * scale),
                best: roundTo50(6600 * scale),
                seerGood: 14, seerBetter: 16, seerBest: 18,
                stageGood: "Single", stageBetter: "Two-Stage", stageBest: "Variable Speed"
            )
        }
        // Common warranty text (editable later in the editor)
        let warranty = "WARRANTY: 10 years manufacturer warranty, 1 year labor warranty"
        // Helper to generate placeholder 5-letter model codes (deterministic per tier/type)
        func code(_ base: String) -> String {
            let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
            var hash = abs(base.hashValue)
            var s = ""
            for _ in 0..<5 {
                s.append(letters[hash % letters.count])
                hash /= 3 + (hash % 7)
            }
            return String(s.prefix(5))
        }
        // Numeric tag based on capacity to embed into model codes:
        // - For tonnage types: 1.5 -> 18, each +0.5 adds +6 (2.0 -> 24, 2.5 -> 30, ...)
        // - For furnace (BTU): 40_000 -> 40, 45_000 -> 45, etc.
        func numericTag(for type: EquipmentType, capacity: Double) -> String {
            switch type {
            case .furnaceOnly:
                let thousands = Int(round(capacity / 1000.0))
                return String(thousands)
            default:
                // capacity is tonnage
                let steps = Int(round((capacity - 1.5) / 0.5))
                let value = 18 + (steps * 6)
                return String(value)
            }
        }
        func model(_ prefix: String, type: EquipmentType, capacity: Double, tier: Tier) -> String {
            "\(code("\(prefix)-\(type.rawValue)-\(capacity)-\(tier)"))-\(numericTag(for: type, capacity: capacity))"
        }
        func optionFor(tier: Tier, seer: Double, stage: String, price: Double) -> SystemOption {
            switch type {
            case .acCondenserOnly:
                return SystemOption(tier: tier,
                                    seer: seer,
                                    stage: stage,
                                    tonnage: capacity,
                                    price: price,
                                    outdoorModel: model("COND", type: type, capacity: capacity, tier: tier),
                                    warrantyText: warranty)
            case .coilOnly, .airHandlerOnly:
                return SystemOption(tier: tier,
                                    seer: seer,
                                    stage: stage,
                                    tonnage: capacity,
                                    price: price,
                                    indoorModel: model("INDR", type: type, capacity: capacity, tier: tier),
                                    warrantyText: warranty)
            case .heatPumpOnly:
                return SystemOption(tier: tier,
                                    seer: seer,
                                    stage: stage,
                                    tonnage: capacity,
                                    price: price,
                                    outdoorModel: model("HPOD", type: type, capacity: capacity, tier: tier),
                                    indoorModel: model("HPIN", type: type, capacity: capacity, tier: tier),
                                    warrantyText: warranty)
            case .furnaceOnly:
                return SystemOption(tier: tier,
                                    seer: seer,
                                    stage: stage,
                                    tonnage: capacity,
                                    price: price,
                                    furnaceModel: model("FURN", type: type, capacity: capacity, tier: tier),
                                    warrantyText: warranty)
            default:
                return SystemOption(tier: tier,
                                    seer: seer,
                                    stage: stage,
                                    tonnage: capacity,
                                    price: price,
                                    warrantyText: warranty)
            }
        }
        return [
            optionFor(tier: .good, seer: caps.seerGood, stage: caps.stageGood, price: caps.good),
            optionFor(tier: .better, seer: caps.seerBetter, stage: caps.stageBetter, price: caps.better),
            optionFor(tier: .best, seer: caps.seerBest, stage: caps.stageBest, price: caps.best),
        ]
    }
    
    private static func roundTo50(_ v: Double) -> Double {
        (round(v / 50.0) * 50.0)
    }
    
    // MARK: - Migration/Seeding helpers
    private func seedMissingTemplatesIfNeeded() {
        let baseline = Self.defaultSystemTemplates()
        var updated = systemTemplates
        for tpl in baseline {
            if !updated.contains(where: { $0.equipmentType == tpl.equipmentType && $0.tonnage == tpl.tonnage }) {
                updated.append(tpl)
            }
        }
        if updated.count != systemTemplates.count {
            systemTemplates = updated
        }
        if addOnTemplates.isEmpty {
            addOnTemplates = Self.defaultAddOnTemplates()
        }
    }
    
    private static func defaultAddOnTemplates() -> [AddOnTemplate] {
        [
            AddOnTemplate(name: "WiFi Thermostat", description: "Smart thermostat install", defaultPrice: 350, enabled: true, freeWhenTierIsBest: true),
            AddOnTemplate(name: "Surge Protector", description: "Outdoor unit protection", defaultPrice: 225, enabled: true),
            AddOnTemplate(name: "Duct Sealing", description: "Seal supply/return leaks", defaultPrice: 600, enabled: true)
        ]
    }
    
    // MARK: - Helpers
    
    func systemTemplate(for tonnage: Double, equipment: EquipmentType) -> EstimateSystem? {
        // Match exact tonnage if present; otherwise nearest by absolute difference
        let candidates = systemTemplates.filter { $0.equipmentType == equipment }
        guard !candidates.isEmpty else { return nil }
        if let exact = candidates.first(where: { $0.tonnage == tonnage }) {
            return exact
        }
        return candidates.min(by: { abs($0.tonnage - tonnage) < abs($1.tonnage - tonnage) })
    }
    
    func enabledAddOnTemplates() -> [AddOnTemplate] {
        addOnTemplates.filter { $0.enabled }
    }
    
    // MARK: - Import/Export
    func exportTemplatesJSON() -> Data? {
        let bundle = TemplatesBundle(systemTemplates: systemTemplates, addOnTemplates: addOnTemplates)
        return try? JSONEncoder().encode(bundle)
    }
    
    func exportSystemTemplatesJSON() -> Data? {
        let bundle = TemplatesBundle(systemTemplates: systemTemplates, addOnTemplates: [])
        return try? JSONEncoder().encode(bundle)
    }
    
    func exportAddOnTemplatesJSON() -> Data? {
        let bundle = TemplatesBundle(systemTemplates: [], addOnTemplates: addOnTemplates)
        return try? JSONEncoder().encode(bundle)
    }
    
    func importTemplates(from data: Data) throws {
        let bundle = try JSONDecoder().decode(TemplatesBundle.self, from: data)
        self.systemTemplates = bundle.systemTemplates
        self.addOnTemplates = bundle.addOnTemplates
    }
    
    // Build a composite "AC Condenser + Coil" template by combining single templates for the same tonnage
    func buildCondenserCoilComposite(for tonnage: Double) -> EstimateSystem? {
        guard let condenser = systemTemplate(for: tonnage, equipment: .acCondenserOnly),
              let coil = systemTemplate(for: tonnage, equipment: .coilOnly) else {
            return nil
        }
        var merged: [SystemOption] = []
        for tier in Tier.allCases {
            guard let cOpt = condenser.options.first(where: { $0.tier == tier }),
                  let kOpt = coil.options.first(where: { $0.tier == tier }) else { continue }
            let combined = SystemOption(
                tier: tier,
                showToCustomer: cOpt.showToCustomer && kOpt.showToCustomer,
                isSelectedByCustomer: false,
                seer: max(cOpt.seer, kOpt.seer),
                stage: cOpt.stage,
                tonnage: tonnage,
                price: cOpt.price + kOpt.price,
                imageName: cOpt.imageName ?? kOpt.imageName,
                outdoorModel: cOpt.outdoorModel,
                indoorModel: kOpt.indoorModel,
                furnaceModel: nil,
                warrantyText: cOpt.warrantyText ?? kOpt.warrantyText,
                advantages: Array(Set(cOpt.advantages + kOpt.advantages))
            )
            merged.append(combined)
        }
        let name = "AC Condenser + Coil \(tonnage == floor(tonnage) ? "\(Int(tonnage)) Ton" : "\(tonnage) Ton")"
        return EstimateSystem(name: name, tonnage: tonnage, equipmentType: .acCondenserCoil, options: merged)
    }
    
    // Build a composite "AC Condenser + Coil + Furnace" from singles
    func buildACFurnaceComposite(for tonnage: Double) -> EstimateSystem? {
        guard let ac = buildCondenserCoilComposite(for: tonnage) else { return nil }
        // Map tonnage to a typical furnace BTU target
        let targetBTU: Double
        switch tonnage {
        case ..<2.0: targetBTU = 40000
        case 2.0..<2.5: targetBTU = 60000
        case 2.5..<3.5: targetBTU = 80000
        case 3.5..<4.5: targetBTU = 100000
        default: targetBTU = 110000
        }
        // Find nearest furnace template
        let furnaceCandidates = systemTemplates.filter { $0.equipmentType == .furnaceOnly }
        guard let furnace = furnaceCandidates.min(by: { abs($0.tonnage - targetBTU) < abs($1.tonnage - targetBTU) }) else {
            return EstimateSystem(name: "AC + Furnace \(formatTonnage(tonnage))", tonnage: tonnage, equipmentType: .acFurnace, options: ac.options)
        }
        var merged: [SystemOption] = []
        for tier in Tier.allCases {
            if let acOpt = ac.options.first(where: { $0.tier == tier }),
               let fOpt = furnace.options.first(where: { $0.tier == tier }) {
                let combined = SystemOption(
                    tier: tier,
                    showToCustomer: acOpt.showToCustomer && fOpt.showToCustomer,
                    isSelectedByCustomer: false,
                    seer: acOpt.seer,
                    stage: acOpt.stage,
                    tonnage: tonnage,
                    price: acOpt.price + fOpt.price,
                    imageName: acOpt.imageName,
                    outdoorModel: acOpt.outdoorModel,
                    indoorModel: acOpt.indoorModel,
                    furnaceModel: fOpt.furnaceModel ?? "Furnace",
                    warrantyText: acOpt.warrantyText ?? fOpt.warrantyText,
                    advantages: Array(Set(acOpt.advantages + fOpt.advantages))
                )
                merged.append(combined)
            }
        }
        let name = "AC + Furnace \(formatTonnage(tonnage))"
        return EstimateSystem(name: name, tonnage: tonnage, equipmentType: .acFurnace, options: merged)
    }
    
    // Build "Heat Pump + Air Handler" composite from singles
    func buildHeatPumpAirHandlerComposite(for tonnage: Double) -> EstimateSystem? {
        guard let hp = systemTemplate(for: tonnage, equipment: .heatPumpOnly),
              let ah = systemTemplate(for: tonnage, equipment: .airHandlerOnly) else { return nil }
        var merged: [SystemOption] = []
        for tier in Tier.allCases {
            guard let hOpt = hp.options.first(where: { $0.tier == tier }),
                  let aOpt = ah.options.first(where: { $0.tier == tier }) else { continue }
            let combined = SystemOption(
                tier: tier,
                showToCustomer: hOpt.showToCustomer && aOpt.showToCustomer,
                isSelectedByCustomer: false,
                seer: max(hOpt.seer, aOpt.seer),
                stage: hOpt.stage,
                tonnage: tonnage,
                price: hOpt.price + aOpt.price,
                imageName: hOpt.imageName ?? aOpt.imageName,
                outdoorModel: hOpt.outdoorModel,
                indoorModel: aOpt.indoorModel,
                furnaceModel: nil,
                warrantyText: hOpt.warrantyText ?? aOpt.warrantyText,
                advantages: Array(Set(hOpt.advantages + aOpt.advantages))
            )
            merged.append(combined)
        }
        let name = "Heat Pump + Air Handler \(formatTonnage(tonnage))"
        return EstimateSystem(name: name, tonnage: tonnage, equipmentType: .heatPumpAirHandler, options: merged)
    }
    
    // Build a composite "AC Condenser + Coil + Furnace" from singles with explicit furnace BTU
    func buildCondenserCoilFurnaceComposite(tonnage: Double, furnaceBTU: Double) -> EstimateSystem? {
        guard let ac = buildCondenserCoilComposite(for: tonnage) else { return nil }
        // Find nearest furnace by furnaceBTU
        let furnaceCandidates = systemTemplates.filter { $0.equipmentType == .furnaceOnly }
        guard let furnace = furnaceCandidates.min(by: { abs($0.tonnage - furnaceBTU) < abs($1.tonnage - furnaceBTU) }) else {
            return EstimateSystem(name: "AC Condenser + Coil + Furnace \(formatTonnage(tonnage))", tonnage: tonnage, furnaceBTU: furnaceBTU, equipmentType: .acCondenserCoilFurnace, options: ac.options)
        }
        var merged: [SystemOption] = []
        for tier in Tier.allCases {
            if let acOpt = ac.options.first(where: { $0.tier == tier }),
               let fOpt = furnace.options.first(where: { $0.tier == tier }) {
                let combined = SystemOption(
                    tier: tier,
                    showToCustomer: acOpt.showToCustomer && fOpt.showToCustomer,
                    isSelectedByCustomer: false,
                    seer: acOpt.seer,
                    stage: acOpt.stage,
                    tonnage: tonnage,
                    price: acOpt.price + fOpt.price,
                    imageName: acOpt.imageName,
                    outdoorModel: acOpt.outdoorModel,
                    indoorModel: acOpt.indoorModel,
                    furnaceModel: fOpt.furnaceModel ?? "Furnace",
                    warrantyText: acOpt.warrantyText ?? fOpt.warrantyText,
                    advantages: Array(Set(acOpt.advantages + fOpt.advantages))
                )
                merged.append(combined)
            }
        }
        let name = "AC Condenser + Coil + Furnace \(formatTonnage(tonnage)) • \(Int(furnaceBTU).formatted(.number.grouping(.automatic))) BTU"
        return EstimateSystem(name: name, tonnage: tonnage, furnaceBTU: furnaceBTU, equipmentType: .acCondenserCoilFurnace, options: merged)
    }
}


