//
//  PrintableFullSummaryView.swift
//  CoolSeasonApp
//

import SwiftUI

// Individual printable page per system (mirrors SystemSummaryPage layout)
struct PrintableSystemPage: View {
    let estimate: Estimate
    let system: EstimateSystem
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimate").font(.title.bold())
            customerBlock
            HStack {
                Text("\(index + 1). System")
                    .font(.headline)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(pastel(index).opacity(0.25))
                    .clipShape(Capsule())
                Spacer()
            }
            Text(system.name).font(.title3.bold())
            HStack(alignment: .top, spacing: 12) {
                printableTierCard(system: system, tier: .good, accent: .blue)
                printableTierCard(system: system, tier: .better, accent: .purple)
                printableTierCard(system: system, tier: .best, accent: .pink)
            }
        }
        .padding(16)
        .background(Color.white)
    }
    
    private var customerBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Customer").font(.headline)
            Text("Name: \(estimate.customerName)")
            Text("Address: \(estimate.address)")
            Text("Phone: \(estimate.phone)")
            Text("Email: \(estimate.email)")
        }
    }
    
    private func printableTierCard(system: EstimateSystem, tier: Tier, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(seriesLabel(tier)).font(.headline)
            if let opt = system.options.first(where: { $0.tier == tier && $0.showToCustomer }) {
                Text("\(formatSystemCapacity(system)) • \(system.equipmentType.rawValue)")
                    .font(.subheadline)
                Text("\(opt.seer, specifier: "%.0f") SEER • \(opt.stage)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("System")
                    Spacer()
                    Text(formatCurrency(opt.price)).bold()
                }
                if !enabledAddOns.isEmpty {
                    Divider().padding(.vertical, 2)
                    Text("Add-Ons").font(.subheadline).bold()
                    ForEach(enabledAddOns) { addon in
                        HStack {
                            Text(addon.name).font(.caption2)
                            Spacer()
                            Text(formatCurrency(addon.price)).font(.caption2).bold()
                        }
                    }
                }
                Divider().padding(.vertical, 2)
                HStack {
                    Text("Add-Ons Subtotal")
                    Spacer()
                    Text(formatCurrency(addOnsSubtotal)).bold()
                }
                HStack {
                    Text("Total").bold()
                    Spacer()
                    Text(formatCurrency(opt.price + addOnsSubtotal)).bold()
                }
            } else {
                Text("No option").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(accent.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(0.45), lineWidth: 1))
    }
    
    private var enabledAddOns: [AddOn] {
        estimate.addOns.filter { $0.enabled && $0.systemId == system.id }
    }
    private var addOnsSubtotal: Double {
        enabledAddOns.map { $0.price }.reduce(0, +)
    }
    
    private func seriesLabel(_ t: Tier) -> String {
        switch t {
        case .good: return "Good"
        case .better: return "Better"
        case .best: return "Best"
        }
    }
    private func formatSystemCapacity(_ sys: EstimateSystem) -> String {
        if sys.equipmentType == .furnaceOnly {
            return "\(Int(sys.tonnage).formatted(.number.grouping(.automatic))) BTU"
        } else {
            return formatTonnage(sys.tonnage)
        }
    }
    private func pastel(_ idx: Int) -> Color {
        switch idx % 3 { case 0: return .blue; case 1: return .green; default: return .orange }
    }
}

// Printable totals comparison page (mirrors totalsComparisonSection)
struct PrintableTotalsComparisonPage: View {
    let estimate: Estimate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimate Totals").font(.title.bold())
            customerBlock
            Text("Proposal Totals by Series").font(.headline)
            HStack(alignment: .top, spacing: 12) {
                column(title: "Good", tier: .good, color: .blue)
                column(title: "Better", tier: .better, color: .purple)
                column(title: "Best", tier: .best, color: .pink)
            }
        }
        .padding(16)
        .background(Color.white)
    }
    
    private var customerBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Customer").font(.headline)
            Text("Name: \(estimate.customerName)")
            Text("Address: \(estimate.address)")
            Text("Phone: \(estimate.phone)")
            Text("Email: \(estimate.email)")
        }
    }
    
    private func column(title: String, tier: Tier, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            ForEach(Array(enabledSystems.enumerated()), id: \.element.id) { pair in
                let idx = pair.offset
                let sys = pair.element
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(idx + 1). System").font(.subheadline).bold()
                    HStack {
                        Text("System")
                        Spacer()
                        Text(formatCurrency(optionPrice(system: sys, tier: tier))).bold()
                    }
                    let addons = addOnsForSystem(sys)
                    if !addons.isEmpty {
                        ForEach(addons) { addon in
                            HStack {
                                Text(addon.name).font(.caption2)
                                Spacer()
                                Text(formatCurrency(addon.price)).font(.caption2).bold()
                            }
                        }
                    }
                    Divider().padding(.vertical, 2)
                    HStack {
                        Text("Add-Ons Subtotal")
                        Spacer()
                        Text(formatCurrency(addOnsSubtotal(for: sys))).bold()
                    }
                    HStack {
                        Text("Total").bold()
                        Spacer()
                        Text(formatCurrency(optionPrice(system: sys, tier: tier) + addOnsSubtotal(for: sys))).bold()
                    }
                }
            }
            Divider()
            HStack {
                Text("Total").bold()
                Spacer()
                Text(formatCurrency(enabledSystems.map { optionPrice(system: $0, tier: tier) + addOnsSubtotal(for: $0) }.reduce(0, +))).bold()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.45), lineWidth: 1))
    }
    
    private var enabledSystems: [EstimateSystem] { estimate.systems.filter { $0.enabled } }
    
    private func optionPrice(system: EstimateSystem, tier: Tier) -> Double {
        system.options.first(where: { $0.tier == tier })?.price ?? 0
    }
    private func addOnsForSystem(_ system: EstimateSystem) -> [AddOn] {
        estimate.addOns.filter { $0.enabled && $0.systemId == system.id }
    }
    private func addOnsSubtotal(for system: EstimateSystem) -> Double {
        addOnsForSystem(system).map { $0.price }.reduce(0, +)
    }
}



