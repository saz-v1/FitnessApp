import SwiftUI

struct BMIDetailView: View {
    @EnvironmentObject var userManager: UserManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // BMI Value
                HStack {
                    Text("Your BMI:")
                        .font(.headline)
                    Text(String(format: "%.1f", userManager.calculateBMI()))
                        .font(.title)
                        .bold()
                }
                
                // BMI Category and Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.headline)
                    Text(userManager.getBMICategory().description)
                        .foregroundColor(.secondary)
                }
                
                // BMI Scale Visualization
                BMIScaleView(currentBMI: userManager.calculateBMI())
                
                // Height and Weight
                Group {
                    HStack {
                        Text("Height:")
                        Text(userManager.user.usesMetric ? 
                            "\(Int(userManager.user.height)) cm" :
                            "\(Int(userManager.user.height)) in")
                            .bold()
                    }
                    
                    HStack {
                        Text("Weight:")
                        Text(userManager.user.usesMetric ?
                            "\(Int(userManager.user.weight)) kg" :
                            "\(Int(userManager.user.weight)) lbs")
                            .bold()
                    }
                }
                .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("BMI Details")
    }
}

struct BMIScaleView: View {
    let currentBMI: Double
    
    var body: some View {
        VStack(spacing: 8) {
            Text("BMI Scale")
                .font(.headline)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Scale background
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .frame(height: 30)
                    
                    // BMI marker
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 4, height: 40)
                        .offset(x: calculateMarkerPosition(width: geometry.size.width))
                }
            }
            .frame(height: 40)
            
            // Scale labels
            HStack {
                Text("16.5")
                Spacer()
                Text("18.5")
                Spacer()
                Text("25")
                Spacer()
                Text("30")
                Spacer()
                Text("35")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
    
    private func calculateMarkerPosition(width: CGFloat) -> CGFloat {
        let minBMI: Double = 16.5
        let maxBMI: Double = 35
        let bmiRange = maxBMI - minBMI
        let position = (currentBMI - minBMI) / bmiRange
        return CGFloat(position) * width
    }
} 