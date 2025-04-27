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
- AI-powered workout recommendations
- Personalized fitness advice
- Smart goal suggestions
- Progress analysis and insights

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
- Accessibility support

### Navigation
- Tab-based navigation
- Modal presentations
- Deep linking support
- Smooth transitions
