//
//  EstimateListView.swift
//  CoolSeasonApp
//

import SwiftUI

struct EstimateListView: View {
    @EnvironmentObject var estimateVM: EstimateViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var searchText: String = ""
    @State private var navigateToFlow: Bool = false
    @State private var selectedEstimateId: UUID?
    @State private var startAtSummary: Bool = false
    
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
                                    Text(est.customerName.isEmpty ? "(No Name)" : est.customerName)
                                        .font(.headline)
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
        return estimateVM.estimates
            .sorted { $0.customerName.localizedCaseInsensitiveCompare($1.customerName) == .orderedAscending }
            .filter { key.isEmpty || $0.customerName.lowercased().contains(key) }
    }
}

#Preview {
    EstimateListView()
        .environmentObject(EstimateViewModel())
        .environmentObject(SettingsViewModel())
}


