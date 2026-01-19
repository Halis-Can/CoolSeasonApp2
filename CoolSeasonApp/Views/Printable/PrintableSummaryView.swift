//
//  PrintableSummaryView.swift
//  CoolSeasonApp
//

import SwiftUI

struct PrintableSummaryView: View {
    let estimate: Estimate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title + Meta
            HStack {
                Text("Estimate")
                    .font(.system(size: 28, weight: .bold))
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Estimate #:").font(.caption).foregroundStyle(.secondary)
                        Text(estimate.estimateNumber.isEmpty ? "—" : estimate.estimateNumber)
                            .font(.headline)
                    }
                    HStack(spacing: 6) {
                        Text("Date:").font(.caption).foregroundStyle(.secondary)
                        Text(estimate.estimateDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                    }
                }
            }
            // Customer
            VStack(alignment: .leading, spacing: 2) {
                Text("Customer").font(.title3).bold()
                LabeledRow(label: "Name:", value: estimate.customerName)
                LabeledRow(label: "Address:", value: estimate.address)
                LabeledRow(label: "Phone:", value: estimate.phone)
                LabeledRow(label: "Email:", value: estimate.email)
            }
            // Proposal Cards in three columns if space allows; print layout: vertical stack
            VStack(alignment: .leading, spacing: 12) {
                ProposalCard(tier: .good, title: "Good", estimate: estimate, color: .blue)
                ProposalCard(tier: .better, title: "Better", estimate: estimate, color: .purple)
                ProposalCard(tier: .best, title: "Best", estimate: estimate, color: .pink)
            }
            // Signature small box
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Signature").font(.headline)
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            .background(Color(UIColor.secondarySystemBackground))
                            .frame(width: 240, height: 110)
                        if let data = estimate.customerSignatureImageData, let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 220, height: 90)
                        } else {
                            Text("No signature")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(Color.white)
    }
    
    private struct LabeledRow: View {
        let label: String
        let value: String
        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(label).font(.subheadline.bold())
                Text(value).font(.subheadline)
            }
        }
    }
    
    private struct ProposalCard: View {
        let tier: Tier
        let title: String
        let estimate: Estimate
        let color: Color
        
        var body: some View {
            let items = systemsWithOption
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                if items.isEmpty {
                    Text("No matching options").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(items, id: \.0.id) { sys, opt in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(sys.name) • \(formatCapacity(sys)) • \(sys.equipmentType.rawValue)")
                                .font(.subheadline).bold()
                            Text("\(opt.seer, specifier: "%.0f") SEER • \(opt.stage)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let m = opt.outdoorModel, !m.isEmpty {
                                Text("Outdoor: \(m)").font(.caption).foregroundStyle(.secondary)
                            }
                            if let m = opt.indoorModel, !m.isEmpty {
                                Text("Indoor: \(m)").font(.caption).foregroundStyle(.secondary)
                            }
                            if let m = opt.furnaceModel, !m.isEmpty {
                                Text("Furnace: \(m)").font(.caption).foregroundStyle(.secondary)
                            }
                            HStack {
                                Spacer()
                                Text(formatCurrency(opt.price)).font(.subheadline.bold())
                            }
                        }
                        .padding(8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    if !enabledAddOns.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Additional Equipment").font(.subheadline).bold()
                            ForEach(enabledAddOns) { addon in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(addon.name)
                                        Text(addon.description).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(formatCurrency(addon.price)).bold()
                                }
                                .padding(6)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    Divider().padding(.vertical, 4)
                    HStack {
                        Text("Systems Subtotal")
                        Spacer()
                        Text(formatCurrencyPrintable(optionSum))
                    }
                    HStack {
                        Text("Add-Ons Subtotal")
                        Spacer()
                        Text(formatCurrencyPrintable(addOnsSubtotal))
                    }
                    HStack {
                        Text("Total Investment").bold()
                        Spacer()
                        Text(formatCurrencyPrintable(totalIncludingAddOns)).font(.title3.bold())
                    }
                }
            }
            .padding(14)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(UIColor.separator), lineWidth: 1))
        }
        
        private var systemsWithOption: [(EstimateSystem, SystemOption)] {
            estimate.systems.compactMap { sys in
                guard let opt = sys.options.first(where: { $0.tier == tier && $0.isSelectedByCustomer }) else { return nil }
                return (sys, opt)
            }
        }
        private var enabledAddOns: [AddOn] {
            estimate.addOns.filter { $0.enabled }
        }
        private var addOnsSubtotal: Double {
            enabledAddOns.map { $0.price }.reduce(0, +)
        }
        private var optionSum: Double {
            systemsWithOption.map { $0.1.price }.reduce(0, +)
        }
        private var totalIncludingAddOns: Double {
            optionSum + addOnsSubtotal
        }
        
        private func formatCapacity(_ sys: EstimateSystem) -> String {
            if sys.equipmentType == .furnaceOnly {
                return "\(Int(sys.tonnage)) BTU"
            } else {
                return formatTonnagePrintable(sys.tonnage)
            }
        }
    }
}

// MARK: - Formatters

private func formatCurrencyPrintable(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    return f.string(from: NSNumber(value: value)) ?? "$0.00"
}

private func formatTonnagePrintable(_ value: Double) -> String {
    if value == floor(value) {
        return "\(Int(value)) Ton"
    } else {
        return "\(value) Ton"
    }
}


