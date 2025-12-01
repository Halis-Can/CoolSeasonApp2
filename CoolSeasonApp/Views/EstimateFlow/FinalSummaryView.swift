//
//  FinalSummaryView.swift
//  CoolSeasonApp
//

import SwiftUI
import MessageUI

struct FinalSummaryView: View {
    @EnvironmentObject var estimateVM: EstimateViewModel
    @State private var showingActivity = false
    @State private var showingMail = false
    @State private var showingMessage = false
    @State private var pdfData: Data?
    @State private var pdfURL: URL?
    let back: () -> Void
    
    var body: some View {
        Group {
            if enabledSystems.count > 1 {
                // Multi-system: show per-system paged summaries, then a totals page
                TabView {
                    ForEach(Array(enabledSystems.enumerated()), id: \.element.id) { idx, sys in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                Text("Estimate").font(.largeTitle.bold())
                                customerSection
                                SystemSummaryPage(system: sys, index: idx)
                                signatureSection
                                shareButton
                            }
                            .frame(maxWidth: 900)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                        }
                    }
                    // Final totals page
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            Text("Estimate Totals").font(.largeTitle.bold())
                            customerSection
                            totalsComparisonSection
                            signatureSection
                            shareButton
                        }
                        .frame(maxWidth: 900)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                    }
                }
                .tabViewStyle(.page)
            } else {
                // Single-system: keep consolidated layout
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Estimate")
                            .font(.largeTitle.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                        customerSection
                        if let only = enabledSystems.first {
                            SystemSummaryPage(system: only, index: 0)
                        }
                        signatureSection
                        shareButton
                    }
                    .frame(maxWidth: 900)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                }
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingActivity) {
            if let url = pdfURL {
                ActivityView(activityItems: [url])
            } else if let data = pdfData {
                ActivityView(activityItems: [data, "CoolSeason Estimate.pdf"])
            }
        }
        .sheet(isPresented: $showingMail) {
            if let data = pdfData {
                MailComposerView(
                    subject: "CoolSeason Estimate",
                    recipients: estimateVM.currentEstimate.email.isEmpty ? [] : [estimateVM.currentEstimate.email],
                    body: "Please find your HVAC estimate attached.",
                    attachments: [(data, "application/pdf", "CoolSeasonEstimate.pdf")]
                )
            }
        }
        .sheet(isPresented: $showingMessage) {
            if let data = pdfData {
                MessageComposerView(
                    recipients: estimateVM.currentEstimate.phone.isEmpty ? [] : [estimateVM.currentEstimate.phone],
                    body: "Your CoolSeason estimate is attached.",
                    attachments: [(data, "com.adobe.pdf", "CoolSeasonEstimate.pdf")]
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        generatePDF(); showingMail = true
                    } label: { Label("Email", systemImage: "envelope") }
                    .disabled(!MFMailComposeViewController.canSendMail())
                    Button {
                        generatePDF(); showingMessage = true
                    } label: { Label("Text", systemImage: "message") }
                    .disabled(!MFMessageComposeViewController.canSendText())
                } label: {
                    Image(systemName: "paperplane")
                }
            }
        }
    }
    
    private var enabledSystems: [EstimateSystem] {
        estimateVM.currentEstimate.systems.filter { $0.enabled }
    }
    
    private var shareButton: some View {
        Button {
            generatePDF()
            showingActivity = true
        } label: {
            Label("Share Estimate (Email / Text / PDF)", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }
    
    private var customerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Customer").font(.title2).bold()
                LabeledRow(label: "Name:", value: estimateVM.currentEstimate.customerName)
                LabeledRow(label: "Address:", value: estimateVM.currentEstimate.address)
                LabeledRow(label: "Phone:", value: estimateVM.currentEstimate.phone)
                LabeledRow(label: "Email:", value: estimateVM.currentEstimate.email)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimate #").font(.caption).foregroundStyle(.secondary)
                    Text(estimateVM.currentEstimate.estimateNumber.isEmpty ? "—" : estimateVM.currentEstimate.estimateNumber)
                        .font(.title2.bold())
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date").font(.caption).foregroundStyle(.secondary)
                    Text(estimateVM.currentEstimate.estimateDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.title3)
                }
            }
            .padding(12)
            .frame(minWidth: 220)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: 2)
            )
        }
    }
    
    private struct LabeledRow: View {
        let label: String
        let value: String
        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label).font(.subheadline.bold())
                Text(value).font(.subheadline)
            }
        }
    }
    
    // MARK: - Proposal Options (3-column boxes for Comfortable / Performance / Infinity)
    
    private var proposalOptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Proposal Options").font(.title2).bold()
            HStack(alignment: .top, spacing: 16) {
                ForEach(visibleTiers, id: \.self) { tier in
                    ProposalTierCard(tier: tier, label: label(for: tier))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(UIColor.separator), lineWidth: 1)
            )
        }
    }
    
    private var visibleTiers: [Tier] {
        [Tier.good, .better, .best].filter { tier in
            estimateVM.currentEstimate.systems.contains { sys in
                sys.options.contains { $0.tier == tier && $0.isSelectedByCustomer }
            }
        }
    }
    
    private func label(for tier: Tier) -> String {
        switch tier {
        case .good: return "Comfortable Series"
        case .better: return "Performance Series"
        case .best: return "Infinity Series"
        }
    }
    
    private struct ProposalTierCard: View {
        let tier: Tier
        let label: String
        @EnvironmentObject var estimateVM: EstimateViewModel
        
        var body: some View {
            let items = systemsWithOption
            VStack(alignment: .leading, spacing: 10) {
                // Up to 3 images across the top (if available)
                if !imageNames.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(imageNames.prefix(3), id: \.self) { name in
                            Image(systemName: name)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Spacer()
                    }
                }
                
                Text(label).font(.headline)
                if items.isEmpty {
                    Text("No matching options").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(items, id: \.0.id) { sys, opt in
                        VStack(alignment: .leading, spacing: 6) {
                            // Single line system info
                            Text("\(sys.name) • \(formatSystemCapacity(sys)) • \(sys.equipmentType.rawValue)")
                                .font(.subheadline).bold()
                            Text("\(opt.seer, specifier: "%.0f") SEER • \(opt.stage)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            // Model numbers
                            if let m = opt.outdoorModel, !m.isEmpty {
                                Text("Outdoor: \(m)").font(.caption).foregroundStyle(.secondary)
                            }
                            if let m = opt.indoorModel, !m.isEmpty {
                                Text("Indoor: \(m)").font(.caption).foregroundStyle(.secondary)
                            }
                            if let m = opt.furnaceModel, !m.isEmpty {
                                Text("Furnace: \(m)").font(.caption).foregroundStyle(.secondary)
                            }
                            // Price at the bottom of sub-box
                            HStack {
                                Spacer()
                                Text(formatCurrency(opt.price)).font(.subheadline.bold())
                            }
                        }
                        .padding(6)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                
                // Inline Additional Equipment list for clarity
                if !enabledAddOns.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Additional Equipment")
                            .font(.subheadline).bold()
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
                // Per-card subtotals and total investment
                HStack {
                    Text("Systems Subtotal")
                    Spacer()
                    Text(formatCurrency(optionSum))
                }
                HStack {
                    Text("Add-Ons Subtotal")
                    Spacer()
                    Text(formatCurrency(addOnsSubtotal))
                }
                HStack {
                    Text("Total Investment").bold()
                    Spacer()
                    Text(formatCurrency(totalIncludingAddOns)).font(.title3.bold())
                }
                Button {
                    estimateVM.acceptProposal(tier: tier)
                } label: {
                    Text("Accept \(label)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(pastelColor(for: tier).opacity(0.25))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(UIColor.separator), lineWidth: 1)
            )
        }
        
        private var systemsWithOption: [(EstimateSystem, SystemOption)] {
            estimateVM.currentEstimate.systems.compactMap { sys in
                guard let opt = sys.options.first(where: { $0.tier == tier && $0.isSelectedByCustomer }) else { return nil }
                return (sys, opt)
            }
        }
        
        private var addOnsSubtotal: Double {
            var total: Double = 0
            for a in estimateVM.currentEstimate.addOns {
                if a.enabled { total += a.price }
            }
            return total
        }
        
        private var enabledAddOns: [AddOn] {
            var items: [AddOn] = []
            for a in estimateVM.currentEstimate.addOns {
                if a.enabled { items.append(a) }
            }
            return items
        }
        
        private var optionSum: Double {
            systemsWithOption.map { $0.1.price }.reduce(0, +)
        }
        
        private var totalIncludingAddOns: Double {
            optionSum + addOnsSubtotal
        }
        
        private var imageNames: [String] {
            systemsWithOption.compactMap { (_, opt) -> String? in
                if let name = opt.imageName, UIImage(systemName: name) != nil {
                    return name
                }
                return nil
            }
        }
        
        private func formatSystemCapacity(_ sys: EstimateSystem) -> String {
            if sys.equipmentType == .furnaceOnly {
                return "\(Int(sys.tonnage).formatted(.number.grouping(.automatic))) BTU"
            } else {
                return formatTonnage(sys.tonnage)
            }
        }
        
        private func pastelColor(for tier: Tier) -> Color {
            switch tier {
            case .good: return Color.blue
            case .better: return Color.purple
            case .best: return Color.pink
            }
        }
    }
    
    // MARK: - Per-system page
    private struct SystemSummaryPage: View {
        let system: EstimateSystem
        let index: Int
        @EnvironmentObject var estimateVM: EstimateViewModel
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(index + 1). System")
                        .font(.headline)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(pastelColorForIndex(index).opacity(0.25))
                        .clipShape(Capsule())
                    Spacer()
                }
                Text(system.name).font(.title2).bold()
                
                // Three side-by-side tier cards for this system
                HStack(alignment: .top, spacing: 12) {
                    SystemTierCard(system: system, tier: .good, accent: Color.blue)
                    SystemTierCard(system: system, tier: .better, accent: Color.purple)
                    SystemTierCard(system: system, tier: .best, accent: Color.pink)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 14).fill(pastelColorForIndex(index).opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(pastelColorForIndex(index).opacity(0.35), lineWidth: 1))
        }
        
        private var enabledAddOns: [AddOn] {
            estimateVM.currentEstimate.addOns.filter { $0.enabled && $0.systemId == system.id }
        }
        
        private func label(for tier: Tier) -> String {
            switch tier {
            case .good: return "Comfortable Series"
            case .better: return "Performance Series"
            case .best: return "Infinity Series"
            }
        }
        
        private func formatSystemCapacity(_ sys: EstimateSystem) -> String {
            if sys.equipmentType == .furnaceOnly {
                return "\(Int(sys.tonnage).formatted(.number.grouping(.automatic))) BTU"
            } else {
                return formatTonnage(sys.tonnage)
            }
        }
        
        private func pastelColorForIndex(_ idx: Int) -> Color {
            switch idx % 3 {
            case 0: return Color.blue
            case 1: return Color.green
            default: return Color.orange
            }
        }
    }
    
    // Single system tier card with per-tier totals
    private struct SystemTierCard: View {
        let system: EstimateSystem
        let tier: Tier
        let accent: Color
        @EnvironmentObject var estimateVM: EstimateViewModel
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(seriesLabel(tier))
                    .font(.headline)
                if let opt = option {
                    Text("\(formatSystemCapacity(system)) • \(system.equipmentType.rawValue)")
                        .font(.subheadline)
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
                    // System price just above Add-Ons, as requested
                    HStack {
                        Text("System")
                        Spacer()
                        Text(formatCurrency(opt.price)).bold()
                    }
                    // List add-ons individually for this system (smaller text to fit columns)
                    if !enabledAddOnsForSystem.isEmpty {
                        Divider().padding(.vertical, 2)
                        Text("Add-Ons").font(.subheadline).bold()
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(enabledAddOnsForSystem) { addon in
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(addon.name).font(.caption2)
                                        Text(addon.description).font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(formatCurrency(addon.price)).font(.caption2).bold()
                                }
                                .padding(6)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    Divider().padding(.vertical, 4)
                    HStack {
                        Text("Add-Ons")
                        Spacer()
                        Text(formatCurrency(addOnsSubtotal))
                    }
                    HStack {
                        Text("Total").bold()
                        Spacer()
                        Text(formatCurrency(opt.price + addOnsSubtotal)).bold()
                    }
                } else {
                    Text("No option available").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(accent.opacity(0.16)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.45), lineWidth: 1))
        }
        
        private var option: SystemOption? {
            system.options.first(where: { $0.tier == tier && $0.showToCustomer })
        }
        private var addOnsSubtotal: Double {
            var total: Double = 0
            for a in estimateVM.currentEstimate.addOns {
                if a.enabled && a.systemId == system.id { total += a.price }
            }
            return total
        }
        private var enabledAddOnsForSystem: [AddOn] {
            var items: [AddOn] = []
            for a in estimateVM.currentEstimate.addOns {
                if a.enabled && a.systemId == system.id { items.append(a) }
            }
            return items
        }
        
        private func seriesLabel(_ t: Tier) -> String {
            switch t {
            case .good: return "Comfortable Series"
            case .better: return "Performance Series"
            case .best: return "Infinity Series"
            }
        }
        
        private func formatSystemCapacity(_ sys: EstimateSystem) -> String {
            if sys.equipmentType == .furnaceOnly {
                return "\(Int(sys.tonnage).formatted(.number.grouping(.automatic))) BTU"
            } else {
                return formatTonnage(sys.tonnage)
            }
        }
    }
    
    private var systemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Systems").font(.title2).bold()
            ForEach(estimateVM.currentEstimate.systems.filter { $0.enabled }) { sys in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(sys.name) – \(formatTonnage(sys.tonnage)) – \(sys.equipmentType.rawValue)")
                        .font(.headline)
                    let selected = sys.options.filter { $0.showToCustomer && $0.isSelectedByCustomer }
                    if selected.isEmpty {
                        Text("No options selected").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(selected.enumerated()), id: \.offset) { idx, opt in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Option \(idx + 1)")
                                        .font(.subheadline.bold())
                                    Text("\(opt.tier.displayName) • \(opt.seer, specifier: "%.0f") SEER • \(opt.stage)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Text(formatCurrency(opt.price)).bold()
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).stroke(Color(UIColor.separator)))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var addOnsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Additional Equipment").font(.title2).bold()
            if estimateVM.currentEstimate.addOns.filter({ $0.enabled }).isEmpty {
                Text("None").foregroundStyle(.secondary)
            } else {
                ForEach(estimateVM.currentEstimate.addOns.filter { $0.enabled }) { addon in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(addon.name)
                            Text(addon.description).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(formatCurrency(addon.price)).bold()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private var totalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Totals").font(.title2).bold()
            HStack {
                Text("Systems Subtotal")
                Spacer()
                Text(formatCurrency(estimateVM.currentEstimate.systemsSubtotal))
            }
            HStack {
                Text("Add-Ons Subtotal")
                Spacer()
                Text(formatCurrency(estimateVM.currentEstimate.addOnsSubtotal))
            }
            HStack {
                Text("Total Investment")
                    .bold()
                Spacer()
                Text(formatCurrency(estimateVM.currentEstimate.grandTotal))
                    .bold()
            }
        }
    }
    
    // Comparison of proposal totals per tier across all systems
    private var totalsComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Proposal Totals by Series").font(.title2).bold()
            HStack(alignment: .top, spacing: 12) {
                tierTotalsColumn(title: "Comfortable Series", tier: .good, color: .blue)
                tierTotalsColumn(title: "Performance Series", tier: .better, color: .purple)
                tierTotalsColumn(title: "Infinity Series", tier: .best, color: .pink)
            }
        }
    }
    
    private func tierTotalsColumn(title: String, tier: Tier, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ForEach(Array(enabledSystems.enumerated()), id: \.element.id) { idx, sys in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(idx + 1). System").font(.subheadline).bold()
                    // System price line
                    HStack {
                        Text("System")
                        Spacer()
                        Text(formatCurrency(optionPrice(system: sys, tier: tier))).bold()
                    }
                    // Add-ons listed individually
                    let addons = addOnsForSystem(sys)
                    if !addons.isEmpty {
                        ForEach(addons) { addon in
                            HStack(alignment: .firstTextBaseline) {
                                Text(addon.name).font(.caption)
                                Spacer()
                                Text(formatCurrency(addon.price)).font(.caption).bold()
                            }
                        }
                    }
                    // Subtotals
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
                Text(formatCurrency(enabledSystems.map { perSystemTierTotal(system: $0, tier: tier) }.reduce(0, +)))
                    .bold()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.16)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.45), lineWidth: 1))
    }
    
    private func perSystemTierTotal(system: EstimateSystem, tier: Tier) -> Double {
        optionPrice(system: system, tier: tier) + addOnsSubtotal(for: system)
    }
    
    private func optionPrice(system: EstimateSystem, tier: Tier) -> Double {
        system.options.first(where: { $0.tier == tier })?.price ?? 0
    }
    
    private func addOnsForSystem(_ system: EstimateSystem) -> [AddOn] {
        estimateVM.currentEstimate.addOns.filter { $0.enabled && $0.systemId == system.id }
    }
    
    private func addOnsSubtotal(for system: EstimateSystem) -> Double {
        addOnsForSystem(system).map { $0.price }.reduce(0, +)
    }
    
    private var signatureSection: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Text("Signature").font(.headline)
                SignatureView(signatureData: Binding(
                    get: { estimateVM.currentEstimate.customerSignatureImageData },
                    set: { estimateVM.currentEstimate.customerSignatureImageData = $0; estimateVM.recalculateTotals() }
                ))
                .frame(width: 260, height: 120)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(UIColor.separator), lineWidth: 1)
                )
            }
        }
    }
    
    private func generatePDF() {
        // Build page-per-system + totals comparison PDF that mirrors the on-screen layout
        let estimate = estimateVM.currentEstimate
        let systems = estimate.systems.filter { $0.enabled }
        var pages: [AnyView] = []
        for (idx, sys) in systems.enumerated() {
            pages.append(AnyView(PrintableSystemPage(estimate: estimate, system: sys, index: idx)))
        }
        pages.append(AnyView(PrintableTotalsComparisonPage(estimate: estimate)))
        if let url = SwiftUIViewPDFRenderer.renderPages(pages: pages) {
            pdfURL = url
            pdfData = nil
            return
        }
        // Fallbacks
        if let url = SummaryPDFRenderer().renderPDF(estimate: estimate) {
            pdfURL = url
            pdfData = nil
            return
        }
        pdfData = EstimatePDFRenderer.render(estimate: estimate)
        pdfURL = nil
    }
}


