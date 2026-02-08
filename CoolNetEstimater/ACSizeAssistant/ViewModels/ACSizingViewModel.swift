//
//  ACSizingViewModel.swift
//  CoolNetEstimater
//

import Foundation
import Combine

final class AppStateViewModel: ObservableObject {
    @Published var selectedClimateZone: ClimateZone? = .zone1
    @Published var zipCode: String = ""
    @Published var floors: [FloorInput]
    @Published var results: [FloorResult] = []
    
    private let engine = SizingEngine()
    
    init() {
        self.floors = []
        self.selectedClimateZone = .zone1 // Default to Zone 1
    }
    
    func addFloor() {
        guard floors.count < 3 else { return }
        let defaultName = floors.isEmpty ? "Main Level" : (floors.count == 1 ? "Upstairs" : "Downstairs")
        let defaultType: FloorType = floors.isEmpty ? .main : (floors.count == 1 ? .upper : .basement)
        floors.append(FloorInput(name: defaultName, floorType: defaultType, squareFootage: 1000, needsCooling: true, needsHeating: true, hasSeparateSystem: true))
    }
    
    func calculateSizing() {
        guard let zone = selectedClimateZone else { return }
        results = engine.sizeFloors(zone: zone, floors: floors)
    }
    
    func removeFloor(id: UUID) {
        floors.removeAll { $0.id == id }
    }
}


