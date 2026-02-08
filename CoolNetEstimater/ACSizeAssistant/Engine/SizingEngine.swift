//
//  SizingEngine.swift
//  CoolNetEstimater
//

import Foundation

struct SizingEngine {
    // Cooling tables per climate zone (sqft ranges)
    // Matches index.html `coolingTables`
    private let coolingTables: [ClimateZone: [Double: (min: Int, max: Int)]] = [
        .zone1: [
            1.5: (600, 900),
            2.0: (901, 1200),
            2.5: (1201, 1500),
            3.0: (1501, 1800),
            3.5: (1801, 2100),
            4.0: (2101, 2400),
            5.0: (2401, 3000)
        ],
        .zone2: [
            1.5: (600, 950),
            2.0: (951, 1250),
            2.5: (1251, 1550),
            3.0: (1551, 1850),
            3.5: (1851, 2150),
            4.0: (2151, 2500),
            5.0: (2501, 3100)
        ],
        .zone3: [
            1.5: (600, 1000),
            2.0: (1001, 1300),
            2.5: (1301, 1600),
            3.0: (1601, 1900),
            3.5: (1901, 2200),
            4.0: (2201, 2600),
            5.0: (2601, 3200)
        ],
        .zone4: [
            1.5: (700, 1050),
            2.0: (1051, 1350),
            2.5: (1351, 1600),
            3.0: (1601, 2000),
            3.5: (2001, 2250),
            4.0: (2251, 2700),
            5.0: (2751, 3300)
        ],
        .zone5: [
            1.5: (700, 1100),
            2.0: (1101, 1400),
            2.5: (1401, 1650),
            3.0: (1651, 2100),
            3.5: (2101, 2300),
            4.0: (2301, 2700),
            5.0: (2701, 3300)
        ]
    ]
    
    // Heating BTU/ft² ranges by zone
    private let heatingRanges: [ClimateZone: (min: Int, max: Int)] = [
        .zone1: (30, 35),
        .zone2: (35, 40),
        .zone3: (40, 45),
        .zone4: (45, 50),
        .zone5: (50, 60)
    ]
    
    private let standardFurnaceSizes: [Int] = [45000, 60000, 70000, 80000, 90000, 100000, 120000]
    
    // Cooling adjustment factors
    private func adjustCoolingSqft(_ sqft: Double, type: FloorType) -> Double {
        switch type {
        case .upper: return sqft * 1.15
        case .basement: return sqft * 0.8
        case .main: return sqft
        }
    }
    
    // Heating adjustment factors
    private func adjustHeatingSqft(_ sqft: Double, type: FloorType) -> Double {
        switch type {
        case .upper: return sqft * 1.10
        case .basement: return sqft * 0.85
        case .main: return sqft
        }
    }
    
    // Returns (tonnage, explanation)
    func findCoolingTonnage(zone: ClimateZone, adjustedSqft: Double) -> (Double, String)? {
        guard let table = coolingTables[zone] else { return nil }
        var best: (ton: Double, range: (min: Int, max: Int))?
        var bestDistance = Double.greatestFiniteMagnitude
        
        for (ton, range) in table {
            if adjustedSqft >= Double(range.min) && adjustedSqft <= Double(range.max) {
                let expl = "Adjusted \(Int(round(adjustedSqft))) sq ft falls in the \(String(format: "%.1f", ton))-ton range (\(range.min)–\(range.max) sq ft) for Zone \(zone.rawValue)."
                return (ton, expl)
            }
            let center = Double(range.min + range.max) / 2.0
            let dist = abs(adjustedSqft - center)
            if dist < bestDistance {
                bestDistance = dist
                best = (ton, range)
            }
        }
        if let best {
            let expl = "Adjusted \(Int(round(adjustedSqft))) sq ft is outside standard ranges; closest is \(String(format: "%.1f", best.ton)) tons (\(best.range.min)–\(best.range.max) sq ft) for Zone \(zone.rawValue)."
            return (best.ton, expl)
        }
        return nil
    }
    
    // Returns (furnaceBTU, explanation)
    func findHeatingBTU(zone: ClimateZone, sqft: Double, type: FloorType) -> (Int, String)? {
        guard let hr = heatingRanges[zone] else { return nil }
        let adj = adjustHeatingSqft(sqft, type: type)
        let minBTU = adj * Double(hr.min)
        let maxBTU = adj * Double(hr.max)
        var chosen: Int? = nil
        for size in standardFurnaceSizes {
            if Double(size) >= minBTU {
                chosen = size
                break
            }
        }
        if chosen == nil {
            chosen = standardFurnaceSizes.last
        }
        guard let chosen else { return nil }
        // Format grouped numbers for readability
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let minText = formatter.string(from: NSNumber(value: Int(round(minBTU)))) ?? "\(Int(round(minBTU)))"
        let maxText = formatter.string(from: NSNumber(value: Int(round(maxBTU)))) ?? "\(Int(round(maxBTU)))"
        let finalExpl = "Estimated heat loss for Zone \(zone.rawValue): \(minText)–\(maxText) BTU (adjusted for \(type.title.lowercased()) floor). Selected \(formatter.string(from: NSNumber(value: chosen)) ?? "\(chosen)") BTU as the nearest standard furnace size."
        return (chosen, finalExpl)
    }
    
    func sizeFloors(zone: ClimateZone, floors: [FloorInput]) -> [FloorResult] {
        var results: [FloorResult] = []
        for f in floors {
            var explanationParts: [String] = []
            var tonnage: Double? = nil
            var furnace: Int? = nil
            
            if f.needsCooling {
                let adj = adjustCoolingSqft(f.squareFootage, type: f.floorType)
                if let cool = findCoolingTonnage(zone: zone, adjustedSqft: adj) {
                    tonnage = cool.0
                    explanationParts.append(cool.1)
                }
            }
            if f.needsHeating {
                if let heat = findHeatingBTU(zone: zone, sqft: f.squareFootage, type: f.floorType) {
                    furnace = heat.0
                    explanationParts.append(heat.1)
                }
            }
            if f.needsCooling || f.needsHeating {
                results.append(FloorResult(floorName: f.name, floorType: f.floorType, recommendedTonnage: tonnage, recommendedFurnaceBTU: furnace, explanation: explanationParts.joined(separator: " ")))
            }
        }
        return results
    }
}


