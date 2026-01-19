//
//  CompanyInfoSettingsView.swift
//  CoolSeasonApp
//

import SwiftUI

struct CompanyInfoSettingsView: View {
    @AppStorage("company_name") private var companyName: String = "CoolSeason HVAC"
    @AppStorage("company_phone") private var companyPhone: String = ""
    @AppStorage("company_email") private var companyEmail: String = ""
    @AppStorage("company_address") private var companyAddress: String = ""
    @AppStorage("company_license") private var companyLicense: String = ""
    @AppStorage("company_website") private var companyWebsite: String = ""
    
    // Draft values edited in the form; saved back to AppStorage on Save
    @State private var draftName: String = ""
    @State private var draftPhone: String = ""
    @State private var draftEmail: String = ""
    @State private var draftAddress: String = ""
    @State private var draftLicense: String = ""
    @State private var draftWebsite: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Form {
                Section("Company Information") {
                    TextField("Company Name", text: $draftName)
                    TextField("Phone", text: $draftPhone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $draftEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    TextField("Address", text: $draftAddress)
                    TextField("License Number", text: $draftLicense)
                    TextField("Website", text: $draftWebsite)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.none)
                        .autocorrectionDisabled(true)
                }
                
                Section {
                    Button {
                        // Persist drafts to AppStorage; Final Summary / diğer ekranlar anında güncellenir
                        companyName = draftName
                        companyPhone = draftPhone
                        companyEmail = draftEmail
                        companyAddress = draftAddress
                        companyLicense = draftLicense
                        companyWebsite = draftWebsite.lowercased()
                    } label: {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: 700)
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
        .background(CoolGradientBackground())
        .navigationTitle("Company Information")
        .onAppear {
            // Form ilk açıldığında AppStorage değerlerini draft’lara yükle
            draftName = companyName
            draftPhone = companyPhone
            draftEmail = companyEmail
            draftAddress = companyAddress
            draftLicense = companyLicense
            draftWebsite = companyWebsite
        }
    }
}

