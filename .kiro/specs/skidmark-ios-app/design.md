# Design Document: Skidmark iOS App

## Overview

The Skidmark iOS app is a native Swift application that brings AI-powered fantasy football roast generation to iOS devices. The app maintains feature parity with the existing Next.js web application while leveraging iOS-native capabilities for authentication, data persistence, and sharing.

The architecture follows a clean separation between presentation (SwiftUI views), business logic (view models and services), and data access (API clients and local storage). The app communicates with a backend API hosted on AWS that handles AI roast generation via AWS Bedrock. League data is fetched directly from ESPN and Sleeper APIs, with appropriate authentication handling for each platform.

The design prioritizes user experience through default-on roast generation, secure credential storage, offline data access, and seamless sharing to messaging platforms. The power rankings algorithm matches the web app formula exactly to ensure consistency across platforms.

## Architecture

The iOS app follows the MVVM (Model-View-ViewModel) pattern with additional service layers for API communication and data persistence. This architecture provides clear separation of concerns and testability.

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        SwiftUI Views                         │
│  (LeagueListView, PowerRankingsView, ContextEditorView)    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                       View Models                            │
│   (LeagueViewModel, RankingsViewModel, ContextViewModel)   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    Service Layer                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ ESPN Service │  │Sleeper Service│  │Backend Service│     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │Storage Service│  │Keychain Svc  │                        │
│  └──────────────┘  └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    External Systems                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  ESPN API    │  │  Sleeper API │  │  AWS Backend │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

The presentation layer (SwiftUI views) handles user interaction and display logic. Views are declarative and reactive, updating automatically when view model state changes. Views should contain minimal logic, delegating all business operations to view models.

The view model layer manages presentation state and coordinates between views and services. View models expose published properties that views observe, handle user actions, and orchestrate service calls. Each major screen has a corresponding view model that owns its state.

The service layer encapsulates all external communication and data persistence. Services are protocol-based to enable testing and dependency injection. The ESPN and Sleeper services handle platform-specific API communication, the backend service manages AI roast generation, the storage service handles local data persistence, and the keychain service manages secure credential storage.

### Data Flow

User actions flow from views to view models. View models call appropriate services to fetch or persist data. Services communicate with external APIs or local storage. Results flow back through services to view models, which update published state. SwiftUI automatically re-renders views when published state changes.

For league connection, the user selects a platform and enters credentials. The view model validates input and calls the appropriate service (ESPN or Sleeper). The service fetches league data and returns a normalized league model. The view model updates state and triggers navigation to power rankings. The storage service persists the league connection for future sessions.

For roast generation, the view model sends team data and league context to the backend service. The backend service calls AWS Bedrock with a structured prompt. The service parses the AI response into individual roasts. The view model updates state with roasts for each team. Views display roasts beneath corresponding teams in the rankings list.

## Components and Interfaces

### Core Models

The League model represents a connected fantasy league with properties for id, name, platform (ESPN or Sleeper), season year, and team count. It includes optional authentication data for ESPN leagues.

The Team model represents a fantasy team within a league with properties for id, name, owner name, record (wins, losses, ties), points for, points against, power score, rank, streak, and optional roster of top players. It includes an optional roast string when Skidmark mode generates content.

The LeagueContext model stores user-provided customization with properties for inside jokes (array of term and explanation pairs), player personalities (array of name and description pairs), sacko punishment description, and general culture notes.

The LeagueConnection model persists league connection details with properties for league id, platform, league name, last updated timestamp, and whether authentication is configured.

### View Models

LeagueListViewModel manages the list of connected leagues. It exposes published properties for leagues array, loading state, and error messages. It provides methods to fetch all leagues from storage, add a new league connection, remove a league connection, and select a league for viewing.

PowerRankingsViewModel manages power rankings display and roast generation. It exposes published properties for teams array, loading state, roasts enabled flag (defaults to true), last updated timestamp, and error messages. It provides methods to fetch league data from the appropriate platform, calculate power rankings using the algorithm, generate roasts via backend service, refresh data, and toggle roast display.

LeagueContextViewModel manages league context editing. It exposes published properties for inside jokes array, personalities array, sacko punishment string, culture notes string, and save state. It provides methods to load context for a league, add/edit/remove inside jokes, add/edit/remove personalities, update sacko and culture fields, and save context to storage.

### Services

ESPNService handles ESPN API communication. It conforms to a LeagueDataService protocol with methods to authenticate with credentials, fetch league data for a given league id and season, and validate authentication status. The service manages cookie-based authentication by storing ESPN_S2 and SWID values in keychain and including them in API request headers. It transforms ESPN API responses into normalized Team models.

SleeperService handles Sleeper API communication. It conforms to the same LeagueDataService protocol with methods to fetch league data (no authentication needed) and fetch current NFL week. The service makes parallel requests to league, rosters, users, and matchups endpoints, then combines the data into normalized Team models.

BackendService handles AI roast generation. It provides a method to generate roasts that takes an array of teams and league context, constructs a prompt for AWS Bedrock, sends the request to the backend API, and parses the response into a dictionary mapping team id to roast text. The service handles retries and error cases.

StorageService manages local data persistence using UserDefaults for non-sensitive data and file storage for larger datasets. It provides methods to save and load league connections, save and load league context, cache league data with timestamps, and clear cached data for a league.

KeychainService manages secure credential storage. It provides methods to save ESPN credentials (ESPN_S2 and SWID), retrieve ESPN credentials, delete ESPN credentials, and check if credentials exist for a league. The service uses iOS Keychain APIs with appropriate access control.

### ESPN Authentication Design

Given that ESPN does not provide an official public API, the app must use the unofficial API endpoints with cookie-based authentication. The design supports two authentication flows to balance user experience with technical constraints.

For the primary flow, the app uses ASWebAuthenticationSession to present an in-app browser where users log into ESPN. After successful login, the app extracts ESPN_S2 and SWID cookies from the session and stores them securely in keychain. This provides a more integrated experience than manual cookie copying.

For the fallback flow, the app provides instructions for users to manually obtain cookies from Safari developer tools. Users copy the ESPN_S2 and SWID values and paste them into text fields in the app. The app validates the format (ESPN_S2 should be 100+ characters, SWID should start with "{") before storing in keychain.

Both flows store credentials in keychain associated with the league id. When making API requests, the ESPNService retrieves credentials from keychain and includes them in the Cookie header. If authentication fails (401 or 403 response), the service clears stored credentials and prompts for re-authentication.

The design acknowledges that this approach depends on ESPN's unofficial API remaining accessible. If ESPN changes their authentication system or blocks API access, the app will need to adapt. The protocol-based service design allows swapping authentication implementations without changing view models or views.

## Data Models

### Team Data Model

```swift
struct Team: Identifiable, Codable {
    let id: String
    let name: String
    let ownerName: String
    let wins: Int
    let losses: Int
    let ties: Int
    let pointsFor: Double
    let pointsAgainst: Double
    var powerScore: Double
    var rank: Int
    let streak: Streak
    let topPlayers: [Player]
    var roast: String?
    
    struct Streak: Codable {
        let type: StreakType
        let length: Int
        
        enum StreakType: String, Codable {
            case win = "W"
            case loss = "L"
        }
        
        var displayString: String {
            "\(type.rawValue)\(length)"
        }
    }
    
    var record: String {
        ties > 0 ? "\(wins)-\(losses)-\(ties)" : "\(wins)-\(losses)"
    }
    
    var winPercentage: Double {
        let totalGames = Double(wins + losses + ties)
        guard totalGames > 0 else { return 0 }
        return (Double(wins) + Double(ties) * 0.5) / totalGames
    }
}

struct Player: Identifiable, Codable {
    let id: String
    let name: String
    let position: String
    let points: Double
}
```

### League Data Model

```swift
struct League: Identifiable, Codable {
    let id: String
    let name: String
    let platform: Platform
    let seasonYear: Int
    let teamCount: Int
    
    enum Platform: String, Codable {
        case espn = "ESPN"
        case sleeper = "Sleeper"
    }
}

struct LeagueConnection: Identifiable, Codable {
    let id: String
    let leagueId: String
    let platform: League.Platform
    let leagueName: String
    let lastUpdated: Date
    let hasAuthentication: Bool
}
```

### League Context Data Model

```swift
struct LeagueContext: Codable {
    var insideJokes: [InsideJoke]
    var personalities: [PlayerPersonality]
    var sackoPunishment: String
    var cultureNotes: String
    
    struct InsideJoke: Identifiable, Codable {
        let id: UUID
        var term: String
        var explanation: String
    }
    
    struct PlayerPersonality: Identifiable, Codable {
        let id: UUID
        var playerName: String
        var description: String
    }
    
    static var empty: LeagueContext {
        LeagueContext(
            insideJokes: [],
            personalities: [],
            sackoPunishment: "",
            cultureNotes: ""
        )
    }
}
```

### Power Rankings Algorithm

The power rankings calculation matches the web app formula exactly. For each team, calculate three normalized components: win percentage (including ties as 0.5 wins), points for normalized by dividing by the maximum points for in the league, and points against normalized by calculating 1 minus the ratio of team points against to maximum points against in the league.

The power score combines these components with weights: 60% win percentage, 30% normalized points for, and 10% normalized points against. Teams are sorted by power score in descending order and assigned ranks from 1 to N.

```swift
func calculatePowerRankings(teams: [Team]) -> [Team] {
    guard !teams.isEmpty else { return [] }
    
    let maxPointsFor = teams.map { $0.pointsFor }.max() ?? 1.0
    let maxPointsAgainst = teams.map { $0.pointsAgainst }.max() ?? 1.0
    
    var rankedTeams = teams.map { team -> Team in
        var mutableTeam = team
        
        let winPct = team.winPercentage
        let pfNormalized = team.pointsFor / maxPointsFor
        let paNormalized = 1.0 - (team.pointsAgainst / maxPointsAgainst)
        
        mutableTeam.powerScore = (winPct * 0.6) + (pfNormalized * 0.3) + (paNormalized * 0.1)
        
        return mutableTeam
    }
    
    rankedTeams.sort { $0.powerScore > $1.powerScore }
    
    for (index, _) in rankedTeams.enumerated() {
        rankedTeams[index].rank = index + 1
    }
    
    return rankedTeams
}
```

### Backend API Integration

The backend API endpoint for roast generation accepts a POST request with team data and league context. The request body includes an array of team objects with id, name, owner, record, points, streak, and top players, plus the league context object with inside jokes, personalities, sacko, and culture notes.

The backend constructs a prompt for AWS Bedrock that includes instructions for Skidmark's voice and style, the team data formatted for analysis, and the league context for personalization. The prompt specifies that the response should be JSON with team ids mapped to roast text.

The backend calls AWS Bedrock using the Claude model (specific version to be determined during implementation based on availability and performance). The service includes retry logic for transient failures and timeout handling for slow responses.

The response is parsed into a dictionary mapping team id to roast string. The iOS app updates each team's roast property with the corresponding text. If parsing fails or roasts are missing for some teams, the app displays an error and allows retry.

### Data Persistence Strategy

League connections are stored in UserDefaults as an array of LeagueConnection objects encoded to JSON. This provides fast access for the league list view and persists across app launches.

League context is stored in the app's documents directory as individual JSON files named by league id (e.g., "league_12345_context.json"). This keeps context separate per league and allows larger data without UserDefaults size limits.

Cached league data (teams array) is stored in the documents directory as JSON files with timestamps. The cache is used when the app launches offline or to display data immediately while fetching updates. Cache files are named by league id and include the fetch timestamp.

ESPN credentials are stored in iOS Keychain with the league id as the account identifier. This provides secure storage with encryption and prevents credentials from being backed up to iCloud or extracted from device backups.

The storage service provides methods to clear all data for a league when the user removes a connection. This ensures no orphaned data remains on the device.

## Error Handling

The app uses a consistent error handling pattern across all services. Each service defines an error enum conforming to LocalizedError to provide user-friendly error messages.

Network errors are categorized as no connection (offline), timeout (slow response), or server error (5xx responses). Authentication errors distinguish between invalid credentials (401), forbidden access (403), and missing credentials. Data errors cover invalid responses, parsing failures, and missing required fields.

View models catch errors from services and update published error state. Views observe error state and display alerts with descriptive messages and actionable next steps. For example, authentication errors show a "Re-enter Credentials" button, network errors show a "Retry" button, and data errors show a "Refresh" button.

The app logs errors to the console in debug builds with full details including request/response data. In release builds, errors are logged with minimal information to avoid exposing sensitive data. Future iterations could integrate crash reporting services like Sentry or Firebase Crashlytics.

For roast generation failures, the app preserves the power rankings display and shows an error banner at the top of the screen. Users can dismiss the error and continue viewing rankings, or tap "Try Again" to retry roast generation without re-fetching league data.

## Testing Strategy

The app uses a dual testing approach combining unit tests for specific examples and edge cases with property-based tests for universal correctness properties. Both testing approaches are complementary and necessary for comprehensive coverage.

Unit tests focus on specific examples that demonstrate correct behavior, integration points between components, and edge cases like empty data, missing fields, and boundary conditions. Unit tests use XCTest framework and mock services to isolate components.

Property-based tests verify universal properties across all inputs using comprehensive input coverage through randomization. Each property test runs a minimum of 100 iterations with randomly generated data. Property tests use a Swift property-based testing library (such as SwiftCheck or swift-check) and reference design document properties in test comments.

The testing strategy includes unit tests for power rankings calculation with known inputs and expected outputs, data model encoding/decoding, view model state transitions, and error handling paths. It includes property-based tests for correctness properties defined in the next section, API response parsing with varied valid inputs, and data persistence round-trip operations.

Integration tests verify end-to-end flows using the iOS simulator, including league connection with real API calls (using test leagues), roast generation with backend service, and data persistence across app restarts. UI tests use XCUITest to verify critical user flows like connecting a league, viewing power rankings, and sharing roasts.

Mock services are implemented for each protocol to enable testing without network calls. Mocks return predefined data or errors based on test configuration. View models are tested with mock services to verify state management and error handling without external dependencies.


## Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system -- essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

### Property 1: Power Rankings Algorithm Correctness

*For any* set of teams with valid records and points, the power rankings calculation should produce scores using the formula (winPct * 0.6) + (pfNormalized * 0.3) + (paNormalized * 0.1), where win percentage treats ties as 0.5 wins, points for are normalized by league maximum, points against are normalized as 1 - (PA / max PA), and teams are sorted by power score in descending order with ranks assigned 1 through N.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**

### Property 2: Data Persistence Round-Trip

*For any* league connection, league context, or cached league data, saving then loading should produce equivalent data structures with all fields preserved.

**Validates: Requirements 1.6, 1.7, 5.5, 8.7, 10.1, 10.3, 10.4**

### Property 3: Authentication Inclusion in ESPN Requests

*For any* ESPN API request, when valid credentials exist in keychain for the league, those credentials should be included in the request headers.

**Validates: Requirements 2.2, 2.3**

### Property 4: Invalid Input Error Handling

*For any* invalid league ID, invalid credentials, or malformed API response, the system should return a descriptive error without crashing and allow the user to retry.

**Validates: Requirements 1.5, 9.1, 9.2, 9.3, 9.4, 9.5**

### Property 5: Roast Generation Completeness

*For any* successful roast generation request with N teams, the response should contain exactly N roasts, each 3-5 sentences in length, with each roast mapped to the correct team ID.

**Validates: Requirements 4.4, 4.8**

### Property 6: Roast Content References Statistics

*For any* generated roast, the text should contain references to at least one of the following: team record, points scored, recent performance, or player names from the roster.

**Validates: Requirements 4.5**

### Property 7: League Context Inclusion in Roast Prompts

*For any* roast generation request where league context is saved (inside jokes, personalities, sacko, or culture notes), all non-empty context fields should be included in the prompt sent to AWS Bedrock.

**Validates: Requirements 4.6, 5.6**

### Property 8: ESPN Data Transformation Correctness

*For any* ESPN API response, the transformation should combine location and nickname for team names, extract owner names from the owners array, select the top 5 players by applied stat total excluding bench and IR slots, and produce a Team model with all required fields populated.

**Validates: Requirements 12.1, 12.2, 12.3**

### Property 9: Sleeper Data Transformation Correctness

*For any* Sleeper API response set (league, rosters, users), the transformation should use metadata.team_name with fallback to display_name, match roster owner_id to user user_id, and produce a Team model with all required fields populated.

**Validates: Requirements 12.4, 12.5**

### Property 10: Platform-Agnostic Team Model

*For any* team data fetched from either ESPN or Sleeper, the resulting Team model should have the same structure and field types, with missing fields populated with sensible defaults (empty strings for names, 0 for numeric values, empty arrays for collections).

**Validates: Requirements 12.6, 12.7**

### Property 11: League Connection Isolation

*For any* two different league connections, saving context or cached data for one league should not affect the context or cached data for the other league.

**Validates: Requirements 5.8**

### Property 12: Multiple League Support

*For any* number of connected leagues (1 to N), the app should be able to store all connections, display them in a list with correct names and platforms, and load the correct data when a specific league is selected.

**Validates: Requirements 8.1, 8.2, 8.3**

### Property 13: League Removal Cleanup

*For any* league connection that is removed, all associated data (league context, cached league data, and ESPN credentials if applicable) should be deleted from storage, and the league should no longer appear in the connections list.

**Validates: Requirements 8.6, 10.7**

### Property 14: Data Refresh Triggers Recalculation

*For any* power rankings view with existing data, triggering a refresh should re-fetch league data from the API, recalculate power scores using the current data, and update the displayed rankings.

**Validates: Requirements 3.7, 6.2, 6.4**

### Property 15: Export Format Consistency

*For any* set of teams with or without roasts, the export function should produce plain text output with consistent formatting: rank, team name, owner, record, points, and optionally roast text, with each team on separate lines.

**Validates: Requirements 7.3**

### Property 16: Sleeper League Fetch Without Authentication

*For any* valid Sleeper league ID, the app should be able to fetch league data, rosters, and users without requiring any authentication credentials.

**Validates: Requirements 1.2**

### Property 17: ESPN League Fetch With Authentication

*For any* valid ESPN league ID and valid credentials (ESPN_S2 and SWID), the app should be able to fetch league data successfully.

**Validates: Requirements 1.4**

### Property 18: Power Rankings Display Completeness

*For any* team in the power rankings list, the display should include team name, owner name, record (wins-losses or wins-losses-ties), total points, and streak (format: W/L followed by number).

**Validates: Requirements 3.6**
