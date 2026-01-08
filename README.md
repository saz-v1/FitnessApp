# Fitness App

An IOS fitness tracking application built with SwiftUI that helps users track their workouts, weight, calories, and achieve their fitness goals.

## Features

### 1. Dashboard
**Files:**
- `Views/DashboardView.swift`: Main dashboard showing overview of fitness metrics
- `Views/CalorieChartView.swift`: Visual representation of calorie tracking
- `Views/BMIDetailView.swift`: BMI calculation and tracking

The dashboard provides a comprehensive overview of the user's fitness journey, including:
- Daily calorie tracking
- BMI monitoring
- Quick access to key metrics
- Visual charts and progress indicators

### 2. Workout Tracking
**Files:**
- `Views/WorkoutLogView.swift`: Main workout logging interface
- `Views/AddWorkoutSheet.swift`: Interface for adding new workouts
- `Views/WorkoutInsightsView.swift`: Analytics and insights for workouts
- `Views/TargetedWorkoutView.swift`: Custom workout recommendations
- `Services/WorkoutAnalyticsService.swift`: Advanced workout analytics and insights

Features:
- Log different types of workouts
- Track duration, intensity, and calories burned
- Add specific exercises with sets, reps, and weights
- View workout history and statistics
- Get personalized workout recommendations
- Advanced analytics and performance tracking

### 3. Weight Tracking
**Files:**
- `Views/WeightDetailView.swift`: Detailed weight tracking interface
- `Views/AddWeightSheet.swift`: Interface for adding weight entries

Features:
- Track weight over time
- Set weight goals
- View weight trends
- Calculate BMI
- Track progress towards goals

### 4. Health Data Integration
**Files:**
- `Views/HealthDataView.swift`: Health data visualization
- `Services/HealthKitManager.swift`: HealthKit integration
- `Services/HealthKitService.swift`: Additional HealthKit functionality and data processing

Features:
- Integration with Apple HealthKit
- Track various health metrics
- Sync data with Health app
- View comprehensive health statistics
- Advanced health data processing and analysis

### 5. Achievements System
**Files:**
- `Views/AchievementsView.swift`: Achievement tracking interface
- `Models/Achievement.swift`: Achievement model and logic

Features:
- Track fitness milestones
- Earn points for completing activities
- Level progression system
- Achievement categories:
  - Weight achievements
  - Workout achievements
  - Consistency achievements
  - Milestone achievements

### 6. Profile Management
**Files:**
- `Views/ProfileView.swift`: User profile management
- `Models/User.swift`: User data model
- `Models/UserManager.swift`: User data management

Features:
- Personal information management
- Fitness goals setting
- Activity level tracking
- Unit preferences (metric/imperial)
- Profile customization

### 7. Notification System
**Files:**
- `Views/NotificationSettingsView.swift`: Notification preferences
- `Services/NotificationManager.swift`: Notification management

Features:
- Customizable reminders for:
  - Workout sessions
  - Weight logging
  - Food tracking
  - General fitness reminders
- Notification preferences management

### 8. Calorie Tracking
**Files:**
- `Views/CalorieDetailView.swift`: Detailed calorie tracking
- `Views/CalorieChartView.swift`: Calorie visualization

Features:
- Daily calorie tracking
- Calorie goal setting
- Visual progress tracking
- Historical data analysis

### 9. AI Integration
**Files:**
- `Services/ClaudeService.swift`: AI-powered fitness recommendations and insights

Features:
- AI-powered workout recommendations using Claude Haiku 3 API
- Personalized fitness advice
- Smart goal suggestions
- Progress analysis and insights
- Natural language processing for user input
- Contextual understanding of fitness goals

## API Key Configuration

The app uses an API key for certain features. To set up the API key:

1. Create a `Config.swift` file in the root directory
2. Add your Claude API key to the `Config.swift` file:
```swift
import Foundation

struct Config {
    static let apiKey = "YOUR_CLAUDE_API_KEY_HERE"
}
```
3. The `Config.swift` file is already added to `.gitignore` to prevent it from being committed to version control

Note: The app uses the Claude Haiku 3 API for AI-powered features. Make sure to obtain a valid API key from Anthropic's developer portal.

## Technical Architecture

### Directory Structure
```
FitnessApp/
├── Views/           # All UI components
├── Models/          # Data models and business logic
├── Services/        # External service integrations
├── Assets.xcassets/ # App resources
└── Preview Content/ # SwiftUI preview resources
```

### Key Components

#### Models
- `User.swift`: User data model
- `WorkoutRecord.swift`: Workout tracking model
- `Achievement.swift`: Achievement system model
- `HealthKitManager.swift`: HealthKit data management model

#### Services
- `HealthKitManager.swift`: HealthKit integration
- `HealthKitService.swift`: Additional HealthKit functionality
- `NotificationManager.swift`: Notification system
- `UserManager.swift`: User data management
- `WorkoutAnalyticsService.swift`: Workout analytics and insights
- `ClaudeService.swift`: AI integration service

#### Views
- Main navigation views
- Detail views
- Input forms
- Analytics views
- Settings views

## Data Management

### Local Storage
- UserDefaults for user preferences
- Core Data for workout history
- HealthKit for health data

### Data Models
- Comprehensive data models for all features
- Proper data validation
- Type-safe enums for constants

## UI/UX Features

### Design System
- Consistent color scheme
- Modern card-based design
- Responsive layouts

### Navigation
- Tab-based navigation
- Modal presentations
- Deep linking support
- Smooth transitions

## Implementation Details

### State Management
- Uses SwiftUI's `@State`, `@StateObject`, and `@EnvironmentObject` for state management
- Implements MVVM inspired architecture pattern
- Proper separation of concerns between views and business logic

### Data Flow
- Unidirectional data flow using SwiftUI's data binding
- Proper error handling and validation
- Efficient data caching and persistence

### Performance Optimizations
- Lazy loading of views and data
- Efficient image caching
- Background processing for heavy computations
- Memory management best practices

### Security
- Secure storage of user data
- Proper handling of sensitive health information
- Privacy-focused implementation
- Secure API communications

## Development Guidelines

### Code Style
- Follows Swift style guide
- Consistent naming conventions
- Proper documentation
- Clean architecture principles

### Best Practices
- SOLID principles
- DRY (Don't Repeat Yourself)
- KISS (Keep It Simple, Stupid)
- Proper error handling
- Memory management

## Development Principles

### SOLID Principles
The app follows SOLID principles to ensure maintainable and scalable code:

1. **Single Responsibility Principle (SRP)**
   - Each class has one specific responsibility
   - Example: `NotificationManager` handles only notification-related tasks
   ```swift
   class NotificationManager: NSObject, ObservableObject {
       // Only handles notification scheduling, permissions, and management
       func scheduleNotification(title: String, body: String, trigger: UNNotificationTrigger, identifier: String)
       func requestAuthorization()
       func removeAllNotifications()
   }
   ```

2. **Open/Closed Principle (OCP)**
   - Classes are open for extension but closed for modification
   - Example: `Achievement` system allows adding new achievements without modifying existing code
   ```swift
   enum Achievement.Category: String, Codable {
       case weight = "Weight"
       case calories = "Calories"
       case consistency = "Consistency"
       case milestones = "Milestones"
   }
   ```

3. **Liskov Substitution Principle (LSP)**
   - Subtypes can be used in place of their parent types
   - Example: Different workout types can be used interchangeably in the workout history
   ```swift
   struct WorkoutRecord: Identifiable, Codable, Equatable {
       let type: WorkoutType
       let duration: TimeInterval
       let intensity: Intensity
       
       enum WorkoutType: String, Codable, CaseIterable, Identifiable {
           case cardio = "Cardio"
           case strength = "Strength"
           case flexibility = "Flexibility"
           case hiit = "HIIT"
           case yoga = "Yoga"
           case other = "Other"
       }
   }
   ```

4. **Interface Segregation Principle (ISP)**
   - Clients only depend on interfaces they use
   - Example: `HealthKitManager` provides specific interfaces for different health data types
   ```swift
   class HealthKitManager: ObservableObject {
       func fetchSteps() async throws -> Int
       func fetchActiveEnergy() async throws -> Double
       func fetchHeartRate() async throws -> Double
       // Each method is specific to its use case
   }
   ```

5. **Dependency Inversion Principle (DIP)**
   - High-level modules don't depend on low-level modules
   - Example: `WorkoutAnalyticsService` depends on `ClaudeService` through dependency injection
   ```swift
   class WorkoutAnalyticsService: ObservableObject {
       private let claudeService: ClaudeService
       
       init(claudeService: ClaudeService = .shared) {
           self.claudeService = claudeService
       }
       
       func getWorkoutInsights(for user: User) async throws -> String {
           // Uses ClaudeService for AI-powered insights
           return try await claudeService.makeRequest(prompt: prompt)
       }
   }
   ```

### DRY (Don't Repeat Yourself)
The app avoids code duplication through:

1. **Reusable Components**
   - Common UI elements are extracted into reusable views
   ```swift
   struct StatCard: View {
       let title: String
       let value: String
       let icon: String
       // Used across multiple views for consistent styling
   }
   ```

2. **Shared Models**
   - Common data structures are reused
   ```swift
   struct WeightRecord: Codable, Identifiable, Equatable {
       let id: UUID
       let date: Date
       let weight: Double
       // Used for both local and HealthKit weight tracking
   }
   ```

### KISS (Keep It Simple, Stupid)
The app maintains simplicity through:

1. **Clear Naming**
   - Descriptive variable and function names
   ```swift
   func calculateBMI() -> Double
   func scheduleWorkoutReminder()
   ```

2. **Straightforward Logic**
   - Simple, readable code structures
   ```swift
   func getBMICategory() -> BMICategory {
       let bmi = calculateBMI()
       switch bmi {
       case ..<18.5: return .underweight
       case 18.5..<25: return .normal
       case 25..<30: return .overweight
       default: return .obese
       }
   }
   ```

## Future Enhancements

### Planned Features
- Social sharing capabilities
- Advanced workout planning
- Integration with more health platforms
- Enhanced AI recommendations
- Custom workout creation
- Progress sharing
- Community features
- Macronutrient Tracking

### Technical Improvements
- Improved data synchronization
- Better analytics
- More customization options
- Performance optimizations
- Graph Improvements such as Imperial Units handling
