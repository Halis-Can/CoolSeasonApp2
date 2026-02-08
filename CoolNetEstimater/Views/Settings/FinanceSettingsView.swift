//
//  FinanceSettingsView.swift
//  CoolNetEstimater
//

import SwiftUI

struct FinanceSettingsView: View {
    @AppStorage("finance_rate_percent") private var financeRatePercent: Double = 0.0
    @AppStorage("finance_term_months") private var financeTermMonths: Int = 12
    @AppStorage("finance_markup_percent") private var financeMarkupPercent: Double = 0.0
    @AppStorage("payment_option") private var paymentOptionRaw: String = PaymentOption.cashCheckZelle.rawValue
    
    private var selectedPaymentOption: PaymentOption {
        get { PaymentOption(rawValue: paymentOptionRaw) ?? .cashCheckZelle }
        set { paymentOptionRaw = newValue.rawValue }
    }
    
    private let availableTerms: [Int] = [12, 36, 60]
    
    var body: some View {
        VStack(spacing: 16) {
            Form {
                Section {
                    DisclosureGroup("Payment Options") {
                        ForEach(PaymentOption.allCases, id: \.rawValue) { option in
                            Button {
                                paymentOptionRaw = option.rawValue
                            } label: {
                                HStack {
                                    Text(option.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedPaymentOption == option {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Finance options: only visible when Finance is selected
                        if selectedPaymentOption == .finance {
                            Divider()
                                .padding(.vertical, 4)
                            Group {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Finance Rate")
                                        .font(.subheadline.bold())
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
                                .padding(.vertical, 4)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Finance Term")
                                        .font(.subheadline.bold())
                                    Picker("Term", selection: $financeTermMonths) {
                                        ForEach(availableTerms, id: \.self) { term in
                                            Text("\(term) months").tag(term)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                                .padding(.vertical, 4)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Total Rate")
                                        .font(.subheadline.bold())
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
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 700)
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
        .background(CoolGradientBackground())
        .navigationTitle("Payment Settings")
    }
}

private let decimalFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.minimumFractionDigits = 0
    f.maximumFractionDigits = 2
    return f
}()


