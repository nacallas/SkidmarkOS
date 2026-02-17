# Implementation Plan: Skidmark iOS App

## Overview

This implementation plan converts the Skidmark iOS app design into actionable coding tasks. The app is a native Swift/SwiftUI application that connects to ESPN and Sleeper fantasy football platforms, calculates power rankings, and generates AI-powered roasts using AWS Bedrock.

The implementation follows MVVM architecture with protocol-based services for testability. Tasks are organized to build incrementally from core data models through services to view models and finally UI components. Property-based tests validate universal correctness properties, while unit tests cover specific examples and edge cases.

## Tasks

- [x] 1. Set up project structure and core data models
  - Create new Xcode project with SwiftUI app template
  - Set up folder structure: Models/, ViewModels/, Views/, Services/, Utilities/
  - Configure build settings and deployment target (iOS 15+)
  - Add SwiftCheck or swift-check package dependency for property-based testing
  - _Requirements: All_

- [x] 2. Implement core data models
  - [x] 2.1 Create Team data model
    - Define Team struct with all properties (id, name, owner, record, points, streak, players, roast)
    - Implement Streak nested type with display formatting
    - Add computed properties for record string and win percentage
    - Conform to Identifiable and Codable protocols
    - _Requirements: 3.1, 3.2, 3.6, 12.6, 12.7_
  
  - [x] 2.2 Create League and LeagueConnection models
    - Define League struct with id, name, platform enum, season, team count
    - Define LeagueConnection struct for persistence with timestamps
    - Conform both to Identifiable and Codable
    - _Requirements: 1.1, 1.6, 8.1, 8.2, 10.1_
  
  - [x] 2.3 Create LeagueContext model
    - Define LeagueContext struct with inside jokes, personalities, sacko, culture notes
    - Define nested InsideJoke and PlayerPersonality types with UUID identifiers
    - Add static empty factory method
    - Conform to Codable
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_
  
  - [x] 2.4 Write property test for data persistence round-trip
    - **Property 2: Data Persistence Round-Trip**
    - **Validates: Requirements 1.6, 1.7, 5.5, 8.7, 10.1, 10.3, 10.4**
    - Generate random LeagueConnection, LeagueContext, and Team array instances
    - Encode to JSON then decode back
    - Verify all fields are preserved and equal to original
    - Run 100+ iterations with varied data

- [x] 3. Implement power rankings calculation
  - [x] 3.1 Create PowerRankingsCalculator utility
    - Implement calculatePowerRankings function that takes array of teams
    - Calculate win percentage treating ties as 0.5 wins
    - Normalize points for by dividing by league maximum
    - Normalize points against as 1 - (PA / max PA)
    - Calculate power score: (winPct * 0.6) + (pfNorm * 0.3) + (paNorm * 0.1)
    - Sort teams by power score descending and assign ranks 1 to N
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
  
  - [x] 3.2 Write property test for power rankings algorithm
    - **Property 1: Power Rankings Algorithm Correctness**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**
    - Generate random teams with varied records and points
    - Calculate power rankings
    - Verify formula correctness for each team's power score
    - Verify teams are sorted by power score descending
    - Verify ranks are sequential from 1 to N
    - Run 100+ iterations
  
  - [x] 3.3 Write unit tests for power rankings edge cases
    - Test with empty team array (should return empty)
    - Test with single team (rank should be 1)
    - Test with teams having identical records (should rank by points)
    - Test with teams having ties in record
    - _Requirements: 3.1, 3.2_

- [x] 4. Implement storage services
  - [x] 4.1 Create StorageService protocol and implementation
    - Define protocol with methods for saving/loading league connections, context, and cached data
    - Implement using UserDefaults for connections and FileManager for context/cache
    - Add methods to clear data for a specific league
    - Handle encoding/decoding errors gracefully
    - _Requirements: 10.1, 10.3, 10.4, 10.7_
  
  - [x] 4.2 Create KeychainService for secure credential storage
    - Define protocol with methods to save/retrieve/delete ESPN credentials
    - Implement using iOS Keychain APIs with league ID as account identifier
    - Set appropriate access control (kSecAttrAccessibleWhenUnlocked)
    - Handle keychain errors and return Result types
    - _Requirements: 2.2, 10.2_
  
  - [x] 4.3 Write property test for storage round-trip
    - **Property 2: Data Persistence Round-Trip** (continued from 2.4)
    - Test StorageService save then load for all data types
    - Verify data integrity after persistence
    - Run 100+ iterations
  
  - [x] 4.4 Write property test for league connection isolation
    - **Property 11: League Connection Isolation**
    - **Validates: Requirements 5.8**
    - Generate two different league IDs with different contexts
    - Save context for both leagues
    - Verify loading context for league A returns only league A data
    - Verify loading context for league B returns only league B data
    - Run 100+ iterations with varied league IDs

- [x] 5. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement Sleeper service (unauthenticated, simpler to start)
  - [x] 6.1 Define LeagueDataService protocol
    - Define protocol with methods: fetchLeagueData(leagueId:season:) async throws -> [Team]
    - Define custom error enum for network, authentication, and data errors
    - _Requirements: 1.1, 9.1, 9.2, 9.3_
  
  - [x] 6.2 Implement SleeperService conforming to LeagueDataService
    - Fetch league data from Sleeper API (no authentication needed)
    - Make requests to /league, /rosters, /users endpoints (start with basic data)
    - Combine responses into unified data structure
    - _Requirements: 1.2_
  
  - [x] 6.3 Implement Sleeper data transformation
    - Parse Sleeper API responses
    - Use metadata.team_name with fallback to display_name
    - Match roster owner_id to user user_id for owner names
    - Calculate wins/losses/ties from roster data
    - Calculate basic streak (can enhance later)
    - Transform to Team model with required fields (use sensible defaults for optional fields)
    - _Requirements: 12.4, 12.5_
  
  - [x] 6.4 Write basic unit tests for Sleeper service
    - Test successful league data fetch with mock responses
    - Test data transformation produces valid Team models
    - Test error handling for invalid league ID
    - Test error handling for network failures
    - _Requirements: 1.2, 9.1, 9.3_

- [x] 7. Checkpoint - Test Sleeper integration
  - Run all tests to verify Sleeper service works correctly
  - Manually test with a real Sleeper league ID if possible
  - Ensure all tests pass, ask the user if questions arise

- [x] 8. Implement ESPN service (authenticated, more complex)
  - [x] 8.1 Implement ESPNService conforming to LeagueDataService
    - Implement authentication with ESPN_S2 and SWID cookies
    - Fetch league data from ESPN API endpoint
    - Include credentials in Cookie header for requests
    - Handle 401/403 responses by clearing credentials and throwing auth error
    - _Requirements: 1.3, 1.4, 2.1, 2.3, 2.4_
  
  - [x] 8.2 Implement ESPN data transformation
    - Parse ESPN API response JSON
    - Combine team location and nickname for team name
    - Extract owner first and last names from owners array
    - Extract basic roster info (can enhance with top 5 starters later)
    - Calculate streak from recent matchups
    - Transform to Team model with all required fields
    - _Requirements: 12.1, 12.2, 12.3_
  
  - [x] 8.3 Write basic unit tests for ESPN service
    - Test successful league data fetch with mock responses
    - Test authentication header inclusion
    - Test 401 response clears credentials and throws auth error
    - Test data transformation produces valid Team models
    - _Requirements: 2.3, 2.4, 9.2, 9.3_

- [x] 9. Checkpoint - Test ESPN integration
  - Run all tests to verify ESPN service works correctly
  - Ensure all tests pass, ask the user if questions arise

- [x] 10. Implement backend service for roast generation (basic version)
  - [x] 10.1 Create BackendService for AWS Bedrock integration
    - Define generateRoasts method taking teams array and league context
    - Construct JSON request body with team data and context
    - Send POST request to backend API endpoint
    - Parse response JSON into dictionary mapping team ID to roast text
    - Handle timeout and basic error cases
    - _Requirements: 4.2, 4.3, 4.6_
  
  - [x] 10.2 Write basic unit tests for backend service
    - Test successful roast generation with mock responses
    - Test timeout returns appropriate error
    - Test malformed response returns parsing error
    - _Requirements: 4.10, 9.4_

- [x] 11. Checkpoint - Test backend integration
  - Run all tests to verify backend service works correctly
  - Ensure all tests pass, ask the user if questions arise

- [x] 12. Implement view models (basic functionality)
  - [x] 12.1 Create LeagueListViewModel
    - Define @Published properties: leagues array, loading state, error message
    - Implement fetchLeagues method using StorageService
    - Implement addLeague method to save new connection
    - Implement removeLeague method with cleanup (delete context, cache, credentials)
    - Implement selectLeague method to set active league
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_
  
  - [x] 12.2 Create PowerRankingsViewModel
    - Define @Published properties: teams array, loading state, roastsEnabled (default true), lastUpdated, error message
    - Inject LeagueDataService and BackendService dependencies
    - Implement fetchLeagueData method using appropriate service based on platform
    - Implement calculateRankings method using PowerRankingsCalculator
    - Implement generateRoasts method using BackendService
    - Implement refresh method that re-fetches data and recalculates
    - Implement toggleRoasts method to show/hide roasts
    - _Requirements: 3.7, 4.1, 4.8, 4.9, 6.2, 6.4, 6.5_
  
  - [x] 12.3 Create LeagueContextViewModel
    - Define @Published properties: insideJokes, personalities, sackoPunishment, cultureNotes, saveState
    - Inject StorageService dependency
    - Implement loadContext method for specific league
    - Implement addInsideJoke, editInsideJoke, removeInsideJoke methods
    - Implement addPersonality, editPersonality, removePersonality methods
    - Implement updateSacko and updateCulture methods
    - Implement saveContext method to persist to storage
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.7_
  
  - [x] 12.4 Write basic unit tests for view models
    - Test LeagueListViewModel state management
    - Test PowerRankingsViewModel data flow
    - Test LeagueContextViewModel editing operations
    - _Requirements: 5.7, 6.3, 6.5, 6.7_

- [x] 13. Checkpoint - Test view models
  - Run all tests to verify view models work correctly
  - Ensure all tests pass, ask the user if questions arise

- [x] 14. Implement SwiftUI views (basic UI)
  - [x] 14.1 Create LeagueListView
    - Display list of connected leagues with name and platform
    - Add navigation to PowerRankingsView when league selected
    - Add button to navigate to AddLeagueView
    - Add swipe-to-delete for removing leagues
    - Show loading indicator during fetch
    - Show error alert when errors occur
    - _Requirements: 8.2, 8.3, 8.4, 8.5_
  
  - [x] 14.2 Create AddLeagueView
    - Add platform picker (ESPN or Sleeper)
    - Add text field for league ID
    - Conditionally show ESPN credential fields (ESPN_S2, SWID) when ESPN selected
    - Add connect button that validates input and calls view model
    - Show loading indicator during connection
    - Show error alert for invalid credentials or league ID
    - Navigate back to league list on success
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_
  
  - [x] 14.3 Create PowerRankingsView (basic version)
    - Display scrollable list of teams with rank, name, owner, record, points, streak
    - Use basic styling for teams (can enhance with tier colors later)
    - Show roast text beneath each team when roastsEnabled is true
    - Add refresh button and pull-to-refresh gesture
    - Add toolbar button to toggle roasts on/off
    - Show loading indicator during fetch and roast generation
    - Show error banner for errors with retry button
    - Display last updated timestamp
    - _Requirements: 3.6, 4.8, 6.1, 6.2, 6.3, 6.6, 6.7_
  
  - [x] 14.4 Create LeagueContextView (basic version)
    - Display sections for inside jokes, personalities, sacko, culture notes
    - Add forms to add/edit/remove inside jokes with term and explanation fields
    - Add forms to add/edit/remove personalities with name and description fields
    - Add text field for sacko punishment
    - Add text area for culture notes
    - Add save button that calls view model
    - Show confirmation on successful save
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.7_
  
  - [x] 14.5 Implement basic export and sharing functionality
    - Add formatForExport method to PowerRankingsViewModel
    - Format teams as plain text with rank, name, owner, record, points
    - Optionally include roast text based on toggle
    - Implement copyToClipboard action using UIPasteboard
    - Implement share action using ShareLink
    - Show confirmation toast on successful copy
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7_

- [x] 15. Checkpoint - Test UI manually
  - Build and run the app in simulator
  - Test connecting a Sleeper league
  - Test viewing power rankings
  - Test basic navigation flows
  - Ask the user if questions arise

- [x] 16. Wire up dependency injection and app entry point
  - [x] 16.1 Wire up dependency injection
    - Create service container or use environment objects
    - Inject services into view models
    - Inject view models into views
    - Ensure proper lifecycle management
    - _Requirements: All_
  
  - [x] 16.2 Configure app entry point
    - Set up main App struct with initial view
    - Initialize services and storage
    - Handle app lifecycle events
    - _Requirements: 1.7, 10.5_

- [x] 17. Final checkpoint - End-to-end testing
  - Run all unit tests
  - Test complete flow: connect league → view rankings → generate roasts → share
  - Test on physical device if possible
  - Ensure all tests pass, ask the user if questions arise

## Future Enhancements (Optional)

These tasks can be implemented later to enhance the MVP:

- [x] Advanced UI styling and theming
  - Tier-based color coding for teams
  - Enhanced typography and spacing
  - Dark mode optimization
  
- [ ] Advanced error handling
  - Comprehensive error messages for all edge cases
  - Retry logic with exponential backoff
  - Network connectivity monitoring

- [ ] Offline support and caching
  - Cache league data for offline viewing
  - Auto-load last viewed league
  - Background refresh

- [x] ESPN authentication enhancements
  - ASWebAuthenticationSession for in-app login
  - Credential management UI
  - Token refresh handling

- [ ] Property-based tests for comprehensive validation
  - All 17 correctness properties from design document
  - 100+ iterations per property
  - Edge case discovery

## Notes

- The revised plan focuses on building a working MVP with Sleeper first (unauthenticated, simpler)
- ESPN support can be added after Sleeper is working
- Strategic checkpoints after each major component (services, view models, UI)
- Basic unit tests for core functionality, property tests deferred to future enhancements
- The implementation uses Swift and SwiftUI for iOS native development
- Services are protocol-based to enable testing with mocks
- View models use Combine publishers for reactive UI updates
- All sensitive data (ESPN credentials) stored securely in iOS Keychain
