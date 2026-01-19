//
//  FinanceSettingsView.swift
//  CoolSeasonApp
//

import SwiftUI

struct FinanceSettingsView: View {
    @AppStorage("finance_rate_percent") private var financeRatePercent: Double = 0.0
    @AppStorage("finance_term_months") private var financeTermMonths: Int = 12
    @AppStorage("finance_markup_percent") private var financeMarkupPercent: Double = 0.0
    
    private let availableTerms: [Int] = [12, 36, 60]
    
    var body: some View {
        VStack(spacing: 16) {
            Form {
                Section("Finance Rate") {
                    HStack {
                        Text("Rate (%)")
                        Spacer()
                        TextField("0", value: $financeRatePercent, formatter: decimalFormatter)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                    Text("Enter the standard financing interest rate as a percentage.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Finance Term") {
                    Picker("Term", selection: $financeTermMonths) {
                        ForEach(availableTerms, id: \.self) { term in
                            Text("\(term) months").tag(term)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Total Rate") {
                    HStack {
                        Text("Total Rate (%)")
                        Spacer()
                        TextField("0", value: $financeMarkupPercent, formatter: decimalFormatter)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                    Text("Percentage applied on top of totals (Estimate & Final Summary).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 700)
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
        .background(CoolGradientBackground())
        .navigationTitle("Finance Settings")
    }
}

private let decimalFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.minimumFractionDigits = 0
    f.maximumFractionDigits = 2
    return f
}()


