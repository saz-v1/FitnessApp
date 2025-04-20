import SwiftUI

struct AddWeightSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userManager: UserManager
    @State private var weight: Double = 0
    @State private var date = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("Amount", value: $weight, format: .number)
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
            .navigationTitle("Add Weight")
            .navigationBarTitleDisplayMode(.inline)
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
                    .disabled(weight <= 0 || isSaving)
                }
            }
        }
    }
    
    private func saveWeight() async {
        isSaving = true
        errorMessage = nil
        
        do {
            // Convert to kg if using imperial
            let weightInKg = userManager.user.usesMetric ? weight : weight * 0.453592
            
            // Save to HealthKit
            try await HealthKitService.shared.saveWeight(weightInKg, date: date)
            
            // Save to app's data
            let record = WeightRecord(weight: weight, date: date)
            userManager.user.weightHistory.append(record)
            userManager.saveUser()
            
            dismiss()
        } catch {
            errorMessage = "Failed to save weight: \(error.localizedDescription)"
        }
        
        isSaving = false
    }
}

#Preview {
    AddWeightSheet()
        .environmentObject(UserManager())
} 