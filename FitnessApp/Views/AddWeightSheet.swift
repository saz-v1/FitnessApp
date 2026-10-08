import SwiftUI

struct AddWeightSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userManager: UserManager
    @State private var weight: Double = 0
    @State private var date = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var weightFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("A snapshot of your progress", systemImage: "scalemass")
                        .font(.headline).foregroundStyle(AppTheme.accent).padding(.vertical, 8)
                }
                Section("Measurement") {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("Amount", value: $weight, format: .number)
                            .accessibilityIdentifier("weight-amount")
                            .focused($weightFocused)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                        Text(userManager.user.usesMetric ? "kg" : "lbs")
                    }
                    
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .appForm()
            .navigationTitle("Add Weight")
            .navigationBarTitleDisplayMode(.inline)
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveWeight()
                        }
                    }
                    .disabled(!weight.isFinite || weight < (userManager.user.usesMetric ? 1 : 1 / 0.45359237) || weight > (userManager.user.usesMetric ? 700 : 700 / 0.45359237) || isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { weightFocused = false }
                }
            }
        }
    }
    
    private func saveWeight() async {
        isSaving = true
        errorMessage = nil
        
        let weightInKg = userManager.user.usesMetric ? weight : weight * 0.45359237
        guard weightInKg.isFinite, weightInKg > 0, weightInKg <= 700 else {
            errorMessage = "Enter a valid weight."
            isSaving = false
            return
        }
        guard userManager.addWeight(weightInKg, date: date) else {
            errorMessage = userManager.persistenceError ?? "Enter a valid weight and date."
            isSaving = false
            return
        }
        dismiss()
        
        isSaving = false
    }
}

#Preview {
    AddWeightSheet()
        .environmentObject(UserManager())
}
