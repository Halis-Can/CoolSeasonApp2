//
//  AddOnTemplatesView.swift
//  CoolNetEstimater
//

import SwiftUI

struct AddOnTemplatesView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var editTemplate: AddOnTemplate? = nil
    @State private var showingEditor: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            List {
                ForEach(settingsVM.addOnTemplates) { tmpl in
                    HStack(spacing: 12) {
                        Toggle(isOn: bindingForTemplateEnabled(tmpl.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tmpl.name)
                                Text(tmpl.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Price")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("0", value: Binding(
                                    get: { settingsVM.addOnTemplates.first(where: { $0.id == tmpl.id })?.defaultPrice ?? tmpl.defaultPrice },
                                    set: { newVal in
                                        if let idx = settingsVM.addOnTemplates.firstIndex(where: { $0.id == tmpl.id }) {
                                            settingsVM.addOnTemplates[idx].defaultPrice = newVal
                                        }
                                    }
                                ), formatter: currencyFormatter)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                            }
                            if tmpl.freeWhenTierIsBest {
                                Text("Free w/ Best")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                        Button {
                            editTemplate = tmpl
                            showingEditor = true
                        } label: {
                            Image(systemName: "pencil")
                                .imageScale(.medium)
                        }
                        .buttonStyle(.bordered)
                        Button(role: .destructive) {
                            settingsVM.addOnTemplates.removeAll { $0.id == tmpl.id }
                        } label: {
                            Image(systemName: "trash")
                                .imageScale(.medium)
                        }
                        .buttonStyle(.bordered)
                    }
                    .contentShape(Rectangle())
                }
                .onDelete { set in
                    settingsVM.addOnTemplates.remove(atOffsets: set)
                }
                Button {
                    editTemplate = AddOnTemplate(name: "", description: "", defaultPrice: 0, enabled: true, freeWhenTierIsBest: false)
                    showingEditor = true
                } label: {
                    Label("New Template", systemImage: "plus.circle")
                }
            }
            .frame(maxWidth: 900)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
        .background(CoolGradientBackground())
        .navigationTitle("Add-On Templates")
        .sheet(isPresented: $showingEditor) {
            if let binding = bindingForTemplate(editTemplate?.id) {
                AddOnTemplateEditor(template: binding, isNew: false, onSave: nil)
            } else if let newTmpl = editTemplate {
                AddOnTemplateCreator(initial: newTmpl) { created in
                    settingsVM.addOnTemplates.append(created)
                }
            }
        }
    }
    
    private func bindingForTemplate(_ id: UUID?) -> Binding<AddOnTemplate>? {
        guard let id, let idx = settingsVM.addOnTemplates.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { settingsVM.addOnTemplates[idx] },
            set: { settingsVM.addOnTemplates[idx] = $0 }
        )
    }
    
    private func bindingForTemplateEnabled(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { settingsVM.addOnTemplates.first(where: { $0.id == id })?.enabled ?? true },
            set: { newValue in
                guard let idx = settingsVM.addOnTemplates.firstIndex(where: { $0.id == id }) else { return }
                settingsVM.addOnTemplates[idx].enabled = newValue
            }
        )
    }
}

// MARK: - Editors

struct AddOnTemplateEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var template: AddOnTemplate
    let isNew: Bool
    let onSave: (() -> Void)?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Name", text: $template.name)
                    TextField("Description", text: $template.description)
                    HStack {
                        Text("Default Price")
                        Spacer()
                        TextField("0", value: $template.defaultPrice, formatter: currencyFormatter)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 180)
                    }
                    Toggle("Enabled", isOn: $template.enabled)
                    Toggle("Free when Best selected", isOn: $template.freeWhenTierIsBest)
                }
            }
            .navigationTitle(isNew ? "New Add-On Template" : "Edit Add-On Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !template.name.isEmpty else { dismiss(); return }
                        onSave?()
                        dismiss()
                    }
                    .disabled(template.name.isEmpty)
                }
            }
        }
    }
}

struct AddOnTemplateCreator: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: AddOnTemplate
    let onCreate: (AddOnTemplate) -> Void
    
    init(initial: AddOnTemplate, onCreate: @escaping (AddOnTemplate) -> Void) {
        _draft = State(initialValue: initial)
        self.onCreate = onCreate
    }
    
    var body: some View {
        AddOnTemplateEditor(template: $draft, isNew: true, onSave: {
            onCreate(draft)
        })
    }
}

private let currencyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    // Use plain decimal for easier editing; we still show currency elsewhere with formatCurrency(_:)
    f.numberStyle = .decimal
    f.minimumFractionDigits = 0
    f.maximumFractionDigits = 2
    f.usesGroupingSeparator = false
    f.locale = .current
    return f
}()


