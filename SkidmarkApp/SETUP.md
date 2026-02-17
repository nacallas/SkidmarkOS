# Skidmark iOS App Setup

## Current Status

The project structure and core data models have been created. To complete the setup, you need to create an Xcode project.

## Creating the Xcode Project

1. Open Xcode
2. Create a new project: File > New > Project
3. Select "iOS" > "App" template
4. Configure the project:
   - Product Name: SkidmarkApp
   - Interface: SwiftUI
   - Language: Swift
   - Minimum Deployment: iOS 15.0
5. Save the project in the `SkidmarkApp` directory

## Adding Dependencies

Add SwiftCheck for property-based testing:

1. In Xcode, go to File > Add Package Dependencies
2. Enter the URL: `https://github.com/typelift/SwiftCheck.git`
3. Select version: 0.12.0 or later
4. Add to target: SkidmarkAppTests

## Importing Existing Files

The following files have already been created and should be added to your Xcode project:

### Models (already created)
- `Models/Team.swift` - Team data model with streak and player support
- `Models/League.swift` - League and LeagueConnection models
- `Models/LeagueContext.swift` - League context for roast customization

### Views (already created)
- `Views/ContentView.swift` - Placeholder main view

### Tests (already created)
- `Tests/TeamTests.swift` - Basic unit tests for Team model

### App Entry Point (already created)
- `SkidmarkApp.swift` - Main app entry point

## Folder Structure

The project follows this structure:
```
SkidmarkApp/
├── Models/              # Core data models ✓
├── ViewModels/          # MVVM view models (to be created)
├── Views/               # SwiftUI views ✓
├── Services/            # API clients and services (to be created)
├── Utilities/           # Helper functions (to be created)
└── Tests/               # Unit and property-based tests ✓
```

## Alternative: Using Swift Package Manager

If you prefer to use Swift Package Manager without Xcode:

```bash
cd SkidmarkApp
swift build  # Builds successfully
```

Note: Testing with SwiftCheck requires Xcode's XCTest framework. The `swift test` command will fail without Xcode.

## Next Steps

After setting up the Xcode project:
1. Verify all models compile
2. Run the basic unit tests
3. Proceed to Task 2: Implement remaining data models and property-based tests
