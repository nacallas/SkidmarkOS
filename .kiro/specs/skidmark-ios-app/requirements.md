# Requirements Document: Skidmark iOS App

## Introduction

Skidmark is an AI-powered fantasy football analysis tool that generates personalized, profanity-laden roasts for fantasy football leagues. This document specifies the requirements for migrating the existing Next.js web application to a native iOS application while maintaining feature parity and leveraging iOS-native capabilities.

The iOS app will connect to ESPN and Sleeper fantasy platforms, calculate algorithmic power rankings, and use AWS Bedrock (Claude AI) to generate entertaining, statistically-accurate roasts based on team performance, league context, and user-provided inside jokes.

## Glossary

- **Skidmark**: The AI persona that generates fantasy football roasts with an aggressive, profanity-laced style
- **Power_Rankings**: Algorithmic team rankings based on wins (60%), points for (30%), and points against (10%)
- **Roast**: A 3-5 sentence AI-generated trash talk paragraph targeting a specific fantasy team
- **League_Context**: User-provided information including inside jokes, player personalities, sacko punishment, and culture notes
- **Skidmark_Mode**: Feature that enables AI roast generation for power rankings (enabled by default)
- **ESPN_Platform**: Fantasy football platform requiring authentication for private league access
- **Sleeper_Platform**: Fantasy football platform with public API (no authentication required)
- **Backend_API**: AWS-hosted backend service that interfaces with AWS Bedrock for AI generation
- **League_Connection**: Process of linking a fantasy league to the app via platform selection and league ID
- **Export_Feature**: Functionality to copy rankings and roasts to clipboard or share via iOS share sheet

## Requirements

### Requirement 1: League Connection

**User Story:** As a fantasy football player, I want to connect my ESPN or Sleeper league to the app, so that I can view power rankings and generate roasts for my league.

#### Acceptance Criteria

1. WHEN a user selects a platform (ESPN or Sleeper), THE League_Connection SHALL display the appropriate input fields for that platform
2. WHEN a user enters a valid league ID for Sleeper, THE League_Connection SHALL fetch league data without requiring authentication
3. WHEN a user enters a valid league ID for ESPN, THE League_Connection SHALL prompt for ESPN_S2 and SWID cookie values
4. WHEN a user provides valid ESPN cookies and league ID, THE League_Connection SHALL authenticate and fetch league data
5. IF invalid credentials or league ID are provided, THEN THE League_Connection SHALL display a descriptive error message and allow retry
6. WHEN league data is successfully fetched, THE League_Connection SHALL store the connection details for future sessions
7. WHEN a user has previously connected a league, THE League_Connection SHALL automatically load that league on app launch

### Requirement 2: ESPN Authentication

**User Story:** As an ESPN fantasy league member, I want to authenticate with ESPN, so that the app can access my private league data.

#### Acceptance Criteria

1. WHEN a user selects ESPN as the platform, THE ESPN_Platform SHALL provide a method to authenticate with ESPN
2. THE ESPN_Platform SHALL store authentication credentials securely using iOS Keychain
3. WHEN making API requests to ESPN, THE ESPN_Platform SHALL include valid authentication in requests
4. IF ESPN returns authentication errors, THEN THE ESPN_Platform SHALL prompt the user to re-authenticate
5. THE ESPN_Platform SHALL allow users to update or remove stored credentials from settings
6. THE ESPN_Platform SHALL handle authentication token expiration and prompt for re-authentication when needed

### Requirement 3: Power Rankings Calculation

**User Story:** As a fantasy football player, I want to see algorithmic power rankings for my league, so that I can understand team strength beyond just win-loss records.

#### Acceptance Criteria

1. WHEN league data is fetched, THE Power_Rankings SHALL calculate a power score for each team using the formula: (winPct * 0.6) + (pfNormalized * 0.3) + (paNormalized * 0.1)
2. WHEN calculating win percentage, THE Power_Rankings SHALL treat ties as 0.5 wins
3. WHEN normalizing points for, THE Power_Rankings SHALL divide each team's points by the maximum points in the league
4. WHEN normalizing points against, THE Power_Rankings SHALL calculate 1 - (team PA / max PA in league)
5. THE Power_Rankings SHALL sort teams by power score in descending order and assign ranks 1 through N
6. THE Power_Rankings SHALL display team name, owner name, record, total points, and current streak for each team
7. THE Power_Rankings SHALL update calculations whenever league data is refreshed

### Requirement 4: AI Roast Generation

**User Story:** As a fantasy football player, I want to generate AI-powered roasts for each team in my league, so that I can share entertaining trash talk with my league mates.

#### Acceptance Criteria

1. WHEN a user views power rankings, THE Skidmark_Mode SHALL be enabled by default
2. WHEN Skidmark_Mode is enabled, THE Backend_API SHALL send team data and league context to AWS Bedrock
3. THE Backend_API SHALL use an appropriate Claude model from AWS Bedrock for roast generation
4. THE Backend_API SHALL generate one roast per team, each 3-5 sentences in length
5. THE Roast SHALL reference actual statistics including record, points, recent performance, and roster composition
6. THE Roast SHALL incorporate league context when provided (inside jokes, player personalities, culture notes)
7. THE Roast SHALL match Skidmark's voice: aggressive, profanity-laced, creative metaphors, tier-appropriate (celebrates winners, destroys losers)
8. WHEN roasts are generated, THE Skidmark_Mode SHALL display each roast beneath its corresponding team in the power rankings
9. THE Skidmark_Mode SHALL allow users to toggle roasts on/off from settings
10. IF roast generation fails, THEN THE Skidmark_Mode SHALL display an error message and allow retry without re-fetching league data

### Requirement 5: League Context Management

**User Story:** As a fantasy football player, I want to customize league context with inside jokes and player personalities, so that the AI generates more personalized and relevant roasts.

#### Acceptance Criteria

1. THE League_Context SHALL provide input fields for inside jokes (term + explanation)
2. THE League_Context SHALL provide input fields for player personalities (name + description)
3. THE League_Context SHALL provide an input field for sacko punishment description
4. THE League_Context SHALL provide a text area for general league culture notes
5. WHEN a user saves league context, THE League_Context SHALL persist the data locally on the device
6. WHEN generating roasts, THE Backend_API SHALL include all saved league context in the AI prompt
7. THE League_Context SHALL allow users to add, edit, and remove individual context items
8. THE League_Context SHALL associate context with specific league connections (different context per league)

### Requirement 6: Data Refresh

**User Story:** As a fantasy football player, I want to refresh league data to see updated standings and statistics, so that roasts reflect the most current information.

#### Acceptance Criteria

1. THE Power_Rankings SHALL display a refresh button or pull-to-refresh gesture
2. WHEN a user triggers refresh, THE Power_Rankings SHALL re-fetch league data from the appropriate platform API
3. WHEN refresh is in progress, THE Power_Rankings SHALL display a loading indicator
4. WHEN new data is fetched, THE Power_Rankings SHALL recalculate power scores and update the display
5. IF Skidmark_Mode was previously enabled, THEN THE Power_Rankings SHALL clear existing roasts and require re-generation
6. IF refresh fails due to network or API errors, THEN THE Power_Rankings SHALL display an error message and retain previous data
7. THE Power_Rankings SHALL display the timestamp of the last successful data fetch

### Requirement 7: Export and Sharing

**User Story:** As a fantasy football player, I want to copy or share power rankings and roasts, so that I can post them to my league's WhatsApp group or other messaging platforms.

#### Acceptance Criteria

1. THE Export_Feature SHALL provide a "Copy to Clipboard" button that copies formatted rankings and roasts
2. THE Export_Feature SHALL provide a "Share" button that opens the iOS share sheet
3. WHEN copying to clipboard, THE Export_Feature SHALL format the output as plain text with team rankings and roasts
4. WHEN sharing via share sheet, THE Export_Feature SHALL support sharing to WhatsApp, Messages, Mail, and other iOS share targets
5. THE Export_Feature SHALL allow users to toggle whether to include roasts in the export (rankings only vs rankings + roasts)
6. WHEN roasts are not yet generated, THE Export_Feature SHALL only export power rankings without roast content
7. WHEN export is successful, THE Export_Feature SHALL display a confirmation message

### Requirement 8: League Management

**User Story:** As a fantasy football player, I want to manage multiple league connections, so that I can generate roasts for all my fantasy leagues in one app.

#### Acceptance Criteria

1. THE League_Connection SHALL support connecting multiple leagues simultaneously
2. THE League_Connection SHALL display a list of all connected leagues with league name and platform
3. WHEN a user selects a league from the list, THE League_Connection SHALL load that league's power rankings
4. THE League_Connection SHALL allow users to add new league connections from the league list view
5. THE League_Connection SHALL allow users to remove league connections from the league list view
6. WHEN a league is removed, THE League_Connection SHALL delete associated league context and cached data
7. THE League_Connection SHALL persist the list of connected leagues across app sessions

### Requirement 9: Error Handling

**User Story:** As a fantasy football player, I want clear error messages when something goes wrong, so that I can understand and resolve issues.

#### Acceptance Criteria

1. WHEN network connectivity is unavailable, THE Power_Rankings SHALL display a "No internet connection" message
2. WHEN ESPN authentication fails, THE ESPN_Platform SHALL display "Invalid ESPN cookies. Please check your ESPN_S2 and SWID values."
3. WHEN a league ID is not found, THE League_Connection SHALL display "League not found. Please verify your league ID."
4. WHEN AWS Bedrock API fails, THE Skidmark_Mode SHALL display "Roast generation failed. Please try again."
5. WHEN API rate limits are exceeded, THE Power_Rankings SHALL display "Too many requests. Please wait a moment and try again."
6. IF an unexpected error occurs, THEN THE Power_Rankings SHALL display a generic error message and log details for debugging
7. THE Power_Rankings SHALL provide actionable next steps in error messages (e.g., "Retry" button, "Check Settings" link)

### Requirement 10: Data Persistence

**User Story:** As a fantasy football player, I want my league connections and settings to persist between app sessions, so that I don't have to re-enter information every time I open the app.

#### Acceptance Criteria

1. THE League_Connection SHALL store connected league details (platform, league ID, league name) in local storage
2. THE ESPN_Platform SHALL store authentication cookies in iOS Keychain
3. THE League_Context SHALL store inside jokes, personalities, and culture notes in local storage
4. THE Power_Rankings SHALL cache the most recent league data and power rankings in local storage
5. WHEN the app launches, THE League_Connection SHALL load the most recently viewed league automatically
6. WHEN the app launches without internet, THE Power_Rankings SHALL display cached data with a "Last updated" timestamp
7. THE Power_Rankings SHALL clear cached data when a user explicitly removes a league connection

### Requirement 11: User Interface

**User Story:** As a fantasy football player, I want an intuitive and visually appealing interface, so that I can easily navigate the app and enjoy using it.

#### Acceptance Criteria

1. THE Power_Rankings SHALL display teams in a vertically scrollable list with clear visual hierarchy
2. THE Power_Rankings SHALL use distinct visual styling for top-tier teams (ranks 1-3), mid-tier teams, and bottom-tier teams
3. WHEN Skidmark_Mode is enabled, THE Power_Rankings SHALL expand each team row to show the roast text
4. THE Power_Rankings SHALL use appropriate typography and spacing for readability on iOS devices
5. THE League_Connection SHALL use native iOS form controls and validation patterns
6. THE Power_Rankings SHALL support both light and dark mode based on iOS system settings
7. THE Power_Rankings SHALL use iOS-native navigation patterns (navigation bar, tab bar, or similar)

### Requirement 12: Platform-Specific Data Transformation

**User Story:** As a developer, I want to normalize data from ESPN and Sleeper into a consistent format, so that the UI and business logic can work with both platforms uniformly.

#### Acceptance Criteria

1. WHEN fetching ESPN data, THE ESPN_Platform SHALL combine team location and nickname to form the team name
2. WHEN fetching ESPN data, THE ESPN_Platform SHALL extract owner first and last names from the owners array
3. WHEN fetching ESPN data, THE ESPN_Platform SHALL extract the top 5 starters by applied stat total (excluding bench and IR)
4. WHEN fetching Sleeper data, THE Sleeper_Platform SHALL use metadata.team_name or fallback to display_name for team names
5. WHEN fetching Sleeper data, THE Sleeper_Platform SHALL match roster owner_id to user user_id to associate owners with teams
6. THE Power_Rankings SHALL use a unified team data model regardless of source platform
7. THE Power_Rankings SHALL handle missing or null fields gracefully with sensible defaults
