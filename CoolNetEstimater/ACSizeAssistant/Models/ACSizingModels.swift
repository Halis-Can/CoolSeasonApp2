//
//  ACSizingModels.swift
//  CoolNetEstimater
//

import Foundation

enum ClimateZone: Int, CaseIterable, Identifiable, Codable {
    case zone1 = 1, zone2 = 2, zone3 = 3, zone4 = 4, zone5 = 5
    var id: Int { rawValue }
    var title: String { "Zone \(rawValue)" }
}

enum FloorType: String, CaseIterable, Identifiable, Codable {
    case basement, main, upper
    var id: String { rawValue }
    var title: String {
        switch self {
        case .basement: return "Downstairs"
        case .main: return "Main Level"
        case .upper: return "Upstairs"
        }
    }
}

struct FloorInput: Identifiable, Codable {
    let id: UUID
    var name: String
    var floorType: FloorType
    var squareFootage: Double
    var needsCooling: Bool
    var needsHeating: Bool
    var hasSeparateSystem: Bool
    
    init(id: UUID = UUID(),
         name: String,
         floorType: FloorType,
         squareFootage: Double,
         needsCooling: Bool,
         needsHeating: Bool,
         hasSeparateSystem: Bool) {
        self.id = id
        self.name = name
        self.floorType = floorType
        self.squareFootage = squareFootage
        self.needsCooling = needsCooling
        self.needsHeating = needsHeating
        self.hasSeparateSystem = hasSeparateSystem
    }
}

struct FloorResult: Identifiable, Codable {
    let id: UUID
    var floorName: String
    var floorType: FloorType
    var recommendedTonnage: Double?
    var recommendedFurnaceBTU: Int?
    var explanation: String
    
    init(id: UUID = UUID(),
         floorName: String,
         floorType: FloorType,
         recommendedTonnage: Double?,
         recommendedFurnaceBTU: Int?,
         explanation: String) {
        self.id = id
        self.floorName = floorName
        self.floorType = floorType
        self.recommendedTonnage = recommendedTonnage
        self.recommendedFurnaceBTU = recommendedFurnaceBTU
        self.explanation = explanation
    }
}


