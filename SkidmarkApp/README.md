# Skidmark iOS App

AI-powered fantasy football roast generator for iOS.

## Project Structure

```
SkidmarkApp/
├── Models/              # Core data models
│   ├── Team.swift
│   ├── League.swift
│   └── LeagueContext.swift
├── ViewModels/          # MVVM view models
├── Views/               # SwiftUI views
│   └── ContentView.swift
├── Services/            # API clients and data services
├── Utilities/           # Helper functions and utilities
└── Tests/               # Unit and property-based tests
```

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.9+

## Dependencies

- SwiftCheck: Property-based testing framework

## Build and Run

This project uses Swift Package Manager. Open `Package.swift` in Xcode or use the command line:

```bash
swift build
swift test
```

## Architecture

The app follows MVVM (Model-View-ViewModel) architecture with protocol-based services for testability. See the design document in `.kiro/specs/skidmark-ios-app/design.md` for detailed architecture information.
