//
//  EstimateListView.swift
//  CoolNetEstimater
//

import SwiftUI

struct EstimateListView: View {
    @EnvironmentObject var estimateVM: EstimateViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var searchText: String = ""
    @State private var navigateToFlow: Bool = false
    @State private var selectedEstimateId: UUID?
    @State private var startAtSummary: Bool = false
    @State private var selectedTab: EstimateTab = .pending
    
    enum EstimateTab {
        case pending
        case approved
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    TextField("Search by customer name", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        estimateVM.createNewEstimate()
                        startAtSummary = false
                        navigateToFlow = true
                    } label: {
                        Label("New Estimate", systemImage: "plus.circle.fill")
                    }.buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                
                // Tab selector
                Picker("Status", selection: $selectedTab) {
                    Text("Pending").tag(EstimateTab.pending)
                    Text("Approved").tag(EstimateTab.approved)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                List {
                    ForEach(filteredEstimates) { est in
                        HStack {
                            // Tap on name goes directly to Final Summary
                            Button {
                                estimateVM.loadEstimate(est)
                                startAtSummary = true
                                navigateToFlow = true
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(est.customerName.isEmpty ? "(No Name)" : est.customerName)
                                            .font(.headline)
                                        Spacer()
                                        // Status badge
                                        HStack(spacing: 4) {
                                            Image(systemName: est.status == .approved ? "checkmark.circle.fill" : "clock.fill")
                                                .font(.caption)
                                                .foregroundStyle(est.status == .approved ? .green : .orange)
                                            Text(est.status.rawValue)
                                                .font(.caption2)
                                                .foregroundStyle(est.status == .approved ? .green : .orange)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill((est.status == .approved ? Color.green : Color.orange).opacity(0.15))
                                        )
                                    }
                                    Text("\(est.estimateNumber.isEmpty ? "—" : est.estimateNumber) • \(est.estimateDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            // Delete button
                            Button(role: .destructive) {
                                estimateVM.deleteEstimate(id: est.id)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 8)
                            // Tap chevron opens at start
                            Button {
                                estimateVM.loadEstimate(est)
                                startAtSummary = false
                                navigateToFlow = true
                            } label: {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                estimateVM.deleteEstimate(id: est.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationDestination(isPresented: $navigateToFlow) {
                    EstimateFlowView(startStep: startAtSummary ? .summary : .customer)
                }
            }
            .padding(.top)
            .navigationTitle("Estimates")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    private var filteredEstimates: [Estimate] {
        let key = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let statusFilter: EstimateStatus = selectedTab == .pending ? .pending : .approved
        return estimateVM.estimates
            .filter { $0.status == statusFilter }
            .sorted { $0.customerName.localizedCaseInsensitiveCompare($1.customerName) == .orderedAscending }
            .filter { key.isEmpty || $0.customerName.lowercased().contains(key) }
    }
}

#Preview {
    EstimateListView()
        .environmentObject(EstimateViewModel())
        .environmentObject(SettingsViewModel())
}


