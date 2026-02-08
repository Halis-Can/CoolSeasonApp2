//
//  FloorInputView.swift
//  CoolNetEstimater
//

import SwiftUI

struct FloorInputView: View {
    @EnvironmentObject var viewModel: AppStateViewModel
    var onCalculate: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach($viewModel.floors) { $floor in
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(floor.name.isEmpty ? "Floor" : floor.name)
                            .font(.headline)
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading) {
                                Text("Floor name").font(.subheadline).foregroundStyle(.secondary)
                                TextField("e.g. Main Level", text: $floor.name)
                                    .textFieldStyle(.roundedBorder)
                            }
                            VStack(alignment: .leading) {
                                Text("Floor type").font(.subheadline).foregroundStyle(.secondary)
                                Picker("", selection: $floor.floorType) {
                                    ForEach([FloorType.main, .upper, .basement]) { t in
                                        Text(t.title).tag(t)
                                    }
                                }.pickerStyle(.segmented)
                            }
                            VStack(alignment: .leading) {
                                Text("Square footage").font(.subheadline).foregroundStyle(.secondary)
                                TextField("0", value: $floor.squareFootage, formatter: decimalFormatter)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.removeFloor(id: floor.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Needs Cooling", isOn: $floor.needsCooling)
                            Toggle("Needs Heating", isOn: $floor.needsHeating)
                        }
                    }
                }
            }
            
            HStack {
                Button {
                    viewModel.addFloor()
                } label: {
                    Label("Add Floor", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.floors.count >= 3)
                
                Spacer()
                
                Button {
                    viewModel.calculateSizing()
                    if let onCalculate {
                        onCalculate()
                    }
                } label: {
                    Text("Calculate Sizing")
                        .frame(maxWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.floors.isEmpty || viewModel.selectedClimateZone == nil)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Floors & Loads")
    }
}

private let decimalFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 2
    return f
}()

private struct Card<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(Color(UIColor.separator), lineWidth: 1)
        )
    }
}

#Preview {
    FloorInputView().environmentObject(AppStateViewModel())
}


