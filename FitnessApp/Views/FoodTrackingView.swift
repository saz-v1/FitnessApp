import SwiftUI

struct FoodTrackingView: View {
    @StateObject private var viewModel = FoodEntryViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                // Input section
                VStack(spacing: 16) {
                    TextField("Describe your food (e.g., '2 slices of pepperoni pizza')", text: $viewModel.currentDescription)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Button(action: {
                        Task {
                            await viewModel.addFoodEntry()
                        }
                    }) {
                        if viewModel.isEstimating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Estimate Calories")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                    }
                    .disabled(viewModel.currentDescription.isEmpty || viewModel.isEstimating)
                }
                .padding()
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                // Food entries list
                List {
                    ForEach(viewModel.foodEntries) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.description)
                                    .font(.headline)
                                Text(entry.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Text("\(entry.calories) cal")
                                .font(.title3)
                                .foregroundColor(.green)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.removeFoodEntry(viewModel.foodEntries[index])
                        }
                    }
                }
            }
            .navigationTitle("Food Tracker")
        }
    }
}

#Preview {
    FoodTrackingView()
} 