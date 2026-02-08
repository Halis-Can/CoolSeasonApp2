//
//  AppDataStore.swift
//  CoolNetEstimater
//
//  Simple persistence and app-wide state
//

import Foundation
import SwiftUI
import Combine

final class AppDataStore: ObservableObject {
    @Published var currentEstimate: Estimate {
        didSet { recomputeTotalsAndPersist() }
    }
    
    @Published var addOnTemplates: [AddOnTemplate] {
        didSet { persistTemplates() }
    }
    
    private let estimateURL: URL
    private let templatesURL: URL
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    
    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.estimateURL = documents.appendingPathComponent("current_estimate.json")
        self.templatesURL = documents.appendingPathComponent("addon_templates.json")
        
        self.currentEstimate = Self.loadEstimate(from: estimateURL) ?? Self.defaultEstimate()
        self.addOnTemplates = Self.loadTemplates(from: templatesURL) ?? Self.defaultTemplates()
        
        recomputeTotalsAndPersist()
    }
    
    // MARK: - Load/Save
    
    private static func loadEstimate(from url: URL) -> Estimate? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Estimate.self, from: data)
    }
    
    private static func loadTemplates(from url: URL) -> [AddOnTemplate]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([AddOnTemplate].self, from: data)
    }
    
    private func persistEstimate() {
        do {
            let data = try jsonEncoder.encode(currentEstimate)
            try data.write(to: estimateURL, options: [.atomic])
        } catch {
            print("Persist estimate failed: \(error)")
        }
    }
    
    private func persistTemplates() {
        do {
            let data = try jsonEncoder.encode(addOnTemplates)
            try data.write(to: templatesURL, options: [.atomic])
        } catch {
            print("Persist templates failed: \(error)")
        }
    }
    
    // MARK: - Defaults
    
    private static func defaultEstimate() -> Estimate {
        let baseTonnage = 3.0
        let options: [SystemOption] = [
            SystemOption(tier: .good, seer: 14, stage: "Single", tonnage: baseTonnage, price: 6800, imageName: "snow"),
            SystemOption(tier: .better, seer: 16, stage: "Two-Stage", tonnage: baseTonnage, price: 8400, imageName: "wind"),
            SystemOption(tier: .best, seer: 18, stage: "Variable Speed", tonnage: baseTonnage, price: 10400, imageName: "sun.max")
        ]
        let system = EstimateSystem(name: "Main System", tonnage: baseTonnage, equipmentType: .acFurnace, options: options)
        return Estimate(systems: [system], addOns: [])
    }
    
    private static func defaultTemplates() -> [AddOnTemplate] {
        [
            AddOnTemplate(name: "WiFi Thermostat", description: "Smart thermostat install", defaultPrice: 350, enabled: true, freeWhenTierIsBest: true),
            AddOnTemplate(name: "Surge Protector", description: "Outdoor unit protection", defaultPrice: 225, enabled: true),
            AddOnTemplate(name: "Duct Sealing", description: "Seal supply/return leaks", defaultPrice: 600, enabled: true)
        ]
    }
    
    // MARK: - Mutations
    
    func addSystem() {
        let nextIndex = currentEstimate.systems.count + 1
        let tonnage = 3.0
        let options: [SystemOption] = [
            SystemOption(tier: .good, seer: 14, stage: "Single", tonnage: tonnage, price: 6800, imageName: "snow"),
            SystemOption(tier: .better, seer: 16, stage: "Two-Stage", tonnage: tonnage, price: 8400, imageName: "wind"),
            SystemOption(tier: .best, seer: 18, stage: "Variable Speed", tonnage: tonnage, price: 10400, imageName: "sun.max")
        ]
        let system = EstimateSystem(name: "System #\(nextIndex)", tonnage: tonnage, equipmentType: .acFurnace, options: options)
        currentEstimate.systems.append(system)
    }
    
    func removeSystem(_ systemId: UUID) {
        currentEstimate.systems.removeAll { $0.id == systemId }
    }
    
    func toggleSelectOption(systemId: UUID, optionId: UUID) {
        guard let systemIndex = currentEstimate.systems.firstIndex(where: { $0.id == systemId }) else { return }
        for index in currentEstimate.systems[systemIndex].options.indices {
            currentEstimate.systems[systemIndex].options[index].isSelectedByCustomer = (currentEstimate.systems[systemIndex].options[index].id == optionId)
        }
    }
    
    func addAddOn(from template: AddOnTemplate) {
        let price: Double = template.freeWhenTierIsBest && isAnyBestSelected ? 0 : template.defaultPrice
        let addon = AddOn(id: UUID(), templateId: template.id, name: template.name, description: template.description, enabled: true, price: price)
        currentEstimate.addOns.append(addon)
    }
    
    func removeAddOn(_ addOnId: UUID) {
        currentEstimate.addOns.removeAll { $0.id == addOnId }
    }
    
    var isAnyBestSelected: Bool {
        currentEstimate.systems
            .flatMap { $0.options }
            .contains { $0.tier == .best && $0.isSelectedByCustomer }
    }
    
    func recomputeTotalsAndPersist() {
        // Systems subtotal: sum of selected option prices for enabled systems
        var systemsSubtotal: Double = 0
        for system in currentEstimate.systems where system.enabled {
            if let selected = system.options.first(where: { $0.isSelectedByCustomer }) {
                systemsSubtotal += selected.price
            }
        }
        
        // Adjust add-on prices if Best is selected and freeWhenTierIsBest
        var addOnsSubtotal: Double = 0
        for index in currentEstimate.addOns.indices {
            if let templateId = currentEstimate.addOns[index].templateId,
               let template = addOnTemplates.first(where: { $0.id == templateId }),
               template.freeWhenTierIsBest, isAnyBestSelected {
                currentEstimate.addOns[index].price = 0
            } else if let templateId = currentEstimate.addOns[index].templateId,
                      let template = addOnTemplates.first(where: { $0.id == templateId }) {
                currentEstimate.addOns[index].price = template.defaultPrice
            }
        }
        addOnsSubtotal = currentEstimate.addOns.filter { $0.enabled }.map { $0.price }.reduce(0, +)
        
        currentEstimate.systemsSubtotal = systemsSubtotal
        currentEstimate.addOnsSubtotal = addOnsSubtotal
        currentEstimate.grandTotal = systemsSubtotal + addOnsSubtotal
        
        persistEstimate()
    }
}


