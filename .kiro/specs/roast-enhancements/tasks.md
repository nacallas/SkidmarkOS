# Implementation Plan: Roast Enhancements

## Overview

This plan implements roast history with week navigation, richer player-specific prompts with matchup data, and playoff-aware roasts. Work proceeds bottom-up: data models first, then storage, then platform services, then the backend Lambda, then the view model, and finally the UI. Testing tasks are interleaved close to the code they validate.

## Tasks

- [x] 1. Add new data models
  - [x] 1.1 Create `WeeklyMatchup`, `WeeklyPlayerStats`, `SeasonPhase`, `PlayoffBracketEntry`, `WeeklyRoastCache`, and `LeagueSettings` types in new files under `SkidmarkApp/Models/`
    - `WeeklyMatchup.swift`: `WeeklyMatchup` and `WeeklyPlayerStats` structs (Codable, Hashable)
    - `SeasonPhase.swift`: `SeasonPhase` enum and `SeasonPhaseDetector` utility
    - `PlayoffBracket.swift`: `PlayoffBracketEntry` struct
    - `WeeklyRoastCache.swift`: `WeeklyRoastCache` struct
    - `LeagueSettings.swift`: `LeagueSettings` struct
    - _Requirements: 1.2, 5.3, 5.4, 7.3_
  - [x]* 1.2 Write property test for SeasonPhaseDetector
    - **Property 13: Season phase detection**
    - For any (currentWeek, playoffStartWeek) pair where both >= 1, detect returns .regularSeason iff currentWeek < playoffStartWeek
    - **Validates: Requirements 5.3, 5.4**

- [x] 2. Extend StorageService with roast cache
  - [x] 2.1 Add `saveWeeklyRoasts`, `loadWeeklyRoasts`, `deleteAllRoasts`, and `availableRoastWeeks` methods to the `StorageService` protocol and `DefaultStorageService` implementation
    - Store as JSON files: `league_{id}_roasts_week_{n}.json`
    - Wire `deleteAllRoasts` into the existing `clearDataForLeague` method
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_
  - [x]* 2.2 Write property test for roast cache round-trip
    - **Property 1: Roast cache round-trip**
    - For any valid WeeklyRoastCache, save then load returns equivalent object
    - **Validates: Requirements 1.1, 1.2**
  - [x]* 2.3 Write property test for roast cache overwrite
    - **Property 2: Roast cache overwrite**
    - For any league+week, saving twice returns only the second entry
    - **Validates: Requirements 1.3**
  - [x]* 2.4 Write property test for roast cache deletion
    - **Property 3: Roast cache deletion**
    - For any league with roasts across multiple weeks, deleteAllRoasts clears all
    - **Validates: Requirements 1.4**

- [x] 3. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Add matchup and settings fetching to ESPN service
  - [x] 4.1 Add `fetchMatchupData(leagueId:season:week:)` method to `ESPNService`
    - Use the existing `mMatchup` view parameter (already requested) filtered by scoring period
    - Parse matchup schedule entries into `[WeeklyMatchup]` with full player stat lines
    - _Requirements: 3.1, 3.3_
  - [x] 4.2 Add `fetchLeagueSettings(leagueId:season:)` method to `ESPNService`
    - Extract `playoffStartWeek`, `playoffTeamCount`, `currentWeek` from the `mSettings` view
    - _Requirements: 5.1_
  - [x] 4.3 Add `fetchPlayoffBracket(leagueId:season:week:)` method to `ESPNService`
    - Parse playoff matchup schedule entries into `[PlayoffBracketEntry]`
    - _Requirements: 7.1_
  - [x]* 4.4 Write property test for ESPN matchup parsing
    - **Property 6: ESPN matchup parsing produces valid structures**
    - For any valid ESPN matchup JSON, parsed objects have non-empty team IDs, non-negative scores, valid player stats
    - **Validates: Requirements 3.1, 3.3**
  - [x]* 4.5 Write property test for ESPN league settings parsing
    - **Property 11: ESPN league settings parsing**
    - For any valid ESPN settings JSON, parsed LeagueSettings has playoffStartWeek > 0, playoffTeamCount > 0, currentWeek >= 1
    - **Validates: Requirements 5.1**
  - [x]* 4.6 Write property test for ESPN bracket parsing
    - **Property 16: ESPN bracket parsing**
    - For any valid ESPN bracket JSON, parsed entries have non-empty team ID, seed >= 1, consistent boolean flags
    - **Validates: Requirements 7.1**

- [x] 5. Add matchup and settings fetching to Sleeper service
  - [x] 5.1 Add `fetchMatchupData(leagueId:season:week:)` method to `SleeperService`
    - Use Sleeper's `/league/{id}/matchups/{week}` endpoint
    - Pair rosters by `matchup_id`, resolve player names from Sleeper's player map
    - _Requirements: 3.2, 3.4_
  - [x] 5.2 Add `fetchLeagueSettings(leagueId:season:)` method to `SleeperService`
    - Extract playoff config from the existing `/league/{id}` response
    - _Requirements: 5.2_
  - [x] 5.3 Add `fetchPlayoffBracket(leagueId:season:week:)` method to `SleeperService`
    - Use Sleeper's `/league/{id}/winners_bracket` and `/league/{id}/losers_bracket` endpoints
    - _Requirements: 7.2_
  - [x]* 5.4 Write property test for Sleeper matchup parsing
    - **Property 7: Sleeper matchup parsing produces valid structures**
    - **Validates: Requirements 3.2, 3.4**
  - [x]* 5.5 Write property test for Sleeper league settings parsing
    - **Property 12: Sleeper league settings parsing**
    - **Validates: Requirements 5.2**
  - [x]* 5.6 Write property test for Sleeper bracket parsing
    - **Property 17: Sleeper bracket parsing**
    - **Validates: Requirements 7.2**

- [x] 6. Update LeagueDataService protocol
  - [x] 6.1 Add `fetchMatchupData`, `fetchLeagueSettings`, and `fetchPlayoffBracket` to the `LeagueDataService` protocol with default implementations that throw "not supported"
    - Ensure both ESPNService and SleeperService conform
    - _Requirements: 3.1, 3.2, 5.1, 5.2, 7.1, 7.2_

- [x] 7. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Enhance the backend Lambda prompt
  - [x] 8.1 Update `roast_generator.py` to accept and parse the expanded request body (`matchups`, `week_number`, `season_phase`, `playoff_bracket`)
    - Add backward compatibility: if `matchups` is missing, use existing prompt format
    - _Requirements: 3.5, 4.6_
  - [x] 8.2 Update `_build_prompt` to include a "THIS WEEK'S MATCHUPS" section with per-team scores, opponent, all starter stat lines, top scorer highlight, and biggest bust highlight
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
  - [x] 8.3 Add playoff prompt mode to `_build_prompt` that activates when `season_phase` is `"playoffs"`
    - Swap the roasting approach section to emphasize elimination, bracket stakes, seeds, championship
    - Include a "PLAYOFF BRACKET" section when bracket data is provided
    - Fall back to regular-season format when bracket data is nil/empty
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 7.5_
  - [x]* 8.4 Write property test for prompt includes matchup and player data (Python/hypothesis)
    - **Property 9: Prompt includes matchup and player data**
    - **Validates: Requirements 4.1, 4.2, 4.3**
  - [x]* 8.5 Write property test for empty matchups fallback (Python/hypothesis)
    - **Property 10: Empty matchups fall back to legacy prompt**
    - **Validates: Requirements 4.6**
  - [x]* 8.6 Write property test for phase-appropriate prompt content (Python/hypothesis)
    - **Property 14: Prompt content is phase-appropriate**
    - **Validates: Requirements 6.1, 6.6**
  - [x]* 8.7 Write property test for playoff bracket data in prompt (Python/hypothesis)
    - **Property 15: Playoff bracket data appears in prompt**
    - **Validates: Requirements 6.2, 6.3, 6.4, 6.5**
  - [x]* 8.8 Write property test for playoff bracket fallback (Python/hypothesis)
    - **Property 18: Playoff bracket fallback**
    - **Validates: Requirements 7.5**

- [x] 9. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Extend BackendService with enhanced roast generation
  - [x] 10.1 Add the new `generateRoasts(teams:context:matchups:weekNumber:seasonPhase:playoffBracket:)` method to `BackendService` protocol and `AWSBackendService`
    - Build the expanded request body with matchups, week_number, season_phase, playoff_bracket
    - Keep the existing `generateRoasts(teams:context:)` method as a convenience that calls the new one with empty matchups and regular-season phase
    - _Requirements: 3.5, 5.5, 7.4_
  - [x]* 10.2 Write property test for enhanced request serialization
    - **Property 8: Enhanced request serialization includes all fields**
    - **Validates: Requirements 3.5, 5.5, 7.4**

- [x] 11. Update PowerRankingsViewModel with week navigation and matchup awareness
  - [x] 11.1 Add week navigation state (`selectedWeek`, `currentWeek`, `availableWeeks`) and `navigateToWeek(_ week:)` method
    - Load cached roasts when navigating to a historical week
    - Fetch fresh matchup data when generating roasts for a week
    - _Requirements: 2.1, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8_
  - [x] 11.2 Integrate season phase detection and playoff bracket fetching into the data load flow
    - Call `fetchLeagueSettings` on initial load, determine `SeasonPhase`, fetch bracket if playoffs
    - Pass phase and bracket data to the enhanced `generateRoasts` call
    - _Requirements: 5.3, 5.4, 5.5, 6.1, 7.4_
  - [x] 11.3 Wire roast persistence: save generated roasts to `WeeklyRoastCache` after generation, load from cache on week navigation
    - _Requirements: 1.1, 1.2, 1.3, 2.7_
  - [x]* 11.4 Write property test for week navigation bounds
    - **Property 4: Week navigation bounds**
    - **Validates: Requirements 2.3, 2.4, 2.5, 2.6**
  - [x]* 11.5 Write property test for cache load on week navigation
    - **Property 5: Cache load on week navigation**
    - **Validates: Requirements 2.7**

- [x] 12. Update PowerRankingsView with week navigator UI
  - [x] 12.1 Add a week selector bar above the team list in `PowerRankingsView`
    - Show "Week N" label (or "Week N - Playoffs" when in postseason)
    - Left/right chevron buttons wired to `navigateToWeek`
    - Disable left at week 1, disable right at currentWeek
    - Show "Generate Roasts" button when viewing a week with no cached roasts
    - Show "Past Week" indicator when viewing historical data
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.8, 2.9_

- [x] 13. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- Swift property tests use `swift-testing` with SwiftCheck or a custom helper
- Python property tests use `hypothesis`
