# Requirements Document: Roast Enhancements

## Introduction

This document specifies three related enhancements to the Skidmark iOS app's roast system: historical roast navigation by week, richer player-specific roast prompts with detailed matchup data, and playoff-aware roasts that shift tone and content for postseason weeks. Together these changes transform roasts from a single-week snapshot into a season-long narrative that references specific player performances and adapts to the stakes of each phase of the fantasy season.

## Glossary

- **Roast_History**: The collection of previously generated roasts stored per league, indexed by season week number
- **Week_Navigator**: UI component that allows the user to move between weeks and view historical roasts
- **Matchup_Data**: Per-week head-to-head pairing information including each team's score, opponent, and individual player stat lines
- **Player_Stats**: Individual player performance data for a given week, including name, position, points scored, and key stat categories
- **Roast_Cache**: Local on-device storage of generated roasts keyed by league ID and week number
- **Season_Phase**: Classification of the current week as either regular season or playoffs, derived from league settings
- **Playoff_Bracket**: The postseason tournament structure including seeding, matchup pairings, elimination status, consolation bracket, and championship matchup
- **Backend_API**: The AWS Lambda roast generator service that calls Bedrock Claude to produce roasts
- **Current_Week**: The most recent or in-progress scoring week of the fantasy football season

## Requirements

### Requirement 1: Roast History Storage

**User Story:** As a fantasy football player, I want my generated roasts to be saved by week, so that I can look back at previous weeks' trash talk throughout the season.

#### Acceptance Criteria

1. WHEN roasts are generated for a league, THE Roast_Cache SHALL persist the roasts keyed by league ID and week number
2. WHEN storing roasts, THE Roast_Cache SHALL include the week number, generation timestamp, and the full set of team roasts
3. WHEN roasts already exist in the Roast_Cache for a given league and week, THE Roast_Cache SHALL overwrite the previous entry with the newly generated roasts
4. WHEN a league connection is removed, THE Roast_Cache SHALL delete all stored roasts for that league
5. THE Roast_Cache SHALL store roasts using the same on-device storage mechanism used by the existing StorageService

### Requirement 2: Week Navigation

**User Story:** As a fantasy football player, I want to navigate between weeks in the power rankings view, so that I can revisit roasts and standings from earlier in the season.

#### Acceptance Criteria

1. WHEN the power rankings view loads, THE Week_Navigator SHALL default to the Current_Week
2. THE Week_Navigator SHALL display the currently selected week number prominently
3. WHEN a user taps a "previous week" control, THE Week_Navigator SHALL navigate to the prior week's roasts and data
4. WHEN a user taps a "next week" control, THE Week_Navigator SHALL navigate to the following week's roasts and data
5. WHEN the selected week is week 1, THE Week_Navigator SHALL disable the "previous week" control
6. WHEN the selected week is the Current_Week, THE Week_Navigator SHALL disable the "next week" control
7. WHEN navigating to a week that has stored roasts, THE Week_Navigator SHALL load and display those roasts from the Roast_Cache
8. WHEN navigating to a week that has no stored roasts, THE Week_Navigator SHALL display the rankings without roasts and offer a "Generate Roasts" action
9. WHEN the user is viewing a historical week, THE Week_Navigator SHALL indicate that the data is from a past week

### Requirement 3: Matchup Data Integration

**User Story:** As a fantasy football player, I want roasts to reference specific player performances and head-to-head matchup results, so that the trash talk is more detailed and relevant each week.

#### Acceptance Criteria

1. WHEN fetching league data for a specific week, THE ESPN_Platform SHALL retrieve Matchup_Data including each team's weekly score and opponent
2. WHEN fetching league data for a specific week, THE Sleeper_Platform SHALL retrieve Matchup_Data including each team's weekly score and opponent
3. WHEN fetching Matchup_Data, THE ESPN_Platform SHALL include Player_Stats for each rostered player showing name, position, and points scored that week
4. WHEN fetching Matchup_Data, THE Sleeper_Platform SHALL include Player_Stats for each rostered player showing name, position, and points scored that week
5. WHEN sending roast generation requests, THE Backend_API request SHALL include Matchup_Data for the selected week alongside existing team and context data
6. THE Backend_API prompt SHALL instruct the AI to reference specific player performances, busts, breakout games, and head-to-head matchup outcomes in each roast

### Requirement 4: Enhanced Roast Prompt

**User Story:** As a fantasy football player, I want roasts that call out specific players who boomed or busted, so that the trash talk has more bite and feels personalized to each week.

#### Acceptance Criteria

1. WHEN building the roast prompt, THE Backend_API SHALL format each team's weekly matchup result (win/loss, score, opponent name and score)
2. WHEN building the roast prompt, THE Backend_API SHALL identify and highlight the top-scoring player and the lowest-scoring starter for each team
3. WHEN building the roast prompt, THE Backend_API SHALL include individual player stat lines (name, position, points) for all starters
4. THE Backend_API prompt SHALL instruct the AI to mention at least one specific player performance per roast
5. THE Backend_API prompt SHALL instruct the AI to mock teams that lost despite having a high-scoring player, or won despite a bust on their roster
6. IF Matchup_Data is unavailable for the selected week, THEN THE Backend_API SHALL fall back to the existing season-aggregate prompt format

### Requirement 5: Season Phase Detection

**User Story:** As a fantasy football player, I want the app to know whether the league is in regular season or playoffs, so that roasts can adapt their tone and content accordingly.

#### Acceptance Criteria

1. WHEN fetching league settings, THE ESPN_Platform SHALL extract the playoff start week and number of playoff teams
2. WHEN fetching league settings, THE Sleeper_Platform SHALL extract the playoff start week and number of playoff teams
3. WHEN the current week number is less than the playoff start week, THE Season_Phase SHALL be classified as regular season
4. WHEN the current week number is equal to or greater than the playoff start week, THE Season_Phase SHALL be classified as playoffs
5. THE Season_Phase SHALL be included in the roast generation request sent to the Backend_API

### Requirement 6: Playoff Roasts

**User Story:** As a fantasy football player, I want playoff-specific roasts that talk about elimination, bracket position, and championship stakes, so that the trash talk matches the intensity of the postseason.

#### Acceptance Criteria

1. WHEN the Season_Phase is playoffs, THE Backend_API prompt SHALL shift tone to emphasize elimination pressure, bracket stakes, and championship implications
2. WHEN the Season_Phase is playoffs, THE Backend_API prompt SHALL reference each team's playoff seed and current bracket position
3. WHEN a team has been eliminated, THE Backend_API prompt SHALL mock the elimination and reference consolation bracket status
4. WHEN two teams are matched in a playoff game, THE Backend_API prompt SHALL reference the specific head-to-head playoff matchup and what is at stake
5. WHEN the championship matchup is active, THE Backend_API prompt SHALL give the championship teams a distinct, elevated roast treatment
6. WHEN the Season_Phase is regular season, THE Backend_API prompt SHALL use the existing regular-season roast format without playoff references

### Requirement 7: Playoff Bracket Data

**User Story:** As a developer, I want to fetch and model playoff bracket data from ESPN and Sleeper, so that the roast generator has the context it needs for playoff-specific content.

#### Acceptance Criteria

1. WHEN the Season_Phase is playoffs, THE ESPN_Platform SHALL fetch Playoff_Bracket data including seeds, matchup pairings, and elimination status
2. WHEN the Season_Phase is playoffs, THE Sleeper_Platform SHALL fetch Playoff_Bracket data including seeds, matchup pairings, and elimination status
3. THE Playoff_Bracket data model SHALL include team seed, current round, opponent, win/loss status, and whether the team is in the winners or consolation bracket
4. WHEN sending playoff roast requests, THE Backend_API request SHALL include the Playoff_Bracket data alongside Matchup_Data and team data
5. IF Playoff_Bracket data is unavailable, THEN THE Backend_API SHALL generate roasts using the regular-season format with a note that playoff data could not be retrieved
