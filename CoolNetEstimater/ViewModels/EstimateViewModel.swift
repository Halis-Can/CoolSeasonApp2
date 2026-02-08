//
//  EstimateViewModel.swift
//  CoolNetEstimater
//

import Foundation
import SwiftUI
import Combine

final class EstimateViewModel: ObservableObject {
    @Published var currentEstimate: Estimate {
        didSet {
            if isInternalMutation { return }
            persistAndRecalculate()
            upsertCurrentEstimateIntoList()
        }
    }
    @Published var estimates: [Estimate] = [] {
        didSet {
            if isInternalMutation { return }
            persistEstimatesList()
        }
    }
    
    private let estimateURL: URL
    private let estimatesListURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var isInternalMutation: Bool = false
    
    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        estimateURL = documents.appendingPathComponent("current_estimate.json")
        estimatesListURL = documents.appendingPathComponent("estimates.json")
        if let loaded: Estimate = try? Self.load(Estimate.self, from: estimateURL) {
            currentEstimate = loaded
        } else {
            currentEstimate = Estimate()
        }
        if let loadedList: [Estimate] = try? Self.load([Estimate].self, from: estimatesListURL) {
            estimates = loadedList
        } else {
            estimates = []
        }
        persistAndRecalculate()
    }
    
    // MARK: - Persistence
    
    private static func load<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func persistEstimate() {
        do {
            let data = try encoder.encode(currentEstimate)
            try data.write(to: estimateURL, options: [.atomic])
        } catch {
            print("Persist estimate failed: \(error)")
        }
    }
    
    private func persistEstimatesList() {
        do {
            let data = try encoder.encode(estimates)
            try data.write(to: estimatesListURL, options: [.atomic])
        } catch {
            print("Persist estimate list failed: \(error)")
        }
    }
    
    private func persistAndRecalculate() {
        recalculateTotals()
        persistEstimate()
    }
    
    private func upsertCurrentEstimateIntoList() {
        if let idx = estimates.firstIndex(where: { $0.id == currentEstimate.id }) {
            estimates[idx] = currentEstimate
        } else {
            estimates.append(currentEstimate)
        }
        persistEstimatesList()
    }
    
    // MARK: - Estimates list management
    func createNewEstimate() {
        var new = Estimate()
        new.estimateDate = Date()
        new.estimateNumber = nextEstimateNumber()
        isInternalMutation = true
        currentEstimate = new
        isInternalMutation = false
        upsertCurrentEstimateIntoList()
    }
    
    func loadEstimate(_ estimate: Estimate) {
        isInternalMutation = true
        currentEstimate = estimate
        isInternalMutation = false
    }
    
    func deleteEstimate(id: UUID) {
        estimates.removeAll { $0.id == id }
        if currentEstimate.id == id, let first = estimates.first {
            loadEstimate(first)
        }
        persistEstimatesList()
    }
    
    private func nextEstimateNumber() -> String {
        // Format CS-XXX with 3 digits
        let prefix = "CS-"
        let numbers: [Int] = estimates.compactMap { est in
            if est.estimateNumber.hasPrefix(prefix) {
                let suffix = est.estimateNumber.dropFirst(prefix.count)
                return Int(suffix)
            }
            return nil
        }
        let next = (numbers.max() ?? 0) + 1
        return String(format: "\(prefix)%03d", next)
    }
    
    // MARK: - API
    
    func startNewEstimate(using templates: [EstimateSystem], addOns: [AddOnTemplate]) {
        var systems: [EstimateSystem] = []
        for t in templates {
            // Clone system with fresh IDs and the same options
            let clonedOptions = t.options.map { opt in
                SystemOption(
                    id: UUID(),
                    tier: opt.tier,
                    showToCustomer: opt.showToCustomer,
                    isSelectedByCustomer: false,
                    seer: opt.seer,
                    stage: opt.stage,
                    tonnage: opt.tonnage,
                    price: opt.price,
                    imageName: opt.imageName,
                    outdoorModel: opt.outdoorModel,
                    indoorModel: opt.indoorModel,
                    furnaceModel: opt.furnaceModel,
                    warrantyText: opt.warrantyText,
                    advantages: opt.advantages
                )
            }
            let sys = EstimateSystem(
                id: UUID(),
                enabled: true,
                name: t.name,
                tonnage: t.tonnage,
                equipmentType: t.equipmentType,
                existingBrand: nil,
                existingModel: nil,
                existingAgeYears: nil,
                existingLocation: nil,
                existingNotes: nil,
                options: clonedOptions
            )
            systems.append(sys)
        }
        
        let addOnInstances: [AddOn] = addOns.map { tmpl in
            AddOn(id: UUID(), templateId: tmpl.id, name: tmpl.name, description: tmpl.description, enabled: tmpl.enabled, price: tmpl.defaultPrice)
        }
        
        currentEstimate = Estimate(systems: systems, addOns: addOnInstances)
        recalculateTotals()
        persistEstimate()
    }
    
    func recalculateTotals() {
        var systemsSubtotal: Double = 0
        for sys in currentEstimate.systems where sys.enabled {
            if let selected = sys.options.first(where: { $0.isSelectedByCustomer }) {
                systemsSubtotal += selected.price
            }
        }
        
        let isAnyBestSelected = currentEstimate.systems
            .flatMap { $0.options }
            .contains { $0.tier == .best && $0.isSelectedByCustomer }
        
        // Respect manual price edits. Only force price to 0 when Best is selected and template marks it free.
        isInternalMutation = true
        for idx in currentEstimate.addOns.indices {
            if let tmplId = currentEstimate.addOns[idx].templateId,
               let free = addOnFreeWhenBest[tmplId], free, isAnyBestSelected {
                currentEstimate.addOns[idx].price = 0
            }
        }
        isInternalMutation = false
        
        let addOnsSubtotal = currentEstimate.addOns.filter { $0.enabled }.map { $0.price }.reduce(0, +)
        
        isInternalMutation = true
        currentEstimate.systemsSubtotal = systemsSubtotal
        currentEstimate.addOnsSubtotal = addOnsSubtotal
        currentEstimate.grandTotal = systemsSubtotal + addOnsSubtotal
        isInternalMutation = false
    }
    
    // MARK: - Template price maps (fed via attachTemplates)
    
    private var addOnDefaultPrice: [UUID: Double] = [:]
    private var addOnFreeWhenBest: [UUID: Bool] = [:]
    private var previousAddOnDefaultPrice: [UUID: Double] = [:]
    
    func attachTemplates(_ addOnTemplates: [AddOnTemplate]) {
        // Update template maps
        addOnDefaultPrice = Dictionary(uniqueKeysWithValues: addOnTemplates.map { ($0.id, $0.defaultPrice) })
        addOnFreeWhenBest = Dictionary(uniqueKeysWithValues: addOnTemplates.map { ($0.id, $0.freeWhenTierIsBest) })
        
        // Build per-system add-ons from templates; preserve per-estimate enablement
        isInternalMutation = true
        var rebuilt: [AddOn] = []
        struct AddOnKey: Hashable { let templateId: UUID; let systemId: UUID }
        for system in currentEstimate.systems {
            // Index existing by (templateId, systemId)
            let existingForSystem = Dictionary(uniqueKeysWithValues:
                currentEstimate.addOns
                    .filter { $0.systemId == system.id }
                    .compactMap { addOn -> (AddOnKey, AddOn)? in
                        if let tid = addOn.templateId { return (AddOnKey(templateId: tid, systemId: system.id), addOn) }
                        return nil
                    }
            )
            for tmpl in addOnTemplates {
                if let existing = existingForSystem[AddOnKey(templateId: tmpl.id, systemId: system.id)] {
                    rebuilt.append(AddOn(
                        id: existing.id,
                        templateId: tmpl.id,
                        systemId: system.id,
                        name: tmpl.name,
                        description: tmpl.description,
                        enabled: existing.enabled, // keep user's toggle for this system
                        price: tmpl.defaultPrice
                    ))
                } else {
                    rebuilt.append(AddOn(
                        id: UUID(),
                        templateId: tmpl.id,
                        systemId: system.id,
                        name: tmpl.name,
                        description: tmpl.description,
                        enabled: tmpl.enabled,
                        price: tmpl.defaultPrice
                    ))
                }
            }
        }
        currentEstimate.addOns = rebuilt
        isInternalMutation = false
        recalculateTotals()
        persistEstimate()
    }
    
    // MARK: - Mutations
    
    func addSystem(from template: EstimateSystem) {
        // Clone with fresh IDs
        let clonedOptions = template.options.map { opt in
            SystemOption(
                id: UUID(),
                tier: opt.tier,
                showToCustomer: opt.showToCustomer,
                isSelectedByCustomer: false,
                seer: opt.seer,
                stage: opt.stage,
                tonnage: opt.tonnage,
                price: opt.price,
                imageName: opt.imageName,
                outdoorModel: opt.outdoorModel,
                indoorModel: opt.indoorModel,
                furnaceModel: opt.furnaceModel,
                warrantyText: opt.warrantyText,
                advantages: opt.advantages
            )
        }
        let sys = EstimateSystem(id: UUID(), enabled: true, name: template.name, tonnage: template.tonnage, equipmentType: template.equipmentType, options: clonedOptions)
        currentEstimate.systems.append(sys)
        recalculateTotals()
        persistEstimate()
    }
    
    func removeSystem(_ systemId: UUID) {
        currentEstimate.systems.removeAll { $0.id == systemId }
        recalculateTotals()
        persistEstimate()
    }
    
    func setSystemEnabled(_ systemId: UUID, enabled: Bool) {
        guard let idx = currentEstimate.systems.firstIndex(where: { $0.id == systemId }) else { return }
        currentEstimate.systems[idx].enabled = enabled
        recalculateTotals()
        persistEstimate()
    }
    
    func setOptionVisibility(systemId: UUID, optionId: UUID, showToCustomer: Bool) {
        guard let sidx = currentEstimate.systems.firstIndex(where: { $0.id == systemId }) else { return }
        guard let oidx = currentEstimate.systems[sidx].options.firstIndex(where: { $0.id == optionId }) else { return }
        currentEstimate.systems[sidx].options[oidx].showToCustomer = showToCustomer
        recalculateTotals()
        persistEstimate()
    }
    
    func selectOption(systemId: UUID, optionId: UUID) {
        guard let sidx = currentEstimate.systems.firstIndex(where: { $0.id == systemId }) else { return }
        for idx in currentEstimate.systems[sidx].options.indices {
            currentEstimate.systems[sidx].options[idx].isSelectedByCustomer = (currentEstimate.systems[sidx].options[idx].id == optionId)
        }
        recalculateTotals()
        persistEstimate()
    }
    
    // Allow multiple selections: toggle a single option without unselecting others
    func toggleOptionSelection(systemId: UUID, optionId: UUID) {
        guard let sidx = currentEstimate.systems.firstIndex(where: { $0.id == systemId }) else { return }
        guard let oidx = currentEstimate.systems[sidx].options.firstIndex(where: { $0.id == optionId }) else { return }
        currentEstimate.systems[sidx].options[oidx].isSelectedByCustomer.toggle()
        recalculateTotals()
        persistEstimate()
    }
    
    func addAddOn(from template: AddOnTemplate) {
        let addOn = AddOn(id: UUID(), templateId: template.id, name: template.name, description: template.description, enabled: true, price: template.defaultPrice)
        currentEstimate.addOns.append(addOn)
        attachTemplates([template]) // update price maps incrementally
        recalculateTotals()
        persistEstimate()
    }
    
    func removeAddOn(_ addOnId: UUID) {
        currentEstimate.addOns.removeAll { $0.id == addOnId }
        recalculateTotals()
        persistEstimate()
    }
    
    func setAddOnEnabled(_ addOnId: UUID, enabled: Bool) {
        guard let idx = currentEstimate.addOns.firstIndex(where: { $0.id == addOnId }) else { return }
        currentEstimate.addOns[idx].enabled = enabled
        recalculateTotals()
        persistEstimate()
    }
    
    // MARK: - External helpers expected by UI examples
    
    func textSummary() -> String {
        var lines: [String] = []
        lines.append("CoolSeason HVAC Estimate")
        lines.append("Customer: \(currentEstimate.customerName)")
        lines.append("Address: \(currentEstimate.address)")
        lines.append("Phone: \(currentEstimate.phone)  Email: \(currentEstimate.email)")
        lines.append("")
        lines.append("Systems:")
        for sys in currentEstimate.systems where sys.enabled {
            if let selected = sys.options.first(where: { $0.isSelectedByCustomer }) {
                lines.append("- \(sys.name) • \(sys.equipmentType.rawValue) • \(formatTonnage(sys.tonnage)) • \(selected.tier.displayName) \(Int(selected.seer)) SEER \(selected.stage) • \(formatCurrency(selected.price))")
            } else {
                lines.append("- \(sys.name) • \(sys.equipmentType.rawValue) • \(formatTonnage(sys.tonnage)) • No selection")
            }
        }
        lines.append("")
        lines.append("Additional Equipment:")
        let enabledAddOns = currentEstimate.addOns.filter { $0.enabled }
        if enabledAddOns.isEmpty {
            lines.append("- None")
        } else {
            for addOn in enabledAddOns {
                lines.append("- \(addOn.name): \(formatCurrency(addOn.price))")
            }
        }
        lines.append("")
        lines.append("Totals:")
        lines.append("- Systems: \(formatCurrency(currentEstimate.systemsSubtotal))")
        lines.append("- Add-Ons: \(formatCurrency(currentEstimate.addOnsSubtotal))")
        lines.append("- Total: \(formatCurrency(currentEstimate.grandTotal))")
        return lines.joined(separator: "\n")
    }
    
    func updateSignature(data: Data?) {
        currentEstimate.customerSignatureImageData = data
        persistEstimate()
    }
    
    // MARK: - Wizard helpers (systems from templates)
    
    func ensureSystemCount(_ count: Int, settingsVM: SettingsViewModel) {
        var systems = currentEstimate.systems
        if systems.count < count {
            for i in systems.count..<count {
                let tonnage = 3.0
                let equip: EquipmentType = .acFurnace
                if let tmpl = settingsVM.systemTemplate(for: tonnage, equipment: equip) {
                    let cloned = cloneSystemFromTemplate(tmpl, name: "System #\(i+1)")
                    systems.append(cloned)
                } else {
                    systems.append(EstimateSystem(name: "System #\(i+1)", tonnage: tonnage, equipmentType: equip, options: []))
                }
            }
        } else if systems.count > count {
            systems = Array(systems.prefix(count))
        }
        currentEstimate.systems = systems
        recalculateTotals()
        persistEstimate()
    }
    
    func updateSystemMeta(_ systemId: UUID, name: String? = nil, tonnage: Double? = nil, equipmentType: EquipmentType? = nil) {
        guard let idx = currentEstimate.systems.firstIndex(where: { $0.id == systemId }) else { return }
        if let name = name { currentEstimate.systems[idx].name = name }
        if let tonnage = tonnage { currentEstimate.systems[idx].tonnage = tonnage }
        if let equipmentType = equipmentType { currentEstimate.systems[idx].equipmentType = equipmentType }
        recalculateTotals()
        persistEstimate()
    }
    
    func replaceOptionsForSystem(_ systemId: UUID, using settingsVM: SettingsViewModel) {
        guard let idx = currentEstimate.systems.firstIndex(where: { $0.id == systemId }) else { return }
        let sys = currentEstimate.systems[idx]
        var builtOptions: [SystemOption] = []
        switch sys.equipmentType {
        case .acCondenserCoil:
            if let composite = settingsVM.buildCondenserCoilComposite(for: sys.tonnage) {
                builtOptions = composite.options.map { cloneOption($0) }
            } else {
                builtOptions = []
            }
        case .acCondenserCoilFurnace:
            let btus = sys.furnaceBTU ?? 0
            if let composite = settingsVM.buildCondenserCoilFurnaceComposite(tonnage: sys.tonnage, furnaceBTU: btus) {
                builtOptions = composite.options.map { cloneOption($0) }
            } else {
                builtOptions = []
            }
        case .acFurnace:
            if let composite = settingsVM.buildACFurnaceComposite(for: sys.tonnage) {
                builtOptions = composite.options.map { cloneOption($0) }
            } else {
                builtOptions = []
            }
        case .heatPumpAirHandler:
            if let composite = settingsVM.buildHeatPumpAirHandlerComposite(for: sys.tonnage) {
                builtOptions = composite.options.map { cloneOption($0) }
            } else {
                builtOptions = []
            }
        default:
            if let tmpl = settingsVM.systemTemplate(for: sys.tonnage, equipment: sys.equipmentType) {
                builtOptions = tmpl.options.map { cloneOption($0) }
            } else {
                builtOptions = []
            }
        }
        // Ensure 3 tiers exist; if missing, synthesize from available data
        builtOptions = ensureAllTiers(options: builtOptions, tonnage: sys.tonnage)
        // Ensure option tonnage reflects the system's selected tonnage (e.g., 1.5 Ton)
        for oidx in builtOptions.indices {
            builtOptions[oidx].tonnage = sys.tonnage
        }
        currentEstimate.systems[idx].options = builtOptions
        recalculateTotals()
        persistEstimate()
    }
    
    private func cloneSystemFromTemplate(_ t: EstimateSystem, name: String? = nil) -> EstimateSystem {
        EstimateSystem(
            id: UUID(),
            enabled: true,
            name: name ?? t.name,
            tonnage: t.tonnage,
            equipmentType: t.equipmentType,
            options: t.options.map { cloneOption($0) }
        )
    }
    
    private func cloneOption(_ opt: SystemOption) -> SystemOption {
        SystemOption(
            id: UUID(),
            tier: opt.tier,
            showToCustomer: opt.showToCustomer,
            isSelectedByCustomer: false,
            seer: opt.seer,
            stage: opt.stage,
            tonnage: opt.tonnage,
            price: opt.price,
            imageName: opt.imageName,
            outdoorModel: opt.outdoorModel,
            indoorModel: opt.indoorModel,
            furnaceModel: opt.furnaceModel,
            warrantyText: opt.warrantyText,
            advantages: opt.advantages
        )
    }
    
    // Ensure each Tier has an option; if missing, clone from the closest available and apply small price adjustments
    private func ensureAllTiers(options: [SystemOption], tonnage: Double) -> [SystemOption] {
        var byTier = Dictionary(uniqueKeysWithValues: options.map { ($0.tier, $0) })
        // Pick a base to clone from if needed
        let base = byTier.values.first
        for tier in Tier.allCases {
            if byTier[tier] == nil, let baseOpt = base {
                // Create new option with new id; base other fields on baseOpt
                var price = baseOpt.price
                // Light price scaling so tiers differ visually if only one provided
                switch tier {
                case Tier.allCases.first!:
                    break
                case Tier.allCases.dropFirst().first!:
                    price = (price * 1.12).rounded()
                default:
                    price = (price * 1.25).rounded()
                }
                let newOpt = SystemOption(
                    id: UUID(),
                    tier: tier,
                    showToCustomer: true,
                    isSelectedByCustomer: false,
                    seer: baseOpt.seer,
                    stage: baseOpt.stage,
                    tonnage: tonnage,
                    price: price,
                    imageName: baseOpt.imageName,
                    outdoorModel: baseOpt.outdoorModel,
                    indoorModel: baseOpt.indoorModel,
                    furnaceModel: baseOpt.furnaceModel,
                    warrantyText: baseOpt.warrantyText,
                    advantages: baseOpt.advantages
                )
                byTier[tier] = newOpt
            }
        }
        // Return in canonical tier order
        return Tier.allCases.compactMap { byTier[$0] }
    }
    
    // MARK: - Live sync with template changes
    func syncSystemsWithTemplates(_ templates: [EstimateSystem]) {
        isInternalMutation = true
        for idx in currentEstimate.systems.indices {
            let sys = currentEstimate.systems[idx]
            let newOptions: [SystemOption]
            switch sys.equipmentType {
            case .acCondenserCoil:
                newOptions = compositeOptions(from: templates, tonnage: sys.tonnage, parts: [.acCondenserOnly, .coilOnly])
            case .acCondenserCoilFurnace:
                let base = compositeOptions(from: templates, tonnage: sys.tonnage, parts: [.acCondenserOnly, .coilOnly])
                newOptions = mergeWithFurnace(from: templates, baseTonnage: sys.tonnage, furnaceBTUOverride: sys.furnaceBTU, base: base)
            case .acFurnace:
                newOptions = compositeOptions(from: templates, tonnage: sys.tonnage, parts: [.acCondenserOnly, .coilOnly]) + // start with AC parts
                             mergeWithFurnace(from: templates, baseTonnage: sys.tonnage, base: compositeOptions(from: templates, tonnage: sys.tonnage, parts: [.acCondenserOnly, .coilOnly]))
            case .heatPumpAirHandler:
                newOptions = compositeOptions(from: templates, tonnage: sys.tonnage, parts: [.heatPumpOnly, .airHandlerOnly])
            default:
                guard let tmpl = templates.first(where: { $0.equipmentType == sys.equipmentType && $0.tonnage == sys.tonnage }) else { continue }
                newOptions = tmpl.options
            }
            currentEstimate.systems[idx].options = newOptions.enumerated().map { i, opt in
                if let existing = sys.options.first(where: { $0.tier == opt.tier }) {
                    return SystemOption(
                        id: existing.id,
                        tier: opt.tier,
                        showToCustomer: existing.showToCustomer,
                        isSelectedByCustomer: existing.isSelectedByCustomer,
                        seer: opt.seer,
                        stage: opt.stage,
                        tonnage: sys.tonnage,
                        price: opt.price,
                        imageName: opt.imageName,
                        outdoorModel: opt.outdoorModel,
                        indoorModel: opt.indoorModel,
                        furnaceModel: opt.furnaceModel,
                        warrantyText: opt.warrantyText,
                        advantages: opt.advantages
                    )
                } else {
                    var adjusted = opt
                    adjusted.tonnage = sys.tonnage
                    return adjusted
                }
            }
        }
        isInternalMutation = false
        recalculateTotals()
        persistEstimate()
    }
    
    // Compose options by summing/merging parts from provided templates
    private func compositeOptions(from templates: [EstimateSystem], tonnage: Double, parts: [EquipmentType]) -> [SystemOption] {
        var byTier: [Tier: SystemOption] = [:]
        for tier in Tier.allCases {
            var price: Double = 0
            var seer: Double = 0
            var stage: String = ""
            var imageName: String?
            var outdoorModel: String?
            var indoorModel: String?
            var furnaceModel: String?
            var warranty: String?
            var advantages: Set<String> = []
            var show = true
            for part in parts {
                guard let tmpl = templates.first(where: { $0.equipmentType == part && $0.tonnage == tonnage }),
                      let opt = tmpl.options.first(where: { $0.tier == tier }) else { continue }
                price += opt.price
                seer = max(seer, opt.seer)
                if stage.isEmpty { stage = opt.stage }
                if imageName == nil { imageName = opt.imageName }
                if outdoorModel == nil { outdoorModel = opt.outdoorModel }
                if indoorModel == nil { indoorModel = opt.indoorModel }
                if furnaceModel == nil { furnaceModel = opt.furnaceModel }
                if warranty == nil { warranty = opt.warrantyText }
                advantages.formUnion(opt.advantages)
                show = show && opt.showToCustomer
            }
            byTier[tier] = SystemOption(
                tier: tier,
                showToCustomer: show,
                isSelectedByCustomer: false,
                seer: seer,
                stage: stage,
                tonnage: tonnage,
                price: price,
                imageName: imageName,
                outdoorModel: outdoorModel,
                indoorModel: indoorModel,
                furnaceModel: furnaceModel,
                warrantyText: warranty,
                advantages: Array(advantages)
            )
        }
        return Tier.allCases.compactMap { byTier[$0] }
    }
    
    private func mergeWithFurnace(from templates: [EstimateSystem], baseTonnage: Double, furnaceBTUOverride: Double? = nil, base: [SystemOption]) -> [SystemOption] {
        // Map tonnage to furnace BTU
        let targetBTU: Double
        if let override = furnaceBTUOverride, override > 0 {
            targetBTU = override
        } else {
            switch baseTonnage {
            case ..<2.0: targetBTU = 40000
            case 2.0..<2.5: targetBTU = 60000
            case 2.5..<3.5: targetBTU = 80000
            case 3.5..<4.5: targetBTU = 100000
            default: targetBTU = 110000
            }
        }
        guard let furnace = templates.filter({ $0.equipmentType == .furnaceOnly }).min(by: { abs($0.tonnage - targetBTU) < abs($1.tonnage - targetBTU) }) else {
            return base
        }
        var results: [SystemOption] = []
        for tier in Tier.allCases {
            if let b = base.first(where: { $0.tier == tier }),
               let f = furnace.options.first(where: { $0.tier == tier }) {
                let combined = SystemOption(
                    tier: tier,
                    showToCustomer: b.showToCustomer && f.showToCustomer,
                    isSelectedByCustomer: b.isSelectedByCustomer,
                    seer: b.seer,
                    stage: b.stage,
                    tonnage: baseTonnage,
                    price: b.price + f.price,
                    imageName: b.imageName,
                    outdoorModel: b.outdoorModel,
                    indoorModel: b.indoorModel,
                    furnaceModel: f.furnaceModel ?? "Furnace",
                    warrantyText: b.warrantyText ?? f.warrantyText,
                    advantages: Array(Set(b.advantages + f.advantages))
                )
                results.append(combined)
            }
        }
        return results
    }
    
    // MARK: - Proposal acceptance
    func acceptProposal(tier: Tier) {
        for sidx in currentEstimate.systems.indices {
            for oidx in currentEstimate.systems[sidx].options.indices {
                let isMatch = currentEstimate.systems[sidx].options[oidx].tier == tier
                currentEstimate.systems[sidx].options[oidx].isSelectedByCustomer = isMatch
            }
        }
        recalculateTotals()
        persistEstimate()
    }
    
    // MARK: - Status management
    func approveEstimate() {
        isInternalMutation = true
        currentEstimate.status = .approved
        isInternalMutation = false
        persistEstimate()
        upsertCurrentEstimateIntoList()
    }
    
    func setEstimateStatus(_ status: EstimateStatus) {
        isInternalMutation = true
        currentEstimate.status = status
        isInternalMutation = false
        persistEstimate()
        upsertCurrentEstimateIntoList()
    }
}


